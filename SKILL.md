---
name: agriclaw
description: Help users and farmers fetch local weather and crop price snapshots, then provide practical recommendations. Use when user asks for farm planning, weather checks, crop market prices, or wants to switch provider/model for this project using a safe whitelist-based workflow.
---

# AgriClaw Skill

Follow this workflow:

1. Collect input requirements:
   - location (required)
   - crop name(s) (optional, defaults allowed)
   - optional prices URL
2. Run health check first when environment is new or uncertain:
   - `bash scripts/health-check.sh`
3. Fetch weather + prices:
   - `bash scripts/recommend.sh --location "<location>" --crop <crop>`
4. Return concise result with:
   - weather summary
   - top price lines
   - practical farm action hints

## Model Switch Workflow

When user asks to switch provider/model:

1. Confirm target provider + model.
2. Run:
   - `bash scripts/switch-model.sh --provider <provider> --model <model>`
3. Report:
   - switched status
   - target config file
   - whether restart is needed

## Guardrails

- Never bypass whitelist in `config/providers.json`.
- Always show validation error clearly if provider/model is not allowed.
- Keep output practical and short for field use.
