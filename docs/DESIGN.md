# Zombie Factions Design

Status: Research / Pre-Alpha  
Version: 0.0.2  
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

The shared Lua layer currently provides the faction/relationship registry plus zombie assignment helpers. Runtime targeting behavior remains deferred until SPIKE-001 establishes the cleanest Build 42 integration point.

## Identity model

Reserved identities:

- `zf:vanilla` — default zombie faction;
- `zf:test-red` — shared administrator diagnostic faction;
- `zf:test-blue` — shared administrator diagnostic faction;
- `zf:<id>` — future custom zombie faction namespace;
- `pf:unfactioned` — player with no Project Zomboid faction;
- `pf:<id>` — existing Project Zomboid player faction.

The two test factions are registered in shared code so server and observing clients resolve their identities consistently.

Zombie assignment currently uses zombie `modData` keys for the faction ID and optional SPIKE test-run ID. Persistence and multiplayer propagation remain runtime-validation targets before this mechanism is treated as production-final.

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

Build 42's built-in Horde Spawning UI is `ISSpawnHordeUI`. In multiplayer its ordinary spawn path invokes `/createhorde2`; the server-side command creates zombies through `addZombiesInOutfit(...)`.

For faction test subjects, v0.0.2 extends the existing admin window but uses a namespaced Zombie Factions client command rather than modifying the game's Java slash command. The server handler:

1. requires `Capability.CreateHorde`;
2. accepts only the shared diagnostic factions `zf:test-red` and `zf:test-blue`;
3. validates/configures both directional relationships to `zf:vanilla` before spawning;
4. calls the normal `addZombiesInOutfit(...)` API;
5. uses the returned `ArrayList<IsoZombie>` to tag the exact newly created zombie immediately;
6. assigns a bounded `SPIKE001-####` run ID;
7. emits one concise run summary and result packet.

Selecting `zf:vanilla` leaves the original Horde Spawning `onSpawn()` path unchanged.

The harness is intentionally multiplayer/server-authoritative. It is diagnostic tooling, not the future gameplay population system.

## Zombie-vs-zombie feasibility

A generic target field does not prove the downstream AI supports zombie-on-zombie combat. SPIKE-001 must still trace:

1. candidate discovery and filtering;
2. target assignment;
3. pathing and pursuit;
4. attack-state assumptions;
5. hit/damage processing;
6. death handling;
7. multiplayer authority and synchronization.

That evidence determines whether the runtime can remain Lua-only or requires a deeper extension point.

## Multiplayer model

Relationship configuration and world-changing combat decisions are server-authoritative. Clients may mirror state for presentation, inspection, or bounded diagnostics but must not independently create divergent hostility decisions.

## Development sequence

### 0 — Foundation

- [x] Build 42 repository layout
- [x] normative requirements
- [x] minimal faction/relationship registry
- [x] targeting/combat feasibility spike

### 1 — Engine feasibility and test harness

- [x] identify the built-in Horde Spawning UI/server spawn path
- [x] implement admin-only faction-aware diagnostic spawning
- [x] tag exact returned spawn objects instead of locating them with a proximity scan
- [ ] validate the extended Horde Spawning UI on a Build 42.20.x dedicated client
- [ ] verify faction/test-run mod data survives the required server/client lifecycle
- [ ] trace target discovery and filtering
- [ ] identify the cleanest faction-aware eligibility point
- [ ] run Friendly, Neutral, Hostile, and asymmetric relationship controls
- [ ] trace zombie-to-zombie pursuit/attack/damage/death
- [ ] determine Lua-only versus deeper-hook requirements

### 2 — Faction core

- [ ] production persistence for zombie assignment
- [ ] player-faction resolution
- [ ] persistent/server-configurable relationship state
- [ ] bounded behavioral diagnostics

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
