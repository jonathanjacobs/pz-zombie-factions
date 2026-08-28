# Zombie Factions

**A Project Zomboid Build 42 framework for assigning zombies to factions and defining directional Friendly, Neutral, and Hostile relationships between zombie factions and player factions.**

Status: **Research / Pre-Alpha**  
Current version: **v0.0.6**  
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

Version 0.0.6 contains the active SPIKE-001 diagnostic harness. The built-in admin Horde Spawning window is extended with `zf:test-red` / `zf:test-blue` selections, directional relationship controls to `zf:vanilla`, and an opt-in direct-target probe. Custom test spawns are server-authoritative and require the same `CreateHorde` capability used by vanilla horde spawning.

The v0.0.5 Horde Spawner harness has been validated on a Build 42.20.4 dedicated server/client pair. Version 0.0.6 adds two research checks on top of that working harness:

- independently re-resolve faction/test-run metadata immediately and shortly after spawn, with client-side observation of tagged subjects;
- optionally force one HOSTILE test zombie to target and path toward the nearest Vanilla zombie within 12 tiles, then observe target retention, AI state, ownership, attack state, and death transitions.

The direct-target probe deliberately bypasses normal target discovery. It is a bounded SPIKE experiment, not the production targeting architecture. Zombie Factions still does **not** claim working faction-aware target acquisition or zombie-vs-zombie combat until the complete acquisition, pursuit, attack, damage, death, and multiplayer synchronization chain is demonstrated.

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
