# Безопасность

- Никогда не добавляйте реальные WG/AWG-конфиги, ключи, пароли, backup, APN, IMSI,
  IMEI и закрытые endpoint.
- Используйте документальные адреса `203.0.113.0/24` и заглушки `REPLACE_WITH_...`.
- `setup.env` исполняется `/bin/sh`; используйте только собственный файл с простыми
  присваиваниями и не запускайте скачанный непроверенный вариант.
- Kernel-пакеты должны совпадать с release, target, architecture и kernel ABI.
- Установку и первый reboot выполняйте по Ethernet с доступным failsafe/recovery.
- Не включайте remote SSH без точных source CIDR и серверных маршрутов.
- Не включайте modem time, пока не подтверждено, что `AT+CCLK?` сообщает UTC.

Перед commit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-repo.ps1
gitleaks detect --no-banner --redact
```

Опубликованный приватный ключ считается скомпрометированным и заменяется на клиенте
и сервере, даже если затем был удалён из истории git.
