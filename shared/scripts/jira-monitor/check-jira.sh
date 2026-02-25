#!/bin/zsh

# =============================================================================
# check-jira.sh
#
# Polls Jira for "To Do" tickets assigned to the current user. For each ticket:
# 1. Generates a branch name (generate-branch-name.sh script)
# 2. Determines which repos need changes (check-jira skill: backend-only, frontend-only, or both)
# 3. Launches Cursor Agent CLI only in those repos to run start-jira-work.
#
# The start-jira-work skill handles branch creation, implementation, commits,
# status transition, PR creation, etc. This script finds tickets and kicks off
# only the relevant repo agents.
#
# Usage: check-jira.sh [--dry-run]
#   --dry-run  Validate config and Jira connectivity only; do not process tickets.
# =============================================================================

# ---- CONFIG: Jira ----
# Credentials are read from environment variables (set in ~/.zshrc):
#   JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN
JIRA_BASE_URL="${JIRA_URL:?Set JIRA_URL in your shell profile}"
EMAIL="${JIRA_EMAIL:?Set JIRA_EMAIL in your shell profile}"
API_TOKEN="${JIRA_API_TOKEN:?Set JIRA_API_TOKEN in your shell profile}"

JQL='assignee = currentUser() AND status = "To Do"'

# ---- CONFIG: Repos & Agent ----
BACKEND_REPO="/Users/myeung/Development/auditboard-backend"
FRONTEND_REPO="/Users/myeung/Development/auditboard-frontend"
AGENT_BIN="/Users/myeung/.local/bin/agent"

# ---- CONFIG: Paths ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOCK_FILE="$SCRIPT_DIR/.check-jira.lock"
# AI repo root (parent of shared/) — needed so check-jira skill can read backend/ and frontend/ indicator files
AI_REPO_ROOT="$SCRIPT_DIR/../../.."

# Parse args (before lock so --dry-run doesn't require lock)
DRY_RUN=0
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=1
    break
  fi
done

# =============================================================================
# DRY-RUN: validate config and connectivity only
# =============================================================================
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[$(date)] --- Dry run: validating configuration ---"
  FAIL=0

  if ! command -v jq &>/dev/null; then
    echo "[$(date)] ❌ jq is not installed (required for Jira response parsing)."
    FAIL=1
  fi

  if [[ ! -x "$AGENT_BIN" ]]; then
    echo "[$(date)] ❌ Agent binary not executable or missing: $AGENT_BIN"
    FAIL=1
  fi

  if [[ ! -d "$BACKEND_REPO" ]]; then
    echo "[$(date)] ❌ Backend repo not found or not a directory: $BACKEND_REPO"
    FAIL=1
  fi

  if [[ ! -d "$FRONTEND_REPO" ]]; then
    echo "[$(date)] ❌ Frontend repo not found or not a directory: $FRONTEND_REPO"
    FAIL=1
  fi

  if [[ ! -d "$AI_REPO_ROOT" ]]; then
    echo "[$(date)] ❌ AI repo root not found: $AI_REPO_ROOT"
    FAIL=1
  elif [[ ! -f "$AI_REPO_ROOT/shared/.claude/skills/check-jira/SKILL.md" ]]; then
    echo "[$(date)] ❌ AI repo missing check-jira skill: $AI_REPO_ROOT/shared/.claude/skills/check-jira/SKILL.md"
    FAIL=1
  fi

  BRANCH_SCRIPT="$SCRIPT_DIR/generate-branch-name.sh"
  if [[ ! -x "$BRANCH_SCRIPT" ]]; then
    echo "[$(date)] ❌ Branch name script not executable or missing: $BRANCH_SCRIPT"
    FAIL=1
  fi

  echo -n "[$(date)] Jira: "
  JIRA_RESPONSE=$(curl -s -w "\n%{http_code}" -u "$EMAIL:$API_TOKEN" \
    -G "$JIRA_BASE_URL/rest/api/3/myself" 2>/dev/null)
  JIRA_HTTP=$(echo "$JIRA_RESPONSE" | tail -1)
  if [[ "$JIRA_HTTP" == "200" ]]; then
    echo "OK (authenticated)."
  else
    echo "FAILED (HTTP $JIRA_HTTP). Check JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN."
    FAIL=1
  fi

  if [[ "$FAIL" -eq 1 ]]; then
    echo "[$(date)] --- Dry run failed. Fix the issues above and try again. ---"
    exit 1
  fi
  echo "[$(date)] --- Dry run passed. Configuration is valid. ---"
  exit 0
fi

