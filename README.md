# Zombie Factions

**A Project Zomboid Build 42 framework for assigning zombies to factions and defining directional Friendly, Neutral, and Hostile relationships between zombie factions and player factions.**

Status: **Research / Pre-Alpha**  
Current version: **v0.0.1**  
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

The repository currently contains the faction/relationship data model and research scaffolding. It does **not** yet claim working zombie-vs-zombie combat; Build 42 target acquisition, pursuit, attack, damage, and multiplayer behavior are being traced first.

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
