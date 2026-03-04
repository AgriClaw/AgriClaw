#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT_DIR/runtime/model-config.json"

latest_backup="$(ls -1t "$TARGET".bak.* 2>/dev/null | head -n 1 || true)"

if [[ -z "$latest_backup" ]]; then
  echo "No backup found for rollback."
  exit 1
fi

cp "$latest_backup" "$TARGET"
echo "Rolled back model config from: $latest_backup"
