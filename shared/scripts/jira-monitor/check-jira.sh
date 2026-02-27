#!/bin/zsh

# =============================================================================
# check-jira.sh
#
# Single-ticket orchestrator: given a Jira ticket key, validates it is assigned
# to you and in To Do, generates the branch name, checks if the branch already
# exists in auditboard-backend or auditboard-frontend via GitHub. If it exists,
# opens the PR or branch page and exits. Otherwise uses the determine-repos
# skill to decide backend/frontend/both, then runs backend then frontend
# implementation (start-jira-work) sequentially.
#
# Usage: check-jira.sh <TICKET_KEY>
#   e.g. check-jira.sh SOX-84649
#
# Called by poll-jira.sh for each To Do ticket, or run manually with a ticket ID.
# =============================================================================

set -e

TICKET_KEY="${1:?Usage: check-jira.sh <TICKET_KEY>}"

# ---- CONFIG: Jira ----
JIRA_BASE_URL="${JIRA_URL:?Set JIRA_URL in your shell profile}"
EMAIL="${JIRA_EMAIL:?Set JIRA_EMAIL in your shell profile}"
API_TOKEN="${JIRA_API_TOKEN:?Set JIRA_API_TOKEN in your shell profile}"

# ---- CONFIG: Repos & Agent ----
BACKEND_REPO="/Users/myeung/Development/auditboard-backend"
FRONTEND_REPO="/Users/myeung/Development/auditboard-frontend"
GH_ORG="soxhub"
BACKEND_GH_REPO="${GH_ORG}/auditboard-backend"
FRONTEND_GH_REPO="${GH_ORG}/auditboard-frontend"
AGENT_BIN="/Users/myeung/.local/bin/agent"

# ---- CONFIG: Paths ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
AI_REPO_ROOT="$SCRIPT_DIR/../../.."

STALL_TIMEOUT=${STALL_TIMEOUT:-1200}  # kill agent after 20 min with no output
MAX_RUNTIME=${MAX_RUNTIME:-7200}      # kill agent after 120 min total

log() {
  echo "[$(date)] $1"
}

# run_agent LOG_FILE COMMAND...
# Runs COMMAND in background, streams output to LOG_FILE and stdout, and
# watches for stalls (no new output) or max runtime exceeded.
# Returns the agent's exit code, or 143 if killed by the watchdog.
run_agent() {
  local log_file="$1"; shift

  : > "$log_file"
  "$@" > "$log_file" 2>&1 &
  local agent_pid=$!

  tail -f "$log_file" &
  local tail_pid=$!

  local start_time=$SECONDS
  local last_size=0
  local last_change=$SECONDS

  while kill -0 $agent_pid 2>/dev/null; do
    sleep 15
    local cur_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
    if [[ "$cur_size" -ne "$last_size" ]]; then
      last_size=$cur_size
      last_change=$SECONDS
    fi

    local stall=$(( SECONDS - last_change ))
    local runtime=$(( SECONDS - start_time ))

    if [[ $stall -ge $STALL_TIMEOUT ]]; then
      log "Watchdog: agent (PID $agent_pid) stalled for ${stall}s. Killing."
      kill $agent_pid 2>/dev/null
      break
    fi
    if [[ $runtime -ge $MAX_RUNTIME ]]; then
      log "Watchdog: agent (PID $agent_pid) exceeded max runtime (${runtime}s). Killing."
      kill $agent_pid 2>/dev/null
      break
    fi
  done

  wait $agent_pid 2>/dev/null
  local rc=$?
  kill $tail_pid 2>/dev/null
  wait $tail_pid 2>/dev/null
  return $rc
}

mkdir -p "$LOG_DIR"

# =============================================================================
# Step 1: JQL validation — ticket must be assigned to me and status To Do
# =============================================================================
JQL="key = \"$TICKET_KEY\" AND assignee = currentUser() AND status = \"To Do\""
RESPONSE=$(curl -s -u "$EMAIL:$API_TOKEN" \
  -G "$JIRA_BASE_URL/rest/api/3/search/jql" \
  --data-urlencode "jql=$JQL" \
  --data-urlencode "fields=key,summary" \
  --data-urlencode "maxResults=1")

COUNT=$(echo "$RESPONSE" | jq '.issues | length')
if [[ -z "$COUNT" || "$COUNT" == "null" || "$COUNT" -eq 0 ]]; then
  log "[$TICKET_KEY] Ticket not found, not assigned to you, or not in To Do. Exiting."
  exit 0
