# Folder Sync to SMB

A flexible bash script to automatically sync a local folder to an SMB share with support for both real-time change detection and scheduled syncing. Works on both Linux and macOS.

## Features

- **Cross-Platform**: Works on both Linux and macOS
- **Two-Way Sync**: Files are synced bidirectionally, newer file always wins
- **Smart Deletion Handling**: Deleted files moved to `.trash` folder instead of permanent deletion
- **Auto-Cleanup**: Trash files older than 60 days automatically removed
- **Configurable Delay**: 60-second delay after changes detected (batches rapid changes)
- **Two Sync Modes**:
  - **Watch Mode**: Real-time change detection using `inotifywait` (Linux) or `fswatch` (macOS)
  - **Interval Mode**: Scheduled sync every X seconds (works everywhere)
- **Interactive Setup**: First-run wizard to configure source/destination
- **Config File**: Store settings in `sync.conf` for easy editing
- **Exclude Patterns**: Skip specific files/folders (e.g., `.git`, `node_modules`)
- **Notifications**: Desktop notifications for sync events (optional, Linux only)
- **Logging**: Keep track of all sync operations
- **One-time Sync**: Run sync once and exit

## Requirements

### Both Platforms
- **rsync**: Usually pre-installed on Linux/macOS

### For Watch Mode (Real-time Change Detection)

**Note:** The script will automatically detect missing dependencies and offer to install them for you during setup or when running in watch mode.

**Linux:**
- **inotify-tools**: Required for watch mode
  ```bash
  # Ubuntu/Debian
  sudo apt-get install inotify-tools

  # Fedora
  sudo dnf install inotify-tools

  # Arch
  sudo pacman -S inotify-tools
  ```

**macOS:**
- **fswatch**: Required for watch mode
  ```bash
  # Using Homebrew
  brew install fswatch
  ```

**Homebrew** (macOS only): If you don't have Homebrew and want to use watch mode on macOS, install it first:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

### SMB Share
- **SMB Share**: Must be mounted to your filesystem (see mounting instructions below)

## Quick Start

### 1. Make the script executable
```bash
chmod +x folder-sync.sh control.sh
```

### 2. Run interactive setup
```bash
./folder-sync.sh --setup
```

The setup wizard will ask you for:
- Source directory (local folder to sync from)
- Destination directory (SMB mount point)
- Sync mode (watch or interval)
- Sync interval (if using interval mode)
- Exclude patterns
- Notification preferences

### 3. Initial download (FIRST TIME ONLY)

**If your SMB share already has files**, do an initial download first to avoid any accidental deletions:

```bash
./folder-sync.sh --initial-download
```

This will:
- ✅ Copy all files from SMB → Local
- ✅ Skip files that already exist locally
- ✅ **Never delete anything** (completely safe)
- ✅ Show confirmation before starting

**You only need to do this once!** After the initial download, the two-way sync will keep everything in sync.

### 4. Start syncing

**Option A: Using the control script (recommended)**
```bash
./control.sh start          # Start in background
./control.sh status         # Check if running
./control.sh logs           # View live logs
./control.sh stop           # Stop syncing
./control.sh restart        # Restart
```

**Option B: Run directly**
```bash
./folder-sync.sh           # Runs in foreground (press Ctrl+C to stop)
```

## Control Script (Recommended)

The easiest way to manage folder sync is with the `control.sh` helper script:

```bash
./control.sh start          # Start in background
./control.sh stop           # Stop syncing
./control.sh restart        # Restart
./control.sh status         # Show detailed status
./control.sh logs           # View live logs (Ctrl+C to exit)
./control.sh install        # Install as system service (auto-start on boot)
./control.sh uninstall      # Uninstall system service
```

### Running in Background

The control script automatically manages background execution:
- Creates PID file to track the process
- Logs output to `~/.folder-sync.log`
- Handles graceful shutdown
- Works with both manual processes and system services

### Installing as a Service

For automatic startup on boot:

```bash
./control.sh install        # Install service
./control.sh start          # Start the service
./control.sh status         # Check status
```

**macOS**: Creates launchd plist in `~/Library/LaunchAgents/`
**Linux**: Creates systemd service in `/etc/systemd/system/`

## Direct Usage

You can also run the sync script directly:

