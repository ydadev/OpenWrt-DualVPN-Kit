# Состав файлов

- `scripts/preflight.sh` — read-only проверка транспорта, пакетов и конфигов.
- `scripts/install-dual-vpn.sh` — backup, импорт, маршруты, firewall, LuCI и boot.
- `scripts/configure-*-from-conf.sh` — импорт ровно одного peer без вывода ключей.
- `scripts/vpn-switch` — безопасное ручное переключение после preflight.
- `scripts/vpn-apply-route` — endpoint host routes и активный default route.
- `scripts/vpn-restore-mode*`, `96-vpn-route` — восстановление после загрузки/ifup.
- `scripts/sync-time-from-modem.sh` — optional `AT+CCLK?`, только подтверждённый UTC.
- `scripts/verify-dual-vpn.sh` — обезличенная диагностика.
- `scripts/uninstall-dual-vpn.sh` — удаление управляющего слоя с backup.
- `examples/` — синтетические конфиги и параметрический `setup.env`.
- `tools/validate-repo.ps1` — проверка структуры, ссылок, shell и секретов.
- `tools/build-release.ps1` — чистый source ZIP без `.git` и приватных конфигов.

Репозиторий намеренно не содержит firmware, APK, `.ko`, реальных VPN-конфигов и
устройственно-зависимых драйверов. Это позволяет переносить логику, не создавая
опасного впечатления бинарной совместимости разных роутеров.