# =============================================================================
# LOCK FILE — prevent overlapping runs (agent workflows can take 10-60+ min)
# =============================================================================
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "[$(date)] Previous run (PID $LOCK_PID) still active. Skipping."
    exit 0
  else
    echo "[$(date)] Stale lock file found (PID $LOCK_PID no longer running). Removing."
    rm -f "$LOCK_FILE"
  fi
fi

echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# =============================================================================
# LOGGING
# =============================================================================
mkdir -p "$LOG_DIR"
RUN_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

log() {
  echo "[$(date)] $1"
}

log "Lock acquired (PID $$)."
log "Config: AGENT_BIN=$AGENT_BIN | AI_REPO_ROOT=$AI_REPO_ROOT | LOG_DIR=$LOG_DIR"
echo ""

# Clear cert env vars that point to missing files (e.g. /rootCA.pem from .zshrc).
# The agent fails with "Security command failed" when these point to a path that doesn't exist.
for _var in NODE_EXTRA_CA_CERTS SSL_CERT_FILE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE; do
  _val="${(P)_var}"
  if [[ -n "$_val" && ! -f "$_val" ]]; then
    unset "$_var"
    log "Unset $_var (pointed to missing file: $_val)"
  fi
done

# =============================================================================
# MAIN: Query Jira and kick off agents
# =============================================================================
log "[Jira] Querying To Do tickets (JQL: $JQL)..."

RESPONSE=$(curl -s -u "$EMAIL:$API_TOKEN" \
  -G "$JIRA_BASE_URL/rest/api/3/search/jql" \
  --data-urlencode "jql=$JQL" \
  --data-urlencode "fields=key,summary")

COUNT=$(echo "$RESPONSE" | jq '.issues | length')

if [[ -z "$COUNT" || "$COUNT" == "null" || "$COUNT" -eq 0 ]]; then
  log "[Jira] No To Do tickets found. Exiting."
  exit 0
fi

TICKET_KEYS=$(echo "$RESPONSE" | jq -r '.issues[].key' | tr '\n' ' ')
log "[Jira] Found $COUNT ticket(s): $TICKET_KEYS"
log "[Jira] Starting processing."
echo ""

