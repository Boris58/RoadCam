#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите установщик от имени root." >&2
  exit 1
fi

BASE_URL="https://raw.githubusercontent.com/Boris58/RoadCam/main/deploy"
WORK_DIR="$(mktemp -d /tmp/gdekamera-bootstrap.XXXXXX)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

curl -fsSL "$BASE_URL/update-from-github.sh" -o "$WORK_DIR/update-from-github.sh"
curl -fsSL "$BASE_URL/install-auto-update.sh" -o "$WORK_DIR/install-auto-update.sh"
chmod 0755 "$WORK_DIR/update-from-github.sh" "$WORK_DIR/install-auto-update.sh"
bash "$WORK_DIR/install-auto-update.sh"
