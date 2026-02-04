#!/usr/bin/env bash
# Tome uninstall script
# Usage: sudo ./scripts/uninstall.sh

set -e

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root: sudo ./scripts/uninstall.sh"
  exit 1
fi

CURRENT_USER=$(stat -f "%Su" /dev/console)
AGENT_PLIST="$(eval echo "~$CURRENT_USER")/Library/LaunchAgents/com.andrewzhou.tome.plist"
DAEMON_PLIST="/Library/LaunchDaemons/com.andrewzhou.tome.helper.plist"

echo "Stopping services..."
launchctl unload "$DAEMON_PLIST" 2>/dev/null || true
sudo -u "$CURRENT_USER" launchctl unload "$AGENT_PLIST" 2>/dev/null || true
killall Tome 2>/dev/null || true
killall TomeHelper 2>/dev/null || true

echo "Removing hosts entries..."
HOSTS_FILE="/etc/hosts"
TMP=$(mktemp)
awk '/# tome-block-start/{skip=1} /# tome-block-end/{skip=0; next} !skip' "$HOSTS_FILE" > "$TMP"
mv "$TMP" "$HOSTS_FILE"
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true

echo "Removing files..."
rm -rf /Applications/Tome.app
rm -f /Library/PrivilegedHelperTools/TomeHelper
rm -f "$DAEMON_PLIST"
rm -f "$AGENT_PLIST"
rm -rf "/Library/Application Support/Tome"

echo "✓ Tome uninstalled."
