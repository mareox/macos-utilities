# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A cross-platform bash-based folder synchronization tool that performs two-way sync between local directories and SMB (Samba/CIFS) shares. Works on both Linux and macOS. Features intelligent conflict resolution (newer file wins), safe deletion handling (.trash folders), and supports both real-time change detection and scheduled interval-based syncing.

## Architecture

**Dual-script architecture**:

1. **`folder-sync.sh`** - Main sync script:
   - OS detection (Linux/macOS) at startup
   - Interactive configuration wizard (`interactive_setup()`)
   - Configuration persistence via `sync.conf` file
   - Two distinct sync modes (watch/interval) selected at runtime
   - Rsync wrapper with validation and error handling

2. **`control.sh`** - Process management helper:
   - Start/stop/restart commands
   - Background process management with PID tracking
   - Service installation/uninstallation (systemd/launchd)
   - Status monitoring and log viewing
   - Detects and manages both background processes and system services

**Cross-platform design**:
- OS detection via `uname -s` sets `$OS` variable (lines 12-18)
- Watch mode branches based on `$OS`:
  - **macOS**: Uses `fswatch` for filesystem monitoring
  - **Linux**: Uses `inotifywait` for filesystem monitoring
  - **Unknown OS**: Rejects watch mode, recommends interval mode
- All other functionality (interval mode, rsync, config) is platform-agnostic

**Configuration flow**:
1. Script checks for `sync.conf` in script directory
2. If missing, automatically triggers `interactive_setup()`
3. Setup wizard generates `sync.conf` by sourcing variables into bash
4. Setup wizard shows platform-specific dependency instructions
5. Main script sources `sync.conf` to load user settings

**Sync modes**:
- **Watch mode** (`run_watch_mode()`): Platform-specific file monitoring:
  - Linux: `inotifywait -m -r -e modify,create,delete,move` monitors events
  - macOS: `fswatch -r` monitors directory changes
  - Both trigger `perform_sync()` after `SYNC_DELAY` seconds (default: 60s) to batch rapid changes
- **Interval mode** (`run_interval_mode()`): Simple while loop that calls `perform_sync()` every `SYNC_INTERVAL` seconds.

**Core sync logic** (`perform_sync()`):
- Two-way bidirectional sync:
  1. Syncs SOURCE → DEST with rsync --backup (newer files win)
  2. Syncs DEST → SOURCE with rsync --backup (newer files win)
  3. Deleted files moved to `.trash` directories instead of permanent deletion
  4. Runs `cleanup_trash()` to remove files older than `TRASH_MAX_AGE_DAYS`
- Validates source and destination directories exist
- Dynamically builds rsync commands with trash/backup options
- Uses `eval` to execute constructed command strings
- Returns exit codes for error handling

**Trash cleanup** (`cleanup_trash()`):
- Uses `find` to locate files older than configured days
- Removes old files and empty directories
- Runs after each sync operation
- Default retention: 60 days

**Initial download** (`initial_download()`):
- One-time operation for first-time setup
- Copies DEST → SOURCE only (SMB to Local)
- Uses `rsync --ignore-existing` (skips existing files)
- Never deletes anything
- Requires user confirmation
- Useful when SMB share already contains data

## Key Commands

### First-time setup
```bash
chmod +x folder-sync.sh control.sh
./folder-sync.sh --setup
```

### Control script (recommended)
```bash
./control.sh start          # Start in background
./control.sh stop           # Stop syncing
./control.sh restart        # Restart
./control.sh status         # Show detailed status
./control.sh logs           # View live logs
./control.sh install        # Install as system service
./control.sh uninstall      # Uninstall system service
```

### Running the script directly
```bash
./folder-sync.sh                    # Run with default config (foreground)
./folder-sync.sh --once             # Single sync (for testing)
./folder-sync.sh --config <file>    # Use alternate config
./folder-sync.sh --setup            # Reconfigure settings
```

