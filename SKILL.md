---
name: agriclaw
description: Help users and farmers fetch local weather and crop price snapshots and practical recommendations. Use when users ask for farm planning, weather checks, crop market prices, or ask to get/install/update this AgriClaw skill, or switch provider/model. Before any workflow, ask for location + crop and missing FLOCK_API_KEY.
---

# AgriClaw Skill

## Mandatory Input Gate (before ANY workflow)

Rules:
- Always ask for required inputs before running commands.
- Required: `location`, `crop`.
- Required when missing: `FLOCK_API_KEY`.
- Keep all prompts and replies in English.

Input collection order:
1. Ask: `Please send: location crop (example: London wheat)`
2. Confirm parsed fields: location + crop
3. If key is missing, ask for it once:
   - accept `FLOCK_API_KEY=xxx` or plain key text
   - never print full key; only confirm: `FLOCK_API_KEY received`
4. Only then execute workflow commands.

## Install / Update Workflow (after Mandatory Input Gate)

When user asks to get/install/update the skill, run:
1. `bash install/install.sh`
2. `bash install/install-skill.sh`
3. `bash install/verify-skill-install.sh`

Then return a SIMPLE success block:
- `Install: OK` (or `Install: FAILED`)
- `Path: <installed path>`
- `Revision: <git short sha>`

If install succeeds, immediately return a user-facing snapshot by running:
1. `bash scripts/health-check.sh` (when env is new/uncertain)
2. `bash scripts/recommend.sh --location "<location>" --crop <crop>`

Snapshot must include:
- weather summary
- top crop price lines
- practical action hints

If platform requires a new session to reload skills, state it.
Never claim success before verification passes.

## Usage Workflow (after Mandatory Input Gate)

1. `bash scripts/health-check.sh` (when env is new/uncertain)
2. `bash scripts/recommend.sh --location "<location>" --crop <crop>`
3. Return concise output in this format:
   - `Weather:` <1–2 lines>
   - `Prices:` 1–3 bullet lines
   - `Action:` 2–3 bullet hints

## Model Switch Workflow (after Mandatory Input Gate)

1. Confirm target provider + model.
2. Run: `bash scripts/switch-model.sh --provider <provider> --model <model>`
3. Report: switched status, target config file, restart needed or not.

## Guardrails

- Never bypass whitelist in `config/providers.json`.
- Show validation errors clearly if provider/model is not allowed.
- Keep field-use output short and practical.
