#!/bin/bash

# SMB Mount Script for macOS
# Mounts smb://192.168.10.100/home/ to a local directory

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Configuration
SMB_SERVER="192.168.10.100"
SMB_SHARE="home"
MOUNT_POINT="$HOME/mnt/smb_home"
CREDENTIALS_FILE="$SCRIPT_DIR/.smb_credentials"

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "$(date): SMB share already mounted at $MOUNT_POINT"
    exit 0
fi

# Check if credentials file exists
if [ -f "$CREDENTIALS_FILE" ]; then
    # Read credentials from file
    USERNAME=$(grep "username=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
    PASSWORD=$(grep "password=" "$CREDENTIALS_FILE" | cut -d'=' -f2)

    # Mount with credentials
    mount_smbfs "//${USERNAME}:${PASSWORD}@${SMB_SERVER}/${SMB_SHARE}" "$MOUNT_POINT"
else
    # Mount without credentials (guest or prompted)
    mount_smbfs "//guest@${SMB_SERVER}/${SMB_SHARE}" "$MOUNT_POINT"
fi

if [ $? -eq 0 ]; then
    echo "$(date): Successfully mounted SMB share to $MOUNT_POINT"
    exit 0
else
    echo "$(date): Failed to mount SMB share"
    exit 1
fi
