# AGENTS.md: mac_folder-sync-2-smb

Canonical agent contract. `CLAUDE.md` is an adapter whose first line is `@AGENTS.md`.

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
- OS detection: `uname -s` sets `$OS_TYPE`, normalized to `$OS` (linux/macos/unknown) at startup
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

```bash
chmod +x folder-sync.sh control.sh
./folder-sync.sh --setup             # interactive configuration wizard
./folder-sync.sh --once              # one mutating sync, not a dry run
./folder-sync.sh --initial-download  # one-time SMB → Local copy, no deletions
./control.sh status                 # other actions: start, stop, restart, logs
```

Before changing commands, `sync.conf`, platform dependencies, SMB mounting or
service installation, read the full reference in [README.md](README.md).

## Development Notes

**Bash safety**: Script uses `set -euo pipefail` for strict error handling. All functions should handle errors explicitly.

**String interpolation**: Config values are interpolated into rsync command via `eval`. Paths must be quoted properly. The script handles this in `perform_sync()`.

**Path expansion**: Interactive setup expands `~` to `$HOME` for user convenience.

**Notifications**: Linux uses `notify-send`; macOS desktop notifications are not supported.

**Signal handling**: Trap on INT/TERM for graceful shutdown.
