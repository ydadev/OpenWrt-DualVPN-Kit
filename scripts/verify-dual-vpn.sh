#!/bin/sh

transport_if="$(uci -q get vpnmode.main.transport_if || echo wan)"
wg_if="$(uci -q get vpnmode.main.wg_if || echo wg0)"
awg_if="$(uci -q get vpnmode.main.awg_if || echo awg0)"

echo '=== BOARD ==='
ubus call system board 2>/dev/null || true
echo '=== MODE ==='
uci show vpnmode 2>/dev/null || true
echo '=== TRANSPORT ==='
ifstatus "$transport_if" 2>/dev/null || true
echo '=== VPN STATUS ==='
/usr/sbin/vpn-status 2>/dev/null || true
echo '=== ROUTES ==='
ip -4 route
echo '=== ENDPOINT ROUTES ==='
for endpoint in "$(uci -q get vpnmode.main.wg_endpoint || true)" "$(uci -q get vpnmode.main.awg_endpoint || true)"; do
    [ -n "$endpoint" ] && ip -4 route get "$endpoint" 2>/dev/null || true
done
echo '=== FIREWALL ==='
uci show firewall.dualvpn 2>/dev/null || true
uci show firewall.lan_to_dualvpn 2>/dev/null || true
uci show firewall.dualvpn_admin_ssh_wg 2>/dev/null || true
uci show firewall.dualvpn_admin_ssh_awg 2>/dev/null || true
echo '=== DIRECT LAN TO TRANSPORT ==='
transport_zone="$(uci -q get vpnmode.main.transport_zone || echo wan)"
lan_zone="$(uci -q get vpnmode.main.lan_zone || echo lan)"
for forwarding in $(uci show firewall | sed -n 's/^\(firewall\.[^=]*\)=forwarding$/\1/p'); do
    src="$(uci -q get "$forwarding.src" || true)"
    dest="$(uci -q get "$forwarding.dest" || true)"
    enabled="$(uci -q get "$forwarding.enabled" || echo 1)"
    [ "$src" = "$lan_zone" ] && [ "$dest" = "$transport_zone" ] && echo "$forwarding enabled=$enabled"
done
echo '=== HANDSHAKES ==='
wg show "$wg_if" latest-handshakes 2>/dev/null || true
awg show "$awg_if" latest-handshakes 2>/dev/null || true
echo '=== DNS ==='
nslookup example.com 127.0.0.1 2>/dev/null || true
