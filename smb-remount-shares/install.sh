#!/bin/zsh

set -euo pipefail

readonly script_dir="${0:A:h}"
readonly label="com.mareox.smb-remount"
readonly target_script="$HOME/bin/remount-smb-shares.zsh"
readonly target_plist="$HOME/Library/LaunchAgents/${label}.plist"
readonly template="$script_dir/${label}.plist"
readonly temp_plist="$(mktemp "${TMPDIR%/}/${label}.XXXXXX.plist")"
readonly user_id="$(/usr/bin/id -u)"

trap '/bin/rm -f "$temp_plist"' EXIT

zsh -n "$script_dir/remount-smb-shares.zsh"
zsh "$script_dir/test-remount-smb-shares.zsh"
plutil -lint "$template"

/usr/bin/install -d -m 755 "$HOME/bin" "$HOME/Library/LaunchAgents"
/usr/bin/sed "s|__SCRIPT_PATH__|$target_script|g" "$template" > "$temp_plist"
plutil -lint "$temp_plist"

launchctl bootout "gui/$user_id/$label" 2>/dev/null || true
/usr/bin/install -m 755 "$script_dir/remount-smb-shares.zsh" "$target_script"
/usr/bin/install -m 644 "$temp_plist" "$target_plist"
launchctl bootstrap "gui/$user_id" "$target_plist"
launchctl print "gui/$user_id/$label" >/dev/null

print -- "Installed and loaded $label"
