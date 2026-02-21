#!/bin/zsh

# =============================================================================
# check-jira.sh
#
# Polls Jira for "To Do" tickets assigned to the current user. For each ticket:
# 1. Generates a branch name (generate-branch-name skill)
# 2. Determines which repos need changes (check-jira skill: backend-only, frontend-only, or both)
# 3. Launches Cursor Agent CLI only in those repos to run start-jira-work.
#
# The start-jira-work skill handles branch creation, implementation, commits,
# status transition, PR creation, etc. This script finds tickets and kicks off
# only the relevant repo agents.
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

# =============================================================================
# MAIN: Query Jira and kick off agents
# =============================================================================
log "Querying Jira for To Do tickets..."

RESPONSE=$(curl -s -u "$EMAIL:$API_TOKEN" \
  -G "$JIRA_BASE_URL/rest/api/3/search/jql" \
  --data-urlencode "jql=$JQL" \
  --data-urlencode "fields=key,summary")

COUNT=$(echo "$RESPONSE" | jq '.issues | length')

if [[ -z "$COUNT" || "$COUNT" == "null" || "$COUNT" -eq 0 ]]; then
  log "No To Do tickets found. Exiting."
  exit 0
fi

log "Found $COUNT To Do ticket(s). Processing..."
echo ""

# Iterate through each ticket
echo "$RESPONSE" | jq -r '.issues[].key' | while IFS= read -r TICKET_KEY; do
  log "--- Kicking off $TICKET_KEY ---"

  # Generate branch name using the centralized generate-branch-name skill
  # This ensures single source of truth for branch naming logic
  log "Generating branch name using generate-branch-name skill..."
  BRANCH_NAME_OUTPUT=$("$AGENT_BIN" -p --workspace "$SCRIPT_DIR/../.." \
    "Use the generate-branch-name skill to generate a branch name for Jira ticket $TICKET_KEY. Return ONLY the branch name, nothing else." 2>&1)
  
  # Extract just the branch name from the output (last non-empty line)
  BRANCH_NAME=$(echo "$BRANCH_NAME_OUTPUT" | grep -v '^$' | tail -1 | tr -d '\n\r ')
  
  if [[ -z "$BRANCH_NAME" || "$BRANCH_NAME" == *"error"* || "$BRANCH_NAME" == *"Error"* || "$BRANCH_NAME" == *"Authentication"* ]]; then
    log "Failed to generate branch name for $TICKET_KEY. Output:"
    log "$BRANCH_NAME_OUTPUT"
    log "Skipping ticket."
    continue
  fi
  
  log "Branch name: $BRANCH_NAME"

  # Determine which repos need work using the shared check-jira skill
  log "Determining which repos need changes (check-jira skill)..."
  DECISION_OUTPUT=$("$AGENT_BIN" -p --workspace "$AI_REPO_ROOT" \
    "Use the check-jira skill to determine which repos need changes for Jira ticket $TICKET_KEY. Return ONLY the decision: backend-only, frontend-only, or both." 2>&1)

  DECISION=$(echo "$DECISION_OUTPUT" | grep -v '^$' | tail -1 | tr -d '\n\r ')

  case "$DECISION" in
    backend-only|frontend-only|both) ;;
    *) log "Unrecognized decision '$DECISION', defaulting to 'both'"; DECISION="both" ;;
  esac
  log "Decision: $DECISION"

  BACKEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_backend.log"
  FRONTEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_frontend.log"
  BACKEND_EXIT=""
  FRONTEND_EXIT=""

  # Run agents only for repos that need work. REPO_NEEDED=true so start-jira-work skips its own relevance check.
  if [[ "$DECISION" == "backend-only" || "$DECISION" == "both" ]]; then
    echo ""
    log "========================================="
    log "BACKEND: Starting agent for $TICKET_KEY"
    log "========================================="
    log "Workspace: $BACKEND_REPO"
    log "Log file: $BACKEND_LOG"
    echo ""

    JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
      BRANCH_NAME="$BRANCH_NAME" REPO_NEEDED="true" \
      "$AGENT_BIN" -p -f --approve-mcps --workspace "$BACKEND_REPO" \
      "Start work on Jira ticket $TICKET_KEY" \
      2>&1 | tee "$BACKEND_LOG"
    BACKEND_EXIT=${PIPESTATUS[0]}

    echo ""
    log "Backend agent completed with exit code: $BACKEND_EXIT"
    log "Full backend log saved to: $BACKEND_LOG"
    echo ""
  else
    log "Skipping backend (not needed for this ticket)."
  fi

  if [[ "$DECISION" == "frontend-only" || "$DECISION" == "both" ]]; then
    log "========================================="
    log "FRONTEND: Starting agent for $TICKET_KEY"
    log "========================================="
    log "Workspace: $FRONTEND_REPO"
    log "Log file: $FRONTEND_LOG"
    echo ""

    JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
      BRANCH_NAME="$BRANCH_NAME" REPO_NEEDED="true" \
      "$AGENT_BIN" -p -f --approve-mcps --workspace "$FRONTEND_REPO" \
      "Start work on Jira ticket $TICKET_KEY" \
      2>&1 | tee "$FRONTEND_LOG"
    FRONTEND_EXIT=${PIPESTATUS[0]}

    echo ""
    log "Frontend agent completed with exit code: $FRONTEND_EXIT"
    log "Full frontend log saved to: $FRONTEND_LOG"
    echo ""
  else
    log "Skipping frontend (not needed for this ticket)."
  fi

  log "========================================="
  log "Summary for $TICKET_KEY"
  log "========================================="
  log "Backend:  exit=${BACKEND_EXIT:-skipped} | log=$BACKEND_LOG"
  log "Frontend: exit=${FRONTEND_EXIT:-skipped} | log=$FRONTEND_LOG"
  log "========================================="
  echo ""
done

log "All tickets processed. Done."
