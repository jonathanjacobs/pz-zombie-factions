# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Closed — successful on 2026-08-30 with v0.0.24
Target: Project Zomboid Build 42.20.x

## Question

Can Zombie Factions enforce directional faction relationships at a clean target-eligibility boundary, and can a vanilla `IsoZombie` reliably pursue, attack, damage, and kill another `IsoZombie` in Build 42 multiplayer?

## Evidence boundary

Use Build 42 API documentation, controlled runtime tests/logs, and the privately supplied decompiled Build 42 source as implementation research. Decompiled game source is not copied into this repository.

Do not claim zombie-vs-zombie combat until target acquisition, pursuit, attack, damage, death, and dedicated-server synchronization are all demonstrated.

## Relevant public API surface

Current Build 42 JavaDocs expose:

- `IsoZombie.setTarget(IsoMovingObject)` / `getTarget()`;
- `IsoZombie.spotted(...)`, `spottedNew(...)`, and `spottedOld(...)`;
- `IsoZombie.pathToCharacter(IsoGameCharacter)`;
- `IsoZombie.pathToLocationF(float, float, float)`;
- `IsoZombie.isZombieAttacking(IsoMovingObject)`;
- `IsoZombie.getOnlineID()`, `getOwnerPlayer()`, `isRemoteZombie()`, and `getRealState()`.

These signatures permit another `IsoZombie` to be passed at the type level. They do not prove that downstream AI state transitions or multiplayer combat packets support zombie-to-zombie combat.

A public Build 42.17 Indie Stone bug report documents a `spottedNew(...)` player-null defect when the argument is an `IsoZombie` and a vehicle obstructs view. v0.0.7 conservatively avoided that path. Inspection of the privately supplied Build 42.20.x source shows the relevant player-only dereferences are now guarded and the vehicle branch uses the generic `IsoGameCharacter`. v0.0.11 therefore tests `spottedNew(candidate, false)` only for one server-authorized same-floor pair, inside `pcall`, in a clean no-vehicle setup. The routine remains player-oriented and is not itself a production candidate hook.

Current multiplayer API documentation is also a warning sign for the later damage stage: `GameClient.sendZombieHit(...)` takes an `IsoPlayer` target, and the documented packet enum contains `ZombieHitPlayer` but no corresponding `ZombieHitZombie` entry. Treat this as strong evidence that native zombie-vs-zombie damage networking may require a custom server-authoritative path, not as proof until the pursuit/attack layers are tested.

## Harness validated through v0.0.5

The admin Horde Spawning extension is working on a Build 42.20.4 dedicated server/client pair:

- Vanilla spawning still uses the stock path;
- Test Red / Test Blue custom spawns reach the Zombie Factions server command;
- asymmetric and symmetric relationship values are transported correctly;
- 1-zombie and 10-zombie custom requests succeeded;
- custom assignment is applied to the exact `IsoZombie` returned by `addZombiesInOutfit(...)`.

The one-time nearest-Vanilla lookup used by the SPIKE is diagnostic only. It is not the production targeting design.

## v0.0.6 result — server target assignment is insufficient

The runtime test exercised many faction/relationship combinations with the target-probe checkbox both enabled and disabled.

### Assignment: PASSED

Server-side faction/test-run metadata resolved correctly immediately and after the delayed validation sample. Representative runs reported the expected faction and run ID with `ok=true`.

This confirms that the observed combat failure is not explained by the custom subject losing its server-side faction assignment during the short test window.

### Forced target/path: FAILED at AI transition

Three valid HOSTILE probe runs are especially diagnostic:

| Run | Subject | Candidate | Distance | Initial force | Result |
| --- | ---: | ---: | ---: | --- | --- |
| `SPIKE001-0009` | 24725 | 24722 | 1.02 | `setTarget=true`, `pathToCharacter=true`, retained | target cleared; remained `idle`; no attack |
| `SPIKE001-0010` | 24732 | 24731 | 0.60 | `setTarget=true`, `pathToCharacter=true`, retained | target cleared; remained `idle`; no attack |
| `SPIKE001-0011` | 24733 | 24728 | 0.43 | `setTarget=true`, `pathToCharacter=true`, retained | target cleared; remained `idle`; no attack |

No subject or candidate died. The target could therefore be stored briefly, but the normal update path removed it before pursuit/attack began.

This narrows the failure boundary to **after direct target assignment but before a durable pursuit/attack transition**.

### Multiplayer ownership remains unresolved

All three forced subjects reported `owner=admin`. The v0.0.6 force was performed on the server even though the zombie was client-owned.

Therefore v0.0.6 does **not** distinguish between:

1. the owning client overwriting a server-injected target;
2. vanilla AI/perception logic rejecting a zombie target;
3. target-specific pathing refusing to transition for another zombie;
4. a required internal perception/alert state not being initialized by `setTarget + pathToCharacter` alone.

The v0.0.6 client observer itself loaded, but the runtime client log contained no `CLIENT_OBSERVER` entries. It depended on the server-assigned SPIKE mod-data tag being visible on the client zombie instance. v0.0.7 removes that dependency and addresses subjects by network online ID instead.

## v0.0.7 experiment — owner-side three-phase boundary probe

The UI remains unchanged: check `SPIKE: force nearest HOSTILE Vanilla zombie target` with `spawned faction -> Vanilla = HOSTILE`.

