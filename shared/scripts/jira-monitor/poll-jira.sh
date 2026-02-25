#!/bin/zsh

# =============================================================================
# poll-jira.sh
#
# Scheduled wrapper: polls Jira for "To Do" tickets assigned to the current
# user and invokes check-jira.sh for each ticket. check-jira.sh handles
# branch naming, GH branch checks, repo relevance (determine-repos skill),
# and sequential backend/frontend implementation.
#
# Usage: poll-jira.sh [--dry-run]
#   --dry-run  Validate config and Jira connectivity only; do not process tickets.
# =============================================================================

# ---- CONFIG: Jira ----
# Credentials are read from environment variables (set in ~/.zshrc):
#   JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN
JIRA_BASE_URL="${JIRA_URL:?Set JIRA_URL in your shell profile}"
EMAIL="${JIRA_EMAIL:?Set JIRA_EMAIL in your shell profile}"
API_TOKEN="${JIRA_API_TOKEN:?Set JIRA_API_TOKEN in your shell profile}"

JQL='assignee = currentUser() AND status = "To Do"'

# ---- CONFIG: Paths ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_JIRA_SCRIPT="$SCRIPT_DIR/check-jira.sh"
LOG_DIR="$SCRIPT_DIR/logs"
LOCK_FILE="$SCRIPT_DIR/.check-jira.lock"
# AI repo root (parent of shared/) — needed so determine-repos skill can read indicator files
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

  if [[ ! -x "$CHECK_JIRA_SCRIPT" ]]; then
    echo "[$(date)] ❌ check-jira.sh not executable or missing: $CHECK_JIRA_SCRIPT"
    FAIL=1
  fi

  if [[ ! -d "$AI_REPO_ROOT" ]]; then
    echo "[$(date)] ❌ AI repo root not found: $AI_REPO_ROOT"
    FAIL=1
  elif [[ ! -f "$AI_REPO_ROOT/shared/.claude/skills/determine-repos/SKILL.md" ]]; then
    echo "[$(date)] ❌ AI repo missing determine-repos skill: $AI_REPO_ROOT/shared/.claude/skills/determine-repos/SKILL.md"
    FAIL=1
  fi

  BRANCH_SCRIPT="$SCRIPT_DIR/generate-branch-name.sh"
  if [[ ! -x "$BRANCH_SCRIPT" ]]; then
    echo "[$(date)] ❌ Branch name script not executable or missing: $BRANCH_SCRIPT"
    FAIL=1
  fi

  if ! command -v gh &>/dev/null; then
    echo "[$(date)] ❌ gh CLI not found (required for branch/PR checks)."
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

log() {
  echo "[$(date)] $1"
}

log "Lock acquired (PID $$)."
log "Config: CHECK_JIRA_SCRIPT=$CHECK_JIRA_SCRIPT | AI_REPO_ROOT=$AI_REPO_ROOT | LOG_DIR=$LOG_DIR"
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
# MAIN: Query Jira and invoke check-jira.sh for each ticket
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

for TICKET_KEY in ${(s: :)TICKET_KEYS}; do
  log "[$TICKET_KEY] ---------- Starting ticket ----------"
  "$CHECK_JIRA_SCRIPT" "$TICKET_KEY"
  log "[$TICKET_KEY] ---------- Finished ticket ----------"
  echo ""
done

log "All tickets processed. Done."
