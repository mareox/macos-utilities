#!/bin/bash

# Control script for folder-sync.sh
# Provides easy start/stop/restart/status commands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/folder-sync.sh"
PID_FILE="${SCRIPT_DIR}/.folder-sync.pid"
LOG_FILE="$(pwd)/.folder-sync.log"

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

# Check if running as a service
is_service_installed() {
    if [[ "$OS" == "macos" ]]; then
        if [[ -f "$HOME/Library/LaunchAgents/com.foldersync.plist" ]]; then
            return 0
        fi
    elif [[ "$OS" == "linux" ]]; then
        if systemctl list-unit-files | grep -q "folder-sync.service"; then
            return 0
        fi
    fi
    return 1
}

# Check if service is running
is_service_running() {
    if [[ "$OS" == "macos" ]]; then
        if launchctl list | grep -q "com.foldersync"; then
            return 0
        fi
    elif [[ "$OS" == "linux" ]]; then
        if systemctl is-active --quiet folder-sync.service; then
            return 0
        fi
    fi
    return 1
}

# Check if background process is running
is_process_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            # PID file exists but process is dead, clean up
            rm -f "$PID_FILE"
        fi
    fi

    # Also check for any running instances
    if pgrep -f "bash.*folder-sync.sh" > /dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Start function
start_sync() {
    # Check if already running
    if is_service_running; then
        print_warning "Folder sync is already running as a service"
        return 1
    fi

    if is_process_running; then
        print_warning "Folder sync is already running in background"
        return 1
    fi

    # Prefer service if installed
    if is_service_installed; then
        print_info "Starting folder sync service..."
        if [[ "$OS" == "macos" ]]; then
            launchctl start com.foldersync
        elif [[ "$OS" == "linux" ]]; then
            sudo systemctl start folder-sync.service
        fi
        print_success "Folder sync service started"
    else
        # Start as background process
        print_info "Starting folder sync in background..."
        nohup "$SYNC_SCRIPT" > "$LOG_FILE" 2>&1 &
        local pid=$!
        echo "$pid" > "$PID_FILE"

        # Wait a moment to check if it started successfully
        sleep 2
        if ps -p "$pid" > /dev/null 2>&1; then
            print_success "Folder sync started (PID: $pid)"
            print_info "Log file: $LOG_FILE"
            print_info "View logs: tail -f $LOG_FILE"
        else
            print_error "Failed to start folder sync"
            rm -f "$PID_FILE"
            return 1
        fi
    fi
}

# Stop function
stop_sync() {
    local stopped=false

    # Stop service if running
    if is_service_running; then
        print_info "Stopping folder sync service..."
        if [[ "$OS" == "macos" ]]; then
            launchctl stop com.foldersync
        elif [[ "$OS" == "linux" ]]; then
            sudo systemctl stop folder-sync.service
        fi
        print_success "Folder sync service stopped"
        stopped=true
    fi

    # Stop background process if running
    if is_process_running; then
        print_info "Stopping folder sync background process..."

        # Try PID file first
        if [[ -f "$PID_FILE" ]]; then
            local pid=$(cat "$PID_FILE")
            if ps -p "$pid" > /dev/null 2>&1; then
                kill "$pid" 2>/dev/null || true
                sleep 1
                # Force kill if still running
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
            rm -f "$PID_FILE"
        fi

        # Kill any remaining instances
        pkill -f "bash.*folder-sync.sh" 2>/dev/null || true

        print_success "Folder sync background process stopped"
        stopped=true
    fi

    if [[ "$stopped" == false ]]; then
        print_warning "Folder sync is not running"
        return 1
    fi
}

# Restart function
restart_sync() {
    print_info "Restarting folder sync..."
    stop_sync
    sleep 2
    start_sync
}