The server now:

1. waits for the spawned subject to stabilize;
2. finds one nearby living Vanilla candidate within the bounded SPIKE radius;
3. records subject/candidate online IDs and the current zombie owner;
4. sends those IDs to the requesting client;
5. does **not** call `setTarget` itself;
6. passively observes server-visible target/state/attack/death changes.

The requesting client retries a bounded lookup until both online IDs are locally relevant and verifies that the subject's owner is the local player.

### Phase A — owner target/path

On the owning client:

```text
subject:setTarget(candidate)
subject:pathToCharacter(candidate)
```

The client logs target retention, real state, attack state, ownership, `isRemoteZombie`, distance, movement, and death.

### Phase B — owner `spottedOld` + target/path

If Phase A remains idle or loses the target, the owner tests:

```text
subject:spottedOld(candidate, true)
subject:setTarget(candidate)
subject:pathToCharacter(candidate)
```

`spotted()` / `spottedNew()` are intentionally not used because of the documented Build 42 zombie-target defect described above.

If Phase A has already produced a non-idle/attack transition, Phase B is skipped so a successful state is not disturbed.

### Phase C — raw location-path control

If neither target-specific phase produces AI progress or measurable movement, the owner clears the target and calls:

```text
subject:setTarget(nil)
subject:pathToLocationF(candidate:getX(), candidate:getY(), candidate:getZ())
```

This is not a hostility behavior. It is a control that answers a narrower question: **can the same client-owned zombie enter ordinary movement/pathing toward those coordinates when no zombie target is involved?**

Interpretation:

- Phase C moves while A/B do not: generic pathing works; the blocker is target/perception validation specific to zombie targets.
- Phase C also remains idle: ownership or client-side path command semantics remain suspect, and the probe has not yet isolated zombie-target validation.

## How to interpret v0.0.7

- **Owner Phase A succeeds:** v0.0.6 was primarily an MP authority/ownership problem. Continue tracing the owner-driven pursuit into attack state.
- **Phase A fails, Phase B succeeds:** target assignment alone is insufficient; perception state materially changes pursuit behavior. This was the conservative v0.0.7 interpretation before the supplied Build 42.20.x source was inspected.
- **A/B fail, Phase C moves:** strong evidence that B42's target/perception path rejects or fails to activate another zombie even though generic movement works.
- **A/B/C all remain idle:** do not infer target rejection yet; trace ownership/path command authority more deeply.
- **Pursuit works but attack never starts:** the next blocker is attack-state target assumptions.
- **Attack animation/state works but no damage is delivered:** expect a custom server-authoritative zombie-vs-zombie damage path to be necessary, especially given the documented network packet surface.

## v0.0.8 experiment — server-authoritative impact probe

The v0.0.7 dedicated-server result resolved the earlier AI boundary: on the owning client, `setTarget(candidate)` plus `pathToCharacter(candidate)` retained the target and advanced through `walktoward`, `lunge`, `face-target`, and `attack`. `isZombieAttacking(candidate)` became true repeatedly at melee range. The native attack states did not reduce the candidate's health or cause death.

v0.0.8 therefore leaves client ownership responsible only for the bounded diagnostic target/attack observation. On a rising native attack event at a distance of at most 1.25 tiles, the client requests an impact for the exact SPIKE subject/candidate pair. The server accepts a request only when it validates the active run ID, requester ownership, exact online IDs, server-side subject faction, Vanilla candidate faction, `HOSTILE` relationship, distance, cooldown, and liveness. It then calls `IsoGameCharacter.applyDamage(0.25)` on the candidate and returns health-before, health-after, and death status to the requester.

This tests whether server-side health and death changes synchronize in multiplayer without a native zombie-to-zombie hit packet. It is research instrumentation, not the production damage architecture. Native multiplayer mind synchronization still does not retain the client-side zombie target on the server, and client faction lookup cannot rely on zombie `modData` propagation.

Interpretation:

- **Accepted impact lowers health on server and client:** a server-authoritative damage path is viable; continue testing repeated impacts, death, corpse handling, and disconnect/relevance behavior.
- **Accepted impact lowers server health only:** trace replication/death packets before proposing a production path.
- **Request is rejected:** use the bounded rejection reason to correct the test setup or investigate the failed authority/identity invariant.
- **`applyDamage` errors or does not lower server health:** investigate the supported server-side damage/death API before attempting combat implementation.

## v0.0.9 experiment — lethal death-lifecycle replication

The v0.0.8 dedicated-server result accepted four impacts and reduced the server candidate health from `1.00` to `0.00`, but subsequent client observations still reported local candidate health `1.00` and no visible death. Source inspection confirms that `applyDamage(...)` only subtracts health; it does not enter the normal zombie kill/death lifecycle or emit a general zombie-health packet.

When a validated v0.0.9 impact is lethal, the server now attributes the candidate to the SPIKE subject and calls `die()`. This is the engine lifecycle that creates a corpse and emits the relevant `ZombieDeath` packet. The probe logs `deathLifecycleInvoked=true` only when this call completes without a Lua/Java error.

Interpretation:

