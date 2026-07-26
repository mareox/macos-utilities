#!/bin/zsh

set -u

# This helper deliberately asks Finder for at most one SMB mount at a time.
# Finder owns authentication; no password is read or passed by this script.
readonly server="${SMB_REMOUNT_SERVER:-192.168.10.100}"
readonly retry_delay_seconds="${SMB_REMOUNT_RETRY_DELAY_SECONDS:-900}"
readonly state_dir="${SMB_REMOUNT_STATE_DIR:-${HOME}/Library/Caches/com.mareox.smb-remount}"
readonly pending_file="$state_dir/pending-mount"
readonly nc_bin="${SMB_REMOUNT_NC_BIN:-/usr/bin/nc}"
readonly mount_bin="${SMB_REMOUNT_MOUNT_BIN:-/sbin/mount}"
readonly open_bin="${SMB_REMOUNT_OPEN_BIN:-/usr/bin/open}"
readonly logger_bin="${SMB_REMOUNT_LOGGER_BIN:-/usr/bin/logger}"
readonly stat_bin="${SMB_REMOUNT_STAT_BIN:-/usr/bin/stat}"
readonly date_bin="${SMB_REMOUNT_DATE_BIN:-/bin/date}"

typeset -a mount_points
typeset -a share_urls
mount_points=(
  "/Volumes/PANW"
  "/Volumes/Documents"
)
share_urls=(
  "smb://mareox@192.168.10.100/home/MXPC_Home/PANW"
  "smb://mareox@192.168.10.100/home/MXPC_Home/Documents"
)

log_info() {
  "$logger_bin" -t smb-remount -- "$*"
}

is_server_reachable() {
  "$nc_bin" -G 2 -z "$server" 445 >/dev/null 2>&1
}

is_mounted() {
  local mount_point="$1"
  "$mount_bin" | /usr/bin/grep -Fq " on ${mount_point} "
}

pending_age_seconds() {
  local modified now age
  modified="$("$stat_bin" -f '%m' "$pending_file")" || return 1
  now="$("$date_bin" +%s)" || return 1
  age=$(( now - modified ))
  (( age < 0 )) && age=0
  print -r -- "$age"
}

clear_pending() {
  /bin/rm -f "$pending_file"
}

pending_request_allows_retry() {
  local pending_mount pending_age

  [[ -f "$pending_file" ]] || return 0
  pending_mount="$(<"$pending_file")"

  if [[ -n "$pending_mount" ]] && is_mounted "$pending_mount"; then
    clear_pending
    return 0
  fi

  pending_age="$(pending_age_seconds 2>/dev/null)" || pending_age="$retry_delay_seconds"
  if (( pending_age < retry_delay_seconds )); then
    log_info "Waiting for Finder mount request at ${pending_mount:-unknown} (age=${pending_age}s)"
    return 1
  fi

  log_info "Retry backoff elapsed for ${pending_mount:-unknown}; allowing one new request"
  clear_pending
  return 0
}

request_mount() {
  local mount_point="$1"
  local share_url="$2"

  print -r -- "$mount_point" > "$pending_file"
  log_info "Requesting Finder mount for $mount_point"
  if ! "$open_bin" -g "$share_url"; then
    log_info "Finder request command failed for $mount_point; retry remains rate limited"
  fi
}

request_first_missing_mount() {
  local index mount_point

  for (( index = 1; index <= ${#mount_points}; index++ )); do
    mount_point="$mount_points[index]"
    if ! is_mounted "$mount_point"; then
      request_mount "$mount_point" "$share_urls[index]"
      return 0
    fi
  done

  clear_pending
}

main() {
  if [[ ! "$retry_delay_seconds" =~ '^[0-9]+$' ]] || (( retry_delay_seconds < 1 )); then
    log_info "Invalid SMB_REMOUNT_RETRY_DELAY_SECONDS value: $retry_delay_seconds"
    return 2
  fi

  is_server_reachable || return 0
  /bin/mkdir -p "$state_dir"

  pending_request_allows_retry || return 0
  request_first_missing_mount
}

if [[ "${SMB_REMOUNT_TEST_MODE:-0}" != "1" ]]; then
  main "$@"
fi
