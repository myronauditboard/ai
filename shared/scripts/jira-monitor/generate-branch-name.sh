#!/bin/zsh

# =============================================================================
# generate-branch-name.sh
#
# Outputs a standardized Git branch name from a Jira ticket key and summary.
# Same rules as the generate-branch-name skill: {TICKET-ID}-{sanitized-title},
# entire branch name max 40 characters. Used by check-jira.sh so the monitor
# pipeline does not need to invoke the agent for branch names.
#
# Usage: generate-branch-name.sh TICKET_KEY TICKET_SUMMARY
#   TICKET_KEY   - e.g. SOX-81757
#   TICKET_SUMMARY - Jira ticket summary/title (may be empty; newlines OK)
# Output: exactly one line, the branch name.
# =============================================================================

set -e

TICKET_KEY="${1:?Usage: generate-branch-name.sh TICKET_KEY TICKET_SUMMARY}"
TICKET_SUMMARY="${2:-}"

# Sanitize summary: lowercase, non-alphanumeric → hyphen, collapse hyphens, strip leading/trailing
# (Same algorithm as shared/.claude/skills/generate-branch-name/SKILL.md)
BRANCH_SUFFIX=$(echo "$TICKET_SUMMARY" | \
  tr '[:upper:]' '[:lower:]' | \
  sed 's/[^a-z0-9]/-/g' | \
  sed -E 's/-+/-/g' | \
  sed 's/^-//' | \
  sed 's/-$//')

if [[ -z "$BRANCH_SUFFIX" ]]; then
  echo -n "$TICKET_KEY"
else
  BRANCH_NAME="${TICKET_KEY}-${BRANCH_SUFFIX}"
  BRANCH_NAME="${BRANCH_NAME:0:40}"
  # Strip trailing hyphen so we never end with hyphen (sanitization rule)
  [[ "$BRANCH_NAME" == *- ]] && BRANCH_NAME="${BRANCH_NAME%-}"
  echo -n "$BRANCH_NAME"
fi
