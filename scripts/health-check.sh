#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ok=1

check_bin() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "[OK] $1"
  else
    echo "[MISSING] $1"
    ok=0
  fi
}

echo "AgriClaw health check"
check_bin bash
check_bin curl
check_bin jq

echo "\nChecking config files..."
for f in "$ROOT_DIR/config/defaults.json" "$ROOT_DIR/config/providers.json" "$ROOT_DIR/SKILL.md"; do
  if [[ -f "$f" ]]; then
    echo "[OK] $(basename "$f")"
  else
    echo "[MISSING] $f"
    ok=0
  fi
done

if [[ "$ok" -eq 1 ]]; then
  echo "\nHealth check PASSED"
  exit 0
else
  echo "\nHealth check FAILED"
  exit 1
fi