fi

TICKET_SUMMARY=$(echo "$RESPONSE" | jq -r '.issues[0].fields.summary // ""' | sed 's/\n/ /g' | sed 's/\t/ /g')
log "[$TICKET_KEY] Ticket valid (assigned to me, To Do). Summary: ${TICKET_SUMMARY:0:60}..."

# =============================================================================
# Step 2: Generate branch name
# =============================================================================
BRANCH_NAME=$("$SCRIPT_DIR/generate-branch-name.sh" "$TICKET_KEY" "$TICKET_SUMMARY")
log "[$TICKET_KEY] Branch name: $BRANCH_NAME"

# =============================================================================
# Step 3: Branch existence check (remote via GH API + local via git)
# =============================================================================
BACKEND_BRANCH_EXISTS=0
FRONTEND_BRANCH_EXISTS=0
BACKEND_BRANCH_SOURCE=""
FRONTEND_BRANCH_SOURCE=""

if gh api "repos/$BACKEND_GH_REPO/branches/$BRANCH_NAME" --silent 2>/dev/null; then
  BACKEND_BRANCH_EXISTS=1
  BACKEND_BRANCH_SOURCE="remote"
elif git -C "$BACKEND_REPO" rev-parse --verify "$BRANCH_NAME" &>/dev/null; then
  BACKEND_BRANCH_EXISTS=1
  BACKEND_BRANCH_SOURCE="local"
fi

if gh api "repos/$FRONTEND_GH_REPO/branches/$BRANCH_NAME" --silent 2>/dev/null; then
  FRONTEND_BRANCH_EXISTS=1
  FRONTEND_BRANCH_SOURCE="remote"
elif git -C "$FRONTEND_REPO" rev-parse --verify "$BRANCH_NAME" &>/dev/null; then
  FRONTEND_BRANCH_EXISTS=1
  FRONTEND_BRANCH_SOURCE="local"
fi

if [[ "$BACKEND_BRANCH_EXISTS" -eq 1 ]]; then
  log "[$TICKET_KEY] Backend branch found ($BACKEND_BRANCH_SOURCE). Skipping backend."
  if [[ "$BACKEND_BRANCH_SOURCE" == "remote" ]]; then
    PR_URL=$(gh pr list --head "$BRANCH_NAME" -R "$BACKEND_GH_REPO" --json url -q '.[0].url' 2>/dev/null || true)
    if [[ -n "$PR_URL" ]]; then
      log "[$TICKET_KEY] Backend PR: $PR_URL"
    else
      log "[$TICKET_KEY] Backend branch (no PR): https://github.com/$BACKEND_GH_REPO/tree/$BRANCH_NAME"
    fi
  else
    log "[$TICKET_KEY] Backend branch is local-only (not pushed). May be from a previous incomplete run."
  fi
fi

if [[ "$FRONTEND_BRANCH_EXISTS" -eq 1 ]]; then
  log "[$TICKET_KEY] Frontend branch found ($FRONTEND_BRANCH_SOURCE). Skipping frontend."
  if [[ "$FRONTEND_BRANCH_SOURCE" == "remote" ]]; then
    PR_URL=$(gh pr list --head "$BRANCH_NAME" -R "$FRONTEND_GH_REPO" --json url -q '.[0].url' 2>/dev/null || true)
    if [[ -n "$PR_URL" ]]; then
      log "[$TICKET_KEY] Frontend PR: $PR_URL"
    else
      log "[$TICKET_KEY] Frontend branch (no PR): https://github.com/$FRONTEND_GH_REPO/tree/$BRANCH_NAME"
    fi
  else
    log "[$TICKET_KEY] Frontend branch is local-only (not pushed). May be from a previous incomplete run."
  fi
fi

if [[ "$BACKEND_BRANCH_EXISTS" -eq 1 && "$FRONTEND_BRANCH_EXISTS" -eq 1 ]]; then
  log "[$TICKET_KEY] Both branches already exist. Nothing to do."
  exit 0
fi

# =============================================================================
# Step 4: Repo relevance decision — determine-repos skill
# =============================================================================
log "[$TICKET_KEY] Invoking determine-repos skill..."
AGENT_RC=0
DECISION_OUTPUT=$("$AGENT_BIN" -p -f --workspace "$AI_REPO_ROOT" \
  "Use the determine-repos skill to determine which repos need changes for Jira ticket $TICKET_KEY. Return ONLY the decision: backend-only, frontend-only, or both." 2>&1) || AGENT_RC=$?