- **Client received a corpse/death after a lethal impact: PASSED.** Two dedicated-server runs logged `deathLifecycleInvoked=true`, sent matching client results, and later displayed the resulting corpses. Nonlethal health presentation remains a separate open boundary.
- **Server logs `deathLifecycleInvoked=true` but the client sees no corpse:** inspect `ZombieDeath` relevance and packet handling before proposing a production damage path.
- **The death lifecycle errors:** retain the error log and investigate the supported server-side kill API before proceeding.

## v0.0.10 result — explicit relationship gate

The dedicated-server run observed the Friendly control suppressing dispatch and observed Hostile runs dispatching through pursuit, impact, and client-visible death. Neutral was intentionally not rerun: it enters the same `relationship ~= HOSTILE` suppression branch as Friendly, so its result is code-equivalent but inferred rather than separately runtime-observed.

The v0.0.10 gate copied the request relationship into a delayed record and branched before candidate discovery. It therefore established bounded request gating, but it did not exercise current shared-registry policy inside candidate filtering. Overlapping runs could also change the global relationship during that delay. v0.0.11 removes the copied relationship decision.

## Build 42.20.x acquisition and ownership trace

The supplied source identifies two hard seams:

- player LOS processing scans nearby moving objects and calls `IsoZombie.spotted(player, false)`; there is no equivalent zombie-centric candidate enumeration or Lua target-eligibility callback;
- `NetworkZombieMind` stores a character path goal only for `IsoPlayer`, and received zombie target IDs are resolved through the player-ID map. Another zombie target therefore cannot replicate or survive ownership transfer through the native mind path.

`OnZombieUpdate` runs on the owner before the remainder of the zombie update, so it is the narrowest Lua injection point for a bounded experiment. A custom production path would still need scalable candidate discovery and explicit reacquisition after ownership changes.

## v0.0.11 experiment — faction-aware native acquisition entry

The shared policy now exposes:

```text
allowed, sourceFaction, targetFaction, relationship, reason =
    ZombieFactions.canTarget(attacker, candidate)
```

It is directional, O(1), and side-effect-free. Only `HOSTILE` zombie-to-zombie relationships return true. Friendly, Neutral, unset, self, and non-zombie inputs fail closed. Distance, floor, liveness, ownership, and grant authorization remain contextual caller checks.

For one explicitly requested custom subject, the server performs one bounded scan, applies the current `canTarget` result to each living same-floor candidate, reserves the nearest eligible candidate, and grants the exact IDs to the current owner. It also rejects candidates already used by an active probe and zombie IDs that collide with active player IDs.

The owner then runs:

1. **Phase A — native acquisition entry:** up to 30 bounded `spottedNew(candidate, false)` attempts from that subject's `OnZombieUpdate` path, stopping as soon as the candidate becomes the target;
2. **Phase B — proven control:** if Phase A produces no target or AI progress, call `setTarget(candidate) + pathToCharacter(candidate)` once;
3. **Phase C — movement control:** only if the proven target/path control also stalls, clear the target and call `pathToLocationF(...)`.

The server revalidates current `canTarget`, stable ownership, exact object references, same floor, melee distance, cooldown, and liveness for every diagnostic impact. Ownership change revokes the grant; native target persistence is not expected.

### v0.0.11 runtime result

The dedicated-server test selected one eligible Vanilla target and the first owner-side `spottedNew(candidate, false)` call committed it. The subject reached native pursuit and attack states without needing the direct target/path control. One accepted server `applyDamage(0.25)` changed server candidate health from `1.0` to `0.75`; a later target-owner zombie packet restored server health to `1.0`. Acquisition passed, while server-only nonlethal damage synchronization failed.

## v0.0.12 experiment — target-owner damage application

While the native melee-attack state remains active, the attacker's owner requests rate-limited impacts until the target dies or the bounded grant expires. After all existing server checks pass, the server creates a unique hit ID and broadcasts a fixed `0.25` damage instruction addressed to the target zombie's current owner. Only that owner applies `applyDamage(...)` to its local target and returns the observed before/after health. The server accepts only the current target owner and the exact expected decrement, synchronizes health downward, and finalizes a lethal result with the already-validated server `die()` path. One hit may be in flight per grant; owner changes and acknowledgement timeouts fail closed.

Dedicated-server v0.0.12 runs validated the complete damage route multiple times. Accepted owner acknowledgements and server health both descended `1.0 -> 0.75 -> 0.50 -> 0.25 -> 0.0`; lethal hits reported `deathLifecycleInvoked=true` and produced visible deaths. Runs that did not acquire or retain a target produced no hits, separating the remaining acquisition problem from damage synchronization.

## v0.0.13 result — bounded reciprocal and crowd combat

Dedicated-server testing passed the principal v0.0.13 mechanics. A clean mutual-hostility run granted Red-to-Vanilla and reciprocal Vanilla-to-Red pairs; both subjects attacked, owner-mediated health updates were accepted, and the Vanilla subject killed the Red subject. Three crowd runs produced 155 grants, 160 accepted server impacts, and 37 lethal results while the scan budget never exceeded four subjects in a server frame.

The same logs exposed three follow-up defects:

- the server tick was approximately 10 Hz, making the configured 60-tick scan interval about six seconds and the 1,800-tick lifetime about three minutes rather than the documented one second and 30 seconds;
- Vanilla zombies spawned through the stock path were not directly enrolled, so only a selected reciprocal candidate joined immediately and other Vanilla zombies could appear idle until later reacquisition;
- one pooled Java zombie object changed from its original online ID to `-1` and later represented a new zombie, allowing a stale pending record to attach to the wrong spawn.

