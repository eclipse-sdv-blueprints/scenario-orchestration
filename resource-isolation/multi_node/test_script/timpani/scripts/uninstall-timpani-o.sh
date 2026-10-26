#!/bin/bash
set -euo pipefail
# timpani-o runtime uninstall.
# Stops and removes the manually-run container (image kept).
# The container is created by install-timpani-o.sh as root, so this must run as
# root too — otherwise `podman rm` targets the rootless store and finds nothing.

log() { echo "[uninstall-timpani] $*"; }
die() { echo "[uninstall-timpani] ERROR: $*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || die "Please run as root: sudo $0"

log "Removing container 'timpani-o'"
podman rm -f "timpani-o" 2>/dev/null || true

log "Done"