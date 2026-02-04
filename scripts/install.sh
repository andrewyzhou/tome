#!/usr/bin/env bash
# Tome install script
# Builds and installs the Tome app and its privileged helper daemon.
# Usage: sudo ./scripts/install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$REPO_DIR/build"
APP_DEST="/Applications/Tome.app"
HELPER_DEST="/Library/PrivilegedHelperTools/TomeHelper"
DAEMON_PLIST_SRC="$REPO_DIR/launchdaemons/com.andrewzhou.tome.helper.plist"
DAEMON_PLIST_DEST="/Library/LaunchDaemons/com.andrewzhou.tome.helper.plist"
AGENT_PLIST_SRC="$REPO_DIR/launchagents/com.andrewzhou.tome.plist"
AGENT_PLIST_DEST="$HOME/Library/LaunchAgents/com.andrewzhou.tome.plist"
LOG_FILE="/var/log/tome-helper.log"
SHARED_DIR="/Library/Application Support/Tome"

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root: sudo ./scripts/install.sh"
  exit 1
fi

CURRENT_USER=$(stat -f "%Su" /dev/console)
echo "Installing Tome for user: $CURRENT_USER"

# ---------- Build ----------
echo "Building..."
mkdir -p "$BUILD_DIR"

xcodebuild \
  -project "$REPO_DIR/Tome.xcodeproj" \
  -scheme Tome \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  SYMROOT="$BUILD_DIR" \
  build

xcodebuild \
  -project "$REPO_DIR/Tome.xcodeproj" \
  -scheme TomeHelper \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  SYMROOT="$BUILD_DIR" \
  build

# ---------- Stop existing services ----------
echo "Stopping existing services..."
launchctl unload "$DAEMON_PLIST_DEST" 2>/dev/null || true
sudo -u "$CURRENT_USER" launchctl unload "$AGENT_PLIST_DEST" 2>/dev/null || true
killall Tome 2>/dev/null || true
killall TomeHelper 2>/dev/null || true

# ---------- Install app ----------
echo "Installing Tome.app..."
rm -rf "$APP_DEST"
cp -R "$BUILD_DIR/Release/Tome.app" "$APP_DEST"

# ---------- Install helper ----------
echo "Installing TomeHelper..."
mkdir -p /Library/PrivilegedHelperTools
cp "$BUILD_DIR/Release/TomeHelper" "$HELPER_DEST"
chmod 755 "$HELPER_DEST"
chown root:wheel "$HELPER_DEST"

# ---------- Shared data dir ----------
mkdir -p "$SHARED_DIR"
chmod 777 "$SHARED_DIR"

# ---------- Log file ----------
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# ---------- LaunchDaemon ----------
echo "Installing LaunchDaemon..."
cp "$DAEMON_PLIST_SRC" "$DAEMON_PLIST_DEST"
chown root:wheel "$DAEMON_PLIST_DEST"
chmod 644 "$DAEMON_PLIST_DEST"
launchctl load -w "$DAEMON_PLIST_DEST"

# ---------- LaunchAgent (for current user) ----------
echo "Installing LaunchAgent..."
AGENT_DIR="$(eval echo "~$CURRENT_USER")/Library/LaunchAgents"
mkdir -p "$AGENT_DIR"
cp "$AGENT_PLIST_SRC" "$AGENT_DIR/com.andrewzhou.tome.plist"
chown "$CURRENT_USER" "$AGENT_DIR/com.andrewzhou.tome.plist"
sudo -u "$CURRENT_USER" launchctl load -w "$AGENT_DIR/com.andrewzhou.tome.plist"

echo ""
echo "✓ Tome installed successfully."
echo "  App: $APP_DEST"
echo "  Helper: $HELPER_DEST"
echo "  Daemon: $DAEMON_PLIST_DEST"
echo ""
echo "Launching Tome..."
sudo -u "$CURRENT_USER" open -a "$APP_DEST"
