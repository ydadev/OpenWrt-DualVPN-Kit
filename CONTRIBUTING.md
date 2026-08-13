# Участие в проекте

В изменении укажите OpenWrt release, target, kernel, transport protocol и результаты
reboot/cold boot. Не добавляйте бинарные kernel-пакеты или настройки одной модели в
общий репозиторий.

Проверка:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-repo.ps1
```

Удаляйте из логов ключи, пароли, APN, IMSI/IMEI и реальные endpoint. Сообщение
коммита в этом репозитории оформляется датой `YYYY-MM-DD`.
