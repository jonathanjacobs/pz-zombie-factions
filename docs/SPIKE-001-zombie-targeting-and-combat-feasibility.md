# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Open — v0.0.6 isolated server-target failure; v0.0.7 tests owner-side target, perception, and raw path boundaries  
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

A public Build 42.17 Indie Stone bug report documents a specific `spottedNew(...)` defect when the argument is an `IsoZombie`: the routine contains player-oriented logic and can dereference missing player state when view is obstructed by a vehicle. Because current B42 exposes both `spottedNew` and `spottedOld`, the SPIKE avoids `spotted()`/`spottedNew()` with zombie targets. `spottedOld(...)` is used only as a bounded diagnostic to test whether perception state is a missing gate; it is not proposed as the production acquisition path.

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
- **Phase A fails, Phase B succeeds:** target assignment alone is insufficient; perception state materially changes pursuit behavior. The production path still must avoid the known `spottedNew` zombie-target defect.
- **A/B fail, Phase C moves:** strong evidence that B42's target/perception path rejects or fails to activate another zombie even though generic movement works.
- **A/B/C all remain idle:** do not infer target rejection yet; trace ownership/path command authority more deeply.
- **Pursuit works but attack never starts:** the next blocker is attack-state target assumptions.
- **Attack animation/state works but no damage is delivered:** expect a custom server-authoritative zombie-vs-zombie damage path to be necessary, especially given the documented network packet surface.

## Runtime procedure

Use a quiet open area with the admin not acting as an attractive combat target.

1. Spawn one Vanilla zombie using the normal Horde Manager path.
2. Place the custom spawn point roughly 1–5 tiles away.
3. Set Number of Zombies = 1 and Radius = 0.
4. Select Test Red or Test Blue.
5. Set `Spawned faction -> Vanilla = HOSTILE`.
6. Prefer `Vanilla -> spawned faction = FRIENDLY` with Symmetric unchecked for the cleanest directional test.
7. Check the SPIKE target-probe checkbox.
8. Spawn once and leave both zombies undisturbed for several seconds.
9. Repeat once with mutual HOSTILE if desired.
10. Save client and server logs.

Useful v0.0.7 markers are:

```text
[TARGET_PROBE] phase=dispatch
[OWNER_PROBE] instruction
[OWNER_PROBE] resolved
[OWNER_PROBE] phase=owner-target-path
[OWNER_PROBE] phase=owner-spottedOld-target-path
[OWNER_PROBE] phase=owner-location-path
[CLIENT_OBSERVER]
[SERVER_OBSERVER]
```

A `resolve-timeout` is itself useful: it means the server-selected subject/candidate or ownership identity was not resolvable on the requesting client during the bounded window.

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

Close this spike with the exact target/AI/combat boundaries, the viable Lua hook surface (if any), any deeper-hook requirement, multiplayer authority model, damage/death synchronization approach, and performance implications. Add an ADR only if the resulting architectural choice is significant enough to need one.
