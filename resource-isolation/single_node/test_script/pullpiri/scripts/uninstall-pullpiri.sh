#!/bin/bash
set -euo pipefail
# Single-node pullpiri runtime uninstall.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf /etc/pullpiri/*
rm -rf /run/pullpirilog

podman pod stop -t 0 pullpiri-player || true
podman pod rm -f --ignore pullpiri-player || true
podman pod stop -t 0 pullpiri-server || true
podman pod rm -f --ignore pullpiri-server || true

sleep 1

# Single-node: the nodeagent runs on this same machine.
bash "${SCRIPT_DIR}/uninstall-agent.sh"
