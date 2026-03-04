#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${OPENCLAW_WORKSPACE:-}" ]]; then
  WORKSPACE_DIR="$OPENCLAW_WORKSPACE"
else
  WORKSPACE_DIR="$(cd "$ROOT_DIR/.." && pwd)"
fi

TARGET_DIR="$WORKSPACE_DIR/skills/agriclaw"

if [[ ! -f "$TARGET_DIR/SKILL.md" ]]; then
  echo "VERIFY FAILED: missing $TARGET_DIR/SKILL.md" >&2
  exit 1
fi

if ! grep -q "^name: agriclaw$" "$TARGET_DIR/SKILL.md"; then
  echo "VERIFY FAILED: SKILL.md does not look like AgriClaw skill" >&2
  exit 1
fi

echo "VERIFY PASSED"
echo "skill_path=$TARGET_DIR"
echo "skill_name=$(grep -m1 '^name:' "$TARGET_DIR/SKILL.md" | awk '{print $2}')"
