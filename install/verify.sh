#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT_DIR/scripts/health-check.sh"

echo "\nSmoke test: recommend (weather only)"
bash "$ROOT_DIR/scripts/recommend.sh" --location "Leeds" --crop "wheat" >/dev/null

echo "Verify PASSED"
