# Zombie Factions

A Project Zomboid Build 42 framework for zombie-faction identity and directional `FRIENDLY`, `NEUTRAL`, and `HOSTILE` relationships.

- Status: **Research / Pre-Alpha**
- Current version: **v0.0.34**
- Target baseline: **Project Zomboid Build 42.20.x**

## Current state

SPIKE-001 established faction-aware zombie pursuit, synchronized damage, and normal lethal corpse handling in dedicated-server testing. SPIKE-003 closed successfully for the dedicated-server, one-client standing-zombie scope: v0.0.34 produced isolated-pair contact, audible bites, validated damage, defender reactions, and no repeat of the native-target crash. The same run confirmed the restored Horde Spawner controls and first-click behavior.

The current implementation remains diagnostic tooling. The administrator Horde Spawning extension creates selected test factions and an opt-in SPIKE harness; ordinary vanilla spawning remains unchanged when it is disabled. Production enrollment, persistence, and relationship behavior outside the harness remain planned work.

## Scope and current limits

- Zombies resolve to one zombie faction; `zf:vanilla` is the default.
- Relationships are directional and use `FRIENDLY`, `NEUTRAL`, or `HOSTILE`.
- Default installation preserves normal vanilla behavior.
- Standing faction bites, sounds, and defender reactions are validated diagnostic behavior for the current dedicated-server, one-client scope; two-client ownership, crawlers, and stale air-bite cancellation remain follow-up work.
- Only explicitly enrolled diagnostic zombies participate today.

## Documentation

[`docs/DOCUMENTATION_OWNERSHIP.md`](docs/DOCUMENTATION_OWNERSHIP.md) is the authoritative map. Start with:

- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative behavior.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — current implementation and multiplayer authority model.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — open work and productionization path.
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — observed test outcomes.
- [`docs/spikes/`](docs/spikes/) and [`docs/adr/`](docs/adr/) — experimental evidence and durable decisions.
- [`COMPLIANCE.md`](COMPLIANCE.md) and [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md) — policy, provenance, and release controls.

Original project source is licensed under Apache-2.0. Project Zomboid assets and code are not redistributed or relicensed by this repository. Zombie Factions is an unofficial independent community mod.
