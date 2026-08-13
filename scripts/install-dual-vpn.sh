#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SETUP_FILE="${1:-}"

[ -r "$SETUP_FILE" ] || {
    echo "Usage: $0 /tmp/setup.env" >&2
    exit 1
}

# setup.env is an administrator-controlled shell assignment file.
# Do not use a file downloaded from an untrusted source.
. "$SETUP_FILE"

WG_IF="${WG_IF:-wg0}"
AWG_IF="${AWG_IF:-awg0}"
TRANSPORT_IF="${TRANSPORT_IF:-wan}"
TRANSPORT_ZONE="${TRANSPORT_ZONE:-wan}"
TRANSPORT_METRIC="${TRANSPORT_METRIC:-100}"
LAN_ZONE="${LAN_ZONE:-lan}"
INITIAL_MODE="${INITIAL_MODE:-wg}"
PROBE_IP="${PROBE_IP:-1.1.1.1}"
WG_CONF="${WG_CONF:-}"
AWG_CONF="${AWG_CONF:-}"
WG_MTU="${WG_MTU:-1420}"
AWG_MTU="${AWG_MTU:-1420}"
WG_ADMIN_CIDR="${WG_ADMIN_CIDR:-}"
AWG_ADMIN_CIDR="${AWG_ADMIN_CIDR:-}"
ALLOW_REMOTE_SSH="${ALLOW_REMOTE_SSH:-0}"
ALLOW_DOWNSTREAM_ENDPOINTS="${ALLOW_DOWNSTREAM_ENDPOINTS:-1}"
DNS_SERVERS="${DNS_SERVERS:-}"
PRE_VPN_HOOK="${PRE_VPN_HOOK:-}"
ENABLE_IPV6="${ENABLE_IPV6:-0}"
MODEM_AT_PORT="${MODEM_AT_PORT:-}"
MODEM_CLOCK_IS_UTC="${MODEM_CLOCK_IS_UTC:-0}"

case "$INITIAL_MODE" in wg|awg) ;; *) echo 'ERROR: INITIAL_MODE must be wg or awg.' >&2; exit 1 ;; esac
case "$ALLOW_REMOTE_SSH:$ALLOW_DOWNSTREAM_ENDPOINTS:$ENABLE_IPV6" in
    [01]:[01]:[01]) ;;
    *) echo 'ERROR: boolean values must be 0 or 1.' >&2; exit 1 ;;
esac
for name in "$WG_IF" "$AWG_IF" "$TRANSPORT_IF" "$TRANSPORT_ZONE" "$LAN_ZONE"; do
    echo "$name" | grep -Eq '^[A-Za-z0-9_]+$' || { echo "ERROR: unsafe UCI name: $name" >&2; exit 1; }
done
echo "$PROBE_IP" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' || { echo 'ERROR: PROBE_IP must be an IPv4 literal.' >&2; exit 1; }
echo "$TRANSPORT_METRIC" | grep -Eq '^[0-9]+$' || { echo 'ERROR: TRANSPORT_METRIC must be numeric.' >&2; exit 1; }
[ "$TRANSPORT_METRIC" -gt 10 ] || { echo 'ERROR: TRANSPORT_METRIC must be greater than VPN metric 10.' >&2; exit 1; }
[ -z "$WG_ADMIN_CIDR" ] || echo "$WG_ADMIN_CIDR" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$' || { echo 'ERROR: invalid WG_ADMIN_CIDR.' >&2; exit 1; }
[ -z "$AWG_ADMIN_CIDR" ] || echo "$AWG_ADMIN_CIDR" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$' || { echo 'ERROR: invalid AWG_ADMIN_CIDR.' >&2; exit 1; }
[ "$ALLOW_REMOTE_SSH" = '0' ] || { [ -n "$WG_ADMIN_CIDR" ] && [ -n "$AWG_ADMIN_CIDR" ]; } || {
    echo 'ERROR: both admin CIDRs are required when remote SSH is enabled.' >&2
    exit 1
}
[ -z "$PRE_VPN_HOOK" ] || [ -x "$PRE_VPN_HOOK" ] || { echo "ERROR: PRE_VPN_HOOK is not executable: $PRE_VPN_HOOK" >&2; exit 1; }
if [ -n "$MODEM_AT_PORT" ]; then
    [ "$MODEM_CLOCK_IS_UTC" = '1' ] || { echo 'ERROR: set MODEM_CLOCK_IS_UTC=1 only after confirming AT+CCLK reports UTC.' >&2; exit 1; }
    command -v stty >/dev/null 2>&1 || { echo 'ERROR: stty is required for modem time sync.' >&2; exit 1; }
    [ -r "$SCRIPT_DIR/sync-time-from-modem.sh" ] || { echo 'ERROR: sync-time-from-modem.sh is missing.' >&2; exit 1; }
    PRE_VPN_HOOK='/usr/sbin/dualvpn-sync-modem-time'
