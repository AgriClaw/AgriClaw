# Data Sources

## Weather
- `wttr.in` text endpoint, format=3
- No API key required

## Crop Prices
1. Preferred: user-supplied `--prices-url` feed (JSON/CSV/plain text)
2. Fallback: Stooq futures benchmark for selected crops:
   - wheat -> `zw.f`
   - maize/corn -> `zc.f`
   - soybean -> `zs.f`
   - oats -> `zo.f`
   - rice -> `zr.f`

Note: benchmark futures are not local farm-gate prices; treat as directional market signal.
