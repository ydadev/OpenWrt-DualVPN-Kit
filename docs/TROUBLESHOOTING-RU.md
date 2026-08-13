# Диагностика и откат

## До reboot

```sh
/tmp/OpenWrt-DualVPN-Kit/scripts/verify-dual-vpn.sh
logread > /tmp/logread.txt
dmesg > /tmp/dmesg.txt
```

Не публикуйте полный `/etc/config/network` или backup: там находятся ключи.

## Unsupported protocol

```sh
command -v wg
command -v awg
test -x /lib/netifd/proto/wireguard.sh
test -x /lib/netifd/proto/amneziawg.sh
```

Ошибка означает отсутствие или несовместимость tools/kernel/netifd-protocol. Найдите
пакеты для точного OpenWrt/kernel; LT300 APK или чужой `kmod` использовать нельзя.

## Preflight переключателя не проходит

```sh
ifstatus "$(uci -q get vpnmode.main.transport_if)"
date -u
wg show wg0
awg show awg0
ip -4 route
logread -e vpn-switch -e netifd
```

Старый режим сохраняется намеренно. Проверьте endpoint/порт, ключи, AWG-параметры,
время, маршрут endpoint через транспорт и доступность `PROBE_IP` по ICMP.

## Handshake есть, трафика нет

```sh
ip -4 route show default
ping -c 3 -I wg0 1.1.1.1
ping -c 3 -I awg0 1.1.1.1
nft list ruleset | grep -E 'dualvpn|masquerade'
nslookup example.com 127.0.0.1
```

Проверьте серверный NAT/forwarding, адрес клиента, AllowedIPs, MTU и DNS. У обоих
peer `route_allowed_ips` должен быть 0.

## После reboot нет маршрута

```sh
/etc/init.d/vpn-restore-mode enabled
logread -e vpn-restore-mode
/usr/sbin/vpn-use-wg
```

Транспорт мог подниматься дольше окна восстановления. Увеличьте `ATTEMPTS` только
после диагностики готовности модема/провайдера.

## Потерян доступ

Используйте Ethernet или OpenWrt failsafe. Запустите `uninstall-dual-vpn.sh` либо
вручную удалите правила `firewall.dualvpn*` и включите нужный исходный forwarding.
Backup `/root/pre-openwrt-dualvpn-*.tar.gz` создаётся до изменений.
