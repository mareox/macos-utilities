#!/bin/bash

# Installation script for SMB auto-mount on macOS

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/SMBMount"

echo "Installing SMB auto-mount configuration..."

# Create log directory
mkdir -p "$LOG_DIR"

# Make mount script executable
chmod +x "$SCRIPT_DIR/mount_smb.sh"

# Update plist files with actual paths
sed "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DIR|g; s|LOG_PATH_PLACEHOLDER|$LOG_DIR|g" \
    "$SCRIPT_DIR/com.user.smbmount.login.plist" > "$LAUNCH_AGENTS_DIR/com.user.smbmount.login.plist"

sed "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DIR|g; s|LOG_PATH_PLACEHOLDER|$LOG_DIR|g" \
    "$SCRIPT_DIR/com.user.smbmount.daily.plist" > "$LAUNCH_AGENTS_DIR/com.user.smbmount.daily.plist"

# Unload existing agents if they're already loaded (to avoid errors)
launchctl unload "$LAUNCH_AGENTS_DIR/com.user.smbmount.login.plist" 2>/dev/null || true
launchctl unload "$LAUNCH_AGENTS_DIR/com.user.smbmount.daily.plist" 2>/dev/null || true

# Load the LaunchAgents
echo "Loading LaunchAgents..."
launchctl load "$LAUNCH_AGENTS_DIR/com.user.smbmount.login.plist"
launchctl load "$LAUNCH_AGENTS_DIR/com.user.smbmount.daily.plist"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Two LaunchAgents have been installed:"
echo "  1. Login mount: runs when you log in"
echo "  2. Daily mount: runs every day at 8:00 AM"
echo ""
echo "Mount point will be: $HOME/mnt/smb_home"
echo ""
echo "Optional: Create credentials file to avoid password prompts"
echo "Create ~/.smb_credentials with:"
echo "  username=YOUR_USERNAME"
echo "  password=YOUR_PASSWORD"
echo "Then run: chmod 600 ~/.smb_credentials"
echo ""
echo "The services are now running and will automatically start on system restart."
echo ""
echo "To verify services are running:"
echo "  launchctl list | grep smbmount"
echo ""
echo "To uninstall:"
echo "  launchctl unload $LAUNCH_AGENTS_DIR/com.user.smbmount.login.plist"
echo "  launchctl unload $LAUNCH_AGENTS_DIR/com.user.smbmount.daily.plist"
echo "  rm $LAUNCH_AGENTS_DIR/com.user.smbmount.*.plist"
echo ""
