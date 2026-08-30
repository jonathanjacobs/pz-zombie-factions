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

The shared Lua layer currently provides the faction/relationship registry, zombie assignment helpers, and `canTarget(attacker, candidate)`. The policy helper is directional, O(1), and side-effect-free; it currently supports zombie-to-zombie identity only and fails closed for player candidates until player-faction resolution is implemented. Production targeting remains deferred while SPIKE-001 validates the viable Build 42 integration boundary.

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

SPIKE-001 deliberately tests downstream feasibility before production discovery. In v0.0.14, the diagnostic registers only explicitly requested subjects—including opt-in Vanilla harness spawns—shares one short-lived spatial index among due scans, limits scan work per tick, and grants exact eligible pairs to their owning clients. The bounded scheduler is research instrumentation, not an always-on production targeting service.

Build 42.20.4 runtime evidence shows that server-side `setTarget(otherZombie)` plus `pathToCharacter(otherZombie)` is insufficient for client-owned subjects. The owning-client form of the same calls, however, retained a zombie target and reached native pursuit and attack states. Native attacks did not reduce the candidate's health; a custom lethal server impact successfully entered the normal death/corpse replication lifecycle, while nonlethal health replication and native hit presentation remain unsupported.

The v0.0.7 target probe executes on the zombie's owning client in three bounded phases:

1. `setTarget(candidate)` + `pathToCharacter(candidate)`;
2. if that stalls, `spottedOld(candidate, true)` + target/path;
3. if both target-specific phases stall, clear the target and run `pathToLocationF(...)` toward the candidate coordinates as a generic movement/pathing control.

A public Build 42.17 report documented a player-null defect in `spottedNew(...)`. The supplied Build 42.20.x source guards those player-only branches, but the method remains perception- and ownership-sensitive and is not a production hook by itself. v0.0.11 therefore invokes `spottedNew(candidate, false)` only for one server-authorized pair, inside `pcall`, and retains the proven direct target/path calls as the control.

The three-phase result distinguishes among:

- multiplayer ownership overwriting server-injected AI state;
- perception/alert state being required before pursuit;
- target-specific validation/pathing rejecting zombie candidates;
- generic client-side movement/path authority failing even without a target;
- attack-state or damage/network blockers farther downstream.

In v0.0.8, a separate bounded impact probe observes only the server-selected subject/candidate pair. A rising native attack event at melee range makes a client request; the server validates run identity, ownership, server-side faction/relationship policy, distance, cooldown, and liveness before applying a diagnostic `0.25` damage to the candidate. The v0.0.8 result established server-only health reduction but no client-side health update. In v0.0.9, a lethal diagnostic impact attributes the candidate to the subject and invokes `die()` so the normal server corpse and `ZombieDeath` replication lifecycle can run. Two dedicated-server runs confirmed this produced client-visible corpses. This isolates death replication without making the client authoritative for world-changing damage.

In v0.0.10, the diagnostic policy gate is explicit: Friendly and Neutral log a bounded suppression result before any candidate lookup or client AI instruction, while Hostile alone may enter the forced-target probe. This validates directionality at the harness gate; it does not add autonomous target acquisition.

Source tracing for v0.0.11 found no vanilla zombie-centric candidate enumeration or Lua eligibility callback. Player LOS processing calls `IsoZombie.spotted(player, false)`; there is no equivalent path that discovers another zombie. Native zombie mind and path-goal synchronization also resolve character targets through player IDs, so another zombie target cannot survive normal replication or ownership transfer.

The v0.0.11 boundary probe therefore uses a short-lived custom grant:

1. the server scans once for one explicitly requested custom subject;
2. `canTarget` filters every in-range living same-floor zombie using current authoritative relationship state;
3. the server reserves one nearest eligible candidate and sends the exact pair to the current owner;
4. the owner tries non-forced `spottedNew(...)` during a bounded Phase A;
5. if native acquisition does not commit, direct `setTarget + pathToCharacter` runs as the already-proven control;
6. the server revalidates policy, ownership, object identity, floor, range, cooldown, and liveness for every diagnostic impact and revokes the grant if ownership changes.

