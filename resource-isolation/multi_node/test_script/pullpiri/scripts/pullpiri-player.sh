#!/bin/bash
set -euo pipefail

if [ -n "${1:-}" ]; then
	MASTER_IP="$1"
else
	MASTER_IP="$(hostname -I | awk '{print $1}')"
fi

VERSION="v0.7.2-fix.01"
CONTAINER_IMAGE="ghcr.io/eclipse-pullpiri/pullpiri:${VERSION}"

echo "Running player with image: ${CONTAINER_IMAGE}"

podman pod create \
  --name pullpiri-player \
  --network host \
  --pid host

podman run -d \
  --pod pullpiri-player \
  --name pullpiri-filtergateway \
  -e ROCKSDB_SERVICE_URL="http://${MASTER_IP}:47007" \
  -v /etc/pullpiri/settings.yaml:/etc/pullpiri/settings.yaml:Z \
  -v /run/pullpirilog/:/run/pullpirilog/ \
  ${CONTAINER_IMAGE} \
  /pullpiri/filtergateway

podman run -d \
  --pod pullpiri-player \
  --name pullpiri-actioncontroller \
  -e ROCKSDB_SERVICE_URL="http://${MASTER_IP}:47007" \
  -v /etc/pullpiri/settings.yaml:/etc/pullpiri/settings.yaml:Z \
  -v /run/pullpirilog/:/run/pullpirilog/ \
  ${CONTAINER_IMAGE} \
  /pullpiri/actioncontroller

podman run -d \
  --pod pullpiri-player \
  --name pullpiri-statemanager \
  -e ROCKSDB_SERVICE_URL="http://${MASTER_IP}:47007" \
  -v /etc/pullpiri/settings.yaml:/etc/pullpiri/settings.yaml:Z \
  -v /run/pullpirilog/:/run/pullpirilog/ \
  ${CONTAINER_IMAGE} \
  /pullpiri/statemanager