fi

for command in uci ubus jsonfilter ip ifup sysupgrade; do
    command -v "$command" >/dev/null 2>&1 || { echo "ERROR: missing command: $command" >&2; exit 1; }
done
command -v wg >/dev/null 2>&1 || { echo 'ERROR: wireguard-tools is not installed.' >&2; exit 1; }
command -v awg >/dev/null 2>&1 || { echo 'ERROR: amneziawg-tools is not installed.' >&2; exit 1; }
[ -x /lib/netifd/proto/wireguard.sh ] || { echo 'ERROR: WireGuard netifd protocol is missing.' >&2; exit 1; }
[ -x /lib/netifd/proto/amneziawg.sh ] || { echo 'ERROR: AmneziaWG netifd protocol is missing.' >&2; exit 1; }
[ -n "$(uci -q get "network.$TRANSPORT_IF.proto" || true)" ] || { echo "ERROR: network.$TRANSPORT_IF does not exist." >&2; exit 1; }
uci -q show firewall >/dev/null 2>&1 || { echo 'ERROR: firewall configuration is missing.' >&2; exit 1; }

for file in configure-wireguard-from-conf.sh configure-awg-from-conf.sh vpn-switch vpn-apply-route vpn-restore-mode vpn-restore-mode.init 96-vpn-route verify-dual-vpn.sh preflight.sh uninstall-dual-vpn.sh sync-time-from-modem.sh; do
    [ -r "$SCRIPT_DIR/$file" ] || { echo "ERROR: missing $SCRIPT_DIR/$file" >&2; exit 1; }
    /bin/sh -n "$SCRIPT_DIR/$file"
done

BACKUP="/root/pre-openwrt-dualvpn-$(date +%Y%m%d-%H%M%S).tar.gz"
sysupgrade -b "$BACKUP"
echo "Backup saved to $BACKUP"

if [ -n "$WG_CONF" ]; then
    [ -r "$WG_CONF" ] || { echo "ERROR: cannot read WG_CONF: $WG_CONF" >&2; exit 1; }
    "$SCRIPT_DIR/configure-wireguard-from-conf.sh" "$WG_CONF" "$WG_IF" "$WG_MTU"
fi
if [ -n "$AWG_CONF" ]; then
    [ -r "$AWG_CONF" ] || { echo "ERROR: cannot read AWG_CONF: $AWG_CONF" >&2; exit 1; }
    "$SCRIPT_DIR/configure-awg-from-conf.sh" "$AWG_CONF" "$AWG_IF" "$AWG_MTU"
fi

[ "$(uci -q get "network.$WG_IF.proto" || true)" = 'wireguard' ] || { echo "ERROR: network.$WG_IF is not WireGuard." >&2; exit 1; }
[ "$(uci -q get "network.$AWG_IF.proto" || true)" = 'amneziawg' ] || { echo "ERROR: network.$AWG_IF is not AmneziaWG." >&2; exit 1; }
WG_PEER="${WG_IF}_peer"
AWG_PEER="${AWG_IF}_peer"
WG_ENDPOINT="$(uci -q get "network.$WG_PEER.endpoint_host" || true)"
AWG_ENDPOINT="$(uci -q get "network.$AWG_PEER.endpoint_host" || true)"
WG_PORT="$(uci -q get "network.$WG_PEER.endpoint_port" || true)"
AWG_PORT="$(uci -q get "network.$AWG_PEER.endpoint_port" || true)"
[ -n "$WG_ENDPOINT" ] && [ -n "$WG_PORT" ] && [ -n "$AWG_ENDPOINT" ] && [ -n "$AWG_PORT" ] || { echo 'ERROR: VPN endpoint data is incomplete.' >&2; exit 1; }

