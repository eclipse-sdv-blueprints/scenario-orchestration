#!/bin/bash
set -euo pipefail
# Single-node timpani-o runtime install (manual container smoke test).
# Pulls the timpani-o image from the registry and runs it directly with
# `podman run`, then checks the container stayed up. Only timpani-o is started
# here (timpani-n is started later, in Step 7 of the resource-isolation flow).
#
# Overridable via environment:
#   NODE_CONFIG_YAML    node_configurations.yaml to mount into the container
#   TIMPANI_O_IMAGE     container image tag (default ghcr.io/mco-piccolo/timpani-o:latest)
#   TIMPANI_O_GRPC_PORT gRPC port to publish (default 50052)
#   TIMPANI_O_DATA_PORT data port to publish (default 7777)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NODE_CONFIG_YAML="${NODE_CONFIG_YAML:-${SCRIPT_DIR}/../config/node_configurations.yaml}"
TIMPANI_O_IMAGE="${TIMPANI_O_IMAGE:-ghcr.io/mco-piccolo/timpani-o:latest}"
TIMPANI_O_NAME="timpani-o"
TIMPANI_O_GRPC_PORT="${TIMPANI_O_GRPC_PORT:-50052}"
TIMPANI_O_DATA_PORT="${TIMPANI_O_DATA_PORT:-7777}"
# Path the config is mounted to inside the container (matches the image layout).
CONFIG_IN_CONTAINER="/timpani-o/examples/node_configurations.yaml"

log() { echo "[install-timpani-o] $*"; }
die() { echo "[install-timpani] ERROR: $*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || die "Please run as root: sudo $0"

# --- pull the image and run the container -----------------------------------
run_timpani_o() {
    [[ -f "${NODE_CONFIG_YAML}" ]] || die "Node config not found: ${NODE_CONFIG_YAML}"

    log "Pulling image ${TIMPANI_O_IMAGE}..."
    podman pull "${TIMPANI_O_IMAGE}" || die "Failed to pull ${TIMPANI_O_IMAGE}"

    log "Starting container..."
    podman rm -f "${TIMPANI_O_NAME}" 2>/dev/null || true

    # -s/-d/-c must be passed explicitly, otherwise timpani-o starts with
    # "NodeConfigManager is not loaded" and scheduling fails.
    podman run -d \
        --name "${TIMPANI_O_NAME}" \
        --publish "${TIMPANI_O_GRPC_PORT}:${TIMPANI_O_GRPC_PORT}" \
        --publish "${TIMPANI_O_DATA_PORT}:${TIMPANI_O_DATA_PORT}" \
        --volume "${NODE_CONFIG_YAML}:${CONFIG_IN_CONTAINER}:ro" \
        "${TIMPANI_O_IMAGE}" \
        -s "${TIMPANI_O_GRPC_PORT}" -d "${TIMPANI_O_DATA_PORT}" -c "${CONFIG_IN_CONTAINER}" \
        || die "Failed to start timpani-o container"

    # Smoke test: podman run -d returns 0 even if the container dies right away,
    # so confirm it is still up and dump recent logs.
    sleep 3
    if ! podman ps --format '{{.Names}}' | grep -Fxq "${TIMPANI_O_NAME}"; then
        podman logs "${TIMPANI_O_NAME}" 2>&1 | tail -n 40 || true
        die "Smoke test failed: '${TIMPANI_O_NAME}' container exited"
    fi
    log "Smoke test passed: '${TIMPANI_O_NAME}' is running. Recent logs:"
    podman logs "${TIMPANI_O_NAME}" 2>&1 | tail -n 20 || true
}

run_timpani_o

log "Done. Status: podman ps | Logs: podman logs -f ${TIMPANI_O_NAME}"
