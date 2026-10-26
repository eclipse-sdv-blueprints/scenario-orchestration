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
TIMPANI_PORT="$(resolve_port /dev/arduino_led_timpani)"
NORMAL_PORT="$(resolve_port /dev/arduino_led_normal)"

echo "Uploading ardn_stick to ${JOY_PORT} (/dev/arduino_joystick)..."
arduino-cli upload -p "${JOY_PORT}" --fqbn "${FQBN}" ardn_stick

echo "Uploading ardn_led to ${LED_PORT} (/dev/arduino_led)..."
arduino-cli upload -p "${LED_PORT}" --fqbn "${FQBN}" ardn_led

echo "Uploading ardn_gear to ${GEAR_PORT} (/dev/arduino_gear)..."
arduino-cli upload -p "${GEAR_PORT}" --fqbn "${FQBN}" ardn_gear

echo "Uploading ardn_led_timpani to ${TIMPANI_PORT} (/dev/arduino_led_timpani)..."
arduino-cli upload -p "${TIMPANI_PORT}" --fqbn "${FQBN}" ardn_led_timpani

echo "Uploading ardn_led_normal to ${NORMAL_PORT} (/dev/arduino_led_normal)..."
arduino-cli upload -p "${NORMAL_PORT}" --fqbn "${FQBN}" ardn_led_normal

echo "Upload complete!"
