---
name: agriclaw
description: Help users and farmers fetch local weather and crop price snapshots, then provide practical recommendations. Use when user asks for farm planning, weather checks, crop market prices, or asks to get/install/update this AgriClaw skill, or wants to switch provider/model using a safe whitelist-based workflow. Before ANY workflow (including get/install/update), first ask for location + crop and missing FLOCK_API_KEY.
---

# AgriClaw Skill

## Unified Input Gate (MANDATORY, run before any workflow)

Non-negotiable rule:
- Before running install/get/update, usage, or model-switch commands, ask for and confirm required user input.
- Do not execute any command until required inputs are collected.
- If user asks to skip, still request inputs first.
- All user-facing prompts and replies must be in English.

Always collect and confirm the minimum user input before running any workflow:

1. Ask for location + crop in a simple format:
   - preferred format: `location,crop` or `location crop`
   - examples: `London,wheat` / `London wheat`
2. Parse and confirm:
   - location (required)
   - crop name(s) (required)
   - optional prices URL
3. If either location or crop is missing:
   - ask exactly one short follow-up question: `Please send: location crop (example: London wheat)`
   - do not run any command before both are provided
4. FLock API credential onboarding:
   - if `FLOCK_API_KEY` is missing, ask user once to provide it
   - accept either `FLOCK_API_KEY=xxx` or plain key text
   - if endpoint is needed, ask for `FLOCK_API_ENDPOINT` based on FLock docs
   - never print full key in chat; only confirm as `FLOCK_API_KEY received`
5. Required interaction order:
   - first ask: `Please send: location crop (example: London wheat)`
   - after location+crop are received, ask for key only if missing
   - only then execute workflow commands

## Skill Install / Update Workflow (after Unified Input Gate)

When user asks to install or update this skill, run these commands directly instead of giving manual copy-paste steps first:

1. `bash install/install.sh`
2. `bash install/install-skill.sh`
3. `bash install/verify-skill-install.sh`

Then report only facts you verified from command output:
- installed path
- verification status
- git revision (`git rev-parse --short HEAD`)

After successful install/update, immediately provide a result preview to the user:
1. Run health check if environment is new/uncertain: `bash scripts/health-check.sh`
2. Run recommendation with collected inputs: `bash scripts/recommend.sh --location "<location>" --crop <crop>`
3. Return a concise answer that includes:
   - weather summary
   - top crop price lines
   - practical farm action hints

If platform requires a new session to reload skills, state this explicitly as a platform requirement.
Never claim success before verification passes.

## Usage Workflow (after Unified Input Gate)

1. Run health check first when environment is new or uncertain:
   - `bash scripts/health-check.sh`
2. Fetch weather + prices:
   - `bash scripts/recommend.sh --location "<location>" --crop <crop>`
3. Return concise result with:
   - weather summary
   - top price lines
   - practical farm action hints
4. If user asks about source reliability/coverage, read `references/data-sources.md` and clarify benchmark vs local prices.

## Model Switch Workflow (after Unified Input Gate)

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
