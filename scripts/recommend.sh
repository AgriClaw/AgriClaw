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

# -------- Weather with fallback chain --------
weather=""

# Primary: wttr.in (very simple human-readable)
weather_url="https://wttr.in/${location}?format=3"
weather="$(curl -fsSL --max-time 12 "$weather_url" || true)"

# Fallback: Open-Meteo geocoding + daily forecast (no API key)
if [[ -z "$weather" ]]; then
  encoded_location="$(LOC="$location" python3 -c 'import os,urllib.parse; print(urllib.parse.quote(os.environ["LOC"]))')"
  geocode_json="$(curl -fsSL --max-time 12 "https://geocoding-api.open-meteo.com/v1/search?name=${encoded_location}&count=1&language=en&format=json" || true)"

  if [[ -n "$geocode_json" ]] && echo "$geocode_json" | jq -e '.results[0]' >/dev/null 2>&1; then
    lat="$(echo "$geocode_json" | jq -r '.results[0].latitude')"
    lon="$(echo "$geocode_json" | jq -r '.results[0].longitude')"
    place="$(echo "$geocode_json" | jq -r '.results[0].name')"

    forecast_json="$(curl -fsSL --max-time 12 "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode&timezone=auto" || true)"

    if [[ -n "$forecast_json" ]] && echo "$forecast_json" | jq -e '.daily' >/dev/null 2>&1; then
      tmax="$(echo "$forecast_json" | jq -r '.daily.temperature_2m_max[0] // "n/a"')"
      tmin="$(echo "$forecast_json" | jq -r '.daily.temperature_2m_min[0] // "n/a"')"
      rainp="$(echo "$forecast_json" | jq -r '.daily.precipitation_probability_max[0] // "n/a"')"
      weather="${place}: ${tmin}–${tmax}°C, rain chance ${rainp}% (Open-Meteo)."
    fi
  fi
fi

if [[ -z "$weather" ]]; then
  weather="Weather unavailable (wttr.in and Open-Meteo failed)."
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
echo "Action:"
echo "- If rain risk is high, prioritize drainage and disease checks."
echo "- If hot/dry, review irrigation schedule and mulch cover."
echo "- Compare benchmark price with local buyer quote before sale."
