# Установка на произвольный OpenWrt-роутер

## 1. Условия

Нужны OpenWrt с writable overlay, работающий интернет-транспорт, WireGuard,
AmneziaWG 2.0 и доступ по Ethernet. Не начинайте с настройки VPN: сначала добейтесь,
чтобы `ifstatus wan` или ваш LTE-интерфейс показывал `"up": true` и endpoint обоих
VPN был доступен через него.

Определите платформу:

```sh
ubus call system board
uname -r
apk --print-arch 2>/dev/null || opkg print-architecture
ubus call network.interface dump
uci show firewall
```

Пакеты и особенно `kmod-*` берите только для точного OpenWrt release, target,
architecture и kernel ABI. Проект не включает универсальные бинарники.

## 2. Backup

```sh
sysupgrade -b /tmp/before-dualvpn.tar.gz
sha256sum /tmp/before-dualvpn.tar.gz
```

Скачайте backup и храните закрыто: в нём могут быть пароли и ключи.

## 3. Пакеты

Для обычного WG обычно нужны `kmod-wireguard`, `wireguard-tools` и
`luci-proto-wireguard`. AmneziaWG установите из совместимого с вашей сборкой
источника: kernel module, tools и netifd/LuCI protocol. Дополнительно полезны
`resolveip` и `luci-app-commands`.

Имена пакетов и менеджер (`apk` или `opkg`) зависят от OpenWrt release. Проверка:

```sh
command -v wg
command -v awg
test -x /lib/netifd/proto/wireguard.sh
test -x /lib/netifd/proto/amneziawg.sh
```

## 4. Выбор транспорта

В `examples/setup.env.example` задайте:

```sh
TRANSPORT_IF='wan'
TRANSPORT_ZONE='wan'
TRANSPORT_METRIC='100'
LAN_ZONE='lan'
```

Для LTE логический интерфейс может называться `wwan`, `lte`, `modem` или иначе,
но его firewall-зона часто всё равно называется `wan`. Не подставляйте физическое
устройство `eth0`, `usb0` или `wwan0` вместо логического UCI-интерфейса.
Transport metric должен быть больше VPN metric 10. Значение 100 гарантирует, что
активный VPN станет приоритетным, а endpoint сохранит отдельный host route через
исходный транспорт.

## 5. Передача файлов

```powershell
scp -O -r .\OpenWrt-DualVPN-Kit root@192.168.1.1:/tmp/
scp -O .\my-wireguard.conf root@192.168.1.1:/tmp/wireguard.conf
scp -O .\my-amneziawg.conf root@192.168.1.1:/tmp/amneziawg.conf
scp -O .\setup.env root@192.168.1.1:/tmp/setup.env
```

Реальные конфиги и `setup.env` с приватными путями не добавляйте в git.

## 6. Preflight и установка

```sh
chmod 700 /tmp/OpenWrt-DualVPN-Kit/scripts/*
chmod 600 /tmp/setup.env /tmp/wireguard.conf /tmp/amneziawg.conf
/tmp/OpenWrt-DualVPN-Kit/scripts/preflight.sh /tmp/setup.env
/tmp/OpenWrt-DualVPN-Kit/scripts/install-dual-vpn.sh /tmp/setup.env
```

Установщик:

1. проверяет транспорт и протоколы;
2. создаёт backup;
3. импортирует ровно один peer WG и AWG, не печатая ключи;
4. создаёт единую firewall-зону `dualvpn` и `lan → dualvpn`;
5. отключает существующий `LAN_ZONE → TRANSPORT_ZONE` forwarding как kill switch;
6. устанавливает переключатель, hotplug и boot recovery;
7. при явном разрешении добавляет удалённый SSH и downstream-исключения.

## 7. Активация

```sh
/usr/sbin/vpn-use-wg
/usr/sbin/vpn-status
/tmp/OpenWrt-DualVPN-Kit/scripts/verify-dual-vpn.sh
```

Переключение на AWG:

```sh
/usr/sbin/vpn-use-awg
```

Default route меняется только после handshake и успешного ping через целевой
интерфейс. Неуспешный резерв не ломает текущий режим.

## 8. DNS и MTU

DNS из VPN-конфигов намеренно не применяется автоматически. Укажите в `DNS_SERVERS`
адреса, доступные через оба туннеля, либо оставьте пусто и настройте dnsmasq сами.

Начните с MTU 1420. Для LTE/PPPoE при фрагментации уменьшайте одновременно WG/AWG
до 1380, 1360 или значения, подтверждённого тестом.

## 9. Reboot и cold boot

```sh
reboot
```

После загрузки:

```sh
/usr/sbin/vpn-status
ip -4 route
logread -e vpn-restore-mode
```

Проверьте не только reboot, но и отключение питания. Модем может регистрироваться
дольше обычного; boot recovery делает ограниченное число попыток и не является
бесконечным watchdog.

## 10. Удаление

```sh
/tmp/OpenWrt-DualVPN-Kit/scripts/uninstall-dual-vpn.sh
```

Скрипт удаляет управляющий слой, но сохраняет определения VPN и пакеты. Forwarding,
который установщик сам отключил для kill switch, включается обратно; изначально
отключённые пользовательские правила не изменяются.
