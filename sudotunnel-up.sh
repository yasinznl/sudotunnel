#!/usr/bin/env bash
set -euo pipefail

CONF="/etc/sudotunnel.conf"
[[ -f "$CONF" ]] || { echo "Missing $CONF"; exit 1; }
# shellcheck disable=SC1090
source "$CONF"

ip tunnel del "$TUN_NAME" 2>/dev/null || true
ip tunnel add "$TUN_NAME" mode gre remote "$REMOTE_IP" local "$LOCAL_IP" ttl 255

ip link set "$TUN_NAME" mtu "$MTU" up
ip addr replace "${TUN_IP}/${CIDR}" dev "$TUN_NAME"