cp "$SCRIPT_DIR/vpn-switch" /usr/sbin/vpn-switch
cp "$SCRIPT_DIR/vpn-apply-route" /usr/sbin/vpn-apply-route
cp "$SCRIPT_DIR/vpn-restore-mode" /usr/sbin/vpn-restore-mode
cp "$SCRIPT_DIR/vpn-restore-mode.init" /etc/init.d/vpn-restore-mode
cp "$SCRIPT_DIR/96-vpn-route" /etc/hotplug.d/iface/96-vpn-route
chmod 700 /usr/sbin/vpn-switch /usr/sbin/vpn-apply-route /usr/sbin/vpn-restore-mode
chmod 755 /etc/init.d/vpn-restore-mode /etc/hotplug.d/iface/96-vpn-route
ln -sf /usr/sbin/vpn-switch /usr/sbin/vpn-use-wg
ln -sf /usr/sbin/vpn-switch /usr/sbin/vpn-use-awg
ln -sf /usr/sbin/vpn-switch /usr/sbin/vpn-status
/etc/init.d/vpn-restore-mode enable
if [ -n "$MODEM_AT_PORT" ]; then
    cp "$SCRIPT_DIR/sync-time-from-modem.sh" /usr/sbin/dualvpn-sync-modem-time
    chmod 700 /usr/sbin/dualvpn-sync-modem-time
fi

touch /etc/config/vpnmode
PREVIOUS_DISABLED_FORWARDINGS="$(uci -q get vpnmode.main.disabled_forwardings || true)"
uci -q delete vpnmode.main || true
uci set vpnmode.main=mode
uci set "vpnmode.main.mode=$INITIAL_MODE"
uci set "vpnmode.main.wg_if=$WG_IF"
uci set "vpnmode.main.awg_if=$AWG_IF"
uci set "vpnmode.main.transport_if=$TRANSPORT_IF"
uci set "vpnmode.main.transport_zone=$TRANSPORT_ZONE"
uci set "vpnmode.main.lan_zone=$LAN_ZONE"
uci set "vpnmode.main.wg_endpoint=$WG_ENDPOINT"
uci set "vpnmode.main.awg_endpoint=$AWG_ENDPOINT"
uci set "vpnmode.main.wg_port=$WG_PORT"
uci set "vpnmode.main.awg_port=$AWG_PORT"
uci set "vpnmode.main.probe_ip=$PROBE_IP"
uci set "vpnmode.main.enable_ipv6=$ENABLE_IPV6"
uci set vpnmode.main.auto_failover='0'
[ -z "$WG_ADMIN_CIDR" ] || uci set "vpnmode.main.wg_admin_net=$WG_ADMIN_CIDR"
[ -z "$AWG_ADMIN_CIDR" ] || uci set "vpnmode.main.awg_admin_net=$AWG_ADMIN_CIDR"
[ -z "$PRE_VPN_HOOK" ] || uci set "vpnmode.main.pre_vpn_hook=$PRE_VPN_HOOK"
[ -z "$MODEM_AT_PORT" ] || uci set "vpnmode.main.modem_at_port=$MODEM_AT_PORT"
for forwarding in $PREVIOUS_DISABLED_FORWARDINGS; do
    uci add_list "vpnmode.main.disabled_forwardings=$forwarding"
done
uci commit vpnmode
chmod 600 /etc/config/vpnmode

