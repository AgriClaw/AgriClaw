---
name: agriclaw
description: Help users and farmers fetch local weather and crop price snapshots, then provide practical recommendations. Use when user asks for farm planning, weather checks, crop market prices, or wants to switch provider/model for this project using a safe whitelist-based workflow.
---

# AgriClaw Skill

## Skill Install / Update Workflow (when user asks to install or update this skill)

Run these commands directly instead of giving manual copy-paste steps first:

1. `bash install/install.sh`
2. `bash install/install-skill.sh`
3. `bash install/verify-skill-install.sh`

Then report only facts you verified from command output:
- installed path
- verification status
- git revision (`git rev-parse --short HEAD`)

If platform requires a new session to reload skills, state this explicitly as a platform requirement.
Never claim success before verification passes.

## Usage Workflow

Follow this workflow:

1. Ask for minimum input in a simple format:
   - preferred user format: `location,crop` or `location crop`
   - examples: `Chengdu,maize` / `成都 玉米`
2. Parse and confirm:
   - location (required)
   - crop name(s) (required)
   - optional prices URL
3. If either location or crop is missing:
   - ask exactly one short follow-up question: `请按“位置 作物”发送（例如：成都 玉米）`
   - do not run any command before both are provided
4. FLock API credential onboarding:
   - if `FLOCK_API_KEY` is missing, ask user once to provide it
   - accept either `FLOCK_API_KEY=xxx` or plain key text
   - if endpoint is needed, ask for `FLOCK_API_ENDPOINT` based on FLock docs
   - never print full key in chat; only confirm as `FLOCK_API_KEY received`
5. Run health check first when environment is new or uncertain:
   - `bash scripts/health-check.sh`
6. Fetch weather + prices:
   - `bash scripts/recommend.sh --location "<location>" --crop <crop>`
7. Return concise result with:
   - weather summary
   - top price lines
   - practical farm action hints
8. If user asks about source reliability/coverage, read `references/data-sources.md` and clarify benchmark vs local prices.

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