# Status function
status_sync() {
    echo ""
    echo "=== Folder Sync Status ==="
    echo ""

    local is_running=false

    # Check service
    if is_service_installed; then
        if [[ "$OS" == "macos" ]]; then
            echo "Service: Installed (launchd)"
            if is_service_running; then
                print_success "Status: Running"
                is_running=true
            else
                print_warning "Status: Stopped"
            fi
        elif [[ "$OS" == "linux" ]]; then
            echo "Service: Installed (systemd)"
            if is_service_running; then
                print_success "Status: Running"
                sudo systemctl status folder-sync.service --no-pager | head -n 10
                is_running=true
            else
                print_warning "Status: Stopped"
            fi
        fi
    else
        echo "Service: Not installed"
    fi

    echo ""

    # Check background process
    if is_process_running; then
        if [[ -f "$PID_FILE" ]]; then
            local pid=$(cat "$PID_FILE")
            echo "Background Process: Running"
            echo "PID: $pid"
            is_running=true
        else
            # Process running but no PID file, find it
            local pids=$(pgrep -f "bash.*folder-sync.sh" | tr '\n' ' ')
            echo "Background Process: Running"
            echo "PID(s): $pids"
            is_running=true
        fi
    else
        echo "Background Process: Not running"
    fi

    echo ""

    if [[ -f "$LOG_FILE" ]]; then
        echo "Log file: $LOG_FILE"
        echo "Last 5 log entries:"
        tail -n 5 "$LOG_FILE" 2>/dev/null || echo "  (no recent logs)"
    fi

    echo ""

    if [[ "$is_running" == true ]]; then
        print_success "Folder sync is ACTIVE"
    else
        print_warning "Folder sync is INACTIVE"
    fi

    echo ""
}

# Logs function
logs_sync() {
    if [[ -f "$LOG_FILE" ]]; then
        print_info "Showing live log (Ctrl+C to exit)..."
        tail -f "$LOG_FILE"
    else
        print_error "Log file not found: $LOG_FILE"
        return 1
    fi
}

# Install service function
install_service() {
    if is_service_installed; then
        print_warning "Service is already installed"
        return 1
    fi

    print_info "Installing folder sync as a service..."

    if [[ "$OS" == "macos" ]]; then
        local plist_file="$HOME/Library/LaunchAgents/com.foldersync.plist"
        mkdir -p "$HOME/Library/LaunchAgents"

        cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.foldersync</string>
    <key>ProgramArguments</key>
    <array>
        <string>${SYNC_SCRIPT}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_FILE}</string>
</dict>
</plist>
EOF

        launchctl load "$plist_file"
        print_success "Service installed and loaded (launchd)"
        print_info "Service will auto-start on login"

    elif [[ "$OS" == "linux" ]]; then
        local service_file="/etc/systemd/system/folder-sync.service"

        sudo bash -c "cat > $service_file" << EOF
[Unit]
Description=Folder Sync to SMB
After=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${SYNC_SCRIPT}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable folder-sync.service
        print_success "Service installed and enabled (systemd)"
        print_info "Service will auto-start on boot"
    else
        print_error "Service installation not supported on this OS"
        return 1
    fi
}

# Uninstall service function
uninstall_service() {
    if ! is_service_installed; then
        print_warning "Service is not installed"
        return 1
    fi

    print_info "Uninstalling folder sync service..."

    # Stop if running
    if is_service_running; then
        stop_sync
    fi

    if [[ "$OS" == "macos" ]]; then
        local plist_file="$HOME/Library/LaunchAgents/com.foldersync.plist"
        launchctl unload "$plist_file" 2>/dev/null || true
        rm -f "$plist_file"
        print_success "Service uninstalled (launchd)"

    elif [[ "$OS" == "linux" ]]; then
        sudo systemctl disable folder-sync.service
        sudo rm -f /etc/systemd/system/folder-sync.service
        sudo systemctl daemon-reload
        print_success "Service uninstalled (systemd)"
    fi
}

# Usage function
usage() {
    cat << EOF
Folder Sync Control Script

Usage: $0 [COMMAND]

Commands:
    start           Start folder sync (background or service)
    stop            Stop folder sync
    restart         Restart folder sync
    status          Show current status
    logs            Show live log output (Ctrl+C to exit)
    install         Install as system service (auto-start on boot)
    uninstall       Uninstall system service

Examples:
    $0 start        # Start syncing in background
    $0 stop         # Stop syncing
    $0 status       # Check if running
    $0 logs         # View live logs

EOF
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    case "$1" in
        start)
            start_sync
            ;;
        stop)
            stop_sync
            ;;
        restart)
            restart_sync
            ;;
        status)
            status_sync
            ;;
        logs)
            logs_sync
            ;;
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
