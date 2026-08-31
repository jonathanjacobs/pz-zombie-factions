# Zombie Factions

A Project Zomboid Build 42 framework for zombie-faction identity and directional `FRIENDLY`, `NEUTRAL`, and `HOSTILE` relationships.

- Status: **Research / Pre-Alpha**
- Current version: **v0.0.32**
- Target baseline: **Project Zomboid Build 42.20.x**

## Current state

SPIKE-001 established faction-aware zombie pursuit, synchronized damage, and normal lethal corpse handling in dedicated-server testing. SPIKE-003 remains active: v0.0.31 demonstrated readable standing bites but later crashed when native `AttackState` received an `IsoZombie` target. Version 0.0.32 removes that native target coupling and adds a cosmetic defender reaction for controlled retesting.

The current implementation remains diagnostic tooling. The administrator Horde Spawning extension creates selected test factions and an opt-in SPIKE harness; ordinary vanilla spawning remains unchanged when it is disabled. Production enrollment, persistence, and relationship behavior outside the harness remain planned work.

## Scope and current limits

- Zombies resolve to one zombie faction; `zf:vanilla` is the default.
- Relationships are directional and use `FRIENDLY`, `NEUTRAL`, or `HOSTILE`.
- Default installation preserves normal vanilla behavior.
- Standing faction bites and defender reactions are active test candidates; crawlers, sounds, and stale air-bite cancellation are not yet accepted behavior.
- Only explicitly enrolled diagnostic zombies participate today.

## Documentation

[`docs/DOCUMENTATION_OWNERSHIP.md`](docs/DOCUMENTATION_OWNERSHIP.md) is the authoritative map. Start with:

- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative behavior.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — current implementation and multiplayer authority model.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — open work and productionization path.
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — observed test outcomes.
- [`docs/spikes/`](docs/spikes/) and [`docs/adr/`](docs/adr/) — experimental evidence and durable decisions.

Original project source is licensed under Apache-2.0. Project Zomboid assets and code are not redistributed or relicensed by this repository. Zombie Factions is an unofficial independent community mod.
