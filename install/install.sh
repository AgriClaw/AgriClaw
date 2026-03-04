#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Installing AgriClaw MVP..."
chmod +x "$ROOT_DIR"/scripts/*.sh
mkdir -p "$ROOT_DIR/runtime"

echo "Done. Run: bash install/verify.sh"