if [[ "$AGENT_RC" -ne 0 ]]; then
  log "[$TICKET_KEY] ERROR: determine-repos agent exited with code $AGENT_RC"
  log "[$TICKET_KEY] Agent output (last 30 lines):"
  echo "$DECISION_OUTPUT" | tail -30
fi

DECISION=$(echo "$DECISION_OUTPUT" | grep -oE 'backend-only|frontend-only|both' | tail -1)
if [[ -z "$DECISION" ]]; then
  log "[$TICKET_KEY] Could not parse determine-repos output; defaulting to 'both'"
  DECISION="both"
fi
log "[$TICKET_KEY] Decision: $DECISION"

RUN_BACKEND=$([[ "$BACKEND_BRANCH_EXISTS" -eq 0 && ("$DECISION" == "backend-only" || "$DECISION" == "both") ]] && echo "yes" || echo "no")
RUN_FRONTEND=$([[ "$FRONTEND_BRANCH_EXISTS" -eq 0 && ("$DECISION" == "frontend-only" || "$DECISION" == "both") ]] && echo "yes" || echo "no")

# =============================================================================
# Step 5: Backend implementation (if needed)
# =============================================================================
if [[ "$RUN_BACKEND" == "yes" ]]; then
  log "[$TICKET_KEY] Running backend agent (start-jira-work)..."
  RUN_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  BACKEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_backend.log"
  AGENT_RC=0
  run_agent "$BACKEND_LOG" env \
    JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
    BRANCH_NAME="$BRANCH_NAME" REPO_NEEDED="true" TICKET_TITLE="$TICKET_SUMMARY" \
    "$AGENT_BIN" -p -f --approve-mcps --workspace "$BACKEND_REPO" \
    "Start work on Jira ticket $TICKET_KEY. You MUST use the branch name: $BRANCH_NAME" || AGENT_RC=$?
  if [[ "$AGENT_RC" -ne 0 ]]; then
    log "[$TICKET_KEY] WARNING: backend agent exited with code $AGENT_RC. See $BACKEND_LOG"
  fi
  PR_URL=$(gh pr list --head "$BRANCH_NAME" -R "$BACKEND_GH_REPO" --json url -q '.[0].url' 2>/dev/null || true)
  if [[ -n "$PR_URL" ]]; then
    open "$PR_URL"
    log "[$TICKET_KEY] Opened backend PR: $PR_URL"
  fi
  log "[$TICKET_KEY] Backend done."
fi

# =============================================================================
# Step 6: Frontend implementation (if needed)
# =============================================================================
if [[ "$RUN_FRONTEND" == "yes" ]]; then
  log "[$TICKET_KEY] Running frontend agent (start-jira-work)..."
  RUN_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  FRONTEND_LOG="$LOG_DIR/${RUN_TIMESTAMP}_${TICKET_KEY}_frontend.log"
  AGENT_RC=0
  run_agent "$FRONTEND_LOG" env \
    JIRA_BASE_URL="$JIRA_BASE_URL" JIRA_EMAIL="$EMAIL" JIRA_API_TOKEN="$API_TOKEN" \
    BRANCH_NAME="$BRANCH_NAME" REPO_NEEDED="true" TICKET_TITLE="$TICKET_SUMMARY" \
    "$AGENT_BIN" -p -f --approve-mcps --workspace "$FRONTEND_REPO" \
    "Start work on Jira ticket $TICKET_KEY. You MUST use the branch name: $BRANCH_NAME" || AGENT_RC=$?
  if [[ "$AGENT_RC" -ne 0 ]]; then
    log "[$TICKET_KEY] WARNING: frontend agent exited with code $AGENT_RC. See $FRONTEND_LOG"
  fi
  PR_URL=$(gh pr list --head "$BRANCH_NAME" -R "$FRONTEND_GH_REPO" --json url -q '.[0].url' 2>/dev/null || true)
  if [[ -n "$PR_URL" ]]; then
    open "$PR_URL"
    log "[$TICKET_KEY] Opened frontend PR: $PR_URL"
  fi
  log "[$TICKET_KEY] Frontend done."
fi

if [[ "$RUN_BACKEND" != "yes" && "$RUN_FRONTEND" != "yes" ]]; then
  log "[$TICKET_KEY] Neither backend nor frontend needed for this ticket. Done."
fi

log "[$TICKET_KEY] Done."
