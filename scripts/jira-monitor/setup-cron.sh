#!/bin/zsh

echo "=== Jira Monitor Cron Setup ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JIRA_SCRIPT="$SCRIPT_DIR/check-jira.sh"

# Make sure check-jira.sh is executable
chmod +x "$JIRA_SCRIPT"

# Test the script first
echo "Testing check-jira.sh..."
if ! "$JIRA_SCRIPT"; then
  echo ""
  echo "❌ Script test failed. Please check your configuration."
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
# Note: Agent workflows can take 10-60+ minutes per ticket. A lock file inside
# check-jira.sh prevents overlapping runs.
echo "Installing cron job (runs every 5 minutes)..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /bin/zsh -c 'source ~/.zshrc && $JIRA_SCRIPT' >> $SCRIPT_DIR/logs/cron.log 2>&1") | crontab -

echo ""
echo "✅ Cron job installed!"
echo ""
echo "Current crontab:"
crontab -l | grep "$JIRA_SCRIPT"
echo ""
echo "The script will now run automatically every 5 minutes."
echo "(Agent workflows can take 10-60+ min; a lock file prevents overlapping runs.)"
echo ""
echo "Logs are written to: $SCRIPT_DIR/logs/"
echo ""
echo "To remove the cron job later, run:"
echo "  crontab -l | grep -v 'check-jira.sh' | crontab -"
