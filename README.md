# AgriClaw (MVP)

AgriClaw is an OpenClaw-ready project that helps farmers quickly get:

1. Weather information for a location
2. Crop price snapshots
3. Safe model/provider switching (whitelist-based)

## Features

- **Weather** via `wttr.in` (no API key required)
- **Crop prices** via configurable HTTP source (JSON/CSV/plain text fallback)
- **Provider/model switch** with whitelist validation and backup
- **Health check** for environment readiness

## Quick Start

```bash
cd AgriClaw
bash install/install.sh
bash install/verify.sh
```

## Usage

### 1) Get weather + crop prices

```bash
bash scripts/recommend.sh --location "Leeds" --crop wheat
bash scripts/recommend.sh --location "Nairobi" --crop maize --prices-url "https://example.com/prices.json"
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

## Project Layout

- `SKILL.md` — Skill trigger + workflow for OpenClaw agents
- `scripts/recommend.sh` — Main data aggregation command
- `scripts/switch-model.sh` — Provider/model switch (whitelist)
- `scripts/health-check.sh` — Dependency and config checks
- `config/defaults.json` — Default location/crops/URLs/timeouts
- `config/providers.json` — Allowed providers/models
- `install/*` — Install + verify helpers
- `tests/*` — Sample request payloads

## Notes

- This MVP intentionally uses simple, auditable shell scripts.
- For production, migrate execution layer to an OpenClaw plugin tool for stronger observability and policy controls.