uci set "network.$WG_IF.nohostroute=1"
uci set "network.$AWG_IF.nohostroute=1"
uci set "network.$WG_PEER.route_allowed_ips=0"
uci set "network.$AWG_PEER.route_allowed_ips=0"
uci set "network.$TRANSPORT_IF.metric=$TRANSPORT_METRIC"
if [ -n "$WG_ADMIN_CIDR" ]; then
    uci -q delete network.vpn_admin_wg_route || true
    uci set network.vpn_admin_wg_route=route
    uci set "network.vpn_admin_wg_route.interface=$WG_IF"
    uci set "network.vpn_admin_wg_route.target=$WG_ADMIN_CIDR"
    uci set network.vpn_admin_wg_route.metric='5'
fi
if [ -n "$AWG_ADMIN_CIDR" ]; then
    uci -q delete network.vpn_admin_awg_route || true
    uci set network.vpn_admin_awg_route=route
    uci set "network.vpn_admin_awg_route.interface=$AWG_IF"
    uci set "network.vpn_admin_awg_route.target=$AWG_ADMIN_CIDR"
    uci set network.vpn_admin_awg_route.metric='5'
fi
uci commit network

uci -q delete firewall.dualvpn || true
uci set firewall.dualvpn=zone
uci set firewall.dualvpn.name='dualvpn'
uci add_list "firewall.dualvpn.network=$WG_IF"
uci add_list "firewall.dualvpn.network=$AWG_IF"
uci set firewall.dualvpn.input='REJECT'
uci set firewall.dualvpn.output='ACCEPT'
uci set firewall.dualvpn.forward='REJECT'
uci set firewall.dualvpn.masq='1'
uci set firewall.dualvpn.mtu_fix='1'
uci -q delete firewall.lan_to_dualvpn || true
uci set firewall.lan_to_dualvpn=forwarding
uci set "firewall.lan_to_dualvpn.src=$LAN_ZONE"
uci set firewall.lan_to_dualvpn.dest='dualvpn'

for forwarding in $(uci show firewall | sed -n 's/^\(firewall\.[^=]*\)=forwarding$/\1/p'); do
    src="$(uci -q get "$forwarding.src" || true)"
    dest="$(uci -q get "$forwarding.dest" || true)"
    if [ "$src" = "$LAN_ZONE" ] && [ "$dest" = "$TRANSPORT_ZONE" ]; then
        enabled="$(uci -q get "$forwarding.enabled" || echo 1)"
        if [ "$enabled" != '0' ]; then
            uci set "$forwarding.enabled=0"
            case " $PREVIOUS_DISABLED_FORWARDINGS " in
                *" $forwarding "*) ;;
                *) uci add_list "vpnmode.main.disabled_forwardings=$forwarding" ;;
            esac
        fi
    fi
done
uci commit vpnmode

add_endpoint_exception() {
    section="$1" label="$2" endpoint="$3" port="$4"
    uci -q delete "firewall.$section" || true
    [ "$ALLOW_DOWNSTREAM_ENDPOINTS" = '1' ] || return 0
    case "$endpoint" in ''|*[!0-9.]*) echo "WARNING: $label endpoint is not an IPv4 literal; downstream exception skipped." >&2; return 0 ;; esac
    uci set "firewall.$section=rule"
    uci set "firewall.$section.name=Allow-LAN-$label-Endpoint-Direct"
    uci set "firewall.$section.src=$LAN_ZONE"
    uci set "firewall.$section.dest=$TRANSPORT_ZONE"
    uci set "firewall.$section.family=ipv4"
    uci set "firewall.$section.proto=udp"
    uci set "firewall.$section.dest_ip=$endpoint"
    uci set "firewall.$section.dest_port=$port"
    uci set "firewall.$section.target=ACCEPT"
}
add_endpoint_exception dualvpn_endpoint_wg WireGuard "$WG_ENDPOINT" "$WG_PORT"
add_endpoint_exception dualvpn_endpoint_awg AmneziaWG "$AWG_ENDPOINT" "$AWG_PORT"

