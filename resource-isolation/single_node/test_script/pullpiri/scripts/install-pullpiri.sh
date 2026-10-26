#!/bin/bash
set -euo pipefail
# Single-node pullpiri runtime install.
# Usage: install-pullpiri.sh [NODE_IP]
#   NODE_IP  local node IP (auto-detected from the first NIC if omitted)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "${1:-}" ]; then
	NODE_IP="$1"
else
	NODE_IP="$(hostname -I | awk '{print $1}')"
fi

HOST_NAME="$(hostname)"

mkdir -p /etc/pullpiri/pullpiri_shared_rocksdb
chown 1001:1001 /etc/pullpiri/pullpiri_shared_rocksdb

mkdir -p /etc/pullpiri
mkdir -p /run/pullpirilog

cat > /etc/pullpiri/settings.yaml << EOF
host:
  name: ${HOST_NAME}
  ip: ${NODE_IP}
  type: vehicle
  role: master
dds:
  idl_path: src/vehicle/dds/idl
  domain_id: 100
EOF

bash "${SCRIPT_DIR}/pullpiri-server.sh" "${NODE_IP}"
bash "${SCRIPT_DIR}/pullpiri-player.sh" "${NODE_IP}"

sleep 1

# Single-node: the nodeagent runs on this same machine.
bash "${SCRIPT_DIR}/install-agent.sh" "${NODE_IP}" "${NODE_IP}"