The client also logged repeated `NetworkZombieMind: goal character is not set`. Decompiled Build 42.20.x code confirms that `NetworkZombieMind.set(...)` accepts `PathFindBehavior2.Goal.Character` only when the target is an `IsoPlayer`; `pathToCharacter(otherZombie)` necessarily enters the error branch. Location goals are explicitly serialized.

## v0.0.14 experiment — direct enrollment and serialized pursuit

v0.0.14 makes these bounded corrections:

1. Vanilla spawns made while the SPIKE checkbox remains enabled use the diagnostic server path and every returned zombie is queued directly;
2. Vanilla spawns with the checkbox disabled still use the unmodified Horde Spawning path;
3. pending and active records retain their enrollment-time subject/candidate online IDs and fail closed if a pooled object changes identity;
4. discovery retries every 10 server ticks (about one second), the shared index refreshes every five ticks, and a run lasts 600 server ticks (about 60 seconds);
5. grant lifetime is transmitted in seconds and converted to the client's approximately 60 Hz clock;
6. the owner retains `setTarget(candidate)` but pursues the candidate's refreshed coordinates with `pathToLocationF(...)`, avoiding the unsupported zombie character-path serialization form;
7. the existing four-scan budget, shared targets, owner-only instructions, and validated damage/death route remain unchanged.

This remains explicit SPIKE instrumentation. It does not enroll naturally spawned zombies or claim production-scale performance.

## v0.0.14 runtime procedure

Use a quiet open same-floor area with no vehicle between the zombies. Put the admin in invisible/ghost mode if available, or move the admin away immediately after spawning so the custom subject does not prefer the player.

1. Remove existing loaded zombies and use Number of Zombies = 1 with Radius = 0.
2. Select Test Red, set `Spawned faction -> Vanilla = HOSTILE`, set `Vanilla -> spawned faction = HOSTILE`, and leave Symmetric checked.
3. Check `SPIKE: test bounded faction acquisition/reacquisition`.
4. Spawn the Red zombie first in an open area.
5. Wait about 3 seconds, switch to Vanilla, **leave the SPIKE checkbox checked**, and spawn one Vanilla zombie 2–4 tiles away.
6. Move the admin away and leave both zombies undisturbed for up to 60 seconds.
7. Save client and server logs. This focused run validates direct Vanilla enrollment and the new serialized location-path control before another crowd run.

Useful v0.0.14 markers are:

```text
[SPIKE001-<run>] spawned=1 ... faction=zf:vanilla ... targetProbeSubjects=1
[ACQUISITION_PROBE] phase=no-eligible-candidate ... retryInTicks=10
[ACQUISITION_PROBE] phase=scan ... eligible=1 ... selected=<candidate>
[ACQUISITION_PROBE] phase=grant reason=acquired
[ACQUISITION_PROBE] phase=reciprocal ... queued=true
[ACQUISITION_PROBE] phase=grant reason=reciprocal
[ACQUISITION_PROBE] phase=instruction
[ACQUISITION_PROBE] phase=owner-spottedNew ... committed=true|false
[OWNER_PROBE] resolved
[OWNER_PROBE] phase=owner-target-path-control ... pathToLocationF=true
[OWNER_PROBE] phase=owner-reacquire-control
[OWNER_PROBE] phase=owner-path-refresh
[CLIENT_OBSERVER]
[SERVER_OBSERVER]
[IMPACT_PROBE]
[DAMAGE_PROBE] phase=dispatch ... targetOwner=<owner>
[OWNER_DAMAGE] phase=ack ... beforeHealth=1.0 afterHealth=0.75
[OWNER_DAMAGE] phase=accepted ... serverAfterHealth=0.75
[IMPACT_RESULT]
[OWNER_DAMAGE] phase=accepted ... lethal=true deathLifecycleInvoked=true
```

Interpretation:

- `owner-spottedNew ... committed=true` followed by the direct control being skipped means the native perception entry accepted the authorized zombie candidate.
- The Vanilla spawn summary must report `faction=zf:vanilla` and `targetProbeSubjects=1`; otherwise direct enrollment failed.
- If native spotting remains uncommitted but `owner-target-path-control ... pathToLocationF=true` produces pursuit and attack, the serialized location-path mitigation passed.
- `phase=reciprocal ... queued=true` followed by a reciprocal grant demonstrates that the reverse Hostile relationship entered the same server-authorized path.
- `phase=owner-transition ... action=wait` followed by `action=regrant` and a new instruction demonstrates ownership reacquisition without a rescan or per-tick packets.
- If the exact target is cleared, `owner-reacquire-control` should restore the target and refresh a location path without clearing it.
- Four accepted owner-damage hits should show both owner and server health descending `1.0 -> 0.75 -> 0.50 -> 0.25 -> 0.0`, followed by `deathLifecycleInvoked=true` and a visible corpse.
- `phase=timeout`, `target-owner-unavailable`, or `target-owner-mismatch` means the owner-routing portion failed; do not treat that as a damage result.

A `resolve-timeout` is itself useful: it means the server-selected subject/candidate or ownership identity was not resolvable on the requesting client during the bounded window.

The client log should contain no new `NetworkZombieMind: goal character is not set` entries during this isolated test. Any such entry means another game path is still installing a zombie character goal and must be correlated by timestamp before scaling the test.