### Initial download (first-time setup)
```bash
./folder-sync.sh --initial-download # Safely copy all files from SMB → Local (no deletions)
```

### Testing sync behavior
```bash
./folder-sync.sh --once             # Test without continuous monitoring
./control.sh logs                   # Monitor sync activity
tail -f ~/.folder-sync.log          # View log file directly
```

### Configuration
Edit `sync.conf` directly or regenerate via `--setup`. Required variables:
- `SOURCE_DIR`: Local directory to sync from
- `DEST_DIR`: SMB mount point to sync to
- `SYNC_MODE`: "watch" or "interval"
- `SYNC_INTERVAL`: Seconds between syncs (interval mode only)
- `SYNC_DELAY`: Seconds to wait after detecting changes before syncing (watch mode, default: 60)
- `TRASH_ENABLED`: "yes" or "no" - move deleted files to .trash
- `TRASH_MAX_AGE_DAYS`: Days to keep trash files before auto-deletion (default: 60)
- `EXCLUDE_PATTERNS`: Space-separated patterns for rsync --exclude (`.trash` auto-excluded)

## Development Notes

**Bash safety**: Script uses `set -euo pipefail` for strict error handling. All functions should handle errors explicitly.

**String interpolation**: Config values are interpolated into rsync command via `eval`. Paths must be quoted properly. The script handles this in `perform_sync()` at lines 75-83.

**Path expansion**: Interactive setup expands `~` to `$HOME` for user convenience.

**Color output**: Uses ANSI escape codes via helper functions (`print_info`, `print_success`, `print_warning`, `print_error`).

**Logging**: Optional file logging via `log_message()`. Controlled by `LOG_FILE` config variable.

**Signal handling**: Trap on INT/TERM for graceful shutdown.

**Platform-specific file watchers**:
- Linux: `inotifywait -m -r -e modify,create,delete,move` monitors specific events
- macOS: `fswatch -r -e ".*" -i "\\..*"` monitors all changes recursively

**Auto-install dependencies**: The `check_and_install_dependency()` function:
- Detects if required tools are installed
- Prompts user to install if missing
- Detects appropriate package manager (brew for macOS, apt/dnf/pacman/yum for Linux)
- Runs installation with user confirmation
- Called during both interactive setup and when starting watch mode

## Platform-Specific Considerations

**Dependencies**:
- Linux watch mode: Requires `inotify-tools` package
- macOS watch mode: Requires `fswatch` (installed via Homebrew)
- Interval mode: No additional dependencies beyond rsync

**Notifications**:
- Linux: Uses `notify-send` for desktop notifications
- macOS: Desktop notifications not currently supported

**SMB mounting**:
- Linux: Uses `mount -t cifs` with credentials
- macOS: Uses `mount -t smbfs` or Finder GUI (Cmd+K)
- Default mount locations:
  - Linux: `/mnt/` or `/run/user/*/gvfs/`
  - macOS: `/Volumes/`

**Service management**:
- Linux: systemd service files
- macOS: launchd plist files in `~/Library/LaunchAgents/`

## Configuration Defaults

**Sync behavior**:
- Two-way bidirectional sync (newer file wins)
- Rsync options: `-avh --ignore-errors --backup --backup-dir`
- Deleted files moved to `.trash` directories
- Trash retention: 60 days
- Sync delay: 60 seconds (watch mode)

**Default excludes**: `.git .DS_Store Thumbs.db` (plus `.trash` auto-excluded)

**Default log location**: `~/.folder-sync.log`

**Trash locations**:
- `SOURCE_DIR/.trash/` - Files deleted from local
- `DEST_DIR/.trash/` - Files deleted from SMB

## SMB Considerations

The script assumes the SMB share is already mounted. It validates directory existence but does not handle mounting. Mount validation happens in `perform_sync()` by checking if `DEST_DIR` exists as a directory.
