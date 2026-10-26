#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "${1:-}" ]; then
	MASTER_IP="$1"
else
	MASTER_IP="$(hostname -I | awk '{print $1}')"
fi

# Optional guest install arguments
GUEST_HOST="${2:-}"
GUEST_PORT="${3:-22}"
GUEST_USER="${4:-}"
GUEST_PASS="${5:-}"
GUEST_SUDO_PASS="${6:-${GUEST_PASS}}"
GUEST_NODE_IP="${7:-}"
GUEST_TEST_SCRIPT_DIR="${8:-/home/lge/work/demo/sdv-blueprint/resource-isolation/multi_node/test_script}"

HOST_NAME="$(hostname)"

mkdir -p /etc/pullpiri/pullpiri_shared_rocksdb
chown 1001:1001 /etc/pullpiri/pullpiri_shared_rocksdb

mkdir -p /etc/pullpiri
mkdir -p /run/pullpirilog

cat > /etc/pullpiri/settings.yaml << EOF
host:
  name: ${HOST_NAME}
  ip: ${MASTER_IP}
  type: vehicle
  role: master
dds:
  idl_path: src/vehicle/dds/idl
  domain_id: 100
EOF

bash "${SCRIPT_DIR}/pullpiri-server.sh" "${MASTER_IP}"
bash "${SCRIPT_DIR}/pullpiri-player.sh" "${MASTER_IP}"

sleep 1

bash "${SCRIPT_DIR}/install-agent.sh" "${MASTER_IP}" "${MASTER_IP}"

if [[ -n "${GUEST_HOST}" && -n "${GUEST_USER}" ]]; then
  echo "Installing nodeagent on guest node (${GUEST_USER}@${GUEST_HOST}:${GUEST_PORT})..."

  if command -v sshpass >/dev/null 2>&1 && [[ -n "${GUEST_PASS}" ]]; then
    sshpass -p "${GUEST_PASS}" ssh -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -p "${GUEST_PORT}" "${GUEST_USER}@${GUEST_HOST}" \
      "set -e; \
       node_ip='${GUEST_NODE_IP}'; \
       if [[ -z \"\$node_ip\" ]]; then \
         node_ip=\$(ip -4 route get '${MASTER_IP}' 2>/dev/null | awk '{for(i=1;i<=NF;i++) if(\$i==\"src\") {print \$(i+1); exit}}'); \
       fi; \
       if [[ -z \"\$node_ip\" ]]; then \
         node_ip=\$(hostname -I | awk '{print \$1}'); \
       fi; \
       printf '%s\n' '${GUEST_SUDO_PASS}' | sudo -S -p '' bash '${GUEST_TEST_SCRIPT_DIR}/pullpiri/scripts/install-agent.sh' '${MASTER_IP}' \"\$node_ip\""
  else
    ssh -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -p "${GUEST_PORT}" "${GUEST_USER}@${GUEST_HOST}" \
      "set -e; \
       node_ip='${GUEST_NODE_IP}'; \
       if [[ -z \"\$node_ip\" ]]; then \
         node_ip=\$(ip -4 route get '${MASTER_IP}' 2>/dev/null | awk '{for(i=1;i<=NF;i++) if(\$i==\"src\") {print \$(i+1); exit}}'); \
       fi; \
       if [[ -z \"\$node_ip\" ]]; then \
         node_ip=\$(hostname -I | awk '{print \$1}'); \
       fi; \
       printf '%s\n' '${GUEST_SUDO_PASS}' | sudo -S -p '' bash '${GUEST_TEST_SCRIPT_DIR}/pullpiri/scripts/install-agent.sh' '${MASTER_IP}' \"\$node_ip\""
  fi
fi
