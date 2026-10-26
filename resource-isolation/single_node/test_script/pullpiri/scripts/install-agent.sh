#!/bin/bash
set -euo pipefail

MASTER_IP="${1:-}"
NODE_IP="${2:-}"

if [[ -z "${MASTER_IP}" ]] || [[ -z "${NODE_IP}" ]]; then
	echo "ERROR: Both MASTER_IP and NODE_IP arguments are required." >&2
	echo "Usage: $0 MASTER_IP NODE_IP" >&2
	exit 1
fi

if [[ "$MASTER_IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
	echo "MASTER_IP: '${MASTER_IP}'"
else
	echo "ERROR: Invalid IPv4 address for MASTER_IP - '${MASTER_IP}'"
	exit 1
fi

if [[ "$NODE_IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
	echo "NODE_IP: '${NODE_IP}'"
else
	echo "ERROR: Invalid IPv4 address for NODE_IP - '${NODE_IP}'"
	exit 1
fi

NODE_NAME=$(hostname)
NODE_ROLE="nodeagent"
NODE_TYPE="vehicle"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
	SUFFIX="amd64"
elif [ "$ARCH" = "aarch64" ]; then
	SUFFIX="arm64"
else
	echo "Error: Unsupported architecture '${ARCH}'."
	exit 1
fi

AGENT_BINARY_PATH="/opt/pullpiri/nodeagent"
rm -f "$AGENT_BINARY_PATH"
mkdir -p /opt/pullpiri
if [ ! -f "$AGENT_BINARY_PATH" ]; then
	BINARY_URL="https://github.com/eclipse-pullpiri/pullpiri/releases/latest/download/nodeagent-linux-${SUFFIX}"
	echo "Downloading binary from ${BINARY_URL}..."
	curl -L -o nodeagent "${BINARY_URL}"
	if [ $? -ne 0 ]; then
		echo "Error: Failed to download binary from ${BINARY_URL}"
		exit 1
	fi
	mv -f nodeagent /opt/pullpiri/nodeagent
fi
chmod +x /opt/pullpiri/nodeagent
echo "Binary installed to /opt/pullpiri/nodeagent"

mkdir -p /etc/pullpiri
cat > /etc/pullpiri/nodeagent.yaml << EOF
nodeagent:
  node_name: "${NODE_NAME}"
  node_type: "${NODE_TYPE}"
  node_role: "${NODE_ROLE}"
  master_ip: "${MASTER_IP}"
  node_ip: "${NODE_IP}"
  grpc_port: 47004
  log_level: "info"
  metrics:
    collection_interval: 5
    batch_size: 50
  system:
    hostname: "${NODE_NAME}"
    platform: "$(uname -s)"
    architecture: "${ARCH}"
EOF

cat > /etc/systemd/system/nodeagent.service << EOF
[Unit]
Description=Pullpiri NodeAgent Service
After=network-online.target
Wants=podman.socket

[Service]
Type=simple
ExecStart=/opt/pullpiri/nodeagent --config /etc/pullpiri/nodeagent.yaml
Restart=on-failure
RestartSec=10
Environment=RUST_LOG=info
Environment=MASTER_NODE_IP=${MASTER_IP}
Environment=NODE_IP=${NODE_IP}
Environment=GRPC_PORT=47004
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
ReadWritePaths=/etc/pullpiri
ReadWritePaths=/etc/containers/systemd

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nodeagent.service || true
systemctl restart nodeagent.service
