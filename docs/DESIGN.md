# Zombie Factions Design

Status: Research / Pre-Alpha  
Version: 0.0.1  
Target: Project Zomboid Build 42.20.x

Normative runtime behavior is defined in [`REQUIREMENTS.md`](REQUIREMENTS.md). This document describes the current implementation strategy and development sequence.

## Core API

The faction layer should ultimately answer four questions:

```text
getZombieFaction(zombie)
getRelationship(sourceFaction, targetFaction)
canTarget(attacker, candidate)
shouldRetaliate(attacker, aggressor)
```

The initial shared Lua registry already establishes `zf:vanilla`, the three relationship constants, faction registration, and directional relationship lookup. Runtime targeting behavior is intentionally deferred until the Build 42 targeting/combat spike is resolved.

## Identity model

Reserved identities:

- `zf:vanilla` — default zombie faction.
- `zf:<id>` — custom zombie faction.
- `pf:unfactioned` — player with no Project Zomboid faction.
- `pf:<id>` — existing Project Zomboid player faction.

Zombie assignment should ultimately use persistent zombie-associated data rather than a transient Lua table keyed only by object instance.

## Targeting integration

Preferred flow:

```text
candidate discovered
        |
resolve attacker faction
        |
resolve candidate faction
        |
relationship policy
        |
eligible / reject
```

The preferred hook is at, or immediately before, vanilla target acquisition. Repeated global scanning and `setTarget(nil)` churn is a fallback of last resort.

## SPIKE-001 admin test harness

The first behavioral prototype needs deterministic test subjects. The preferred harness is an admin-only extension of Project Zomboid's built-in Horde Spawning tool.

For each diagnostic spawn operation the administrator should be able to select:

- a zombie faction such as `zf:test-red`;
- `spawned faction -> zf:vanilla` relationship;
- `zf:vanilla -> spawned faction` relationship;
- optionally mirror the relationship symmetrically;
- the normal horde count/location controls needed to position the subjects.

This is diagnostic tooling, not the future gameplay spawning/population system. If extending the vanilla Horde Spawning panel proves too brittle, a small adjacent Zombie Factions admin panel may use the same authoritative spawn path instead.

The harness should mark spawned test subjects so diagnostic logging can be restricted to them rather than instrumenting every active zombie.

## Zombie-vs-zombie feasibility

A generic target field does not prove the downstream AI supports zombie-on-zombie combat. The active spike must trace:

1. candidate discovery and filtering;
2. target assignment;
3. pathing and pursuit;
4. attack-state assumptions;
5. hit/damage processing;
6. death handling;
7. multiplayer authority and synchronization.

That evidence determines whether the runtime can remain Lua-only or requires a deeper extension point.

## Multiplayer model

Relationship configuration and world-changing combat decisions should be authoritative on the server. Clients should receive only the state needed for presentation, inspection, or bounded diagnostics.

## Development sequence

### 0 — Foundation

- [x] Build 42 repository layout
- [x] normative requirements
- [x] minimal faction/relationship registry
- [x] targeting/combat feasibility spike

### 1 — Engine feasibility and test harness

- [ ] identify the built-in Horde Spawning UI/server spawn path
- [ ] add admin-only faction-aware diagnostic spawning
- [ ] verify faction identity is attached before targeting decisions observe the spawned subjects
- [ ] trace target discovery and filtering
- [ ] identify the cleanest faction-aware eligibility point
- [ ] run Friendly, Neutral, Hostile, and asymmetric relationship controls
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
- server/admin configuration tools beyond the diagnostic harness
- appearance, gameplay spawning/population rules, territory, abilities, loot, and NPC integrations as separate layers
