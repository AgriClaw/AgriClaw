#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS="$ROOT_DIR/config/defaults.json"

location=""
crop=""
prices_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --location) location="${2:-}"; shift 2 ;;
    --crop) crop="${2:-}"; shift 2 ;;
    --prices-url) prices_url="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: recommend.sh --location <city> [--crop <name>] [--prices-url <url>]
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -f "$DEFAULTS" ]]; then
  default_location="$(jq -r '.default_location // ""' "$DEFAULTS")"
  default_crop="$(jq -r '.default_crop // "wheat"' "$DEFAULTS")"
  max_lines="$(jq -r '.max_price_lines // 5' "$DEFAULTS")"
else
  default_location=""
  default_crop="wheat"
  max_lines=5
fi

location="${location:-$default_location}"
crop="${crop:-$default_crop}"

if [[ -z "$location" ]]; then
  echo "ERROR: --location required (or set default_location in config/defaults.json)"
  exit 1
fi

weather_url="https://wttr.in/${location}?format=3"
weather="$(curl -fsSL --max-time 12 "$weather_url" || true)"
if [[ -z "$weather" ]]; then
  weather="Weather unavailable (wttr.in request failed)."
fi

price_lines=()

if [[ -n "$prices_url" ]]; then
  body="$(curl -fsSL --max-time 12 "$prices_url" || true)"
  if [[ -n "$body" ]]; then
    if echo "$body" | jq -e . >/dev/null 2>&1; then
      # Try common JSON shape: [{crop,price,market,currency,date}, ...]
      mapfile -t price_lines < <(echo "$body" | jq -r --arg c "$crop" '
        (if type=="array" then . else .data // [] end)
        | map(select((.crop // .name // "") | ascii_downcase | contains($c|ascii_downcase)))
        | .[:10]
        | .[]
        | "- " + ((.crop // .name // "crop")|tostring)
          + ": " + ((.price // .value // "n/a")|tostring)
          + " " + ((.currency // "")|tostring)
          + (if (.market // "") != "" then " @ " + (.market|tostring) else "" end)
      ' 2>/dev/null)
    else
      # CSV/plain text fallback: grep crop keyword
      mapfile -t price_lines < <(echo "$body" | grep -i "$crop" | head -n 10 | sed 's/^/- /')
    fi
  fi
fi

if [[ ${#price_lines[@]} -eq 0 ]]; then
  price_lines=("- No live price source supplied or matching records found for '$crop'.")
fi

# trim to max lines
price_lines=("${price_lines[@]:0:${max_lines:-5}}")

echo "=== AgriClaw Snapshot ==="
echo "Location: $location"
echo "Crop: $crop"
echo ""
echo "Weather:"
echo "$weather"
echo ""
echo "Prices:"
printf '%s
' "${price_lines[@]}"
echo ""
echo "Practical Hints:"
echo "- If rain is likely, prioritize drainage and disease checks."
echo "- If hot/dry, review irrigation schedule and mulch cover."
echo "- Compare today price with your local buyer before harvest sale."
