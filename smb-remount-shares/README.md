# SMB Remount Shares

Safely maintains the macOS Finder mounts for:

- `/Volumes/PANW` from `smb://192.168.10.100/home/MXPC_Home/PANW`
- `/Volumes/Documents` from `smb://192.168.10.100/home/MXPC_Home/Documents`
- `/Volumes/GIT` from `smb://atlas/GIT`

The helper probes each missing share's server on TCP/445, skipping offline servers.
It asks Finder to connect to only one share and records that request. Later runs
wait for that request to finish; a missing mount retries only after 15 minutes.
This prevents repeated Finder authentication dialogs when the NAS is reachable
but authentication is still pending or was cancelled.

Finder and the macOS Keychain remain responsible for authentication. This tool
does not read, log, pass, or store an SMB password.

## Install or update

```zsh
./install.sh
```

This validates the source and test suite, installs the helper at
`~/bin/remount-smb-shares.zsh`, renders the LaunchAgent at
`~/Library/LaunchAgents/com.mareox.smb-remount.plist`, and bootstraps it for the
current user. The agent runs at login and then every 60 seconds; routine checks
are local-only when all mounts exist. An offline NAS does not block Atlas.

## Verify

```zsh
zsh test-remount-smb-shares.zsh
plutil -lint "$HOME/Library/LaunchAgents/com.mareox.smb-remount.plist"
launchctl print "gui/$(id -u)/com.mareox.smb-remount"
mount | rg '(/Volumes/(PANW|Documents|GIT)|192\.168\.10\.100|atlas)'
```

## Disable

```zsh
launchctl bootout "gui/$(id -u)/com.mareox.smb-remount"
```
