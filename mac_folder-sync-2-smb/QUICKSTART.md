# Quick Start Guide

**Note**: This script performs **two-way sync** with newer file wins. Deleted files are moved to `.trash` folders (auto-cleaned after 60 days).

## 1. Mount Your SMB Share

**macOS:**
```bash
# Via Finder: Cmd+K → smb://server/share
# Or command line:
mount -t smbfs //username@server/share /Volumes/my-share
```

**Linux:**
```bash
# Example: Mount SMB share
sudo mkdir -p /mnt/my-smb-share
sudo mount -t cifs //server/share /mnt/my-smb-share -o username=myuser,password=mypass
```

Or mount via file manager (Nautilus/Dolphin): `smb://server/share`

## 2. Install Dependencies (for watch mode)

**Note:** You can skip this step! The script will automatically detect missing dependencies and offer to install them when you run setup.

**macOS:**
```bash
brew install fswatch
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install inotify-tools rsync

# Fedora
sudo dnf install inotify-tools rsync
```

## 3. Run Setup

```bash
chmod +x folder-sync.sh control.sh
./folder-sync.sh --setup
```

Answer the prompts:
- **Source**: Your local folder (e.g., `/home/user/Documents`)
- **Destination**: Your SMB mount point (e.g., `/mnt/my-smb-share/backup`)
- **Mode**:
  - `1` for real-time (watch mode) - requires fswatch/inotify-tools
  - `2` for scheduled (interval mode) - works everywhere
- **Sync delay**: Wait time after changes detected (default: 60 seconds)
- **Interval**: How often to sync (if using interval mode, e.g., 30 seconds)
- **Trash**: Enable trash for deleted files (default: yes)
- **Trash retention**: Days to keep trash (default: 60)
- **Excludes**: Files/folders to skip (e.g., `.git node_modules`)

## 4. Initial Download (FIRST TIME ONLY)

**If your SMB share already has files:**

```bash
./folder-sync.sh --initial-download
```

This safely copies all files from SMB → Local without deleting anything. **Skip this if starting fresh!**

## 5. Start Syncing

**Recommended: Use the control script**
```bash
./control.sh start          # Start in background
./control.sh status         # Check if running
```

**Alternative: Run directly (foreground)**
```bash
./folder-sync.sh           # Press Ctrl+C to stop
```

## 5. Managing the Sync

```bash
./control.sh stop           # Stop syncing
./control.sh restart        # Restart
./control.sh logs           # View live logs
./control.sh install        # Install as service (auto-start on boot)
```

## 6. Test First (Recommended)

```bash
# Sync once without continuous monitoring
./folder-sync.sh --once
```

Check the destination to verify files synced correctly.

## Common Commands

```bash
# Run with default config
./folder-sync.sh

# Reconfigure settings
./folder-sync.sh --setup

# Sync once and exit
./folder-sync.sh --once

# View help
./folder-sync.sh --help

# Check logs
tail -f ~/.folder-sync.log
```

## Watch Mode vs Interval Mode

| Feature | Watch Mode | Interval Mode |
|---------|------------|---------------|
| **How it works** | Monitors file changes in real-time | Runs rsync every X seconds |
| **Requirements** | fswatch (macOS) or inotify-tools (Linux) | None (just rsync) |
| **Sync speed** | Instant (on change) | Delayed (max X seconds) |
| **CPU usage** | Low | Very low |
| **Best for** | Active development, frequent changes | Stable folders, scheduled backups |

## Troubleshooting Quick Fixes

### SMB not mounted?
```bash
# Check if mounted
mount | grep cifs

# Remount
sudo mount -a
```

### Permission denied?
```bash
# Check destination is writable
touch /mnt/my-smb-share/test.txt
rm /mnt/my-smb-share/test.txt
```

### File watcher not found?
**macOS:**
```bash
brew install fswatch
```

**Linux:**
```bash
sudo apt-get install inotify-tools
```

**Or use interval mode instead** - edit `sync.conf` and change:
```bash
SYNC_MODE="interval"
```

## Need Help?

See `README.md` for comprehensive documentation.
