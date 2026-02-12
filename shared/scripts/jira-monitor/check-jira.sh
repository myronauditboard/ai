#!/bin/zsh

# =============================================================================
# check-jira.sh
#
# Polls Jira for "To Do" tickets assigned to the current user and launches
# Cursor Agent CLI (headless) in both auditboard-backend and auditboard-frontend
# repos to execute the start-jira-work skill for each ticket.
#
# The skill itself handles everything: Jira lookup, branch creation,
# implementation, commits, status transition, PR creation, etc.
# This script is just the orchestrator that finds tickets and kicks off agents.
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
  BRANCH_NAME_OUTPUT=$("$AGENT_BIN" -p --workspace "$SCRIPT_DIR/../general" \
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

  BACKEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_backend.log"
  FRONTEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_frontend.log"

  # Launch backend and frontend agents in parallel — each agent reads
  # the start-jira-work skill and handles the full workflow autonomously.
  # Export Jira credentials so the agent can transition tickets via REST API.
  # Also pass BRANCH_NAME so both repos use the same branch name.
  log "Launching agent for $TICKET_KEY in backend..."
  JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
    BRANCH_NAME="$BRANCH_NAME" \
    "$AGENT_BIN" -p -f --approve-mcps --workspace "$BACKEND_REPO" \
    "Start work on Jira ticket $TICKET_KEY" \
    > "$BACKEND_LOG" 2>&1 &
  BACKEND_PID=$!

  log "Launching agent for $TICKET_KEY in frontend..."
  JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
    BRANCH_NAME="$BRANCH_NAME" \
    "$AGENT_BIN" -p -f --approve-mcps --workspace "$FRONTEND_REPO" \
    "Start work on Jira ticket $TICKET_KEY" \
    > "$FRONTEND_LOG" 2>&1 &
  FRONTEND_PID=$!

  # Wait for both agents to finish
  log "Waiting for agents (backend PID=$BACKEND_PID, frontend PID=$FRONTEND_PID)..."
  wait $BACKEND_PID
  BACKEND_EXIT=$?
  wait $FRONTEND_PID
  FRONTEND_EXIT=$?

  log "Agent results for $TICKET_KEY: backend=$BACKEND_EXIT, frontend=$FRONTEND_EXIT"
  log "  Backend log:  $BACKEND_LOG"
  log "  Frontend log: $FRONTEND_LOG"
  echo ""
done

log "All tickets processed. Done."