# Iterate through each ticket (key and summary from Jira response; summary normalized to one line for parsing)
echo "$RESPONSE" | jq -r '.issues[] | [.key, ((.fields.summary // "") | gsub("\n"; " ") | gsub("\t"; " "))] | @tsv' | while IFS=$'\t' read -r TICKET_KEY TICKET_SUMMARY; do
  log "[$TICKET_KEY] ---------- Starting ticket ----------"

  # Generate branch name via script (deterministic; no agent call)
  BRANCH_NAME=$("$SCRIPT_DIR/generate-branch-name.sh" "$TICKET_KEY" "$TICKET_SUMMARY")
  log "[$TICKET_KEY] [1/3] Branch name: $BRANCH_NAME (from script)"

  # Check if branch already exists in each repo (avoid launching agents that would immediately exit)
  log "[$TICKET_KEY] [1/3] Branch exists check: fetching and listing branches in backend and frontend repos..."
  (git -C "$BACKEND_REPO" fetch origin 2>/dev/null; git -C "$BACKEND_REPO" branch -a 2>/dev/null) | grep -wqF "$BRANCH_NAME" && BACKEND_BRANCH_EXISTS=1 || BACKEND_BRANCH_EXISTS=0
  (git -C "$FRONTEND_REPO" fetch origin 2>/dev/null; git -C "$FRONTEND_REPO" branch -a 2>/dev/null) | grep -wqF "$BRANCH_NAME" && FRONTEND_BRANCH_EXISTS=1 || FRONTEND_BRANCH_EXISTS=0
  log "[$TICKET_KEY] [1/3] Branch exists: backend=$([[ "$BACKEND_BRANCH_EXISTS" -eq 1 ]] && echo "yes" || echo "no"), frontend=$([[ "$FRONTEND_BRANCH_EXISTS" -eq 1 ]] && echo "yes" || echo "no")"

  if [[ "$BACKEND_BRANCH_EXISTS" -eq 1 && "$FRONTEND_BRANCH_EXISTS" -eq 1 ]]; then
    log "[$TICKET_KEY] Branch $BRANCH_NAME already exists in both repos; skipping ticket (no check-jira or repo agents)."
    echo ""
    continue
  fi

  # Invoke the check-jira skill to decide which repos need work (agent output may include extra text; we parse the result next)
  log "[$TICKET_KEY] [2/3] Repo decision: invoking check-jira agent (workspace=$AI_REPO_ROOT)"
  DECISION_START=$(date +%s)
  DECISION_OUTPUT=$("$AGENT_BIN" -p --workspace "$AI_REPO_ROOT" \
    "Use the check-jira skill to determine which repos need changes for Jira ticket $TICKET_KEY. Return ONLY the decision: backend-only, frontend-only, or both." 2>&1)
  DECISION_END=$(date +%s)
  log "[$TICKET_KEY] [2/3] Repo decision: agent finished in $((DECISION_END - DECISION_START))s"

  # Parse agent output: extract decision token (agent may wrap in markdown or add extra lines)
  DECISION=$(echo "$DECISION_OUTPUT" | grep -oE 'backend-only|frontend-only|both' | tail -1)
  if [[ -z "$DECISION" ]]; then
    log "[$TICKET_KEY] [2/3] Repo decision: could not parse output, defaulting to 'both'"
    DECISION="both"
  fi
  log "[$TICKET_KEY] [2/3] Repo decision: $DECISION"

  BACKEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_backend.log"
  FRONTEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_frontend.log"
  BACKEND_EXIT=""
  FRONTEND_EXIT=""

  RUN_BACKEND=$([[ "$DECISION" == "backend-only" || "$DECISION" == "both" ]] && [[ "$BACKEND_BRANCH_EXISTS" -eq 0 ]] && echo "yes" || echo "no")
  RUN_FRONTEND=$([[ "$DECISION" == "frontend-only" || "$DECISION" == "both" ]] && [[ "$FRONTEND_BRANCH_EXISTS" -eq 0 ]] && echo "yes" || echo "no")
  log "[$TICKET_KEY] [3/3] Repo agents: will run backend=$RUN_BACKEND, frontend=$RUN_FRONTEND"

  # Run agents only for repos that need work and where the branch does not already exist.
  # REPO_NEEDED=true so start-jira-work skips its own relevance check.
  if [[ "$RUN_BACKEND" == "yes" ]]; then
    echo ""
    log "[$TICKET_KEY] [3/3] BACKEND: launching agent (workspace=$BACKEND_REPO, log=$BACKEND_LOG)"
    BACKEND_START=$(date +%s)

    JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
      BRANCH_NAME="$BRANCH_NAME" REPO_NEEDED="true" \
      "$AGENT_BIN" -p -f --approve-mcps --workspace "$BACKEND_REPO" \
      "Start work on Jira ticket $TICKET_KEY" \
      2>&1 | tee "$BACKEND_LOG"
    BACKEND_EXIT=${PIPESTATUS[0]}
    BACKEND_END=$(date +%s)

    log "[$TICKET_KEY] [3/3] BACKEND: finished in $((BACKEND_END - BACKEND_START))s, exit=$BACKEND_EXIT"
    echo ""
  else
    if [[ "$BACKEND_BRANCH_EXISTS" -eq 1 ]]; then
      log "[$TICKET_KEY] [3/3] BACKEND: skipped (branch $BRANCH_NAME already exists)."
    else
      log "[$TICKET_KEY] [3/3] BACKEND: skipped (not needed for this ticket)."
    fi
  fi

  if [[ "$RUN_FRONTEND" == "yes" ]]; then
    log "[$TICKET_KEY] [3/3] FRONTEND: launching agent (workspace=$FRONTEND_REPO, log=$FRONTEND_LOG)"
    FRONTEND_START=$(date +%s)

    JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
      BRANCH_NAME="$BRANCH_NAME" REPO_NEEDED="true" \
      "$AGENT_BIN" -p -f --approve-mcps --workspace "$FRONTEND_REPO" \
      "Start work on Jira ticket $TICKET_KEY" \
      2>&1 | tee "$FRONTEND_LOG"
    FRONTEND_EXIT=${PIPESTATUS[0]}
    FRONTEND_END=$(date +%s)

    log "[$TICKET_KEY] [3/3] FRONTEND: finished in $((FRONTEND_END - FRONTEND_START))s, exit=$FRONTEND_EXIT"
    echo ""
  else
    if [[ "$FRONTEND_BRANCH_EXISTS" -eq 1 ]]; then
      log "[$TICKET_KEY] [3/3] FRONTEND: skipped (branch $BRANCH_NAME already exists)."
    else
      log "[$TICKET_KEY] [3/3] FRONTEND: skipped (not needed for this ticket)."
    fi
  fi

  log "[$TICKET_KEY] ---------- Summary: backend exit=${BACKEND_EXIT:-skipped}, frontend exit=${FRONTEND_EXIT:-skipped} ----------"
  echo ""
done

log "All tickets processed. Done."
