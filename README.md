# Zombie Factions

**A Project Zomboid Build 42 framework for assigning zombies to factions and defining directional Friendly, Neutral, and Hostile relationships between zombie factions and player factions.**

Status: **Research / Pre-Alpha**  
Current version: **v0.0.7**  
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

Version 0.0.7 contains the active SPIKE-001 diagnostic harness. The built-in admin Horde Spawning window is extended with `zf:test-red` / `zf:test-blue` selections, directional relationship controls to `zf:vanilla`, and one opt-in target probe. Custom test spawns are server-authoritative and require the same `CreateHorde` capability used by vanilla horde spawning.

Dedicated Build 42.20.4 testing has established two useful boundaries:

- custom faction/test-run assignment resolves correctly immediately and again after a delayed server check;
- server-side `IsoZombie:setTarget(otherZombie)` plus `pathToCharacter(otherZombie)` can store the zombie target briefly, but the tested subjects remained `idle`, never attacked, and cleared the target shortly afterward.

Those forced subjects were client-owned. Version 0.0.7 therefore moves the active experiment to the zombie's owning client. The server selects one nearby Vanilla candidate and sends the exact subject/candidate online IDs to the requester. The owner then runs a bounded three-phase probe: direct target/path, an explicit `spottedOld(...)` perception fallback plus target/path, and—only if both target-specific phases stall—a raw `pathToLocationF(...)` control toward the candidate coordinates.

The probe deliberately avoids `spotted()` / `spottedNew()` with zombie targets because Build 42 has a documented player-oriented defect in that path. The location-path phase is a diagnostic control only; it is not faction behavior. Client and server both emit bounded transition diagnostics.

This is research instrumentation, not the production targeting architecture. Zombie Factions still does **not** claim working faction-aware target acquisition or zombie-vs-zombie combat until the complete acquisition, pursuit, attack, damage, death, and multiplayer synchronization chain is demonstrated.

## Project docs

- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative runtime requirements.
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