This tests the native perception entry without adding a recurring global scan. Production behavior will require a scalable candidate source plus explicit reacquisition after ownership changes.

The v0.0.11 runtime test committed the exact candidate through owner-side `spottedNew(...)` and reached native pursuit and attack. Its accepted server-only `applyDamage(0.25)` briefly changed server health from `1.0` to `0.75`, after which the target owner's ordinary zombie packet restored `1.0`. v0.0.12 therefore routes each validated fixed-damage hit to the target zombie's current owner. Dedicated-server tests validated owner and server health descending `1.0 -> 0.75 -> 0.50 -> 0.25 -> 0.0`, followed by server-finalized death. Hit IDs, current-owner checks, one in-flight hit per grant, bounded acknowledgement timeouts, and a bounded duplicate-acknowledgement cache contain duplicates and ownership races.

v0.0.13 extended that validated pair protocol with bounded discovery and reacquisition, and dedicated-server crowd testing validated reciprocal grants, repeated damage/deaths, and the four-scans-per-tick ceiling. The logs also established that server `OnTick` runs at approximately 10 Hz: the nominal 60-tick retry was about six seconds and the nominal 1,800-tick lifetime was about three minutes.

v0.0.14 corrects the scheduler to that observed clock. Up to 64 explicitly requested subjects per run retry discovery every 10 server ticks for 60 seconds. A 12-tile spatial bucket index is rebuilt at most every five server ticks and reused by at most four due subject scans per tick. Opt-in Vanilla Horde Spawns are directly enrolled, so their participation no longer depends on reciprocal discovery by an already-active attacker. Probe records retain the online IDs captured at enrollment and are discarded or reacquired if Java object pooling changes either identity.

On the owner, native spotting is still attempted before direct control. Direct control retains the exact authorized zombie in `setTarget(...)` but uses a refreshed `pathToLocationF(...)` pursuit goal. This follows the decompiled Build 42.20.x network contract: `NetworkZombieMind` serializes location goals, whereas a character goal is serializable only when its target is an `IsoPlayer`. The location-path change is a v0.0.14 mitigation that still requires runtime confirmation that pursuit/attack remains intact and the prior multiplayer error spam disappears.

The v0.0.14 stress run confirmed pursuit, damage, and death at high density, but exposed deeper player-only assumptions during obstacle combat: `attackFromWindowsLunge(...)` reads Moodles and body state from its target, which is invalid for an `IsoZombie`, and exact crowd overlap can leave `LungeState` with a zero direction vector. v0.0.15 added an owner-local polling interlock, but its retest proved that a fence animation event can run before polling clears the attached zombie target.

v0.0.16 therefore separates travel from engagement. During travel the owner clears any zombie target and installs only a coordinate goal with `pathToLocationF(...)`. It cancels that coordinate path before attaching the exact authorized candidate within a clear local melee envelope, and detaches the candidate before coordinate pursuit resumes. `spottedNew(otherZombie, false)` is removed because it installs an unsupported zombie character goal. The traversal/overlap checks remain a secondary fail-closed guard, while player targets are preserved by pausing faction control. This changes no server policy or packet volume.

The v0.0.16 stress result established that this control split avoids the prior crash, but not that the diagnostic harness scales. Per-frame observer construction and logging dominated the client trace, two combat listeners duplicated polling, overlapping runs doubled the active-controller budget, repeated grant resolution scanned the entire local zombie list, and candidate deaths caused synchronized requeue bursts. v0.0.17 consolidates owner work behind one 10 Hz scheduler, shares ID resolution, caches square-boundary checks, uses movement-driven path refresh, aggregates metrics, and tightens damage request eligibility.

