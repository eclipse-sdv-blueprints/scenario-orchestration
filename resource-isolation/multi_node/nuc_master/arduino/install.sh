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

JOY_PORT="$(resolve_port /dev/arduino_joystick)"
LED_PORT="$(resolve_port /dev/arduino_led)"
GEAR_PORT="$(resolve_port /dev/arduino_gear)"

echo "Uploading ardn_stick to ${JOY_PORT} (/dev/arduino_joystick)..."
arduino-cli upload -p "${JOY_PORT}" --fqbn "${FQBN}" ardn_stick

echo "Uploading ardn_led to ${LED_PORT} (/dev/arduino_led)..."
arduino-cli upload -p "${LED_PORT}" --fqbn "${FQBN}" ardn_led

echo "Uploading ardn_gear to ${GEAR_PORT} (/dev/arduino_gear)..."
arduino-cli upload -p "${GEAR_PORT}" --fqbn "${FQBN}" ardn_gear

echo "Upload complete!"
