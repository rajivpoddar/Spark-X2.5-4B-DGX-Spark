#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "run with sudo" >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
INSTALL_DIR=/home/user/serve/spark-x25-dgx/dgx-spark

if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
  echo "expected recipe at $INSTALL_DIR, found $SCRIPT_DIR" >&2
  exit 1
fi

if [[ ! -f "$INSTALL_DIR/spark25.env" ]]; then
  echo "missing $INSTALL_DIR/spark25.env" >&2
  exit 1
fi

install -m 0644 "$INSTALL_DIR/systemd/spark-x25-sglang.service" \
  /etc/systemd/system/spark-x25-sglang.service
systemctl daemon-reload
systemctl enable spark-x25-sglang.service

echo "installed spark-x25-sglang.service; start it explicitly after validation"