v0.0.18 tests shared-target mob acquisition. A due subject that finds a candidate becomes a mob leader; pending same-faction subjects near that leader inherit the candidate without running their own candidate scan. `ZombieFactions.ZombieMobSize` includes the leader, defaults to `1`, and treats `0` as unlimited for the eligible local mob. Followers wait behind the leader during candidate-death reacquisition so one refreshed discovery can repopulate the mob instead of causing a simultaneous scan burst. This remains a bounded experiment; production discovery should eventually use an ownership-aware local spatial index and server validation rather than per-pair diagnostic grants.

v0.0.19 adds crowd distribution without an exclusive reservation table. Each active assignment contributes a soft penalty to candidate score, and distance remains part of the score, so pile-ons remain legal when enemies are scarce while leaders spread across viable alternatives. Owner clients path each mob member to a stable ring position around the candidate. A staggered no-progress timer requests one server-validated reassignment, and the previous candidate receives a one-scan avoidance penalty. Reattachment backoff bounds unsupported exact-target writes when Build 42 repeatedly clears a zombie target.

v0.0.20 makes enrollment persistent. Target and impact grants carry an explicit lifetime flag and are no longer removed by an elapsed-time counter. Cleanup is event-driven: death, identity reuse, ownership loss, invalid policy, level or distance separation, explicit release, and no-progress reassignment remain authoritative termination or transition conditions. Per-operation timeouts remain bounded.

v0.0.21 makes mob membership stable for the lifetime of each enrolled runtime zombie. One-time recruitment uses the vanilla `ZombieConfig.RallyTravelDistance`, while `ZombieFactions.ZombieMobSize` remains the membership cap. Each mob keeps one elected discovery leader; followers hold no pending discovery records and wake only when the leader grants a target or when the server already knows that a member was targeted or damaged. Leader election prefers an owned member near the mob center and changes when the current leader dies, becomes unavailable, or separates. Death, pooled-object identity reuse, and faction changes remove members; an empty mob terminates. A shared wake queue emits at most eight follower grants per server tick. Membership is intentionally server-runtime state during this spike rather than save-persistent identity.

v0.0.22 treats a leader's successful scan as contact with an enemy faction, not an instruction for every follower to converge on the same zombie. Each waking member makes one bounded local selection against the same cached spatial index, constrained to that enemy faction and softly balanced by existing assignment load. Followers still do not run recurring discovery. Candidate death or detected no progress causes one event-driven member replacement selection; only a mob without a viable active engagement returns its leader to recurring discovery.

v0.0.23 adds an explicit owner-local melee commitment for a clear authorized pair within 0.90 tile. The shared client scheduler runs targeting before impact, records a pass-scoped authorization for the exact server grant, and starts a staggered bite animation cycle. Its hit point may request server validation even when vanilla clears the native zombie target between controller passes. A committed pair does not trigger no-progress reassignment merely because neither zombie can move at contact. Per-attacker cooldown and a four-request-per-pass client budget bound impact traffic.

v0.0.24 corrects the presentation layer without changing that damage/control split. `IsoGameCharacter.setBumpType` describes collision reactions, not an animation to play; unsupported `Bite` and `BiteLow` values can enter the zombie bumped action state without a matching animation capable of emitting `BumpAnimFinished`. The explicit melee cycle therefore remains timing-only. A compatibility guard sets the completion variable and clears the bump state only when it finds one of those two values written by v0.0.23. Legitimate vanilla bump types are never modified. A future attack visual must use a lifecycle that can safely target another zombie and must remain independent of damage authorization.

A stable mob may contain active and dormant members at the same time. Mob-wide activity must not suppress event-driven recovery for a specific dormant member: if that member is attacked or becomes the known target of an eligible hostile zombie, it must be able to receive a direct server-validated wake-up against that candidate even while another member remains active. A member that temporarily lacks a candidate may be retried through bounded mob topology or combat events, but followers must not gain recurring independent discovery scans.

## Admin diagnostic harness

