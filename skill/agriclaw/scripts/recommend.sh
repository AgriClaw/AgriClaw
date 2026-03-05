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
  default_crop="$(jq -r '.default_crop // ""' "$DEFAULTS")"
  max_lines="$(jq -r '.max_price_lines // 5' "$DEFAULTS")"
else
  default_location=""
  default_crop=""
  max_lines=5
fi

location="${location:-$default_location}"
crop="${crop:-$default_crop}"

if [[ -z "$location" ]]; then
  echo "ERROR: --location is required."
  echo "Example: bash scripts/recommend.sh --location \"Chengdu\" --crop maize"
  exit 1
fi

if [[ -z "$crop" ]]; then
  echo "ERROR: --crop is required."
  echo "Example: bash scripts/recommend.sh --location \"Chengdu\" --crop maize"
  exit 1
fi

weather_url="https://wttr.in/${location}?format=3"
weather="$(curl -fsSL --max-time 12 "$weather_url" || true)"
if [[ -z "$weather" ]]; then
  weather="Weather unavailable (wttr.in request failed)."
fi

price_lines=()

# Optional custom source first
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

# Built-in global benchmark adapter (Stooq futures, no key)
if [[ ${#price_lines[@]} -eq 0 ]]; then
  crop_key="$(echo "$crop" | tr '[:upper:]' '[:lower:]')"
  symbol=""
  case "$crop_key" in
    wheat) symbol="zw.f" ;;
    maize|corn) symbol="zc.f" ;;
    soybean|soybeans|soya) symbol="zs.f" ;;
    oats) symbol="zo.f" ;;
    rice) symbol="zr.f" ;;
  esac

  if [[ -n "$symbol" ]]; then
    stooq_url="https://stooq.com/q/l/?s=${symbol}&f=sd2t2ohlcv&h&e=csv"
    stooq_csv="$(curl -fsSL --max-time 12 "$stooq_url" || true)"
    if [[ -n "$stooq_csv" ]]; then
      line="$(echo "$stooq_csv" | tail -n +2 | head -n 1)"
      if [[ -n "$line" ]]; then
        # Symbol,Date,Time,Open,High,Low,Close,Volume
        IFS=',' read -r sym dt tm op hi lo cl vol <<< "$line"
        if [[ -n "${cl:-}" && "$cl" != "N/D" ]]; then
          price_lines=("- ${crop} benchmark (futures): ${cl} USD @ Stooq (${sym}, ${dt})")
        fi
      fi
    fi
  fi
fi

if [[ ${#price_lines[@]} -eq 0 ]]; then
  price_lines=("- No live price source supplied/matched. For local market pricing, pass --prices-url with your market API/feed.")
fi

# trim to max lines
price_lines=("${price_lines[@]:0:${max_lines:-5}}")

echo "🌾 AgriClaw Snapshot"
echo "📍 Location: $location"
echo "🌱 Crop: $crop"
echo ""
echo "🌦 Weather"
echo "$weather"
echo ""
echo "💹 Prices"
printf '%s
' "${price_lines[@]}"
echo ""
echo "✅ Recommended Actions"
echo "- If rain is likely, prioritize drainage and disease checks."
echo "- If conditions turn hot or dry, review irrigation timing and mulch cover."
echo "- Compare today's benchmark with your local buyer before marketing grain."
