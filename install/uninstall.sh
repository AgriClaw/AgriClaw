#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Uninstall only removes runtime artifacts (not project source)."
rm -rf "$ROOT_DIR/runtime"
echo "Done."
