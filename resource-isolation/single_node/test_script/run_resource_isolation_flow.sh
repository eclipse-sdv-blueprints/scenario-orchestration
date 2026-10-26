#!/usr/bin/env bash
set -euo pipefail
# Single-node orchestrator: start flow
# Everything runs locally on this machine. Env overrides: see config.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./config.env
source "${SCRIPT_DIR}/config.env"
# shellcheck source=./lib/utils.sh
source "${SCRIPT_DIR}/lib/utils.sh"

main() {
  require_cmd docker

  NODE_IP="$(detect_node_ip)"
  [[ -n "${NODE_IP}" ]] || { err "Could not determine local node IP."; exit 1; }
  info "Node: name='${NODE_NAME}' ip='${NODE_IP}'"

  info "Step 1) docker compose up -d"
  # apiserver binds to NODE_IP (settings.yaml host.ip); pass it so the serial-bridge
  # reaches the apiserver on the same address instead of the docker host gateway.
  ( cd "${SERIAL_BRIDGE_DIR}" && MASTER_IP="${NODE_IP}" docker compose up -d )

  info "Step 2) pullpiri runtime install"
  run_sudo bash "${TEST_SCRIPT_DIR}/pullpiri/scripts/install-pullpiri.sh" "${NODE_IP}"

  info "Step 3) restart nodeagent.service"
  run_sudo systemctl restart nodeagent.service

  info "Step 4) start monitoring script (background)"
  ( cd "${MONITORING_DIR}" && nohup ./start.sh > monitoring_start.log 2>&1 & echo monitoring_started )

  info "Step 5) start timpani-o (container)"
  # Load the timpani-o image and run it as a container (see install-timpani-o.sh).
  run_sudo bash "${TEST_SCRIPT_DIR}/timpani/scripts/install-timpani-o.sh"
  info "Step 5) timpani-o container started (logs: sudo podman logs -f timpani-o)"

  echo
  warn "Step 6) After operating the Arduino, proceed with the YAML transmission."
  warn "Watching container '${DATABROKER_CONTAINER}' log for up to ${WAIT_LOG_TIMEOUT_SEC}s:"
  echo "       (regex: ${DATABROKER_LOG_REGEX})"

  set +e
  wait_for_container_log "${DATABROKER_CONTAINER}" "${DATABROKER_LOG_REGEX}" "${WAIT_LOG_TIMEOUT_SEC}"
  step6_rc=$?
  set -e

  case ${step6_rc} in
    0) info "Step 6 pattern matched" ;;
    1) warn "data broker container not found" ;;
    *) warn "Step 6 log watch timed out (code: ${step6_rc})" ;;
  esac

  if [[ ${step6_rc} -ne 0 ]]; then
    read -r -p "Continue with Step 7? [y/N] " ans
    if [[ ! "${ans}" =~ ^[Yy]$ ]]; then
      err "Aborted by user."
      exit 1
    fi
  fi

  info "Step 7) install & start timpani-n (systemd service)"
  run_sudo env NODE_NAME="${NODE_NAME}" NODE_IP="${NODE_IP}" \
    bash "${TEST_SCRIPT_DIR}/timpani/scripts/install-timpani-n.sh"
  info "Step 7) timpani-n service started (logs: sudo journalctl -u timpani-n -f)"

  info "Done."
}

main "$@"
