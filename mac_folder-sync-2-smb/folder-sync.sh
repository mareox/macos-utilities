#!/bin/bash

# Folder Sync Script - Sync local folder to SMB share
# Supports both real-time change detection and scheduled sync

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/sync.conf"
DEFAULT_CONFIG="${SCRIPT_DIR}/sync.conf.example"

# Detect OS
OS_TYPE="$(uname -s)"
case "${OS_TYPE}" in
    Linux*)     OS="linux";;
    Darwin*)    OS="macos";;
    *)          OS="unknown";;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to send notification
send_notification() {
    local title="$1"
    local message="$2"

    if [[ "${ENABLE_NOTIFICATIONS:-no}" == "yes" ]]; then
        if command -v notify-send &> /dev/null; then
            notify-send "$title" "$message"
        fi
    fi
}

# Function to log messages
log_message() {
    local message="$1"
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    fi
}

# Function to check and install dependencies
check_and_install_dependency() {
    local tool="$1"
    local package="$2"

    if command -v "$tool" &> /dev/null; then
        return 0  # Tool already installed
    fi

    print_warning "$tool is not installed"

    # Detect package manager and suggest installation
    if [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            print_error "Homebrew is not installed. Please install Homebrew first:"
            print_error "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            return 1
        fi

        echo -n "Would you like to install $package via Homebrew? (y/n): "
        read -r install_choice

        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            print_info "Installing $package..."
            if brew install "$package"; then
                print_success "$package installed successfully"
                return 0
            else
                print_error "Failed to install $package"
                return 1
            fi
        else
            print_info "Skipping installation. Install manually with: brew install $package"
            return 1
        fi

    elif [[ "$OS" == "linux" ]]; then
        # Detect Linux package manager
        if command -v apt-get &> /dev/null; then
            PKG_MANAGER="apt-get"
            INSTALL_CMD="sudo apt-get install -y"
        elif command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
            INSTALL_CMD="sudo dnf install -y"
        elif command -v pacman &> /dev/null; then
            PKG_MANAGER="pacman"
            INSTALL_CMD="sudo pacman -S --noconfirm"
        elif command -v yum &> /dev/null; then
            PKG_MANAGER="yum"
            INSTALL_CMD="sudo yum install -y"
        else
            print_error "Could not detect package manager. Please install $package manually."
            return 1
        fi

        echo -n "Would you like to install $package via $PKG_MANAGER? (y/n): "
        read -r install_choice

        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            print_info "Installing $package..."
            if $INSTALL_CMD "$package"; then
                print_success "$package installed successfully"
                return 0
            else
                print_error "Failed to install $package"
                return 1
            fi
        else
            print_info "Skipping installation. Install manually with: $INSTALL_CMD $package"
            return 1
        fi
    else
        print_error "Cannot auto-install on this operating system"
        return 1
    fi
}

# Function to clean up old trash files
cleanup_trash() {
    local trash_dir="$1"
    local max_age_days="${TRASH_MAX_AGE_DAYS:-60}"

    if [[ ! -d "$trash_dir" ]]; then
        return 0
    fi

    print_info "Cleaning up trash files older than ${max_age_days} days..."
    log_message "Cleaning up trash in: $trash_dir"

    # Find and delete files older than max_age_days
    find "$trash_dir" -type f -mtime +${max_age_days} -delete 2>/dev/null || true

    # Remove empty directories
    find "$trash_dir" -type d -empty -delete 2>/dev/null || true

    log_message "Trash cleanup completed"
}

# Function to perform two-way sync
perform_sync() {
    print_info "Starting two-way sync: ${SOURCE_DIR} <-> ${DEST_DIR}"
    log_message "Two-way sync started: ${SOURCE_DIR} <-> ${DEST_DIR}"

    # Check if source exists
    if [[ ! -d "$SOURCE_DIR" ]]; then
        print_error "Source directory does not exist: $SOURCE_DIR"
        log_message "ERROR: Source directory does not exist: $SOURCE_DIR"
        return 1
    fi

    # Check if destination exists
    if [[ ! -d "$DEST_DIR" ]]; then
        print_error "Destination directory does not exist: $DEST_DIR"
        log_message "ERROR: Destination directory does not exist: $DEST_DIR"
        return 1
    fi

    # Create trash directories if enabled
    local trash_enabled="${TRASH_ENABLED:-yes}"
    local source_trash="${SOURCE_DIR}/.trash"
    local dest_trash="${DEST_DIR}/.trash"

    if [[ "$trash_enabled" == "yes" ]]; then
        mkdir -p "$source_trash"
        mkdir -p "$dest_trash"
    fi

    # Build base rsync options
    local rsync_base_opts="-avh --ignore-errors"

    # Add trash/backup options
    if [[ "$trash_enabled" == "yes" ]]; then
        rsync_base_opts+=" --backup --backup-dir"
    fi

    # Build exclude patterns
    local exclude_opts=""
    for pattern in $EXCLUDE_PATTERNS; do
        exclude_opts+=" --exclude=$pattern"
    done

    # Always exclude .trash directories
    exclude_opts+=" --exclude=.trash"

    local sync_failed=false

    # Sync 1: Source -> Destination (with trash for deleted files)
    print_info "Syncing: Local -> SMB..."
    local rsync_cmd1="rsync $rsync_base_opts"
    if [[ "$trash_enabled" == "yes" ]]; then
        rsync_cmd1+="=\"$dest_trash\""
    fi
    rsync_cmd1+="$exclude_opts \"${SOURCE_DIR}/\" \"${DEST_DIR}/\""

    if ! eval "$rsync_cmd1"; then
        print_warning "Sync Local -> SMB encountered errors"
        log_message "WARNING: Sync Local -> SMB failed"
        sync_failed=true
    fi

    # Sync 2: Destination -> Source (with trash for deleted files)
    print_info "Syncing: SMB -> Local..."
    local rsync_cmd2="rsync $rsync_base_opts"
    if [[ "$trash_enabled" == "yes" ]]; then
        rsync_cmd2+="=\"$source_trash\""
    fi
    rsync_cmd2+="$exclude_opts \"${DEST_DIR}/\" \"${SOURCE_DIR}/\""

    if ! eval "$rsync_cmd2"; then
        print_warning "Sync SMB -> Local encountered errors"
        log_message "WARNING: Sync SMB -> Local failed"
        sync_failed=true
    fi

    # Clean up old trash files
    if [[ "$trash_enabled" == "yes" ]]; then
        cleanup_trash "$source_trash"
        cleanup_trash "$dest_trash"
    fi

    if [[ "$sync_failed" == true ]]; then
        print_warning "Sync completed with some errors"
        log_message "Sync completed with errors"
        send_notification "Folder Sync" "Sync completed with some errors"
        return 1
    else
        print_success "Two-way sync completed successfully"
        log_message "Two-way sync completed successfully"
        send_notification "Folder Sync" "Two-way sync completed successfully"
        return 0
    fi
}

# Function to run in watch mode (real-time change detection)
run_watch_mode() {
    print_info "Monitoring: $SOURCE_DIR"
    print_info "Press Ctrl+C to stop"

    # Perform initial sync
    perform_sync

    # Use appropriate file watcher based on OS
    if [[ "$OS" == "macos" ]]; then
        # macOS: Use fswatch
        print_info "Starting watch mode with fswatch..."

        # Check if fswatch is installed, offer to install if not
        if ! check_and_install_dependency "fswatch" "fswatch"; then
            print_error "Cannot run watch mode without fswatch"
            print_error "Alternatively, use interval mode by editing sync.conf:"
            print_error "  SYNC_MODE=\"interval\""
            exit 1
        fi

        # Monitor for changes with fswatch
        fswatch -r -e ".*" -i "\\..*" "$SOURCE_DIR" |
        while read -r changed_file; do
            print_info "Change detected: $changed_file"
            log_message "Change detected: $changed_file"

            # Add a delay to batch rapid changes
            local delay="${SYNC_DELAY:-60}"
            print_info "Waiting ${delay} seconds before syncing..."
            sleep "$delay"

            perform_sync
        done

    elif [[ "$OS" == "linux" ]]; then
        # Linux: Use inotifywait
        print_info "Starting watch mode with inotifywait..."

        # Check if inotifywait is installed, offer to install if not
        if ! check_and_install_dependency "inotifywait" "inotify-tools"; then
            print_error "Cannot run watch mode without inotifywait"
            print_error "Alternatively, use interval mode by editing sync.conf:"
            print_error "  SYNC_MODE=\"interval\""
            exit 1
        fi

        # Monitor for changes with inotifywait
        inotifywait -m -r -e modify,create,delete,move "$SOURCE_DIR" --format '%w%f' |
        while read -r changed_file; do
            print_info "Change detected: $changed_file"
            log_message "Change detected: $changed_file"

            # Add a delay to batch rapid changes
            local delay="${SYNC_DELAY:-60}"
            print_info "Waiting ${delay} seconds before syncing..."
            sleep "$delay"

            perform_sync
        done

    else
        print_error "Watch mode is not supported on this operating system: ${OS_TYPE}"
        print_error "Please use interval mode instead by editing sync.conf:"
        print_error "  SYNC_MODE=\"interval\""
        exit 1
    fi
}

# Function to run in interval mode (scheduled sync)
run_interval_mode() {
    print_info "Starting interval mode..."
    print_info "Sync interval: ${SYNC_INTERVAL} seconds"
    print_info "Press Ctrl+C to stop"

    while true; do
        perform_sync
        print_info "Waiting ${SYNC_INTERVAL} seconds until next sync..."
        sleep "$SYNC_INTERVAL"
    done
}

# Function to perform initial download from destination to source
initial_download() {
    print_info "=== Initial Download Mode ==="
    print_info "This will copy all files from SMB to Local without deleting anything"
    echo ""

    # Check if source exists
    if [[ ! -d "$SOURCE_DIR" ]]; then
        print_error "Source directory does not exist: $SOURCE_DIR"
        log_message "ERROR: Source directory does not exist: $SOURCE_DIR"
        return 1
    fi

    # Check if destination exists
    if [[ ! -d "$DEST_DIR" ]]; then
        print_error "Destination directory does not exist: $DEST_DIR"
        log_message "ERROR: Destination directory does not exist: $DEST_DIR"
        return 1
    fi

    print_info "From: ${DEST_DIR} (SMB)"
    print_info "To:   ${SOURCE_DIR} (Local)"
    echo ""
    print_warning "This will copy missing files from SMB to Local"
    print_warning "Existing files will be skipped (not overwritten)"
    print_warning "Nothing will be deleted"
    echo ""
    echo -n "Continue with initial download? (y/n): "
    read -r confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Initial download cancelled"
        return 0
    fi

    print_info "Starting initial download..."
    log_message "Initial download started: ${DEST_DIR} -> ${SOURCE_DIR}"

    # Build rsync command for initial download
    # --ignore-existing: skip files that exist in destination
    # No --delete flag: never delete anything
    local rsync_cmd="rsync -avh --ignore-existing"

    # Add exclude patterns
    local exclude_opts=""
    for pattern in $EXCLUDE_PATTERNS; do
        exclude_opts+=" --exclude=$pattern"
    done

    # Always exclude .trash directories
    exclude_opts+=" --exclude=.trash"

    rsync_cmd+="$exclude_opts \"${DEST_DIR}/\" \"${SOURCE_DIR}/\""

    print_info "Running: rsync -avh --ignore-existing ${DEST_DIR}/ ${SOURCE_DIR}/"
    echo ""

    # Execute rsync
    if eval "$rsync_cmd"; then
        print_success "Initial download completed successfully!"
        log_message "Initial download completed successfully"
        echo ""
        print_info "Next steps:"
        print_info "  1. Verify files in: $SOURCE_DIR"
        print_info "  2. Start two-way sync: ./folder-sync.sh"
        print_info "     or use: ./control.sh start"
        return 0
    else
        print_error "Initial download failed"
        log_message "ERROR: Initial download failed"
        return 1
    fi
}

# Function to create config file interactively
interactive_setup() {
    print_info "Interactive Setup - Folder Sync Configuration"
    echo ""

    # Source directory
    echo -n "Enter source directory (local folder to sync FROM): "
    read -r source_dir

    # Expand ~ to home directory
    source_dir="${source_dir/#\~/$HOME}"

    # Validate source directory
    if [[ ! -d "$source_dir" ]]; then
        print_warning "Source directory does not exist: $source_dir"
        echo -n "Create it? (y/n): "
        read -r create_source
        if [[ "$create_source" =~ ^[Yy]$ ]]; then
            mkdir -p "$source_dir"
            print_success "Created source directory"
        else
            print_error "Aborting setup"
            exit 1
        fi
    fi

    # Destination directory
    echo -n "Enter destination directory (SMB mount point): "
    read -r dest_dir

    # Expand ~ to home directory
    dest_dir="${dest_dir/#\~/$HOME}"

    # Validate destination directory
    if [[ ! -d "$dest_dir" ]]; then
        print_warning "Destination directory does not exist: $dest_dir"
        print_info "Make sure your SMB share is mounted first!"
        echo -n "Create it anyway? (y/n): "
        read -r create_dest
        if [[ "$create_dest" =~ ^[Yy]$ ]]; then
            mkdir -p "$dest_dir"
            print_success "Created destination directory"
        fi
    fi

    # Sync mode
    echo ""
    echo "Select sync mode:"
    if [[ "$OS" == "macos" ]]; then
        echo "  1) Watch mode (real-time change detection - requires fswatch: brew install fswatch)"
    elif [[ "$OS" == "linux" ]]; then
        echo "  1) Watch mode (real-time change detection - requires inotify-tools)"
    else
        echo "  1) Watch mode (real-time change detection - may not be supported)"
    fi
    echo "  2) Interval mode (sync every X seconds)"
    echo -n "Enter choice (1 or 2): "
    read -r mode_choice

    if [[ "$mode_choice" == "1" ]]; then
        sync_mode="watch"

        # Check for required dependencies for watch mode
        echo ""
        print_info "Checking for required dependencies..."

        if [[ "$OS" == "macos" ]]; then
            if ! check_and_install_dependency "fswatch" "fswatch"; then
                print_warning "Watch mode requires fswatch. Falling back to interval mode."
                sync_mode="interval"
                echo -n "Enter sync interval in seconds [30]: "
                read -r interval
                interval="${interval:-30}"
            fi
        elif [[ "$OS" == "linux" ]]; then
            if ! check_and_install_dependency "inotifywait" "inotify-tools"; then
                print_warning "Watch mode requires inotify-tools. Falling back to interval mode."
                sync_mode="interval"
                echo -n "Enter sync interval in seconds [30]: "
                read -r interval
                interval="${interval:-30}"
            fi
        fi
    else
        sync_mode="interval"
        echo -n "Enter sync interval in seconds [30]: "
        read -r interval
        interval="${interval:-30}"
    fi

    # Sync delay
    echo ""
    if [[ "$sync_mode" == "watch" ]]; then
        echo -n "Enter sync delay in seconds (time to wait after changes detected) [60]: "
        read -r sync_delay
        sync_delay="${sync_delay:-60}"
    else
        sync_delay=60
    fi

    # Trash settings
    echo ""
    echo -n "Enable trash for deleted files? (y/n) [y]: "
    read -r enable_trash
    enable_trash="${enable_trash:-y}"
    if [[ "$enable_trash" =~ ^[Yy]$ ]]; then
        trash_enabled="yes"
        echo -n "Keep trash files for how many days? [60]: "
        read -r trash_days
        trash_days="${trash_days:-60}"
    else
        trash_enabled="no"
        trash_days=60
    fi

    # Exclude patterns
    echo ""
    echo -n "Enter exclude patterns (space-separated) [.git .DS_Store Thumbs.db]: "
    read -r exclude_patterns
    exclude_patterns="${exclude_patterns:-.git .DS_Store Thumbs.db}"

    # Notifications
    echo -n "Enable notifications? (y/n) [y]: "
    read -r enable_notif
    enable_notif="${enable_notif:-y}"
    if [[ "$enable_notif" =~ ^[Yy]$ ]]; then
        notifications="yes"
    else
        notifications="no"
    fi

    # Create config file
    cat > "$CONFIG_FILE" << EOF
# Folder Sync Configuration File
# Generated on $(date)

# Source directory (local folder to sync FROM)
SOURCE_DIR="$source_dir"

# Destination directory (SMB mount point or remote path)
DEST_DIR="$dest_dir"

# Sync mode: "watch" for real-time change detection, "interval" for scheduled sync
SYNC_MODE="$sync_mode"

# Interval in seconds (only used if SYNC_MODE="interval")
SYNC_INTERVAL=${interval:-30}

# Sync delay in seconds (for watch mode - time to wait after detecting changes)
SYNC_DELAY=$sync_delay

# Two-way sync: Files are synced in both directions, newer file always wins
# Deleted files are NOT propagated - they are moved to .trash instead

# Enable trash for deleted files
TRASH_ENABLED="$trash_enabled"

# Maximum age for trash files in days
TRASH_MAX_AGE_DAYS=$trash_days

# Exclude patterns
EXCLUDE_PATTERNS="$exclude_patterns"

# Enable notifications
ENABLE_NOTIFICATIONS="$notifications"

# Log file location
LOG_FILE="\$(pwd)/.folder-sync.log"
EOF

    print_success "Configuration saved to: $CONFIG_FILE"
    echo ""
    echo -n "Start syncing now? (y/n): "
    read -r start_now

    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        return 0
    else
        print_info "Run './folder-sync.sh' to start syncing"
        exit 0
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -s, --setup             Run interactive setup
    -c, --config FILE       Use specific config file (default: sync.conf)
    --once                  Perform sync once and exit
    --initial-download      Download all files from SMB to Local (first-time setup)

If no config file exists, interactive setup will run automatically.

Examples:
    $0 --setup              # Run interactive setup
    $0 --initial-download   # Download from SMB to Local (safe, no deletions)
    $0                      # Run with default config (two-way sync)
    $0 --once               # Sync once and exit

First-time setup workflow:
    1. $0 --setup           # Configure paths
    2. $0 --initial-download # Download existing files from SMB
    3. $0                   # Start two-way sync
    or: ./control.sh start  # Start in background

EOF
}

# Main script
main() {
    local run_once=false
    local run_initial_download=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -s|--setup)
                interactive_setup
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --once)
                run_once=true
                shift
                ;;
            --initial-download)
                run_initial_download=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Check if config exists, if not run setup
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "Config file not found: $CONFIG_FILE"
        interactive_setup
    fi

    # Load config
    print_info "Loading configuration from: $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    # Validate required variables
    if [[ -z "${SOURCE_DIR:-}" ]] || [[ -z "${DEST_DIR:-}" ]]; then
        print_error "SOURCE_DIR and DEST_DIR must be set in config file"
        exit 1
    fi

    # Run initial download mode
    if [[ "$run_initial_download" == true ]]; then
        initial_download
        exit $?
    fi

    # Run once mode
    if [[ "$run_once" == true ]]; then
        perform_sync
        exit $?
    fi

    # Start sync based on mode
    case "${SYNC_MODE:-interval}" in
        watch)
            run_watch_mode
            ;;
        interval)
            run_interval_mode
            ;;
        *)
            print_error "Invalid SYNC_MODE: ${SYNC_MODE}. Use 'watch' or 'interval'"
            exit 1
            ;;
    esac
}

# Trap Ctrl+C for graceful shutdown
trap 'echo ""; print_info "Shutting down..."; exit 0' INT TERM

# Run main function
main "$@"
