# Zombie Factions

**A Project Zomboid Build 42 framework for assigning zombies to factions and defining directional Friendly, Neutral, and Hostile relationships between zombie factions and player factions.**

Status: **Research / Pre-Alpha**  
Current version: **v0.0.24**
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

Version 0.0.24 contains the diagnostic harness that successfully closed SPIKE-001. The built-in admin Horde Spawning window is extended with `zf:test-red` / `zf:test-blue` selections, directional relationship controls to `zf:vanilla`, and an opt-in acquisition/reacquisition and impact/death probe. Any Red, Blue, or Vanilla spawn made with the SPIKE checkbox enabled uses the server-authorized harness and requires the same `CreateHorde` capability used by vanilla horde spawning. Vanilla spawning without the checkbox remains on the stock path.

Dedicated Build 42.20.4 testing has established these boundaries:

- custom faction/test-run assignment resolves correctly immediately and again after a delayed server check;
- server-side `IsoZombie:setTarget(otherZombie)` plus `pathToCharacter(otherZombie)` is insufficient for client-owned subjects, but the same calls on the owning client retain the target and reach native pursuit and attack states;
- native zombie-on-zombie attack states do not change the candidate's health or cause death;
- a bounded server-authoritative impact can enter the normal zombie death lifecycle, and the resulting corpse replicated to the client;
- an owner-only `spottedNew` acquisition committed the granted zombie target, but a server-only nonlethal health change was later replaced by the target owner's normal zombie state packet;
- v0.0.12 owner-mediated damage successfully synchronized four fixed hits and a lethal server-finalized death on multiple dedicated-server runs;
- the v0.0.10 gate suppressed a Friendly run and dispatched Hostile runs that produced deaths; Neutral uses the same suppression branch but was intentionally not rerun.
- v0.0.13 reciprocal and crowd runs produced repeated grants, synchronized impacts, and visible deaths under the four-scans-per-tick budget; delayed or absent participation by newly spawned Vanilla zombies exposed an enrollment and scheduler-timing issue rather than a failure of the validated damage route.
- a v0.0.14 high-density run reached roughly 410 loaded zombies before Build 42's player-specific fence-lunge code crashed the client on a zombie target; this was not an anti-cheat kick or server timeout.
- a v0.0.15 retest confirmed its traversal interlock was active and prevented the earlier zero-vector failure, but polling still could not guarantee that a zombie target was detached before a fence animation event; v0.0.16 therefore keeps zombie targets detached throughout travel.
- v0.0.16 prevented the prior crash, but its diagnostic per-zombie callbacks and high-volume state logging caused severe client slowdown under overlapping 100-zombie runs while the server remained at its normal tick rate.

The shared `canTarget(attacker, candidate)` policy resolves directional zombie-faction eligibility without changing AI state. When the SPIKE checkbox is enabled, every spawned diagnostic subject—including Vanilla subjects—is enrolled. Due scans share a short-lived spatial index, process at most four leaders per server tick, and retry once per second while a subject lacks a candidate. The server grants the nearest eligible same-floor zombie; mutual hostility can enqueue the reverse side, and multiple attackers may share a target. Pending and active records are pinned to their original network online IDs so pooled zombie objects cannot silently become a different combatant.

The owning client uses two explicit modes in v0.0.16. During pursuit it clears any zombie target and follows only refreshed `pathToLocationF` coordinates. It cancels that coordinate path and attaches the exact server-authorized candidate only within a clear melee envelope: no farther than 1.20 tiles, on the same or an adjacent square and without an intervening wall, window, blocked door, or hoppable boundary. It clears the target before resuming pursuit beyond 1.35 tiles. No path command runs while a zombie target is attached, and `spottedNew(otherZombie, false)` is no longer used. This avoids both unsupported multiplayer character-goal synchronization and Build 42's player-specific obstacle-lunge path.

The v0.0.15 owner-local traversal/overlap interlock remains as a secondary guard. It now clears any zombie target during an unsafe state, including a stale target assigned in a dense crowd. An existing player target is preserved and faction control pauses instead of overwriting vanilla player aggro. These controls add no network packets.

v0.0.17 runs targeting and impact work through one shared owner-client scheduler every six client ticks instead of registering two `OnZombieUpdate` callbacks. It resolves pending grants through one shared online-ID index, caches melee-boundary checks by square pair, refreshes paths after meaningful target movement or a five-second fallback, and emits aggregate performance counters every five seconds instead of per-subject state logs. Damage requests require two stable close-range samples, the exact retained candidate, and no more than 0.90 tile of client separation.

