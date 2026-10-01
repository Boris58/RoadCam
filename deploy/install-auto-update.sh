#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите установщик от имени root." >&2
  exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -m 0755 "$SOURCE_DIR/update-from-github.sh" /usr/local/sbin/gdekamera-auto-update

cat > /etc/systemd/system/gdekamera-auto-update.service <<'UNIT'
[Unit]
Description=Проверка обновлений сайта Где камера
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/gdekamera-auto-update
UNIT

cat > /etc/systemd/system/gdekamera-auto-update.timer <<'UNIT'
[Unit]
Description=Регулярная проверка обновлений сайта Где камера

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
RandomizedDelaySec=5min
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now gdekamera-auto-update.timer
echo "Автообновление установлено. Проверка выполняется примерно раз в час."
echo "Ручная проверка: systemctl start gdekamera-auto-update.service"
systemctl start gdekamera-auto-update.service
