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
