#!/bin/bash
# /********************************************************************************
# * Copyright (c) 2026 Contributors to the Eclipse Foundation
# *
# * See the NOTICE file(s) distributed with this work for additional
# * information regarding copyright ownership.
# *
# * This program and the accompanying materials are made available under the
# * terms of the Apache License 2.0 which is available at
# * https://www.apache.org/licenses/LICENSE-2.0
# *
# * SPDX-License-Identifier: Apache-2.0
# ********************************************************************************/

# Compile LED Arduino sketches for Guest NUC

arduino-cli compile --fqbn arduino:renesas_uno:unor4wifi ardn_led_timpani
arduino-cli compile --fqbn arduino:renesas_uno:unor4wifi ardn_led_normal