```bash
./folder-sync.sh [OPTIONS]

Options:
    -h, --help              Show help message
    -s, --setup             Run interactive setup
    -c, --config FILE       Use specific config file (default: sync.conf)
    --once                  Perform sync once and exit
    --initial-download      Download all files from SMB to Local (first-time setup)
```

### Examples

```bash
# First-time setup workflow
./folder-sync.sh --setup              # Configure paths
./folder-sync.sh --initial-download   # Download existing files from SMB
./folder-sync.sh                      # Start two-way sync

# Run with default config (foreground)
./folder-sync.sh

# Run interactive setup
./folder-sync.sh --setup

# Sync once and exit (useful for testing)
./folder-sync.sh --once

# Use custom config file
./folder-sync.sh --config my-sync.conf
```

## How Two-Way Sync Works

The script performs bidirectional synchronization with intelligent conflict resolution:

### Sync Behavior

1. **Modified Files**: Newer file (by timestamp) always wins and replaces the older version
2. **New Files**: Copied to the other side
3. **Deleted Files**: Moved to `.trash` folder (not permanently deleted)
4. **Trash Cleanup**: Files in `.trash` older than 60 days are automatically removed

### Example Scenarios

```
Scenario 1: File modified on local
Local:  document.txt (modified 3:00 PM)
SMB:    document.txt (modified 2:00 PM)
Result: Local version copied to SMB (newer wins)

Scenario 2: File modified on SMB
Local:  photo.jpg (modified 1:00 PM)
SMB:    photo.jpg (modified 2:00 PM)
Result: SMB version copied to Local (newer wins)

Scenario 3: File deleted from local
Local:  [file.txt deleted]
SMB:    file.txt exists
Result: file.txt moved to SMB/.trash/ (safe deletion)

Scenario 4: Both sides modified
Local:  report.pdf (modified 3:00 PM)
SMB:    report.pdf (modified 3:01 PM)
Result: SMB version wins (1 minute newer)
```

### Trash Folder Structure

```
SOURCE_DIR/.trash/          # Deleted files from local
DEST_DIR/.trash/            # Deleted files from SMB
```

## Configuration

The script uses `sync.conf` to store settings. You can edit this file directly:

```bash
# Source directory (local folder to sync FROM)
SOURCE_DIR="/home/user/Documents"

# Destination directory (SMB mount point)
DEST_DIR="/mnt/smb-share/backup"

# Sync mode: "watch" or "interval"
SYNC_MODE="watch"

# Interval in seconds (for interval mode)
SYNC_INTERVAL=30

# Sync delay in seconds (for watch mode)
# Time to wait after detecting changes before syncing (batches rapid changes)
SYNC_DELAY=60

# Enable trash for deleted files
TRASH_ENABLED="yes"

# Maximum age for trash files in days
TRASH_MAX_AGE_DAYS=60

# Exclude patterns (space-separated)
# Note: .trash directories are automatically excluded
EXCLUDE_PATTERNS=".git .DS_Store Thumbs.db node_modules"

# Enable notifications
ENABLE_NOTIFICATIONS="yes"

# Log file location
LOG_FILE="$HOME/.folder-sync.log"
```

### Configuration Options Explained

- `SYNC_DELAY`: Seconds to wait after detecting changes before syncing (default: 60). Allows batching multiple rapid file changes into a single sync operation.
- `TRASH_ENABLED`: When "yes", deleted files are moved to `.trash` instead of being permanently removed
- `TRASH_MAX_AGE_DAYS`: Files in `.trash` older than this many days are automatically deleted (default: 60)

## Mounting an SMB Share

Before running the script, you need to mount your SMB share.

### macOS

**Option 1: Finder (GUI)**
1. Open Finder
2. Press `Cmd+K` or go to "Go" → "Connect to Server"
3. Enter: `smb://server/share`
4. Click "Connect" and enter credentials
5. The share will be mounted at `/Volumes/share`

**Option 2: Command Line**
```bash
# Create mount point
sudo mkdir -p /Volumes/my-share

# Mount the share
mount -t smbfs //username:password@server/share /Volumes/my-share

# Or with prompt for password
mount -t smbfs //username@server/share /Volumes/my-share
```

**Option 3: Auto-mount on Login**
1. Mount the share via Finder (Option 1)
2. Go to System Settings → General → Login Items
3. Add the mounted volume to "Open at Login"

### Linux

