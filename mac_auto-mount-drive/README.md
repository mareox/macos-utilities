# SMB Auto-Mount for macOS

Automatically mounts `smb://192.168.10.100/home/` at login and daily at 8:00 AM.

## Installation

1. **Run the installer:**
   ```bash
   ./install.sh
   ```

2. **(Optional) Set up credentials to avoid password prompts:**
   ```bash
   echo "username=YOUR_USERNAME" > ~/.smb_credentials
   echo "password=YOUR_PASSWORD" >> ~/.smb_credentials
   chmod 600 ~/.smb_credentials
   ```

3. **Load the services:**
   ```bash
   launchctl load ~/Library/LaunchAgents/com.user.smbmount.login.plist
   launchctl load ~/Library/LaunchAgents/com.user.smbmount.daily.plist
   ```

## What Gets Installed

- **mount_smb.sh**: Script that performs the SMB mounting
- **com.user.smbmount.login.plist**: LaunchAgent that runs at login
- **com.user.smbmount.daily.plist**: LaunchAgent that runs daily at 8:00 AM

## Mount Location

The SMB share will be mounted at: `~/mnt/smb_home`

## Logs

Check logs at:
- `~/Library/Logs/SMBMount/smb_mount.log`
- `~/Library/Logs/SMBMount/smb_mount.err`
- `~/Library/Logs/SMBMount/smb_mount_daily.log`
- `~/Library/Logs/SMBMount/smb_mount_daily.err`

## Manual Testing

Test the mount script manually:
```bash
./mount_smb.sh
```

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.user.smbmount.login.plist
launchctl unload ~/Library/LaunchAgents/com.user.smbmount.daily.plist
rm ~/Library/LaunchAgents/com.user.smbmount.*.plist
```

## Troubleshooting

- **Check if services are loaded:**
  ```bash
  launchctl list | grep smbmount
  ```

- **View recent logs:**
  ```bash
  tail ~/Library/Logs/SMBMount/*.log
  ```

- **Manually unmount:**
  ```bash
  umount ~/mnt/smb_home
  ```
