#!/usr/bin/env bash
set -euo pipefail
# Multi-node orchestrator: stop/teardown flow
# Env overrides: see config.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./config.env
source "${SCRIPT_DIR}/config.env"
# shellcheck source=./lib/utils.sh
source "${SCRIPT_DIR}/lib/utils.sh"

main() {
  require_cmd ssh
  require_cmd timeout
  resolve_auth_mode
  info "Auth mode: USE_SSHPASS=$USE_SSHPASS"

  info "Step 1) master: docker compose down"
  on_master "cd '$MASTER_SERIAL_BRIDGE_DIR'; docker compose down"

  info "Step 2) guest: monitoring stop.sh"
  on_guest "cd '$GUEST_MONITORING_DIR'; ./stop.sh"

  info "Step 3) stop timpani (master: timpani-o container, guest: timpani-n package)"
  on_master_sudo "bash '$MASTER_TEST_SCRIPT_DIR/timpani/scripts/uninstall-timpani-o.sh'"
  on_guest_sudo  "bash '$GUEST_TEST_SCRIPT_DIR/timpani/scripts/uninstall-timpani-n.sh'"

  info "Step 4) master: pullpiri runtime uninstall script"
  on_master_sudo "bash '$MASTER_TEST_SCRIPT_DIR/pullpiri/scripts/uninstall-pullpiri.sh' '$GUEST_HOST' '$GUEST_PORT' '$GUEST_USER' '$GUEST_PASS' '$GUEST_SUDO_PASS' '$GUEST_TEST_SCRIPT_DIR'"

  info "Step 5) guest: podman rm -f --all"
  on_guest_sudo "podman rm -f --all || true"

  info "Teardown done."
}

main "$@"
