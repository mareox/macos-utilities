# AGENTS.md: mac_auto-mount-drive

Canonical agent contract. `CLAUDE.md` is an adapter whose first line is `@AGENTS.md`.

## Project Overview

This is a macOS automation tool that automatically mounts an SMB network share (`smb://192.168.10.100/home/`) using macOS LaunchAgents. It runs at two intervals:
- At user login (via `com.user.smbmount.login.plist`)
- Daily at 8:00 AM (via `com.user.smbmount.daily.plist`)

The mount point is `~/mnt/smb_home`.

## Architecture

The system consists of three main components:

1. **mount_smb.sh**: Core mounting script
   - Checks if share is already mounted to avoid duplicate mounts
   - Supports optional credentials via a `.smb_credentials` file next to the script (`$SCRIPT_DIR/.smb_credentials`; username/password)
   - Falls back to guest mount if credentials file doesn't exist
   - Uses macOS `mount_smbfs` command

2. **LaunchAgent plists**: Two plist files that trigger the mount script
   - Both use placeholder values (`SCRIPT_PATH_PLACEHOLDER`, `LOG_PATH_PLACEHOLDER`) that get replaced during installation
   - Login plist uses `RunAtLoad` key to trigger at login
   - Daily plist uses `StartCalendarInterval` to trigger at 8:00 AM

3. **install.sh**: Installation automation
   - Creates log directory at `~/Library/Logs/SMBMount/`
   - Performs path substitution in plist templates using `sed`
   - Copies configured plists to `~/Library/LaunchAgents/`
   - Makes mount_smb.sh executable

## Key Configuration Points

When modifying this tool, be aware of:

- **SMB_SERVER and SMB_SHARE**: Hardcoded in mount_smb.sh:10-11
- **Mount point**: `~/mnt/smb_home` (mount_smb.sh:12)
- **Credentials file**: `.smb_credentials` in the script directory (mount_smb.sh:13) - NOT in home directory
- **Log locations**: `~/Library/Logs/SMBMount/` with separate logs for each trigger
- **Schedule time**: 8:00 AM in com.user.smbmount.daily.plist:17-19

## Installation Workflow

1. User runs `./install.sh`
2. Script creates log directory at `~/Library/Logs/SMBMount/`
3. Script makes mount_smb.sh executable
4. Script uses `sed` to replace placeholders in plist templates with actual paths
5. Modified plists are written to `~/Library/LaunchAgents/`
6. Script automatically unloads existing agents (if loaded) to avoid conflicts
7. Script automatically loads the LaunchAgents - no manual `launchctl load` needed

## Testing and Debugging

**Manual mount test:**
```bash
./mount_smb.sh
```

**Check if LaunchAgents are loaded:**
```bash
launchctl list | grep smbmount
```

**View logs:**
```bash
tail ~/Library/Logs/SMBMount/*.log
tail ~/Library/Logs/SMBMount/*.err
```

**Unload services:**
```bash
launchctl unload ~/Library/LaunchAgents/com.user.smbmount.login.plist
launchctl unload ~/Library/LaunchAgents/com.user.smbmount.daily.plist
```

## Credential Security

The credentials file (`.smb_credentials` in the script directory) must have permissions set to 600 to prevent unauthorized access. The file format is:
```
username=YOUR_USERNAME
password=YOUR_PASSWORD
```

The mount script reads this file using `grep` and `cut` to extract values (mount_smb.sh:29-30).

**Note**: README.md and `install.sh` both print instructions to create `~/.smb_credentials` in the home directory, but the script reads `.smb_credentials` from the script directory. Create the file next to the script; those hints are stale.
