#!/bin/zsh

# Installs the Jira monitor as a user LaunchAgent so it runs in your graphical
# session (every 5 minutes). The Cursor Agent needs this session for macOS
# Security/keychain; cron runs without it and fails with exit 195.
#
# Same behavior as setup-cron: check-jira.sh runs every 5 min. See check-jira.sh
# and shared/.claude/skills/ for details.
#
# Ensure JIRA_URL, JIRA_EMAIL, and JIRA_API_TOKEN are exported in ~/.zshrc so
# the agent can update Jira status (To Do → In Progress) via the REST API when
# running headless under launchd.

set -e

echo "=== Jira Monitor (LaunchAgent) Setup ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JIRA_SCRIPT="$SCRIPT_DIR/check-jira.sh"
LOG_DIR="$SCRIPT_DIR/logs"
LABEL="com.jira-monitor.check-jira"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$LOG_DIR"
chmod +x "$JIRA_SCRIPT"

# Dry-run
echo "Running check-jira.sh --dry-run..."
if ! "$JIRA_SCRIPT" --dry-run; then
  echo ""
  echo "❌ Dry-run failed. Fix the issues above and run setup again."
  exit 1
fi

echo ""
echo "✅ Script test passed!"
echo ""

# Remove cron job if present (avoid running twice)
if crontab -l 2>/dev/null | grep -q "$JIRA_SCRIPT"; then
  echo "Removing existing cron job..."
  crontab -l 2>/dev/null | grep -v "$JIRA_SCRIPT" | crontab -
  echo ""
fi

# Unload existing LaunchAgent if present
if launchctl list "$LABEL" &>/dev/null; then
  echo "Unloading existing LaunchAgent..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
  echo ""
fi

# Write plist (escape & and > for XML in the -c argument)
CMD_STR="source ~/.zshrc && $JIRA_SCRIPT >> $LOG_DIR/cron.log 2>&1"
CMD_STR_ESC="${CMD_STR//&/&amp;}"; CMD_STR_ESC="${CMD_STR_ESC//</&lt;}"; CMD_STR_ESC="${CMD_STR_ESC//>/&gt;}"

cat > "$PLIST_DEST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>-l</string>
		<string>-c</string>
		<string>$CMD_STR_ESC</string>
	</array>
	<key>StartInterval</key>
	<integer>300</integer>
	<key>RunAtLoad</key>
	<false/>
	<key>WorkingDirectory</key>
	<string>$HOME</string>
	<key>StandardOutPath</key>
	<string>$LOG_DIR/cron.log</string>
	<key>StandardErrorPath</key>
	<string>$LOG_DIR/cron.log</string>
</dict>
</plist>
EOF

echo "Installing LaunchAgent (runs every 5 minutes in your session)..."
launchctl load "$PLIST_DEST"

echo ""
echo "✅ LaunchAgent installed and loaded!"
echo ""
echo "  Plist: $PLIST_DEST"
echo "  Logs:  $LOG_DIR/"
echo ""
echo "The script runs every 5 minutes while you're logged in (graphical session)."
echo "A lock file in check-jira.sh prevents overlapping runs."
echo ""
echo "To stop and remove the LaunchAgent:"
echo "  launchctl unload $PLIST_DEST"
echo "  rm $PLIST_DEST"
echo ""
