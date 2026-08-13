# Транспорт: Ethernet, Wi-Fi WAN и LTE/5G

DualVPN работает поверх логического интерфейса netifd. Проекту безразлично, создан
он DHCP, PPPoE, QMI, MBIM, RNDIS, NCM, ModemManager или Wi-Fi-клиентом.

Проверка транспорта:

```sh
ifstatus wan
ubus call network.interface dump
ip -4 route
```

`TRANSPORT_IF` — имя секции `/etc/config/network`; `TRANSPORT_ZONE` — имя firewall-
зоны, куда она включена. Они не обязаны совпадать.

## Без LTE

Для обычного кабельного WAN чаще всего достаточно:

```sh
TRANSPORT_IF='wan'
TRANSPORT_ZONE='wan'
TRANSPORT_METRIC='100'
```

Часы получают NTP через WAN до VPN. `PRE_VPN_HOOK` и `MODEM_AT_PORT` оставьте пустыми.

## С LTE/5G

Сначала отдельно настройте APN, PIN, режим модема и reconnect. Установщик DualVPN не
угадывает AT-порт и не меняет APN. Убедитесь, что endpoint доступен через SIM/APN.

Если NTP недоступен до VPN, некоторые модемы отдают время сети оператора через:

```text
AT+CCLK?
```

Это опция, а не универсальное свойство. Оператор может не передавать NITZ, модем
может хранить старое время, а `+CCLK` может быть локальным временем со смещением.
Сначала вручную сравните ответ с `date -u`. Только если часы действительно UTC:

```sh
MODEM_AT_PORT='/dev/ttyUSB2'
MODEM_CLOCK_IS_UTC='1'
```

Тогда установщик добавит pre-VPN hook. Если уверенности нет, используйте собственный
`PRE_VPN_HOOK`, локальный NTP/GPS или не включайте функцию.

Для QMI/MBIM AT-порт может отсутствовать или принадлежать другому tty. Не пишите в
порт управления QMI/MBIM как в serial AT.

## Два физических провайдера

Этот release принимает один transport interface. Multi-WAN/mwan3 остаётся внешним
слоем: предоставьте DualVPN логический транспорт с уже выбранным рабочим маршрутом.
Policy routing до VPN endpoint должен оставаться согласованным с mwan3.
