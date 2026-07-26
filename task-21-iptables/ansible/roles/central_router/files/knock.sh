#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-192.168.255.1}"

for PORT in 7000 8000 9000; do
  timeout 1 bash -c ":</dev/tcp/${TARGET}/${PORT}" 2>/dev/null || true
  sleep 1
done
