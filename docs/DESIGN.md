# Zombie Factions Design

Status: Research / Pre-Alpha  
Version: 0.0.6  
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

The shared Lua layer currently provides the faction/relationship registry plus zombie assignment helpers. Production targeting behavior remains deferred until SPIKE-001 establishes the cleanest Build 42 integration point.

## Identity model

Reserved identities:

- `zf:vanilla` — default zombie faction;
- `zf:test-red` — shared administrator diagnostic faction;
- `zf:test-blue` — shared administrator diagnostic faction;
- `zf:<id>` — future custom zombie faction namespace;
- `pf:unfactioned` — player with no Project Zomboid faction;
- `pf:<id>` — existing Project Zomboid player faction.

The two test factions are registered in shared code so server and observing clients resolve their identities consistently.

Zombie assignment currently uses zombie `modData` keys for the faction ID and optional SPIKE test-run ID. The v0.0.6 harness independently resolves those values immediately after assignment and again after a short delay for a bounded sample. A client-side observer also reports tagged subjects when the transmitted mod data becomes visible there. Save/restart and relevance lifecycle persistence remain separate validation targets before this mechanism is treated as production-final.

## Targeting integration

Preferred production flow:

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

### SPIKE direct-target probe

Before modifying candidate discovery, v0.0.6 performs a narrower feasibility experiment: if explicitly enabled by an admin, one newly spawned HOSTILE test zombie is paired with the nearest living `zf:vanilla` zombie within 12 tiles. The server calls `setTarget(candidate)` and `pathToCharacter(candidate)`, then observes whether the target is retained and whether vanilla pursuit/attack states progress.

This probe intentionally bypasses normal target discovery. Its one-time bounded candidate search may inspect the current zombie list because it is diagnostic research on one explicit test subject; that scan is **not** an acceptable production targeting architecture.

If the forced-target chain fails, SPIKE-001 can identify whether the blocker is target retention, pathing, attack-state assumptions, damage handling, or multiplayer ownership before investing in a candidate-discovery hook. If the forced-target chain works, the next research step is to trace `spotted(...)` / candidate eligibility and introduce `canTarget(...)` at the narrowest safe boundary.

## SPIKE-001 admin test harness

Build 42's built-in Horde Spawning UI is `ISSpawnHordeUI`. In multiplayer its ordinary spawn path invokes `/createhorde2`; the server-side command creates zombies through `addZombiesInOutfit(...)`.

For faction test subjects, the extension uses a namespaced Zombie Factions client command rather than modifying the game's Java slash command. The server handler:

1. requires `Capability.CreateHorde`;
2. accepts only the shared diagnostic factions `zf:test-red` and `zf:test-blue`;
3. validates/configures both directional relationships to `zf:vanilla` before spawning;
4. calls the normal `addZombiesInOutfit(...)` API;
5. uses the returned `ArrayList<IsoZombie>` to tag the exact newly created zombie immediately;
6. assigns a bounded `SPIKE001-####` run ID;
7. verifies assignment immediately and queues bounded delayed verification;
8. optionally queues the direct-target probe;
9. emits concise run summaries and transition-only diagnostics.

Selecting `zf:vanilla` leaves the original Horde Spawning `onSpawn()` path unchanged.

The v0.0.5 harness UI and custom spawn command were runtime-validated on a Build 42.20.4 dedicated server/client pair, including Red/Blue faction selection, asymmetric relationships, mutual hostility, and multi-zombie spawning.

## Zombie-vs-zombie feasibility

The current Build 42 API surface is permissive at the type boundary: an `IsoZombie` target is an `IsoMovingObject`, `pathToCharacter(...)` accepts `IsoGameCharacter`, and `isZombieAttacking(...)` accepts `IsoMovingObject`. That makes a direct zombie target syntactically possible but does not establish downstream behavioral support.

SPIKE-001 must still validate:

1. candidate discovery and filtering;
2. target assignment and retention;
3. pathing and pursuit;
4. attack-state assumptions;
5. hit/damage processing;
6. death handling;
7. multiplayer authority and synchronization.

That evidence determines whether the runtime can remain Lua-only or requires a deeper extension point.

## Multiplayer model

Relationship configuration and world-changing combat decisions are server-authoritative. Clients may mirror state for presentation, inspection, or bounded diagnostics but must not independently create divergent hostility decisions.

The v0.0.6 client observer is passive: it reports tagged zombie state/target changes but does not make hostility or damage decisions.

## Development sequence

### 0 — Foundation

- [x] Build 42 repository layout
- [x] normative requirements
- [x] minimal faction/relationship registry
- [x] open targeting/combat feasibility spike

### 1 — Engine feasibility and test harness

- [x] identify the built-in Horde Spawning UI/server spawn path
- [x] implement admin-only faction-aware diagnostic spawning
- [x] tag exact returned spawn objects instead of locating them with a proximity scan
- [x] validate the extended Horde Spawning UI on a Build 42.20.4 dedicated client/server pair
- [x] add immediate and delayed assignment-resolution diagnostics
- [x] add opt-in forced-target/path feasibility probe
- [ ] verify tagged faction/test-run mod data is visible on the observing client
- [ ] verify faction/test-run data across save/restart and relevance lifecycle transitions
- [ ] validate forced zombie-to-zombie target retention and pursuit
- [ ] trace target discovery and filtering
- [ ] identify the cleanest faction-aware eligibility point
- [ ] run Friendly, Neutral, Hostile, and asymmetric behavioral controls
- [ ] trace zombie-to-zombie attack/damage/death
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
