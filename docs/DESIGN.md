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

The shared Lua layer currently provides the faction/relationship registry, zombie assignment helpers, and `canTarget(attacker, candidate)`. The policy helper is directional, O(1), and side-effect-free; it currently supports zombie-to-zombie identity only and fails closed for player candidates until player-faction resolution is implemented. SPIKE-001 established a viable Build 42 integration boundary; production enrollment, persistence, and ownership-transition behavior remain follow-on work.

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

Build 42 exposes no vanilla zombie-to-zombie discovery callback, and its native character target synchronization is player-oriented. Production targeting therefore uses bounded server-local discovery rather than recurring all-zombie scans. The accepted control flow is:

1. the server resolves faction policy and selects an exact eligible zombie pair;
2. the server sends a typed target grant only to the subject zombie's current owner;
3. that owner performs coordinate pursuit and attaches the exact zombie target only inside a clear melee envelope;
4. the attacker owner requests an impact at the authorized hit point;
5. the server revalidates identity, policy, ownership, level, distance, cooldown, and liveness;
6. the target owner applies the uniquely identified nonlethal decrement, and the server verifies it and finalizes lethal death through the normal corpse lifecycle.

Target and impact grants are persistent until an event invalidates them; individual operation timeouts and rate limits remain bounded. A grant ends or changes on death, pooled-object identity reuse, ownership loss, invalid policy, level or distance separation, explicit release, or no-progress reassignment.

Stable server-runtime mobs reduce duplicate discovery. Membership is assigned once, uses `ZombieConfig.RallyTravelDistance` for recruitment, and is capped by `ZombieFactions.ZombieMobSize`. Each mob elects one recurring discovery leader. On contact, each member receives one bounded, load-aware selection against the discovered hostile faction; followers do not run recurring discovery. Multiple attackers may share a target, but a soft assignment penalty and stable approach positions distribute crowds when alternatives exist. Wake-up grants are owner-specific and drained through a bounded shared queue.

A stable mob may contain active and dormant members at the same time. Mob-wide activity must not suppress event-driven recovery for a specific dormant member: if that member is attacked or becomes the known target of an eligible hostile zombie, it must be able to receive a direct server-validated wake-up against that candidate even while another member remains active. A member that temporarily lacks a candidate may be retried through bounded mob topology or combat events, but followers must not gain recurring independent discovery scans.

## Admin diagnostic harness

The admin Horde Spawning extension and its SPIKE checkbox are diagnostic tooling, not the production enrollment path. Vanilla spawning remains unchanged when the checkbox is disabled. The harness workflow, version history, test procedures, and evidence are maintained in [`SPIKE-001-zombie-targeting-and-combat-feasibility.md`](SPIKE-001-zombie-targeting-and-combat-feasibility.md).

## Zombie-vs-zombie feasibility

SPIKE-001 is closed successfully: directional zombie-faction hostility and synchronized zombie-on-zombie combat are feasible in Build 42.20.x. The complete vanilla player-target combat path is not reusable. Native AI can supply portions of pursuit and attack behavior, while the validated multiplayer implementation requires explicit grants and owner-mediated, server-validated damage. See the SPIKE closeout and [`ADR-001-zombie-combat-authority.md`](ADR-001-zombie-combat-authority.md) for the evidence and accepted authority boundary.

## Multiplayer model

Relationship configuration, target authorization, impact validation, and lethal finalization are server-authoritative. The owner client controls only the locally simulated pursuit/engagement step and applies a server-instructed nonlethal decrement to the target it owns. Every command is pair-specific and state-change-driven; clients do not make independent hostility or world-changing damage decisions. Ownership changes invalidate the affected grant and require explicit reacquisition.

## Development sequence

### 0 — Foundation

- [x] Build 42 repository layout
- [x] normative requirements
- [x] minimal faction/relationship registry
- [x] targeting/combat feasibility spike

### 1 — Engine feasibility

- [x] validate faction-aware diagnostic spawning and exact zombie assignment
- [x] establish owner-controlled pursuit and close-range engagement against another zombie
- [x] validate owner-mediated nonlethal damage and server-finalized death/corpse synchronization
- [x] validate bounded leader/follower discovery and distributed crowd combat at mob sizes `1` and `8`
- [x] close SPIKE-001 and record the accepted authority model in ADR-001
- [ ] restore event-driven recovery for a dormant member while another member keeps the mob active ([#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2))
- [ ] reduce distance-rejected faction impact requests without weakening server validation ([#1](https://github.com/jonathanjacobs/pz-zombie-factions/issues/1))
- [ ] validate the explicit Red/Blue/Vanilla relationship matrix so expected Neutral pairs are distinguishable from failed retaliation
- [ ] profile client FPS and server load at mob size `8` before testing unlimited mobs
- [ ] validate ownership reacquisition with a real owner transfer
- [ ] validate assignment across save/restart and relevance transitions

### 2 — Faction core

- [ ] automatic production enrollment for naturally spawned and relevance-loaded zombies outside the diagnostic harness
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
- profile server tick time, memory use, garbage collection, candidate work, and packet counts under representative large mixed-faction crowds after the basic mechanics are correct
- revisit compact runtime representation only if profiling shows a material need: numeric faction/relationship codes, fixed-capacity candidate caches, flat reusable arrays, packed 16-bit zombie IDs, or Java primitive storage are options, but byte packing is explicitly deferred until then
- keep acquisition state server-local and owner commands targeted so optimization does not introduce per-zombie-per-tick packets; allow multiple attackers per target, with only an optional soft distribution preference for large crowd battles rather than a hard attacker cap
- appearance, gameplay spawning/population rules, territory, abilities, loot, and NPC integrations as separate layers
