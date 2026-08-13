#!/bin/sh
set -eu

SETUP_FILE="${1:-}"
[ -r "$SETUP_FILE" ] || { echo "Usage: $0 /tmp/setup.env" >&2; exit 1; }
. "$SETUP_FILE"

TRANSPORT_IF="${TRANSPORT_IF:-wan}"
TRANSPORT_ZONE="${TRANSPORT_ZONE:-wan}"
WG_CONF="${WG_CONF:-}"
AWG_CONF="${AWG_CONF:-}"

echo '=== BOARD ==='
ubus call system board
echo '=== STORAGE ==='
df -h /overlay
echo '=== TRANSPORT ==='
ifstatus "$TRANSPORT_IF"
up="$(ifstatus "$TRANSPORT_IF" | jsonfilter -e '@.up' 2>/dev/null || true)"
[ "$up" = 'true' ] || { echo "ERROR: transport $TRANSPORT_IF is down." >&2; exit 1; }
echo '=== FIREWALL ZONE ==='
uci show firewall | grep -F ".name='$TRANSPORT_ZONE'" >/dev/null || { echo "ERROR: zone $TRANSPORT_ZONE not found." >&2; exit 1; }
echo '=== REQUIRED COMMANDS ==='
for command in uci ubus jsonfilter ip wg awg sysupgrade; do
    command -v "$command" >/dev/null 2>&1 || { echo "ERROR: missing $command" >&2; exit 1; }
    echo "OK: $command"
done
[ -x /lib/netifd/proto/wireguard.sh ] || { echo 'ERROR: WireGuard netifd protocol missing.' >&2; exit 1; }
[ -x /lib/netifd/proto/amneziawg.sh ] || { echo 'ERROR: AmneziaWG netifd protocol missing.' >&2; exit 1; }
[ -r "$WG_CONF" ] || { echo "ERROR: WG_CONF unreadable: $WG_CONF" >&2; exit 1; }
[ -r "$AWG_CONF" ] || { echo "ERROR: AWG_CONF unreadable: $AWG_CONF" >&2; exit 1; }
echo 'Preflight: OK'
