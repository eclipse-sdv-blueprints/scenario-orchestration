#!/usr/bin/env bash
set -euo pipefail
# Single-node orchestrator: stop/teardown flow
# Everything runs locally on this machine. Env overrides: see config.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./config.env
source "${SCRIPT_DIR}/config.env"
# shellcheck source=./lib/utils.sh
source "${SCRIPT_DIR}/lib/utils.sh"

main() {
  require_cmd docker

  info "Step 1) docker compose down"
  ( cd "${SERIAL_BRIDGE_DIR}" && docker compose down )

  info "Step 2) monitoring stop.sh"
  ( cd "${MONITORING_DIR}" && ./stop.sh )

  info "Step 3) stop timpani-o container and uninstall timpani-n package"
  run_sudo bash "${TEST_SCRIPT_DIR}/timpani/scripts/uninstall-timpani-o.sh"
  run_sudo bash "${TEST_SCRIPT_DIR}/timpani/scripts/uninstall-timpani-n.sh"

  info "Step 4) pullpiri runtime uninstall"
  run_sudo bash "${TEST_SCRIPT_DIR}/pullpiri/scripts/uninstall-pullpiri.sh"

  info "Step 5) podman rm -f --all"
  run_sudo podman rm -f --all || true

  info "Teardown done."
}

main "$@"
