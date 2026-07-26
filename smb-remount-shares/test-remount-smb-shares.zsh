#!/bin/zsh

set -euo pipefail

readonly script_dir="${0:A:h}"
readonly subject="$script_dir/remount-smb-shares.zsh"

if [[ ! -r "$subject" ]]; then
  print -u2 -- "missing subject: $subject"
  exit 1
fi

readonly test_dir="$(mktemp -d "${TMPDIR%/}/smb-remount-test.XXXXXX")"
trap '/bin/rm -rf "$test_dir"' EXIT

export SMB_REMOUNT_TEST_MODE=1
export SMB_REMOUNT_STATE_DIR="$test_dir/state"
export SMB_REMOUNT_RETRY_DELAY_SECONDS=900
export SMB_REMOUNT_OPEN_BIN=record_open

typeset -a open_calls
typeset -A mounted
typeset -g server_reachable=1
typeset -g test_pending_age=0

record_open() {
  open_calls+=("$*")
}

source "$subject"

is_server_reachable() {
  (( server_reachable ))
}

is_mounted() {
  [[ "${mounted["$1"]:-0}" == "1" ]]
}

pending_age_seconds() {
  print -r -- "$test_pending_age"
}

log_info() {
  :
}

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

assert_equal() {
  [[ "$1" == "$2" ]] || fail "expected '$1', got '$2'"
}

assert_file_text() {
  local expected="$1"
  local actual
  actual="$(<"$pending_file")"
  assert_equal "$expected" "$actual"
}

reset_case() {
  /bin/rm -rf "$SMB_REMOUNT_STATE_DIR"
  /bin/mkdir -p "$SMB_REMOUNT_STATE_DIR"
  open_calls=()
  mounted=()
  server_reachable=1
  test_pending_age=0
}

# A healthy machine must not ask Finder to mount anything.
reset_case
mounted["/Volumes/PANW"]=1
mounted["/Volumes/Documents"]=1
main
assert_equal "0" "${#open_calls}"
[[ ! -e "$pending_file" ]] || fail "healthy mounts left a pending marker"

# If both shares are absent, request only the first one and persist that fact.
reset_case
main
assert_equal "1" "${#open_calls}"
assert_equal "-g smb://mareox@192.168.10.100/home/MXPC_Home/PANW" "$open_calls[1]"
assert_file_text "/Volumes/PANW"

# A still-pending request must suppress the next timer invocation.
main
assert_equal "1" "${#open_calls}"

# Once PANW is mounted, the next invocation may request Documents, not PANW again.
mounted["/Volumes/PANW"]=1
main
assert_equal "2" "${#open_calls}"
assert_equal "-g smb://mareox@192.168.10.100/home/MXPC_Home/Documents" "$open_calls[2]"
assert_file_text "/Volumes/Documents"

# A failed request retries only after the configured backoff period.
test_pending_age=899
main
assert_equal "2" "${#open_calls}"
test_pending_age=900
main
assert_equal "3" "${#open_calls}"

# An unreachable NAS must not create a Finder request or pending marker.
reset_case
server_reachable=0
main
assert_equal "0" "${#open_calls}"
[[ ! -e "$pending_file" ]] || fail "unreachable NAS left a pending marker"

print -- "PASS: SMB remount serialization and retry-backoff behavior"
