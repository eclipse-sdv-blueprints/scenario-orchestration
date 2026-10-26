#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional guest uninstall arguments
GUEST_HOST="${1:-}"
GUEST_PORT="${2:-22}"
GUEST_USER="${3:-}"
GUEST_PASS="${4:-}"
GUEST_SUDO_PASS="${5:-${GUEST_PASS}}"
GUEST_TEST_SCRIPT_DIR="${6:-/home/lge/work/demo/sdv-blueprint/resource-isolation/multi_node/test_script}"

rm -rf /etc/pullpiri/*
rm -rf /run/pullpirilog

podman pod stop -t 0 pullpiri-player || true
podman pod rm -f --ignore pullpiri-player || true
podman pod stop -t 0 pullpiri-server || true
podman pod rm -f --ignore pullpiri-server || true

sleep 1

bash "${SCRIPT_DIR}/uninstall-agent.sh"

if [[ -n "${GUEST_HOST}" && -n "${GUEST_USER}" ]]; then
	echo "Uninstalling nodeagent on guest node (${GUEST_USER}@${GUEST_HOST}:${GUEST_PORT})..."

	if command -v sshpass >/dev/null 2>&1 && [[ -n "${GUEST_PASS}" ]]; then
		sshpass -p "${GUEST_PASS}" ssh -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -p "${GUEST_PORT}" "${GUEST_USER}@${GUEST_HOST}" \
			"set -e; printf '%s\n' '${GUEST_SUDO_PASS}' | sudo -S -p '' bash '${GUEST_TEST_SCRIPT_DIR}/pullpiri/scripts/uninstall-agent.sh'"
	else
		ssh -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -p "${GUEST_PORT}" "${GUEST_USER}@${GUEST_HOST}" \
			"set -e; printf '%s\n' '${GUEST_SUDO_PASS}' | sudo -S -p '' bash '${GUEST_TEST_SCRIPT_DIR}/pullpiri/scripts/uninstall-agent.sh'"
	fi
fi
