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

Environment:
  FLOCK_API_KEY      Your Flock.io API key (required for AI recommendation)
  FLOCK_API_ENDPOINT Flock.io base URL (default: https://api.flock.io/v1)
  FLOCK_MODEL        Model to use (default: gemini-3-pro-preview)
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
rainp=""   # precipitation probability percentage (0-100)
tmin=""
tmax=""

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
      tmax="$(echo "$forecast_json" | jq -r '.daily.temperature_2m_max[0] // ""')"
      tmin="$(echo "$forecast_json" | jq -r '.daily.temperature_2m_min[0] // ""')"
      rainp="$(echo "$forecast_json" | jq -r '.daily.precipitation_probability_max[0] // ""')"

      tmax_show="${tmax:-n/a}"
      tmin_show="${tmin:-n/a}"
      rainp_show="${rainp:-n/a}"
      weather="${place}: ${tmin_show}–${tmax_show}°C, rain chance ${rainp_show}% (Open-Meteo)."
    fi
  fi
fi

if [[ -z "$weather" ]]; then
  weather="Weather unavailable (wttr.in and Open-Meteo failed)."
fi

price_lines=()
price_value=""

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
          price_value="$cl"
        fi
      fi
    fi
  fi
fi

if [[ -z "$price_value" && ${#price_lines[@]} -gt 0 ]]; then
  price_value="$(echo "${price_lines[0]}" | grep -Eo '[0-9]+(\.[0-9]+)?' | head -n 1 || true)"
fi

if [[ ${#price_lines[@]} -eq 0 ]]; then
  price_lines=("- No live price source supplied/matched. For local market pricing, pass --prices-url with your market API/feed.")
fi

# trim to max lines
price_lines=("${price_lines[@]:0:${max_lines:-5}}")

# -------- Dynamic Pest Diagnosis & Policy --------
weather_lc="$(echo "$weather" | tr '[:upper:]' '[:lower:]')"
risk_level="Low"
pest_diag="Low immediate pest pressure signal from current weather."
field_policy="Continue routine scouting and maintain normal spray interval."

if [[ "$weather_lc" == *"rain"* || "$weather_lc" == *"drizzle"* || "$weather_lc" == *"storm"* ]]; then
  risk_level="High"
  pest_diag="High moisture-driven disease risk (fungal pressure likely)."
  field_policy="Delay spraying until leaf surface dries; prioritize fungal scouting and preventive fungicide window."
elif [[ "$weather_lc" == *"fog"* || "$weather_lc" == *"mist"* || "$weather_lc" == *"haze"* || "$weather_lc" == *"🌫"* ]]; then
  risk_level="Medium"
  pest_diag="Moderate foliar disease risk from damp canopy and reduced drying."
  field_policy="Scout lower canopy first; avoid early-morning sprays; spray only on confirmed hotspots."
fi

if [[ -n "$rainp" && "$rainp" != "n/a" ]]; then
  rain_int="${rainp%.*}"
  if [[ "$rain_int" =~ ^[0-9]+$ && "$rain_int" -ge 60 ]]; then
    risk_level="High"
    pest_diag="High rain probability suggests elevated disease pressure."
    field_policy="Prioritize drainage checks and protective disease management before rainfall events."
  fi
fi

# Heat stress / pest acceleration add-on
if [[ -n "$tmax" ]]; then
  tmax_int="${tmax%.*}"
  if [[ "$tmax_int" =~ ^[0-9]+$ && "$tmax_int" -ge 30 ]]; then
    pest_diag="$pest_diag Heat may accelerate sucking pests (aphids/mites)."
    field_policy="$field_policy Increase edge-row scouting frequency in the afternoon."
  fi
fi

trade_policy="Collect at least 2 local buyer quotes before selling."
if [[ -n "$price_value" ]]; then
  if awk "BEGIN {exit !($price_value >= 560)}"; then
    trade_policy="Price is relatively strong vs benchmark bands: consider phased selling (30-50%) and keep the rest for optional upside."
  elif awk "BEGIN {exit !($price_value >= 500 && $price_value < 560)}"; then
    trade_policy="Price is mid-range: split sales into 2-3 batches to reduce timing risk."
  else
    trade_policy="Price is relatively soft: if storage and cash flow allow, avoid full-volume sale today; monitor 24-72h."
  fi
fi

# -------- Print Snapshot --------
echo "=== AgriClaw Snapshot ==="
echo "Location: $location"
echo "Crop: $crop"
echo ""
echo "Weather:"
echo "$weather"
echo ""
echo "Prices:"
printf '%s\n' "${price_lines[@]}"
echo ""
echo "Pest Diagnosis & Policy:"
echo "- Risk: $risk_level"
echo "- Diagnosis: $pest_diag"
echo "- Field policy: $field_policy"
echo "- Trade policy: $trade_policy"
echo ""
echo "Action:"
echo "- Prioritize today's field task by risk level before routine work."
echo "- Re-check weather and one local price quote before end of day."
echo "- Keep notes (disease spots, buyer quotes) for tomorrow's decision."

# -------- Flock.io AI Recommendation --------
FLOCK_API_KEY="${FLOCK_API_KEY:-}"
FLOCK_API_ENDPOINT="${FLOCK_API_ENDPOINT:-https://api.flock.io/v1}"
FLOCK_MODEL="${FLOCK_MODEL:-gemini-3-pro-preview}"

if [[ -z "$FLOCK_API_KEY" ]]; then
  echo ""
  echo "=== AI Recommendation ==="
  echo "(Skipped: FLOCK_API_KEY is not set. Export it to enable AI advice.)"
  exit 0
fi

# Build a concise context string for the LLM
price_summary="$(printf '%s\n' "${price_lines[@]}")"

ai_context="You are AgriClaw, a practical agricultural advisor.
A farmer in ${location} is growing ${crop}.

Current conditions:
- Weather: ${weather}
- Market prices:
${price_summary}
- Pest risk level: ${risk_level}
- Pest/disease diagnosis: ${pest_diag}
- Field policy: ${field_policy}
- Trade policy: ${trade_policy}

Give the farmer 3–5 concrete, prioritised action recommendations for today.
Be concise, practical, and field-ready. Use bullet points.
End with one sentence on what to watch for tomorrow."

# Escape for JSON
user_content="$(printf '%s' "$ai_context" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"

request_body="{
  \"model\": \"${FLOCK_MODEL}\",
  \"stream\": false,
  \"messages\": [
    {\"role\": \"system\", \"content\": \"You are AgriClaw, a concise and practical AI agricultural advisor. Respond in plain text with bullet points only — no markdown headers.\"},
    {\"role\": \"user\", \"content\": ${user_content}}
  ]
}"

echo ""
echo "=== AI Recommendation (Flock.io / ${FLOCK_MODEL}) ==="

ai_response="$(curl -fsSL --max-time 30 \
  -X POST "${FLOCK_API_ENDPOINT}/chat/completions" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -H "x-litellm-api-key: ${FLOCK_API_KEY}" \
  -d "$request_body" 2>/dev/null || true)"

if [[ -z "$ai_response" ]]; then
  echo "(Flock.io API call failed or timed out. Check FLOCK_API_KEY and network.)"
  exit 0
fi

# Extract the assistant message content
ai_text="$(echo "$ai_response" | jq -r '
  if .choices then
    (.choices[0].message.content // .choices[0].delta.content // "")
  elif .error then
    "API error: " + (.error.message // .error | tostring)
  else
    "Unexpected response format."
  end
' 2>/dev/null || echo "(Failed to parse Flock.io response.)")"

echo "$ai_text"
