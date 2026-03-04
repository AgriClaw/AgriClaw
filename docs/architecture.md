# AgriClaw Architecture (MVP)

- Skill layer: `SKILL.md`
- Execution layer: shell scripts in `scripts/`
- Config layer: `config/defaults.json` + `config/providers.json`
- Runtime state: `runtime/model-config.json`

Design goals:
- Simple and auditable
- Whitelist-based model switching
- Easy migration to plugin tool in phase 2
