#!/usr/bin/env bash
set -euo pipefail
# Guest preflight: build images, compile/upload Arduino sketches
# Run directly on the guest node.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../config.env
source "${SCRIPT_DIR}/../config.env"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

main() {
  require_cmd sudo
  require_cmd podman
  require_cmd arduino-cli

  info "=== Guest preflight ==="
  info "NUC_GUEST_DIR=$GUEST_NUC_GUEST_DIR"
  [[ -d "$GUEST_NUC_GUEST_DIR" ]] || { err "missing dir: $GUEST_NUC_GUEST_DIR"; exit 1; }

  ensure_arduino_lib "Adafruit NeoPixel"
  info "Compile/upload Arduino sketches"
  cd "$GUEST_ARDUINO_DIR"
  bash ./compile.sh
  bash ./install.sh

  info "Build guest images"
  cd "$GUEST_NUC_GUEST_DIR/led-timpani-controller"
  sudo podman build -t localhost/led-timpani-controller:latest .

  cd "$GUEST_NUC_GUEST_DIR/led-normal-controller"
  sudo podman build -t localhost/led-normal-controller:latest .

  cd "$GUEST_NUC_GUEST_DIR/kuksa-bridge"
  # The guest kuksa-bridge connects to the master's KUKSA databroker. Bake the
  # master IP into the image via .env (no hardcoding). MASTER_NODE_IP is required
  # (set it in config.env).
  kb_env="$GUEST_NUC_GUEST_DIR/kuksa-bridge/.env"
  master_ip="${MASTER_NODE_IP:-}"
  [[ -n "$master_ip" ]] || { err "MASTER_NODE_IP is not set. Please set it in config.env."; exit 1; }
  info "Set KUKSA_HOST=$master_ip in $kb_env"
  if grep -q '^KUKSA_HOST=' "$kb_env"; then
    sed -i "s/^KUKSA_HOST=.*/KUKSA_HOST=$master_ip/" "$kb_env"
  else
    printf 'KUKSA_HOST=%s\n' "$master_ip" >> "$kb_env"
  fi
  sudo podman build -t localhost/resiso-kuksa-bridge-guest:latest .

  info "Ensure stress-ng image"
  if ! sudo podman image exists localhost/stress-ng:latest; then
    sudo podman build -t localhost/stress-ng:latest - <<'EOF'
FROM alpine:latest
RUN apk add --no-cache stress-ng
ENTRYPOINT ["stress-ng"]
EOF
  fi

  [[ -f "$GUEST_MONITORING_DIR/docker-compose.yml" ]] || warn "monitoring compose file not found"

  info "=== Guest preflight done ==="
}

main "$@"
