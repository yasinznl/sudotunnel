#!/usr/bin/env bash
set -euo pipefail

CONF="/etc/sudotunnel.conf"
[[ -f "$CONF" ]] || exit 0
# shellcheck disable=SC1090
source "$CONF"

ip tunnel del "$TUN_NAME" 2>/dev/null || true
