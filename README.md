# Zombie Factions

**A Project Zomboid Build 42 framework for assigning zombies to factions and defining directional Friendly, Neutral, and Hostile relationships between zombie factions and player factions.**

Status: **Research / Pre-Alpha**  
Current version: **v0.0.1**  
Target baseline: **Project Zomboid Build 42.20.x**

## Current scope

The first milestone is intentionally narrow:

- every zombie belongs to exactly one zombie faction;
- unassigned zombies belong to the built-in `Vanilla` faction;
- additional zombie factions can be registered;
- relationships are directional;
- relationship values are `FRIENDLY`, `NEUTRAL`, or `HOSTILE`;
- zombie factions can define relationships toward other zombie factions, vanilla player factions, and unfactioned players;
- installing the mod without defining custom factions must preserve vanilla zombie behavior.

This repository currently establishes the data model, repository structure, design constraints, and research plan. It does **not** yet claim working zombie-vs-zombie combat. That capability depends on Build 42 target-acquisition, pathing, attack-state, hit-processing, and multiplayer behavior that is being validated before implementation.

## Documentation

- [`docs/README.md`](docs/README.md) — documentation index.
- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative MVP behavior.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — proposed technical design.
- [`docs/TESTING.md`](docs/TESTING.md) — validation strategy.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — development roadmap.
- [`docs/spikes/`](docs/spikes/) — implementation research.
- [`docs/adr/`](docs/adr/) — architecture decisions.
- [`COMPLIANCE.md`](COMPLIANCE.md) — Project Zomboid mod-policy compliance entry point.

## License and disclaimer

Original project source code is licensed under Apache License 2.0. Project Zomboid code and assets remain property of The Indie Stone and are not relicensed or redistributed by this repository.

Zombie Factions is an unofficial independent community mod and is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.