Build 42's Horde Spawning UI is `ISSpawnHordeUI`. Vanilla spawning remains on its original path unless the SPIKE checkbox is enabled; opt-in Vanilla and custom diagnostic factions use a namespaced client/server command gated by `Capability.CreateHorde`.

The server:

1. validates the diagnostic faction and directional relationships;
2. calls `addZombiesInOutfit(...)`;
3. assigns the exact returned zombie object;
4. records a bounded `SPIKE001-####` ID;
5. performs immediate and delayed assignment verification;
6. when requested, recruits each spawned diagnostic subject once into a stable local mob;
7. queues only each mob's elected leader and uses a shared spatial index plus per-tick budget to select a `canTarget`-eligible zombie;
8. dispatches exact subject/candidate online IDs only to the subject's current owner;
9. regrants after ownership changes and wakes or requeues the stable mob after candidate invalidation;
10. passively observes server-visible target/state/attack/death transitions.

The owning client resolves those online IDs with bounded retries, confirms local ownership, and maintains the exact pair through owner-side native acquisition plus the proven target/path control. While the native melee-attack state remains active, the impact probe requests rate-limited server validation. The server routes each resulting fixed damage instruction only to the target zombie's current owner and waits for a validated acknowledgement before synchronizing server health or finalizing death. This avoids depending on client propagation of the SPIKE mod-data tag merely to identify the diagnostic subject.

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

If a production implementation must trigger behavior on the owning client, the server still owns relationship policy and damage truth, with tightly bounded synchronization rather than independent client hostility decisions. Build 42's native zombie target and path-goal fields resolve character IDs as players, so a zombie target requires a typed custom grant and must be reacquired whenever subject ownership changes.

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
- [x] add owner-side target/path, `spottedOld` perception fallback, and raw location-path control
- [x] demonstrate owner-side target/path retention, pursuit, and attack-state entry
- [x] establish that no further `spottedOld(...)` or raw location-path control is needed once Phase A progresses
- [x] validate server-authoritative impact health reduction on the server and establish that it does not update client zombie health directly
- [x] validate lethal death/corpse replication through the normal server death lifecycle
- [x] validate Friendly and Hostile at the diagnostic policy gate; confirm Neutral uses the same suppression branch without a separate runtime run
- [x] trace the bounded attack, server damage, death/corpse, and MP synchronization path
- [x] establish that vanilla discovery and mind synchronization are player-only at the required seams
- [x] validate v0.0.11 native `spottedNew` acquisition entry versus the proven direct target/path control
- [x] validate v0.0.12 owner-mediated nonlethal health synchronization and lethal server finalization
- [x] validate the v0.0.13 bounded spatial candidate scheduler and reciprocal/crowd grants
- [x] validate v0.0.14 direct Vanilla enrollment, immutable identity guards, corrected timing, and location-path networking mitigation
- [x] validate that v0.0.15 traversal polling suppresses zero-vector failures but cannot close the fence-animation race
- [x] validate v0.0.16 targetless pursuit and crash avoidance; identify client diagnostic polling/logging as the stress bottleneck
- [x] close SPIKE-001 after v0.0.24 validates stable timed melee without invalid bump states, sustained synchronized damage, bounded packets, and crowd operation at mob size `1`
- [x] validate size-8 stable membership, leader-only faction discovery, distributed member targets, bounded packet flow, and sustained synchronized damage
- [ ] restore event-driven recovery for a dormant member while another member keeps the mob active ([#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2))
- [ ] reduce distance-rejected faction impact requests without weakening server validation ([#1](https://github.com/jonathanjacobs/pz-zombie-factions/issues/1))
- [ ] validate the explicit Red/Blue/Vanilla relationship matrix so expected Neutral pairs are distinguishable from failed retaliation
- [ ] profile client FPS and server load at mob size `8` before testing unlimited mobs
- [ ] validate ownership reacquisition with a real owner transfer
- [x] determine that the validated diagnostic mechanism is feasible without a deeper engine hook and record the authority split in ADR-001
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
