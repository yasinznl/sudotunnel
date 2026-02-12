#!/usr/bin/env bash
set -euo pipefail

APP="sudotunnel"
UP="/usr/local/bin/${APP}-up"
DOWN="/usr/local/bin/${APP}-down"
UNIT="/etc/systemd/system/${APP}.service"
CONF="/etc/${APP}.conf"

die() { echo "ERROR: $*" >&2; exit 1; }
need_root() { [[ ${EUID:-0} -eq 0 ]] || die "Run as root."; }
has() { command -v "$1" >/dev/null 2>&1; }

is_ipv4() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r a b c d <<<"$1"
  for x in "$a" "$b" "$c" "$d"; do
    [[ "$x" =~ ^[0-9]+$ ]] || return 1
    (( x >= 0 && x <= 255 )) || return 1
  done
  return 0
}

prompt() {
  local var="$1" msg="$2" def="${3:-}"
  local val=""
  if [[ -n "$def" ]]; then
    read -r -p "$msg [$def]: " val || true
    val="${val:-$def}"
  else
    read -r -p "$msg: " val || true
  fi
  printf -v "$var" '%s' "$val"
}

usage() {
  cat <<EOF
${APP} installer

Usage:
  sudo ./install.sh [options]

Options:
  --local-ip <IPv4>        Public/local server IP (source)
  --remote-ip <IPv4>       Remote peer public IP (destination)
  --tun-ip <IPv4>          Tunnel IP on this host (e.g. 10.10.0.9)
  --peer-ip <IPv4>         Peer tunnel IP (e.g. 10.10.0.10)
  --cidr <N>               Tunnel CIDR (default: 30)  (Tip: /31 avoids broadcast)
  --mtu <N>                Tunnel MTU (default: 1476)
  --name <ifname>          Tunnel interface name (default: sudotunnel)
  --uninstall              Remove service + scripts + config
  -h, --help               Show help

Examples:
  sudo ./install.sh --local-ip 193.233.254.223 --remote-ip 185.232.155.120 --tun-ip 10.10.0.9 --peer-ip 10.10.0.10
  sudo ./install.sh --cidr 31 --tun-ip 10.10.0.0 --peer-ip 10.10.0.1
EOF
}

UNINSTALL=0
LOCAL_IP=""
REMOTE_IP=""
TUN_IP=""
PEER_IP=""
CIDR="30"
MTU="1476"
TUN_NAME="sudotunnel"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-ip) LOCAL_IP="${2:-}"; shift 2;;
    --remote-ip) REMOTE_IP="${2:-}"; shift 2;;
    --tun-ip) TUN_IP="${2:-}"; shift 2;;
    --peer-ip) PEER_IP="${2:-}"; shift 2;;
    --cidr) CIDR="${2:-}"; shift 2;;
    --mtu) MTU="${2:-}"; shift 2;;
    --name) TUN_NAME="${2:-}"; shift 2;;
    --uninstall) UNINSTALL=1; shift 1;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
done

need_root
has ip || die "Missing dependency: ip (iproute2)"
has systemctl || die "Missing dependency: systemctl (systemd)"

if [[ "$UNINSTALL" -eq 1 ]]; then
  systemctl stop "${APP}.service" >/dev/null 2>&1 || true
  systemctl disable "${APP}.service" >/dev/null 2>&1 || true
  rm -f "$UNIT" "$UP" "$DOWN" "$CONF"
  systemctl daemon-reload || true
  echo "Uninstalled ${APP}."
  exit 0
fi

# Interactive mode if anything missing
if [[ -z "$LOCAL_IP" ]]; then prompt LOCAL_IP "Enter LOCAL public IP (source)"; fi
if [[ -z "$REMOTE_IP" ]]; then prompt REMOTE_IP "Enter REMOTE public IP (destination)"; fi
if [[ -z "$TUN_IP" ]]; then prompt TUN_IP "Enter tunnel IP on THIS server" "10.10.0.9"; fi
if [[ -z "$PEER_IP" ]]; then prompt PEER_IP "Enter tunnel IP on PEER server" "10.10.0.10"; fi

is_ipv4 "$LOCAL_IP" || die "Invalid --local-ip"
is_ipv4 "$REMOTE_IP" || die "Invalid --remote-ip"
is_ipv4 "$TUN_IP" || die "Invalid --tun-ip"
is_ipv4 "$PEER_IP" || die "Invalid --peer-ip"
[[ "$CIDR" =~ ^([0-9]|[12][0-9]|3[0-2])$ ]] || die "Invalid --cidr"
[[ "$MTU" =~ ^[0-9]+$ ]] || die "Invalid --mtu"

# Prevent /30 network/broadcast mistakes (like .11 broadcast)
if [[ "$CIDR" == "30" ]]; then
  ip_to_int() { IFS='.' read -r a b c d <<<"$1"; echo $(( (a<<24)+(b<<16)+(c<<8)+d )); }
  int_to_ip() { local n="$1"; echo "$(( (n>>24)&255 )).$(( (n>>16)&255 )).$(( (n>>8)&255 )).$(( n&255 ))"; }

  tun_i="$(ip_to_int "$TUN_IP")"
  net_i=$(( tun_i & 0xFFFFFFFC ))
  bcast_i=$(( net_i + 3 ))
  net_ip="$(int_to_ip "$net_i")"
  bcast_ip="$(int_to_ip "$bcast_i")"

  [[ "$TUN_IP" != "$net_ip" && "$TUN_IP" != "$bcast_ip" ]] || die "For /30, tun-ip cannot be network or broadcast."
  [[ "$PEER_IP" != "$net_ip" && "$PEER_IP" != "$bcast_ip" ]] || die "For /30, peer-ip cannot be network or broadcast."
fi

# Write config
install -d /etc
cat >"$CONF" <<EOF
TUN_NAME="${TUN_NAME}"
LOCAL_IP="${LOCAL_IP}"
REMOTE_IP="${REMOTE_IP}"
TUN_IP="${TUN_IP}"
CIDR="${CIDR}"
MTU="${MTU}"
EOF
chmod 600 "$CONF"

# Install helper scripts
install -m 0755 "./sudotunnel-up.sh" "$UP"
install -m 0755 "./sudotunnel-down.sh" "$DOWN"

# Install systemd unit
install -m 0644 "./sudotunnel.service" "$UNIT"

systemctl daemon-reload
systemctl enable --now "${APP}.service"

echo "Installed ${APP}."
echo "Test from this host: ping ${PEER_IP}"
echo "Note: GRE uses IP protocol 47. Ensure it is allowed by firewall/provider."
