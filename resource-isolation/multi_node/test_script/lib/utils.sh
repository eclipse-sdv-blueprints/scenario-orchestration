# =============================================================
# lib/utils.sh  ─  Shared shell functions
# Source after config.env so SSH_CONNECT_TIMEOUT_SEC etc. are set.
# =============================================================

# ── Log helpers ──────────────────────────────────────────────
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err()  { echo "[ERROR] $*" >&2; }

# ── Command existence check ───────────────────────────────────
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Required command not found: $1"
    exit 1
  }
}

# ── SSH options (uses vars from config.env) ───────────────────
SSH_COMMON_OPTS=(
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="${HOME}/.ssh/known_hosts"
  -o LogLevel=ERROR
  -o ConnectTimeout="${SSH_CONNECT_TIMEOUT_SEC:-10}"
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=2
)

# ── SSH auth mode resolution ──────────────────────────────────
resolve_auth_mode() {
  if [[ "${USE_SSHPASS:-auto}" == "auto" ]]; then
    if command -v sshpass >/dev/null 2>&1; then
      USE_SSHPASS="1"
    else
      USE_SSHPASS="0"
      warn "sshpass not installed: falling back to SSH key authentication mode."
    fi
  fi
  [[ "${USE_SSHPASS}" == "1" ]] && require_cmd sshpass
}

# ── Remote command execution ──────────────────────────────────
run_remote() {
  local host="$1" port="$2" user="$3" pass="$4" remote_cmd="$5"
  local rc=0
  local timeout_sec="${REMOTE_CMD_TIMEOUT_SEC:-180}"

  if [[ "${USE_SSHPASS}" == "1" ]]; then
    timeout "${timeout_sec}s" \
      sshpass -p "$pass" ssh "${SSH_COMMON_OPTS[@]}" \
        -o NumberOfPasswordPrompts=1 -p "$port" "$user@$host" "$remote_cmd"
  else
    set +e
    timeout "${timeout_sec}s" \
      ssh "${SSH_COMMON_OPTS[@]}" -o BatchMode=yes -p "$port" "$user@$host" "$remote_cmd"
    rc=$?
    set -e
    if [[ $rc -eq 255 && -n "$pass" ]] && command -v sshpass >/dev/null 2>&1; then
      warn "Key authentication failed ($user@$host:$port). Retrying with password authentication."
      timeout "${timeout_sec}s" \
        sshpass -p "$pass" ssh "${SSH_COMMON_OPTS[@]}" \
          -o NumberOfPasswordPrompts=1 -p "$port" "$user@$host" "$remote_cmd"
      return
    fi
    return "$rc"
  fi
}

# ── Remote sudo execution ─────────────────────────────────────
run_remote_sudo() {
  local host="$1" port="$2" user="$3" pass="$4" sudo_pass="$5" remote_cmd="$6"
  local wrapped qpass qcmd
  printf -v qpass '%q' "$sudo_pass"
  printf -v qcmd  '%q' "$remote_cmd"
  wrapped="printf '%s\\n' $qpass | sudo -S -p '' bash -lc $qcmd"
  run_remote "$host" "$port" "$user" "$pass" "$wrapped"
}

# ── Per-node convenience wrappers ─────────────────────────────
# Use the node credentials from config.env and prepend `set -e` to every
# remote command, so callers only pass the command itself.
on_master()      { run_remote      "$MASTER_HOST" "$MASTER_PORT" "$MASTER_USER" "$MASTER_PASS"                    "set -e; $1"; }
on_master_sudo() { run_remote_sudo "$MASTER_HOST" "$MASTER_PORT" "$MASTER_USER" "$MASTER_PASS" "$MASTER_SUDO_PASS" "set -e; $1"; }
on_guest()       { run_remote      "$GUEST_HOST"  "$GUEST_PORT"  "$GUEST_USER"  "$GUEST_PASS"                     "set -e; $1"; }
on_guest_sudo()  { run_remote_sudo "$GUEST_HOST"  "$GUEST_PORT"  "$GUEST_USER"  "$GUEST_PASS"  "$GUEST_SUDO_PASS"  "set -e; $1"; }

# ── Arduino library check/install ────────────────────────────
ensure_arduino_lib() {
  local lib="${1:-Adafruit NeoPixel}"
  if arduino-cli lib list | grep -qF "$lib"; then
    info "Arduino lib already installed: $lib"
  else
    info "Installing Arduino lib: $lib"
    arduino-cli lib install "$lib"
  fi
}

# ── Wait for a container log pattern on the master node ───────
# Watches DATABROKER_CONTAINER's logs on master for a regex until it matches or
# times out. Uses config.env vars: DATABROKER_CONTAINER, DATABROKER_LOG_REGEX,
# WAIT_LOG_TIMEOUT_SEC. Returns 0 on match, 124 on timeout / container not found.
# The remote SSH command timeout is bumped past the watch window so the watch is
# not killed early by REMOTE_CMD_TIMEOUT_SEC.
wait_for_master_container_log() {
  local remote_cmd
  remote_cmd="$(cat <<REMOTE
c='${DATABROKER_CONTAINER}'
docker ps --format '{{.Names}}' | grep -Fx "\$c" >/dev/null 2>&1 || \
  c=\$(docker ps --format '{{.Names}}' | grep -m1 -E 'resiso-serial-bridge|databroker|broker' || true)
[[ -n "\$c" ]] || { echo '[WARN] data broker container not found'; exit 124; }
echo "[INFO] watching container: \$c"
ts=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
end=\$((\$(date +%s) + ${WAIT_LOG_TIMEOUT_SEC}))
while [[ \$(date +%s) -lt \$end ]]; do
  docker logs --since "\$ts" "\$c" 2>&1 | grep -m1 -E '${DATABROKER_LOG_REGEX}' >/dev/null && exit 0
  sleep 2
done
exit 124
REMOTE
)"
  # Give the SSH command enough time to cover the whole watch window.
  local prev_timeout="${REMOTE_CMD_TIMEOUT_SEC:-180}" rc=0
  REMOTE_CMD_TIMEOUT_SEC=$(( WAIT_LOG_TIMEOUT_SEC + 30 ))
  on_master "${remote_cmd}" || rc=$?
  REMOTE_CMD_TIMEOUT_SEC="${prev_timeout}"
  return "${rc}"
}
