# Zombie Factions

**A Project Zomboid Build 42 framework for assigning zombies to factions and defining directional Friendly, Neutral, and Hostile relationships between zombie factions and player factions.**

- Status: **Research / Pre-Alpha**
- Current version: **v0.0.24**
- Target baseline: **Project Zomboid Build 42.20.x**

## Project scope

The first milestone is intentionally narrow:

- every zombie resolves to exactly one zombie faction;
- unassigned zombies belong to the built-in `Vanilla` faction;
- additional zombie factions can be registered;
- relationships are directional and use `FRIENDLY`, `NEUTRAL`, or `HOSTILE`;
- relationships can target zombie factions, Project Zomboid player factions, or unfactioned players;
- default installation preserves vanilla zombie behavior.

## Current state

SPIKE-001 successfully established that Build 42 multiplayer can support faction-aware zombie pursuit, synchronized damage, and death. The accepted design keeps faction policy and combat validation on the server while the current zombie owner performs bounded pursuit and applies server-authorized nonlethal damage. The server verifies that result and finalizes lethal death through the normal corpse lifecycle.

Version 0.0.24 remains a diagnostic implementation, not production-ready autonomous targeting. Its admin Horde Spawning extension provides `zf:test-red` and `zf:test-blue`, directional relationship controls to `zf:vanilla`, and an opt-in SPIKE combat harness. The diagnostic spawn path requires the same `CreateHorde` capability as vanilla Horde Spawning; ordinary Vanilla spawning remains unchanged when the SPIKE option is disabled.

The Sandbox Admin option **Zombie Mob Size** controls diagnostic mob membership. `1` preserves individual acquisition, values above `1` enable leader/follower mobs up to that size, and `0` removes the membership cap.

## Known limitations

- Only zombies explicitly enrolled through the admin diagnostic harness participate.
- Zombie ownership transfer and save/restart persistence still require production validation.
- Multi-member and unlimited mob scaling remain follow-on performance work.
- The validated timed damage cycle does not yet provide a proper zombie-on-zombie attack animation.
- The diagnostic harness is research instrumentation and is not a release-ready gameplay system.

## Project documentation

- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative runtime requirements.
- [`docs/DESIGN.md`](docs/DESIGN.md) — implementation strategy and development sequence.
- [`docs/SPIKE-001-zombie-targeting-and-combat-feasibility.md`](docs/SPIKE-001-zombie-targeting-and-combat-feasibility.md) — complete Build 42 experiment history, evidence, and closeout.
- [`docs/ADR-001-zombie-combat-authority.md`](docs/ADR-001-zombie-combat-authority.md) — accepted multiplayer targeting and damage authority model.
- [`COMPLIANCE.md`](COMPLIANCE.md) — Project Zomboid policy, provenance, and release constraints.
- [`CHANGELOG.md`](CHANGELOG.md) — version history.

## Runtime layout

```text
Contents/mods/pz-zombie-factions/
```

Original project source is licensed under Apache License 2.0. Project Zomboid code and assets remain property of The Indie Stone and are not redistributed or relicensed by this repository.

Zombie Factions is an unofficial independent community mod and is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.