## v0.0.14 stress result and v0.0.15 safety experiment

The v0.0.14 test passed direct Vanilla enrollment, immutable-ID cleanup, location-goal pursuit, owner-mediated damage, and lethal replication. No new `NetworkZombieMind: goal character is not set` entries were found. The user then intentionally increased multiple factions until the server reported roughly 410 loaded zombies and three overlapping capped SPIKE runs were active.

At 10:23:23.645 the client logged a caught `LungeState` exception because its forward direction was a zero-length vector. Eight milliseconds later, `ClimbOverFenceState.OnAnimEvent_CheckAttack` called `IsoGameCharacter.attackFromWindowsLunge(...)` on a zombie target. That player-oriented method dereferenced `getMoodles()` and threw a fatal `NullPointerException`. The client connection log subsequently recorded `force-disconnect message="crash"`; there was no anti-cheat, kick, validation, or server-timeout marker. The server continued processing and the v0.0.14 identity guards dropped records whose owner-side zombies became unaddressable.

v0.0.15 adds a local safety interlock on the owning client:

1. before native spotting or direct target/path control, and during every tracked update, inspect both participants' real-state names;
2. if either state contains climb, fence, window, or vault, a lunge reports a zero `distancetotarget` animation variable, or planar distance is below 0.10 tile, clear only the exact authorized target and mark the pair suspended;
3. while suspended, do not spot, refresh paths, or request diagnostic impacts;
4. after both states and spacing become safe, clear the suspension and allow the normal bounded acquisition path to resume;
5. log only `phase=safety-suspend` and `phase=safety-resume` transitions. No safety packet is sent.

Validate this first with a small obstacle case, not another 400-zombie run:

1. spawn one mutually Hostile Red/Vanilla pair with the SPIKE checkbox enabled;
2. place or lead them near a fence so one enters `climbfence` while the grant is active;
3. confirm `phase=safety-suspend ... targetCleared=true` appears and neither engine exception occurs;
4. after traversal completes, confirm `phase=safety-resume` followed by target reacquisition and ordinary impacts;
5. repeat in an open area with a modest crowd of 20–40 zombies and confirm `close-overlap` suspensions do not crash or permanently stall unrelated pairs.

## v0.0.15 retest result and v0.0.16 control-path experiment

The second v0.0.15 stress test confirmed that the safety interlock was active: ten traversal suspensions and six resumes were logged, and the earlier `LungeState` zero-vector exception did not recur. Combat remained active through 518 accepted hits and 106 lethal results. The client nevertheless crashed at roughly 237 loaded zombies when `ClimbOverFenceState.OnAnimEvent_CheckAttack` called the player-specific `attackFromWindowsLunge(...)` method while a zombie target was attached. The server only observed the resulting crash disconnect and continued normally; this was not anti-cheat or server overload.

Polling the real state cannot close the interval between a state transition and its animation event, so v0.0.16 removes zombie target attachment from travel entirely:

1. the owning client clears any zombie target and pursues the current authorized candidate with `pathToLocationF(...)` coordinates only;
2. `spottedNew(otherZombie, false)` is no longer called, avoiding its unsupported character-goal path and the associated `NetworkZombieMind: goal character is not set` errors;
3. the coordinate path is cancelled and the exact candidate is attached as a target only at most 1.20 tiles away, when the two zombies occupy the same or adjacent squares on one floor and no wall, window, blocked door, or hoppable boundary separates those squares;
4. if separation exceeds 1.35 tiles or the local boundary becomes obstructed, the zombie target is cleared before coordinate pursuit resumes;
5. an existing player target is not overwritten: faction control pauses for that subject until the player target clears;
6. the v0.0.15 traversal/overlap interlock remains as a secondary fail-closed guard and now clears any zombie target rather than only the originally granted candidate.

The first v0.0.16 validation should be a controlled obstacle test, not another stress test:

1. verify the client and server both load `v0.0.16`;
2. spawn one mutually Hostile Red/Vanilla pair with the SPIKE checkbox enabled on opposite sides of a fence;
3. confirm `phase=coordinate-pursuit ... targetClear=true` during approach and traversal, with no `melee-engagement` until they share a clear melee boundary;
4. after traversal, confirm `phase=melee-engagement`, ordinary attack/impact records, damage, and death;
5. confirm there is no `attackFromWindowsLunge` exception and no new `NetworkZombieMind: goal character is not set` entry before scaling to 20–40 zombies.

## v0.0.16 stress result and v0.0.17 performance experiment

The v0.0.16 stress test passed its primary safety objective. No `attackFromWindowsLunge` exception, zero-vector exception, zombie-mind character-goal error, crash, kick, or timeout occurred; the client exited normally. The server maintained approximately 9.97 ticks per second and saved normally even though its loaded-zombie list peaked at 1,143.

The diagnostic harness itself did not scale on the owner client. The retained client log contained more than 20,000 faction records, including roughly 7,700 records in one ten-second interval. Two overlapping runs could each enroll 64 subjects, two independent `OnZombieUpdate` listeners polled controlled subjects, obstacle checks ran outside melee range, pending grants repeatedly scanned the full client zombie list, and the attack flag frequently alternated every frame and triggered another formatted observer record. The final Red/Vanilla runs also produced 247 distance-rejected impact requests and substantial grant/release churn after shared candidates died.

