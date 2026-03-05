# AgriClaw (MVP)

AgriClaw is an OpenClaw-ready project that helps farmers quickly get:

1. Weather information for a location
2. Crop price snapshots
3. **AI-powered recommendations** via Flock.io (3–5 prioritised today actions)
4. Safe model/provider switching (whitelist-based)

## Features

- **Weather** via `wttr.in` (no API key required)
- **Crop prices** via:
  - configurable HTTP source (JSON/CSV/plain text fallback), or
  - built-in global benchmark adapter (Stooq futures, no API key)
- **AI Recommendation** via [Flock.io API](https://docs.flock.io/flock-products/api-platform/api-endpoint) — sends weather, price and pest context and returns 3–5 prioritised field actions
- **Provider/model switch** with whitelist validation and backup
- **Health check** for environment readiness

## Quick Start

```bash
cd AgriClaw
export FLOCK_API_KEY="your_flock_api_key"          # required for AI recommendation
export FLOCK_MODEL="gemini-3-pro-preview"          # optional, this is the default
export FLOCK_API_ENDPOINT="https://api.flock.io/v1" # optional, this is the default
bash install/install.sh
bash install/verify.sh

# Install skill into OpenClaw workspace (agent-executable)
bash install/install-skill.sh
bash install/verify-skill-install.sh
```

## Usage

### 1) Get weather + crop prices

```bash
bash scripts/recommend.sh --location "Leeds" --crop wheat
bash scripts/recommend.sh --location "Nairobi" --crop maize --prices-url "https://example.com/prices.json"
# without --prices-url, script tries built-in benchmark feed for major crops (wheat/maize/soybean/oats/rice)
# location and crop must be explicitly provided (or set in config/defaults.json)
```

### 2) Switch model/provider safely

```bash
bash scripts/switch-model.sh --provider openai --model gpt-5.3-codex
```

Default config target file is `./runtime/model-config.json`. You can override:

```bash
bash scripts/switch-model.sh --provider openai --model gpt-5.3-codex --target /path/to/config.json
```

### 3) Run health checks

```bash
bash scripts/health-check.sh
```

FLock API endpoint reference:
- https://docs.flock.io/flock-products/api-platform/api-endpoint

## Project Layout

- `SKILL.md` — Skill trigger + workflow for OpenClaw agents
- `scripts/recommend.sh` — Main data aggregation command
- `scripts/switch-model.sh` — Provider/model switch (whitelist)
- `scripts/health-check.sh` — Dependency and config checks
- `config/defaults.json` — Default location/crops/URLs/timeouts
- `config/providers.json` — Allowed providers/models
- `install/*` — Runtime install, skill install, and verify helpers
- `tests/*` — Sample request payloads

## Distributable Skill Package

Packaged skill artifact:

- `dist/agriclaw.skill`

You can rebuild it with:

```bash
python3 -m venv .venv
.venv/bin/pip install pyyaml
.venv/bin/python ../openclaw/skills/skill-creator/scripts/package_skill.py ./skill/agriclaw ./dist
```

## Notes

- This MVP intentionally uses simple, auditable shell scripts.
- For production, migrate execution layer to an OpenClaw plugin tool for stronger observability and policy controls.