uci -q delete firewall.dualvpn_admin_ssh_wg || true
uci -q delete firewall.dualvpn_admin_ssh_awg || true
if [ "$ALLOW_REMOTE_SSH" = '1' ]; then
    uci set firewall.dualvpn_admin_ssh_wg=rule
    uci set firewall.dualvpn_admin_ssh_wg.name='Allow-SSH-from-WireGuard-network'
    uci set firewall.dualvpn_admin_ssh_wg.src='dualvpn'
    uci set firewall.dualvpn_admin_ssh_wg.family='ipv4'
    uci set firewall.dualvpn_admin_ssh_wg.proto='tcp'
    uci set "firewall.dualvpn_admin_ssh_wg.src_ip=$WG_ADMIN_CIDR"
    uci set firewall.dualvpn_admin_ssh_wg.dest_port='22'
    uci set firewall.dualvpn_admin_ssh_wg.target='ACCEPT'
    uci set firewall.dualvpn_admin_ssh_awg=rule
    uci set firewall.dualvpn_admin_ssh_awg.name='Allow-SSH-from-AmneziaWG-network'
    uci set firewall.dualvpn_admin_ssh_awg.src='dualvpn'
    uci set firewall.dualvpn_admin_ssh_awg.family='ipv4'
    uci set firewall.dualvpn_admin_ssh_awg.proto='tcp'
    uci set "firewall.dualvpn_admin_ssh_awg.src_ip=$AWG_ADMIN_CIDR"
    uci set firewall.dualvpn_admin_ssh_awg.dest_port='22'
    uci set firewall.dualvpn_admin_ssh_awg.target='ACCEPT'
fi
uci commit firewall

if [ -n "$DNS_SERVERS" ]; then
    uci set dhcp.@dnsmasq[0].noresolv='1'
    uci -q delete dhcp.@dnsmasq[0].server || true
    for server in $DNS_SERVERS; do uci add_list "dhcp.@dnsmasq[0].server=$server"; done
    uci commit dhcp
fi

if [ -f /etc/config/luci ]; then
    for section in dualvpn_wg dualvpn_awg dualvpn_status; do uci -q delete "luci.$section" || true; done
    uci set luci.dualvpn_wg=command
    uci set luci.dualvpn_wg.name='VPN_WireGuard'
    uci set luci.dualvpn_wg.command='/usr/sbin/vpn-use-wg'
    uci set luci.dualvpn_awg=command
    uci set luci.dualvpn_awg.name='VPN_AmneziaWG'
    uci set luci.dualvpn_awg.command='/usr/sbin/vpn-use-awg'
    uci set luci.dualvpn_status=command
    uci set luci.dualvpn_status.name='VPN_status'
    uci set luci.dualvpn_status.command='/usr/sbin/vpn-status'
    uci commit luci
fi

for path in /usr/sbin/vpn-switch /usr/sbin/vpn-apply-route /usr/sbin/vpn-restore-mode /etc/init.d/vpn-restore-mode /etc/hotplug.d/iface/96-vpn-route /etc/config/vpnmode; do
    grep -qxF "$path" /etc/sysupgrade.conf 2>/dev/null || echo "$path" >>/etc/sysupgrade.conf
done
[ -z "$MODEM_AT_PORT" ] || grep -qxF /usr/sbin/dualvpn-sync-modem-time /etc/sysupgrade.conf 2>/dev/null || echo /usr/sbin/dualvpn-sync-modem-time >>/etc/sysupgrade.conf

/etc/init.d/network reload
/etc/init.d/firewall reload
[ -z "$DNS_SERVERS" ] || /etc/init.d/dnsmasq restart
rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart 2>/dev/null || true
sleep 3

echo 'DualVPN installed. Automatic failover is OFF.'
echo "Transport: $TRANSPORT_IF (firewall zone $TRANSPORT_ZONE)"
echo 'Switch commands: vpn-use-wg, vpn-use-awg, vpn-status'
echo "Activate the initial mode with: /usr/sbin/vpn-switch $INITIAL_MODE"
echo 'Delete temporary setup and VPN config files after validation.'
