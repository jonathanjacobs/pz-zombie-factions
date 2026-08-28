# Zombie Factions Design

Status: Research / Pre-Alpha  
Target: Project Zomboid Build 42.20.x

Normative runtime behavior is defined in [`REQUIREMENTS.md`](REQUIREMENTS.md). This document describes the implementation strategy and development sequence; version-specific evidence belongs in the SPIKE and changelog.

## Core API

The faction layer should ultimately answer four questions:

```text
getZombieFaction(zombie)
getRelationship(sourceFaction, targetFaction)
canTarget(attacker, candidate)
shouldRetaliate(attacker, aggressor)
```

The shared Lua layer currently provides the faction/relationship registry plus zombie assignment helpers. Production targeting remains deferred until SPIKE-001 establishes the cleanest Build 42 integration point.

## Identity model

Reserved identities:

- `zf:vanilla` — default zombie faction;
- `zf:test-red` / `zf:test-blue` — administrator diagnostic factions;
- `zf:<id>` — future custom zombie faction namespace;
- `pf:unfactioned` — player with no Project Zomboid faction;
- `pf:<id>` — existing Project Zomboid player faction.

Zombie assignment currently uses zombie `modData` for faction ID and optional SPIKE run ID. Immediate and delayed server-side resolution have been validated. Save/restart, relevance lifecycle, and client visibility remain separate persistence/synchronization questions before this mechanism is considered production-final.

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

The preferred hook is at, or immediately before, vanilla target acquisition. Repeated global scanning and `setTarget(nil)` churn are fallback approaches of last resort.

SPIKE-001 deliberately tests downstream feasibility before modifying discovery. The current diagnostic pairs one explicit HOSTILE test zombie with one nearby Vanilla zombie using a one-time bounded lookup. That lookup is research instrumentation, not production targeting.

Build 42.20.4 runtime evidence shows that server-side `setTarget(otherZombie)` plus `pathToCharacter(otherZombie)` can retain the zombie target briefly but did not move the tested client-owned subjects out of `idle`; the target was then cleared. The active probe therefore executes target/path calls on the owning client. If ordinary owner-side target/path still stalls, it retries once with `spotted(candidate, true)` before target/path assignment. Server and client observe the result independently.

The result will distinguish among:

- multiplayer ownership overwriting server-injected AI state;
- perception/alert state being required before pursuit;
- target validation rejecting zombie candidates;
- attack-state or damage/network blockers farther downstream.

## Admin diagnostic harness

Build 42's Horde Spawning UI is `ISSpawnHordeUI`. Vanilla spawning remains on its original path. Custom diagnostic factions use a namespaced client/server command gated by `Capability.CreateHorde`.

The server:

1. validates the diagnostic faction and directional relationships;
2. calls `addZombiesInOutfit(...)`;
3. assigns the exact returned zombie object;
4. records a bounded `SPIKE001-####` ID;
5. performs immediate and delayed assignment verification;
6. when requested, selects one nearby Vanilla candidate;
7. dispatches exact subject/candidate online IDs to the requesting client;
8. passively observes server-visible target/state/attack/death transitions.

The owning client resolves those online IDs with bounded retries, confirms local ownership, then performs the two-phase target probe described above. This avoids depending on client propagation of the SPIKE mod-data tag merely to identify the diagnostic subject.

The harness UI/custom spawn path has been validated on a Build 42.20.4 dedicated server/client pair, including Red/Blue selection, asymmetric relationships, mutual hostility, and multi-zombie spawning.

## Zombie-vs-zombie feasibility

The public type surface is permissive: `setTarget` accepts `IsoMovingObject`, `pathToCharacter` accepts `IsoGameCharacter`, and `isZombieAttacking` accepts `IsoMovingObject`. This makes another zombie syntactically passable but does not prove behavioral support.

SPIKE-001 must still establish the complete chain:

1. candidate discovery/filtering;
2. target assignment/retention;
3. pursuit;
4. attack-state entry;
5. damage processing;
6. death/corpse handling;
7. multiplayer authority/synchronization.

The documented MP packet/API surface already suggests zombie-originated native hit handling is player-oriented, so a custom server-authoritative damage path may ultimately be required even if pursuit/attack animation can be reused. That decision remains deferred until the earlier AI stages are demonstrated.

## Multiplayer model

Relationship configuration and world-changing combat decisions are server-authoritative. Client-side AI calls in SPIKE-001 exist only to determine how PZ's ownership model drives a client-owned zombie. They are not the proposed production authority model.

If a production implementation must trigger behavior on the owning client, the server still owns relationship policy and damage truth, with tightly bounded synchronization rather than independent client hostility decisions.

## Development sequence

### 0 — Foundation

- [x] Build 42 repository layout
- [x] normative requirements
- [x] minimal faction/relationship registry
- [x] targeting/combat feasibility spike

### 1 — Engine feasibility

- [x] identify Horde Spawning UI/server spawn path
- [x] implement and validate faction-aware diagnostic spawning
- [x] tag exact returned spawn objects
- [x] validate immediate/delayed server assignment resolution
- [x] demonstrate that server-side zombie target assignment is briefly accepted but cleared without pursuit in client-owned test subjects
- [x] add owner-side target/path plus perception fallback probe
- [ ] determine whether owner-side target/path is retained and enters pursuit
- [ ] determine whether `spotted(...)` changes that result
- [ ] trace the exact target-clearing/eligibility boundary
- [ ] run Friendly, Neutral, Hostile, and asymmetric controls through the eventual acquisition hook
- [ ] trace attack, damage, death, and MP synchronization
- [ ] determine Lua-only versus deeper-hook requirements
- [ ] validate assignment across save/restart and relevance transitions

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
- server/admin configuration beyond the diagnostic harness
- appearance, gameplay spawning/population rules, territory, abilities, loot, and NPC integrations as separate layers
