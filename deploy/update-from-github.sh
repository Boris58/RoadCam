#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите обновление от имени root." >&2
  exit 1
fi

REPOSITORY="Boris58/RoadCam"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPOSITORY/$BRANCH/release"
STATE_DIR="/var/lib/gdekamera-deploy"
STATE_FILE="$STATE_DIR/last-release.sha256"
LOCK_FILE="/run/lock/gdekamera-auto-update.lock"
WORK_DIR="$(mktemp -d /tmp/gdekamera-update.XXXXXX)"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Другое обновление уже выполняется."; exit 0; }

install -d -m 0750 "$STATE_DIR"
curl -fsSL "$BASE_URL/gdekamera-release.tar.gz.sha256" -o "$WORK_DIR/expected.sha256"
EXPECTED="$(awk 'NR==1 {print $1}' "$WORK_DIR/expected.sha256")"
if [ -z "$EXPECTED" ] || ! [[ "$EXPECTED" =~ ^[0-9a-f]{64}$ ]]; then
  echo "GitHub вернул некорректную контрольную сумму." >&2
  exit 1
fi
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$EXPECTED" ]; then
  echo "Где камера: установлена актуальная версия $EXPECTED"
  exit 0
fi

curl -fsSL "$BASE_URL/gdekamera-release.parts" -o "$WORK_DIR/parts"
: > "$WORK_DIR/release.tar.gz"
while IFS= read -r part; do
  [ -n "$part" ] || continue
  if ! [[ "$part" =~ ^gdekamera-release\.part-[0-9]{3}$ ]]; then
    echo "Некорректное имя части релиза: $part" >&2
    exit 1
  fi
  curl -fsSL "$BASE_URL/$part" >> "$WORK_DIR/release.tar.gz"
done < "$WORK_DIR/parts"
ACTUAL="$(sha256sum "$WORK_DIR/release.tar.gz" | awk '{print $1}')"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "Контрольная сумма архива не совпала. Обновление отменено." >&2
  exit 1
fi

mkdir "$WORK_DIR/source"
tar --no-same-owner -xzf "$WORK_DIR/release.tar.gz" -C "$WORK_DIR/source"
if [ ! -x "$WORK_DIR/source/deploy/vps-install.sh" ]; then
  echo "В релизе отсутствует deploy/vps-install.sh." >&2
  exit 1
fi

bash "$WORK_DIR/source/deploy/vps-install.sh"
printf '%s\n' "$EXPECTED" > "$STATE_FILE"
echo "Где камера: успешно установлена версия $EXPECTED"
