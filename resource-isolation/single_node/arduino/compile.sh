#!/bin/bash
# Compile LED Arduino sketches for the single node
arduino-cli compile --fqbn arduino:renesas_uno:unor4wifi ardn_stick
arduino-cli compile --fqbn arduino:renesas_uno:unor4wifi ardn_led
arduino-cli compile --fqbn arduino:renesas_uno:unor4wifi ardn_gear
arduino-cli compile --fqbn arduino:renesas_uno:unor4wifi ardn_led_timpani
arduino-cli compile --fqbn arduino:renesas_uno:unor4wifi ardn_led_normal
