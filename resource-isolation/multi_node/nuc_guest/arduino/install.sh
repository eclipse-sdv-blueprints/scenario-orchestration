#!/bin/bash
set -euo pipefail

FQBN="arduino:renesas_uno:unor4wifi"

resolve_port() {
	local symlink="$1"
	if [[ ! -e "$symlink" ]]; then
		echo "[ERROR] Missing device: $symlink" >&2
		exit 1
	fi
	readlink -f "$symlink"
}

TIMPANI_PORT="$(resolve_port /dev/arduino_led_timpani)"
NORMAL_PORT="$(resolve_port /dev/arduino_led_normal)"

echo "Uploading ardn_led_timpani to ${TIMPANI_PORT} (/dev/arduino_led_timpani)..."
arduino-cli upload -p "${TIMPANI_PORT}" --fqbn "${FQBN}" ardn_led_timpani

echo "Uploading ardn_led_normal to ${NORMAL_PORT} (/dev/arduino_led_normal)..."
arduino-cli upload -p "${NORMAL_PORT}" --fqbn "${FQBN}" ardn_led_normal

echo "Upload complete!"
