# Codex project handoff

## Privacy boundary

- Do not copy private assistant conversation content, titles, summaries, prompts, attachments, project metadata, inferred personal context, logs, or private game/server data into this repository unless explicitly authorized.
- Translate approved work into impersonal, repository-native technical language.
- Apply this rule to source, documentation, comments, commits, issues, pull requests, fixtures, and generated artifacts.

## Start every task here

1. Run `git status --short --branch` and preserve unrelated changes.
2. Read [`docs/DOCUMENTATION_OWNERSHIP.md`](docs/DOCUMENTATION_OWNERSHIP.md) before changing documentation.
3. Use the canonical document for the subject: requirements, architecture/ADRs, roadmap, testing, validation history, spikes, or policy/provenance. See [`docs/RESEARCH_LINKS.md`](docs/RESEARCH_LINKS.md) for external wiki/API/community references.
4. Treat reproducible tests and Project Zomboid logs as stronger evidence than remembered API behavior.

## Project facts

- Mod name: Zombie Factions
- Mod ID: `pz-zombie-factions`
- Steam Workshop ID: Not yet assigned
- Supported baseline: Project Zomboid Build 42.20.x
- Multiplayer target: dedicated server and client
- Development state: research / pre-alpha

## Engineering boundaries

- Keep the deployable package under `Contents/mods/pz-zombie-factions/`.
- Preserve server authority for shared faction policy, target grants, damage validation, and lethal outcomes.
- Do not copy or redistribute Project Zomboid assets, decompiled code, or third-party mod material without documented rights.
- Follow [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md) for engineering and release controls.
- Keep diagnostics bounded and evidence-focused; do not claim release readiness, compatibility, or performance beyond recorded validation.

## Verification expectations

- Keep `VERSION` and both `mod.info` versions aligned.
- Update the repeatable procedure in `docs/TESTING.md` with runtime-test changes.
- Record observed outcomes only after a real run in `docs/VALIDATION_HISTORY.md`; retain bounded experimental detail in `docs/spikes/`.
- Check staged changes for private logs/data, saves, extracted assets, and unrelated files before committing.
