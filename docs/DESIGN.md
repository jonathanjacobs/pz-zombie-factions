# Zombie Factions Design

Status: Research / Pre-Alpha  
Version: 0.0.1  
Target: Project Zomboid Build 42.20.x

## Goal

Add a small faction/diplomacy layer for zombies without replacing unrelated Project Zomboid AI systems.

Every zombie resolves to exactly one zombie faction. Zombies without explicit assignment belong to the built-in `zf:vanilla` faction. Custom factions can define directional relationships toward other zombie factions, vanilla Project Zomboid player factions, and unfactioned players.

The three relationship states are:

- `FRIENDLY` — do not proactively target and do not retaliate solely because damage was received.
- `NEUTRAL` — do not proactively target; retaliation may occur after direct aggression.
- `HOSTILE` — may detect, select, pursue, and attack the target.

Relationships are directional, so `A -> B` may differ from `B -> A`.

## Core API

The faction layer should ultimately answer four questions:

```text
getZombieFaction(zombie)
getRelationship(sourceFaction, targetFaction)
canTarget(attacker, candidate)
shouldRetaliate(attacker, aggressor)
```

The initial shared Lua registry already establishes `zf:vanilla` plus the relationship constants and directional relationship lookup. Runtime targeting behavior is intentionally not implemented until the Build 42 targeting/combat spike is resolved.

## Identity model

Reserved identities:

- `zf:vanilla` — default faction for unassigned zombies.
- `zf:<id>` — custom zombie faction.
- `pf:unfactioned` — player with no Project Zomboid faction.
- `pf:<id>` — existing Project Zomboid player faction.

Zombie Factions will use the game's existing player-faction system rather than create a second player-faction implementation.

Faction assignment must eventually use zombie-associated persistent data that survives the relevant save/load and multiplayer lifecycle. A transient Lua table keyed only by object instance is not sufficient.

## Targeting architecture

The preferred integration point is a target-eligibility decision at, or immediately before, vanilla target acquisition:

```text
candidate discovered
        |
resolve attacker faction
        |
resolve candidate faction
        |
relationship == HOSTILE ? eligible : reject
```

A global per-tick scan that repeatedly clears `zombie:setTarget(nil)` is specifically disfavored. It risks target-reacquisition churn and scales work with the active zombie population.

Zombie-vs-zombie combat is not assumed to work merely because `IsoZombie` can hold a generic moving-object target. Build 42 still needs to be traced through pursuit, attack state, hit processing, death handling, and multiplayer synchronization.

## Multiplayer authority

Targeting, hostility, retaliation, and damage decisions that affect world state must be server-authoritative. Clients may mirror state for presentation or diagnostics but must not independently create divergent hostility decisions.

## Compatibility constraints

With no custom faction configuration:

- ordinary zombies resolve to `zf:vanilla`;
- vanilla zombies do not attack each other;
- normal zombie hostility toward players is preserved;
- the mod must not introduce full-world scans, target churn, network-command spam, or high-volume normal logging.

## Scope boundary

Faction identity and diplomacy are separate from:

- outfits and appearance;
- spawn/population rules;
- territory;
- loot;
- zombie stats or abilities;
- NPC faction behavior.

Those systems may consume the faction API later, but they are not part of the MVP.

## Validation

No feature is considered supported until observed in Build 42 runtime behavior.

The minimum controlled test sequence is:

1. confirm unassigned zombies resolve to `zf:vanilla`;
2. assign a custom faction and verify persistence across relevant lifecycle transitions;
3. verify directional `FRIENDLY`, `NEUTRAL`, and `HOSTILE` relationship resolution;
4. confirm default installation preserves normal player targeting;
5. test faction-aware player targeting;
6. test hostile zombie-to-zombie acquisition, pursuit, attack, damage, and death;
7. repeat authoritative behavior on a dedicated multiplayer server;
8. test save/load and client reconnect;
9. measure target-decision cost and confirm normal operation produces no command/log spam.

If a stage fails, instrument that boundary rather than compensating with broad per-tick overrides.

## Roadmap

### 0 — Foundation

- [x] Build 42 repository layout
- [x] faction/relationship data model
- [x] minimal shared Lua registry
- [x] targeting/combat research spike

### 1 — Engine feasibility

- [ ] trace target discovery and filtering
- [ ] identify the cleanest faction-aware eligibility point
- [ ] trace zombie-to-zombie pursuit/attack/damage/death
- [ ] determine Lua-only versus deeper-hook requirements

### 2 — Faction core

- [ ] persistent zombie assignment
- [ ] player-faction resolution
- [ ] server-authoritative relationship state
- [ ] bounded diagnostics

### 3 — Runtime behavior

- [ ] Friendly suppression
- [ ] Neutral retaliation
- [ ] Hostile targeting
- [ ] zombie-to-zombie combat if supported
- [ ] dedicated-server validation

### Later

- stable public API for other mods
- server/admin configuration tools
- appearance, spawning, territory, abilities, loot, and NPC integrations as separate layers
