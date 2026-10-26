#!/bin/bash
set -euo pipefail

SYSTEMD_FILE="/etc/systemd/system/nodeagent.service"
YAML_FILE="/etc/pullpiri/nodeagent.yaml"
BIN_FILE="/opt/pullpiri/nodeagent"

systemctl stop nodeagent.service || true

if [ -f "$SYSTEMD_FILE" ]; then
	rm -f "$SYSTEMD_FILE"
fi
systemctl daemon-reload || true

if [ -f "$YAML_FILE" ]; then
	rm -f "$YAML_FILE"
fi

if [ -f "$BIN_FILE" ]; then
	rm -f "$BIN_FILE"
fi
