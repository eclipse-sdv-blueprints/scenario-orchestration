# =============================================================
# lib/utils.sh  ─  Shared shell functions (single-node, local only)
# Source after config.env.
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

# ── Local node IP detection ───────────────────────────────────
# Prints an explicit NODE_IP if set, otherwise the first non-loopback
# IPv4 address of this machine.
detect_node_ip() {
  if [[ -n "${NODE_IP:-}" ]]; then
    echo "${NODE_IP}"
    return
  fi
  hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^127\.' | head -n1
}

# ── Local sudo execution ──────────────────────────────────────
# Uses SUDO_PASS via `sudo -S` when provided, otherwise a normal sudo.
run_sudo() {
  if [[ -n "${SUDO_PASS:-}" ]]; then
    printf '%s\n' "${SUDO_PASS}" | sudo -S -p '' "$@"
  else
    sudo "$@"
  fi
}

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

# ── Wait for a container log pattern ──────────────────────────
# Watches a docker container's logs for a regex until it matches or times out.
# Args: <container name> <log regex> <timeout sec>
# Returns: 0 on match, 1 if no container found, 124 on timeout.
wait_for_container_log() {
  local name="$1" regex="$2" timeout="$3"
  local c="${name}"
  if ! docker ps --format '{{.Names}}' | grep -Fx "${c}" >/dev/null 2>&1; then
    c="$(docker ps --format '{{.Names}}' | grep -m1 -E 'resiso-serial-bridge|databroker|broker' || true)"
  fi
  [[ -n "${c}" ]] || return 1

  info "watching container: ${c}"
  local ts end
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  end=$(( $(date +%s) + timeout ))
  while [[ $(date +%s) -lt ${end} ]]; do
    if docker logs --since "${ts}" "${c}" 2>&1 | grep -m1 -E "${regex}" >/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 124
}
