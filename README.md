# OpenWrt DualVPN Kit

Аппаратно-независимый набор для OpenWrt, который использует существующее интернет-
подключение как транспорт и направляет трафик LAN через WireGuard или AmneziaWG 2.0.
Транспортом может быть обычный Ethernet WAN, Wi-Fi WWAN, LTE/5G-модем или любой уже
работающий логический интерфейс OpenWrt.

Проект создан на основе практической эксплуатации Cudy LT300, но не содержит его
firmware, драйверов, APK или аппаратных настроек. Это общий слой маршрутизации,
firewall и управления VPN.

## Возможности

- WireGuard как основной и AmneziaWG как резервный режим либо наоборот;
- оба интерфейса могут оставаться поднятыми: режим выбирает default route, но не
  отключает SSH или другой служебный трафик через резервный туннель;
- ручное переключение с проверкой handshake и трафика до смены default route;
- host route обоих VPN endpoint через исходный транспорт;
- kill switch: LAN не получает незаметный прямой выход через WAN/LTE;
- восстановление выбранного режима после reboot;
- LuCI-кнопки через `luci-app-commands`;
- точечные исключения для клиентов LAN, поднимающих собственный VPN к тем же endpoint;
- опциональный SSH к роутеру только из заданных VPN-подсетей;
- опциональная установка времени через `AT+CCLK?` до VPN;
- конфигурация без прошивки, бинарных kernel-модулей и реальных ключей.

## Поддерживаемые варианты транспорта

Установщику нужен не тип модема, а уже поднятый логический интерфейс OpenWrt:

| Канал | Примеры `TRANSPORT_IF` |
|---|---|
| Ethernet/DHCP/PPPoE | `wan` |
| Wi-Fi клиент | `wwan` |
| USB RNDIS/ECM/NCM | `wwan`, `lte` или ваше имя |
| QMI/MBIM | интерфейс, созданный `uqmi`/`umbim`/ModemManager |
| Встроенный LTE/5G | интерфейс из `/etc/config/network` |

Проверьте имя через `ifstatus <имя>` и `ubus call network.interface dump`. Firewall-
зона задаётся отдельно: обычно это `wan`, даже если интерфейс называется `wwan`.
Установщик назначает транспорту metric `100`, чтобы VPN default с metric `10`
действительно стал приоритетным; значение настраивается через `TRANSPORT_METRIC`.

## Совместимость

Скрипты рассчитаны на современный OpenWrt с UCI, netifd, firewall4/nftables,
procd, `ip`, `jsonfilter`, WireGuard и AmneziaWG. Точный OpenWrt release намеренно
не зафиксирован. Пакеты AmneziaWG и kernel-модули должны точно соответствовать вашей
версии OpenWrt, target, architecture и kernel ABI.

## Быстрый старт

1. Сохраните backup и настройте рабочий транспорт без VPN.
2. Установите WireGuard, AmneziaWG и при необходимости LuCI Commands.
3. Скопируйте проект и два личных конфига в `/tmp`.
4. Создайте `setup.env` из примера.
5. Запустите установщик по Ethernet:

```sh
chmod 700 /tmp/OpenWrt-DualVPN-Kit/scripts/*
/tmp/OpenWrt-DualVPN-Kit/scripts/preflight.sh /tmp/setup.env
/tmp/OpenWrt-DualVPN-Kit/scripts/install-dual-vpn.sh /tmp/setup.env
/usr/sbin/vpn-use-wg
/tmp/OpenWrt-DualVPN-Kit/scripts/verify-dual-vpn.sh
```

Полная инструкция: [docs/INSTALL-RU.md](docs/INSTALL-RU.md).

## Управление

```sh
/usr/sbin/vpn-status
/usr/sbin/vpn-use-wg
/usr/sbin/vpn-use-awg
```

Если установлен `luci-app-commands`, те же действия доступны в
**System → Custom Commands**.

## Документация

- [Установка и адаптация](docs/INSTALL-RU.md)
- [Архитектура и маршруты](docs/ARCHITECTURE-RU.md)
- [LTE/5G, WAN и время](docs/TRANSPORTS-RU.md)
- [Удалённое управление](docs/REMOTE-ACCESS-RU.md)
- [Диагностика и откат](docs/TROUBLESHOOTING-RU.md)
- [Состав файлов](docs/FILES-RU.md)
- [Безопасность](SECURITY.md)

## Ограничения

- Автоматический failover намеренно не включён: краткие потери пакетов не должны
  создавать переключения туда-обратно.
- Импортёры принимают ровно один `[Peer]`.
- IPv6 по умолчанию выключен, чтобы не создать утечку в обход IPv4 VPN.
- Проект не устанавливает подходящий AmneziaWG автоматически: универсального
  kernel-пакета для всех роутеров не существует.
- Первый запуск и откат выполняйте по Ethernet или через надёжный recovery-канал.

## Проверка проекта

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-repo.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build-release.ps1
```

Проект: [ydadev/OpenWrt-DualVPN-Kit](https://github.com/ydadev/OpenWrt-DualVPN-Kit).

Полезные официальные материалы: [WireGuard client on OpenWrt](https://openwrt.org/docs/guide-user/services/vpn/wireguard/client)
и [WWAN: 3G/4G/5G](https://openwrt.org/docs/guide-user/network/wan/wwan/start).

## Лицензия

Собственные скрипты и документация распространяются по MIT. WireGuard, OpenWrt и
AmneziaWG сохраняют лицензии своих upstream-проектов; см. `THIRD-PARTY-NOTICES.md`.
