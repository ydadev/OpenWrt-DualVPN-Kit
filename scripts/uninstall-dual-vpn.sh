#!/bin/sh
set -eu

BACKUP="/root/pre-dualvpn-uninstall-$(date +%Y%m%d-%H%M%S).tar.gz"
sysupgrade -b "$BACKUP"

DISABLED_FORWARDINGS="$(uci -q get vpnmode.main.disabled_forwardings || true)"

/etc/init.d/vpn-restore-mode stop 2>/dev/null || true
/etc/init.d/vpn-restore-mode disable 2>/dev/null || true
rm -f /usr/sbin/vpn-switch /usr/sbin/vpn-apply-route /usr/sbin/vpn-restore-mode
rm -f /usr/sbin/vpn-use-wg /usr/sbin/vpn-use-awg /usr/sbin/vpn-status
rm -f /etc/init.d/vpn-restore-mode /etc/hotplug.d/iface/96-vpn-route

for section in dualvpn lan_to_dualvpn dualvpn_endpoint_wg dualvpn_endpoint_awg dualvpn_admin_ssh_wg dualvpn_admin_ssh_awg; do
    uci -q delete "firewall.$section" || true
done
for section in vpn_admin_wg_route vpn_admin_awg_route; do uci -q delete "network.$section" || true; done
for section in dualvpn_wg dualvpn_awg dualvpn_status; do uci -q delete "luci.$section" || true; done
for forwarding in $DISABLED_FORWARDINGS; do
    [ "$(uci -q get "$forwarding" || true)" = 'forwarding' ] && uci set "$forwarding.enabled=1" || true
done
uci commit firewall
uci commit network
uci commit luci 2>/dev/null || true
rm -f /etc/config/vpnmode
/etc/init.d/network reload
/etc/init.d/firewall reload
rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart 2>/dev/null || true

echo "DualVPN control layer removed. Backup: $BACKUP"
echo 'VPN interface definitions and packages were intentionally kept.'
echo 'Forwardings disabled by the installer were re-enabled.'
