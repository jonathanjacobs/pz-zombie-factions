# Zombie Factions

**A Project Zomboid Build 42 framework for assigning zombies to factions and defining directional Friendly, Neutral, and Hostile relationships between zombie factions and player factions.**

Status: **Research / Pre-Alpha**  
Current version: **v0.0.4**  
Target baseline: **Project Zomboid Build 42.20.x**

## Scope

The first milestone is intentionally narrow:

- every zombie belongs to exactly one zombie faction;
- unassigned zombies belong to the built-in `Vanilla` faction;
- additional zombie factions can be registered;
- relationships are directional;
- relationship values are `FRIENDLY`, `NEUTRAL`, or `HOSTILE`;
- relationships can target other zombie factions, Project Zomboid player factions, or unfactioned players;
- default installation preserves vanilla zombie behavior.

Version 0.0.4 contains the SPIKE-001 diagnostic harness. The built-in admin Horde Spawning window is extended with `zf:test-red` / `zf:test-blue` selections plus directional relationship controls to `zf:vanilla`. Custom test spawns are server-authoritative and require the same `CreateHorde` capability used by vanilla horde spawning.

The 0.0.4 patch explicitly positions the vanilla Spawn/Remove/Close controls after extending the Horde Spawning window and logs the resulting UI geometry. This replaces the earlier attempt to rely on bottom anchoring after a late window resize.

The harness creates deterministic faction-tagged test subjects; it does **not** yet implement faction-aware target acquisition or zombie-vs-zombie combat. Those are the behaviors SPIKE-001 is intended to investigate.

## Project docs

- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative runtime requirements (R1, R2, R3, ...).
- [`docs/DESIGN.md`](docs/DESIGN.md) — implementation strategy and development sequence.
- [`docs/SPIKE-001-zombie-targeting-and-combat-feasibility.md`](docs/SPIKE-001-zombie-targeting-and-combat-feasibility.md) — active Build 42 targeting/combat investigation.
- [`COMPLIANCE.md`](COMPLIANCE.md) — Project Zomboid policy, provenance, and release constraints.
- [`CHANGELOG.md`](CHANGELOG.md) — version history.

## Runtime layout

```text
Contents/mods/pz-zombie-factions/
```

Original project source is licensed under Apache License 2.0. Project Zomboid code and assets remain property of The Indie Stone and are not redistributed or relicensed by this repository.

Zombie Factions is an unofficial independent community mod and is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.