**Option 1: Manual Mount**
```bash
# Create mount point
sudo mkdir -p /mnt/smb-share

# Mount the share
sudo mount -t cifs //server/share /mnt/smb-share -o username=YOUR_USERNAME,password=YOUR_PASSWORD
```

**Option 2: Using /etc/fstab (Auto-mount on boot)**
Add to `/etc/fstab`:
```
//server/share /mnt/smb-share cifs username=YOUR_USERNAME,password=YOUR_PASSWORD,uid=1000,gid=1000 0 0
```

For better security, use a credentials file:
```
//server/share /mnt/smb-share cifs credentials=/home/user/.smbcredentials,uid=1000,gid=1000 0 0
```

Create `/home/user/.smbcredentials`:
```
username=YOUR_USERNAME
password=YOUR_PASSWORD
```

Then:
```bash
chmod 600 ~/.smbcredentials
sudo mount -a
```

**Option 3: Using GNOME/KDE File Manager**
Most Linux desktop environments can mount SMB shares through the file manager:
- **Nautilus (GNOME)**: "Other Locations" → "Connect to Server" → `smb://server/share`
- **Dolphin (KDE)**: Address bar → `smb://server/share`

The mounted share will usually be at: `/run/user/1000/gvfs/...`

## Running as a Service

### macOS (using launchd)

**1. Create a LaunchAgent plist file**

```bash
nano ~/Library/LaunchAgents/com.foldersync.plist
```

Add (replace paths with your actual paths):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.foldersync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/mac_folder-sync-2-smb/folder-sync.sh</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/path/to/mac_folder-sync-2-smb</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/foldersync.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/foldersync.error.log</string>
</dict>
</plist>
```

**2. Load and start the service**

```bash
# Load the service
launchctl load ~/Library/LaunchAgents/com.foldersync.plist

# Start the service
launchctl start com.foldersync

# Check if running
launchctl list | grep foldersync

# Stop the service
launchctl stop com.foldersync

# Unload the service
launchctl unload ~/Library/LaunchAgents/com.foldersync.plist
```

### Linux (using systemd)

**1. Create a systemd service file**

```bash
sudo nano /etc/systemd/system/folder-sync.service
```

Add:
```ini
[Unit]
Description=Folder Sync to SMB
After=network-online.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/path/to/mac_folder-sync-2-smb
ExecStart=/path/to/mac_folder-sync-2-smb/folder-sync.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**2. Enable and start the service**

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable folder-sync.service

# Start the service now
sudo systemctl start folder-sync.service

# Check status
sudo systemctl status folder-sync.service

# View logs
journalctl -u folder-sync.service -f
```

## Troubleshooting

### "inotifywait is not installed" (Linux)
Install `inotify-tools` package (see Requirements section) or use interval mode instead.

### "fswatch is not installed" (macOS)
Install fswatch via Homebrew: `brew install fswatch`, or use interval mode instead.

### "Source/Destination directory does not exist"
- Verify the paths in your `sync.conf`
- For SMB shares, ensure they are mounted before running the script
- Check mount with: `df -h` or `mount | grep cifs`

### Permission Denied
- Ensure you have read access to the source directory
- Ensure you have write access to the destination directory
- For SMB shares, check your mount options include correct `uid` and `gid`

### Sync is slow
- Check network connection to SMB server
- Consider reducing rsync verbosity by removing `-v` from `RSYNC_OPTIONS`
- Add more exclude patterns for large folders you don't need to sync

### Changes not detected (watch mode)
- Verify `inotifywait` is working: `inotifywait -m /your/source/dir`
- Check if you've hit inotify watch limits:
  ```bash
  cat /proc/sys/fs/inotify/max_user_watches
  ```
  Increase if needed:
  ```bash
  echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  ```

## Tips

1. **Test first**: Use `--once` to test your configuration before running continuous sync
2. **Check logs**: Review `~/.folder-sync.log` for sync history
3. **Backup important data**: Always have backups before using `--delete` option
4. **Network reliability**: Use interval mode if your SMB connection is unstable
5. **Large files**: Rsync is efficient and only transfers changed parts of files

## Security Notes

- Store SMB credentials securely (use credential files, not command-line)
- Set appropriate permissions on config files: `chmod 600 sync.conf`
- Consider encrypting sensitive data before syncing
- Use VPN when syncing over untrusted networks

## License

Free to use and modify for personal or commercial use.