v0.0.17 makes the diagnostic control path explicitly time-sliced:

1. one shared client scheduler invokes targeting and impact controllers every six client ticks and only for tracked subjects;
2. one lazy online-ID index resolves all pending grants in a controller pass;
3. detailed subject logging is disabled by default; client and server each emit one aggregate performance record every five seconds while probes are active;
4. obstacle checks occur only within the engagement envelope and are cached until either square changes;
5. pursuit refresh occurs after at least 0.75 tile of candidate movement or a five-second fallback;
6. damage requires the exact retained target, at most 0.90 tile client distance, and two consecutive stable melee samples before a request; requests are limited to once per second;
7. enrollment is bounded across overlapping runs to 64 subjects per requester and 32 per source faction, reserving room for two hostile sides without allowing two horde actions to create 128 controllers;
8. a lost exact target no longer remains falsely marked as engaged; clear melee conditions trigger explicit reattachment.

Validate v0.0.17 with an A/B-style progression:

1. confirm all client/server component markers report `v0.0.17`;
2. spawn 20 Red and 20 Vanilla with mutual Hostile policy and confirm both sides engage, damage, and die;
3. record the five-second `[PERF]` and `[SERVER_PERF]` summaries and observed client FPS;
4. then spawn 100 Red and 100 Vanilla; confirm the spawn summaries enroll at most 32 from each faction and the client summary never exceeds 64 tracked targets;
5. compare FPS against v0.0.16 and verify that `damageRejected` remains low relative to `damageDispatched`;
6. stop before adding more zombies if FPS remains unplayable—the remaining cost would then be native path/animation work rather than diagnostic logging and per-frame Lua polling.

## v0.0.18 shared-target mob experiment

v0.0.18 replaces duplicate discovery within a local faction crowd with a mob lease. The first due same-faction subject that finds a hostile candidate is the leader. Nearby pending members inherit that exact candidate without executing `findNearestEligibleZombie(...)`; they still receive individual owner-targeted grants because simulation ownership can differ between zombies. The Sandbox Admin option **Zombie Mob Size** includes the leader: `1` is individual acquisition, a positive value caps the local mob, and `0` admits every eligible nearby member. Membership uses the 12-tile leader radius and the existing 18-tile candidate-retention bound. Shared targets remain allowed.

The temporary v0.0.17 enrollment caps are removed for this experiment so the mob-size setting controls participation. On candidate death, followers wait one scan interval while the leader retries promptly; if the leader remains available, its next successful scan repopulates the waiting mob before the followers become due.

Validate with the same Red/Vanilla crowd at mob sizes `1`, `8`, and `0`. For each value, capture client FPS plus `[SERVER_PERF]`. A useful result shows `sharedAssignments > 0` for `8` and `0`, materially fewer `scans` than grants, continued deaths on both hostile sides, and no proportional rise in command traffic beyond one state-change grant per admitted member.

## v0.0.18 result and v0.0.19 crowd-control experiment

The size-8 v0.0.18 test validated shared discovery: 296 leaders produced 837 inherited assignments and 1,133 grants, while 362 dispatched damage events were accepted. No crash or kick occurred. At high density, however, nearest-only leader selection and exact-center coordinate pursuit caused multiple mobs to collapse onto the same candidates. Roughly 265 active leases then produced no damage requests for repeated five-second intervals; the owner client reported thousands of target reattachments and no-exact-target samples before lease expiration released the crowd. `NetworkZombieMind: goal character is not set` also reappeared during the dense phase.

v0.0.19 keeps shared targets legal but adds three escape mechanisms: active assignments softly penalize candidate score, deterministic inner/outer ring positions spread approach destinations, and a subject with neither meaningful distance progress nor native attack progress for a staggered five-to-seven-second interval requests one owner-authenticated reassignment. The previous candidate is strongly deprioritized for that replacement scan when alternatives exist. Exact-target attachment retries are limited to twice per second, bounding unsupported target writes when Build 42 clears a zombie target.

## v0.0.20 persistent-hostility experiment

v0.0.20 removes the inherited 60-second expiration from target and impact grants. Grants carry an explicit persistent-lifetime flag and continue until an event invalidates them: death, pooled-object identity reuse, ownership loss, invalid policy, level or distance separation, explicit release, or no-progress reassignment. Acknowledgement timeouts, damage cooldowns, scan budgets, and reacquisition backoff remain bounded because they constrain individual operations rather than ending faction hostility.

## v0.0.21 stable-mob experiment

v0.0.21 replaces temporary mob leases with stable server-runtime membership. Recruitment occurs once, uses the vanilla Rally Travel Distance, and respects **Zombie Mob Size**. Each mob contributes at most one pending discovery leader; followers remain dormant until a leader shares a target. If a dormant member is targeted or damaged by a mutually hostile zombie, the known attacker wakes that member's mob without requiring every follower to scan. Leadership is re-elected when the current leader dies, becomes unavailable, or leaves the local mob center. Individual owner grants remain necessary after wake-up, but discovery itself sends no client packets; follower grants are drained from one shared queue at no more than eight per server tick.