The native Sandbox Admin setting **Zombie Mob Size** now controls stable local mob membership. Its default of `1` preserves individual acquisition. Above `1`, a zombie is recruited once into a nearby same-faction mob with an available slot; `0` removes the local membership cap. Recruitment uses vanilla `ZombieConfig.RallyTravelDistance`. Only the elected leader performs recurring discovery, while followers remain dormant until the mob receives a target. A member being targeted or damaged can wake its dormant mob with the known attacker. Membership is retained until death, invalid identity, or faction change, and leadership transfers when the current leader becomes unavailable or separates from the mob center. Follower grants are limited to eight per server tick so large or unlimited mobs wake progressively rather than generating one packet and pathfinding burst.

v0.0.19 retains shared targets but prevents nearest-only crowd collapse. Candidate scoring applies a soft penalty for each existing assignment, so a leader prefers a less-contested hostile candidate when the distance tradeoff is reasonable. Each member paths toward a deterministic position on a 0.65/0.90-tile ring around its candidate rather than the exact center. A subject that makes no meaningful distance progress and never enters a native attack for a staggered five-to-seven-second interval sends one validated reacquisition request; the server releases that lease and strongly deprioritizes the stalled candidate for the replacement scan. Exact target reattachment is limited to twice per second.

v0.0.20 removes the original 60-second experiment lifetime. Enrolled hostile behavior and candidate discovery now persist until an event requires release or reassignment, such as death, invalid identity, policy or floor change, excessive separation, ownership change, or detected lack of progress. Packet acknowledgements and other individual operations retain short safety timeouts; those no longer terminate the underlying hostile behavior.

v0.0.21 separates persistent hostility from per-zombie discovery. Stable server-side mob records keep permanent runtime membership, one leader in the pending discovery scheduler, and dormant followers with no targeting record. Successful leader discovery activates eligible nearby members; owner-targeted grants remain one-time state changes rather than scan traffic. Server restarts reconstruct membership when diagnostic zombies are enrolled again; save-persistent mob identity remains outside this spike.

v0.0.22 keeps leader-only hostile-faction discovery but no longer sends every member after the leader's exact candidate. On contact, each member performs one local selection against the shared server spatial index, constrained to the enemy faction the leader detected and softly balanced by existing target load. Candidate death and no-progress events trigger one replacement selection for that member rather than a recurring follower scan. The client engagement-backoff path now cancels the tracked zombie's coordinate path instead of passing an undefined variable, which was the source of the v0.0.21 red-box error storm.

v0.0.24 retains v0.0.23's deterministic targeting order and sticky, staggered melee timing but removes its invalid use of zombie `BumpType` as an attack-animation selector. Build 42 reserves that field for collision reactions; the unsupported `Bite` and `BiteLow` values could leave zombies frozen because no matching animation emitted `BumpAnimFinished`. The client now recovers only those legacy values and reports `invalidAttackBumpsRecovered`, while authorization, cooldown, packet budget, and server-validated damage remain unchanged. A proper attack presentation is deferred until it can use the native zombie attack lifecycle without passing a zombie through player-only damage assumptions.

When native attack begins at melee range, the attacker's owner requests one server-validated diagnostic impact. The server revalidates the active grant, current ownership, exact objects, current `canTarget` result, same-floor distance, cooldown, and liveness, then routes a uniquely identified fixed-damage instruction to the target zombie's current owner. That owner applies the damage locally and acknowledges its before/after health; the server validates the exact decrement, synchronizes without permitting health increases, and alone invokes the normal death/corpse lifecycle for a lethal result.

This is still research instrumentation, not autonomous production targeting. It runs only for explicit admin SPIKE subjects; the client does not decide faction policy. Zombie Factions still does **not** claim production-ready zombie-vs-zombie combat until automatic enrollment, ownership transfer/reacquisition, the location-path mitigation, presentation, and the full multiplayer chain are validated.

## Project docs

- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative runtime requirements.
- [`docs/DESIGN.md`](docs/DESIGN.md) — implementation strategy and development sequence.
- [`docs/SPIKE-001-zombie-targeting-and-combat-feasibility.md`](docs/SPIKE-001-zombie-targeting-and-combat-feasibility.md) — completed Build 42 targeting/combat feasibility investigation.
- [`docs/ADR-001-zombie-combat-authority.md`](docs/ADR-001-zombie-combat-authority.md) — accepted multiplayer targeting and damage authority model.
- [`COMPLIANCE.md`](COMPLIANCE.md) — Project Zomboid policy, provenance, and release constraints.
- [`CHANGELOG.md`](CHANGELOG.md) — version history.

## Runtime layout

```text
Contents/mods/pz-zombie-factions/
```

Original project source is licensed under Apache License 2.0. Project Zomboid code and assets remain property of The Indie Stone and are not redistributed or relicensed by this repository.

Zombie Factions is an unofficial independent community mod and is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.
