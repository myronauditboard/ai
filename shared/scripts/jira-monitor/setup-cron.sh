#!/bin/zsh

# Schedules check-jira.sh to run every 5 minutes via cron. check-jira.sh polls Jira
# for To Do tickets, generates branch names, decides which repos need work (check-jira
# skill), skips when the branch already exists, and launches backend/frontend agents
# only when needed. See check-jira.sh and shared/.claude/skills/ for details.
#
# On macOS: cron runs without a graphical session, so the Cursor Agent fails with
# "Security command failed" (exit 195). Use setup-launchd.sh instead; it runs the
# same script every 5 min in your user session. On Linux or headless setups without
# the agent, cron is fine.

echo "=== Jira Monitor Cron Setup ==="
echo ""
if [[ "$(uname)" == Darwin ]]; then
  echo "⚠️  macOS detected. Cron has no graphical session; the Cursor Agent will fail."
  echo "   Use ./setup-launchd.sh instead for a working schedule."
  echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JIRA_SCRIPT="$SCRIPT_DIR/check-jira.sh"
LOG_DIR="$SCRIPT_DIR/logs"

# Ensure logs directory exists (cron redirect writes to logs/cron.log before the script runs)
mkdir -p "$LOG_DIR"

# Make sure check-jira.sh is executable
chmod +x "$JIRA_SCRIPT"

# Dry-run: validate Jira config, agent binary, and repo paths without processing tickets
echo "Running check-jira.sh --dry-run..."
if ! "$JIRA_SCRIPT" --dry-run; then
  echo ""
  echo "❌ Dry-run failed. Please fix the issues above and run setup again."
  exit 1
fi

echo ""
echo "✅ Script test passed!"
echo ""

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$JIRA_SCRIPT"; then
  echo "⚠️  Cron job already exists. Removing old entry..."
  crontab -l 2>/dev/null | grep -v "$JIRA_SCRIPT" | crontab -
fi

# Add the cron job
# Agent workflows can take 10-60+ min per ticket. A lock file in check-jira.sh prevents overlapping runs.
echo "Installing cron job (runs every 5 minutes)..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /bin/zsh -c 'source ~/.zshrc && $JIRA_SCRIPT' >> $LOG_DIR/cron.log 2>&1") | crontab -

echo ""
echo "✅ Cron job installed!"
echo ""
echo "Current crontab:"
crontab -l | grep "$JIRA_SCRIPT"
echo ""
echo "The script will now run automatically every 5 minutes."
echo "(Agent workflows can take 10-60+ min; a lock file prevents overlapping runs.)"
echo ""
echo "Logs: $LOG_DIR/ (check-jira output also in $LOG_DIR/<timestamp>_<ticket>_backend.log, etc.)"
echo ""
echo "To remove the cron job later:"
echo "  crontab -l | grep -v 'check-jira.sh' | crontab -"