Test with mob size `8`. Spawn 20 Red first and wait five seconds with no hostile candidates, then spawn 20 mutually hostile Vanilla zombies. Let combat run for at least 90 seconds. In `[SERVER_PERF]`, confirm `mobMembers` is near the enrolled population, `pendingLeaders` and `leaderScans` track mobs rather than zombies, and `dormant` is high before contact. Confirm both factions respond, `reactiveWakeups` becomes nonzero, deaths continue after 60 seconds, and grants do not rise continuously while targets remain unchanged. For a controlled leader-replacement check, create a separate mob by spawning one Red at a recognizable point and then seven Red nearby; kill or remove that original zombie and confirm `leaderChanges` increments before the remaining members later reacquire. Only then repeat at 80 Red/80 Vanilla; do not test unlimited mobs until size `8` remains healthy.

## v0.0.22 distributed-member experiment

The v0.0.21 crowd run produced 1,597 instances of `attempted index: getPathFindBehavior2 of non-table: null`. The engagement-backoff branch used an undefined local name when cancelling coordinate pursuit; v0.0.22 passes the tracked zombie and also guards path cancellation against a missing subject or path behavior.

The same run showed that leader-only discovery succeeded but one-candidate sharing still collapsed mobs into dense piles. v0.0.22 retains one recurring scanner per mob. A successful leader scan establishes the enemy faction, then each member performs one local, load-aware selection from the cached spatial index against that faction. This is an activation-time assignment pass, not a recurring follower scan. Death and no-progress events can similarly trigger one member-local replacement selection.

Retest first with mob size `8` and 20 Red against 20 mutually hostile Vanilla. Confirm there are no `getPathFindBehavior2` errors or red error boxes, visible combat spreads across multiple opponents, and deaths continue for at least 90 seconds. In `[SERVER_PERF]`, expect `leaderScans` to track mobs, `memberSelections` and `distributedAssignments` to rise on contact, `memberRetargets` to rise only after death or no-progress events, and accepted damage to continue without sustained high `stuckReacquires`. Do not increase the crowd until this controlled run passes.

## v0.0.23 explicit-melee experiment

The v0.0.22 stress run reached 203 enrolled zombies without a mod exception and initially distributed 25 of 31 follower assignments away from the leader's target. It nevertheless produced 1,172 no-progress reacquisitions and only 100 accepted impacts. Late client summaries exceeded 5,000 `impactNoExactTarget` samples per five seconds while server damage stayed at zero. Discovery was functioning; the two-update exact-target requirement was starving melee after vanilla cleared zombie targets in the crowd.

v0.0.23 makes targeting order deterministic and treats a clear authorized pair within 0.90 tile as a sticky melee commitment. The owner starts a staggered bite cycle and requests the existing server-validated impact at its hit point without treating the native target field as authoritative. The server still validates the exact active grant, policy, ownership, identity, level, distance, cooldown, and liveness before routing damage. Each attacker remains limited to one request per second, and each owner client may issue at most four requests per 10 Hz controller pass.

Test with mob size `8`, 20 Red, and 20 mutually hostile Vanilla before another stress run. Spawn each side with radius `3` to `4`, separated by several tiles, and observe for at least 90 seconds. Confirm visible bite motions, sustained deaths, no red errors, and substantially fewer `stuckReacquires`. Client metrics should show `meleeCommitments`, `customAttackStarts`, and `customAttackHits`; `impactAuthorizedWithoutExact` may be high by design, while `impactNoAuthorization` should primarily represent subjects still approaching. Server `damageAccepted` should remain nonzero after the initial contact rather than falling into repeated zero-damage intervals.

## v0.0.24 invalid-bump recovery experiment

The v0.0.23 crowd run was less clumped and produced 284 owner impact requests and 219 server-accepted damage events without a Zombie Factions runtime exception. It also left many zombies frozen with outstretched arms. The client had used `setBumpType("Bite")` and `setBumpType("BiteLow")` as if the field selected an attack animation. Build 42's zombie animation graph instead recognizes bump types as collision reactions; neither supplied value had a matching node to emit `BumpAnimFinished`, so the bumped action could remain latched.

v0.0.24 removes the bump write and leaves the proven staggered timing and damage route intact. While an enrolled zombie is locally controlled, a compatibility guard checks for exactly the two invalid values from v0.0.23, marks the bump animation complete, clears the value, and increments `invalidAttackBumpsRecovered`. It does not clear `left`, `right`, `stagger`, `trippingFromSprint`, or any other vanilla state. The test no longer expects a forced bite visual; attack presentation remains a separate unresolved concern.

Retest with mob size `8`, 20 Red, and 20 mutually hostile Vanilla, spawned at radius `3` to `4`. Observe for at least 90 seconds. Confirm zombies continue moving after close-range impacts, no one remains indefinitely frozen with outstretched arms, deaths continue, and no red errors occur. Capture client `[PERF]` and server `[SERVER_PERF]`; `customAttackHits` and `damageAccepted` should remain active, while `invalidAttackBumpsRecovered` should normally be zero after a clean restart and may be nonzero only when recovering a live state created by v0.0.23.

## Final diagnostic harness flow

The validated admin harness extends Build 42's `ISSpawnHordeUI`. Vanilla spawning remains on its original path unless the SPIKE checkbox is enabled; opt-in Vanilla and custom diagnostic factions use a namespaced client/server command gated by `Capability.CreateHorde`.

The server:

1. validates the diagnostic faction and directional relationships;
2. calls `addZombiesInOutfit(...)` and assigns the exact returned zombie;
3. records a bounded `SPIKE001-####` run ID and performs immediate and delayed assignment verification;
4. recruits each requested subject once into a stable local mob;
5. queues only the elected leader and uses a shared spatial index plus a per-tick budget to select a `canTarget`-eligible hostile faction;
6. makes one bounded, load-aware candidate selection for each waking member;
7. dispatches exact subject/candidate online IDs only to the subject's current owner;
8. regrants after ownership changes and wakes or requeues the stable mob after candidate invalidation;
9. observes server-visible target, state, impact, and death transitions through aggregate diagnostics.

The owning client resolves the exact online IDs with bounded retries, confirms local ownership, and maintains coordinate pursuit plus close-range engagement for the authorized pair. An authorized hit requests server validation; the server routes a fixed nonlethal decrement only to the target zombie's current owner, verifies the acknowledgement, and finalizes lethal death. This avoids relying on client propagation of SPIKE `modData` to identify a diagnostic subject.

## Closeout result

**Answer: yes, directional zombie-faction hostility and synchronized zombie-on-zombie combat are feasible in Build 42.20.x, but not through the complete vanilla player-target combat path.**

The validated boundary is:

1. the server owns faction identity, directional relationship policy, candidate eligibility, stable runtime mob membership, target grants, and impact validation;
2. the current owner client performs bounded pursuit and close-range engagement control because a server-injected target is not durable for a client-owned zombie;
3. vanilla zombie AI can visibly pursue and enter attack behavior against another zombie, but its native attack path does not reliably damage that zombie in multiplayer;
4. an authorized attacker owner requests an impact, the server revalidates the exact grant and combat geometry, and the target owner applies a uniquely identified nonlethal health decrement;
5. the server verifies the acknowledgement, prevents health increases, and finalizes lethal death through the normal server death/corpse lifecycle.

The final v0.0.24 dedicated-server run recorded 43 five-second client summaries and 44 server summaries. It reached 142 enrolled zombies and 137 simultaneously active assignments, issued 734 client impact requests, and accepted 496 server-validated damage events. Damage remained active late in the run. Only three impact requests were deferred by the per-pass budget, and no Zombie Factions exception, kick, disconnect, or invalid attack-bump recovery occurred. The clean `invalidAttackBumpsRecovered=0` result supports the v0.0.24 correction: after removing the unsupported bump-type write, the reported frozen outstretched-arm state did not recur.

Across the spike, controlled tests also established faction assignment, hostile acquisition, owner-side pursuit, attack-state entry, nonlethal synchronization, lethal death/corpse replication, Friendly suppression, and dedicated server/client synchronization. Neutral was not rerun independently; it uses the same policy-suppression branch as Friendly and is accepted on that code-path evidence.

This closes feasibility, not production readiness. The final run used effective mob size `1`, as shown by `mobs == mobMembers`; multi-member leader/follower behavior, unlimited-mob scaling, real ownership transfer, save/restart persistence, automatic production enrollment, and a proper attack presentation remain follow-on work. Distance validation rejected 241 of 737 server damage requests, so tightening impact timing or geometry is also a performance optimization candidate rather than a feasibility blocker.

## Post-closeout size-8 validation

A subsequent v0.0.24 run exercised stable mobs with `ZombieMobSize=8`. It recorded 160 recruits, reached 13 mobs with 100 simultaneous members, performed 130 leader scans and 388 bounded member selections, issued 113 distributed assignments, and completed 15 leader changes. Combat produced 353 server damage requests, of which 237 were accepted. All 116 rejections were distance checks; the client reported no impact-budget deferrals or invalid-bump recoveries, and no Zombie Factions exception or kick occurred.

Representative late summaries showed 89 members, 84 active assignments, five dormant members, and no pending leaders or wakeups. Because the run did not explicitly make every Red/Blue/Vanilla direction Hostile, a visually idle pair may have been policy-correct. Explicit relationship-matrix validation remains necessary. The active-mob guard may also strand an individual dormant member when another member remains engaged; that recovery invariant is tracked in [#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2). Avoidable distance-rejected impact traffic is tracked separately in [#1](https://github.com/jonathanjacobs/pz-zombie-factions/issues/1).

## Acceptance criteria

Zombie-to-zombie hostility is not supported until a controlled hostile 1v1 demonstrates that one test zombie can:

1. resolve the expected faction identity;
2. acquire the intended opposing zombie through the eventual faction-aware path;
3. retain the target;
4. pursue it;
5. enter an attack state;
6. apply damage;
7. disengage or kill the target correctly;
8. synchronize correctly on a dedicated server/client pair.

Friendly and Neutral controls must then show that the same nearby candidate is not proactively attacked when policy prohibits it.

## Performance / architecture guardrails

- relationship lookup should remain O(1);
- no recurring all-zombie-vs-all-zombie scan;
- no per-tick repeated `setTarget(nil)` suppression loop;
- bounded diagnostic scans are permitted only for explicitly requested SPIKE runs;
- multiplayer world-changing damage must ultimately be server-authoritative.

## Deliverable

The target/AI/combat boundaries, viable Lua hook surface, multiplayer authority model, damage/death synchronization route, and performance implications are recorded above. The accepted architectural decision is documented in [`ADR-001-zombie-combat-authority.md`](../adr/ADR-001-zombie-combat-authority.md).
