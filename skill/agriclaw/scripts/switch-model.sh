#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVIDERS_FILE="$ROOT_DIR/config/providers.json"
TARGET_FILE="$ROOT_DIR/runtime/model-config.json"

provider=""
model=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) provider="${2:-}"; shift 2 ;;
    --model) model="${2:-}"; shift 2 ;;
    --target) TARGET_FILE="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: switch-model.sh --provider <provider> --model <model> [--target <path>]
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$provider" || -z "$model" ]]; then
  echo "ERROR: --provider and --model are required"
  exit 1
fi

if [[ ! -f "$PROVIDERS_FILE" ]]; then
  echo "ERROR: missing providers whitelist: $PROVIDERS_FILE"
  exit 1
fi

allowed="$(jq -r --arg p "$provider" --arg m "$model" '
  (.providers[$p] // []) | index($m) // empty
' "$PROVIDERS_FILE")"

if [[ -z "$allowed" ]]; then
  echo "ERROR: model '$model' is not allowed under provider '$provider'."
  echo "Allowed providers/models:"
  jq '.providers' "$PROVIDERS_FILE"
  exit 1
fi

mkdir -p "$(dirname "$TARGET_FILE")"

backup="${TARGET_FILE}.bak.$(date +%s)"
if [[ -f "$TARGET_FILE" ]]; then
  cp "$TARGET_FILE" "$backup"
fi

cat > "$TARGET_FILE" <<EOF
{
  "provider": "$provider",
  "model": "$model",
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "Switched model config successfully."
echo "Target: $TARGET_FILE"
if [[ -n "${backup:-}" && -f "$backup" ]]; then
  echo "Backup: $backup"
fi
echo "Restart gateway if your runtime does not auto-reload model config."
