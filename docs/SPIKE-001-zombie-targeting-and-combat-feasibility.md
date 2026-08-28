# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Open — v0.0.5 spawn harness validated; v0.0.6 assignment and forced-target probe awaiting runtime test  
Target: Project Zomboid Build 42.20.x

## Question

Can Zombie Factions enforce directional faction relationships at a clean target-eligibility boundary, and can a vanilla `IsoZombie` reliably pursue, attack, damage, and kill another `IsoZombie` in Build 42 multiplayer?

## Evidence

Use Project Zomboid Build 42 API documentation, controlled runtime tests/logs, and the privately supplied decompiled Build 42 source as implementation research. Decompiled game source is not copied into this repository.

## Engine trace

Follow the complete path through:

1. candidate discovery and filtering;
2. target assignment;
3. pathfinding/pursuit;
4. attack-state entry and target-type assumptions;
5. hit/damage processing;
6. death handling;
7. server/client authority and synchronization;
8. save/load and relevance transitions.

## Current API findings

Current Build 42 JavaDocs expose several useful type boundaries:

- `IsoZombie.getTarget()` returns `IsoMovingObject`;
- `IsoZombie.setTarget(IsoMovingObject)` accepts a generic moving object;
- `IsoZombie.spotted(IsoMovingObject, boolean)` plus `spottedNew` / `spottedOld` accept generic moving objects;
- `IsoZombie.pathToCharacter(IsoGameCharacter)` accepts a generic game character;
- `IsoZombie.isZombieAttacking(IsoMovingObject)` can test attack state against a generic moving object;
- `IsoZombie.getOnlineID()`, `getOwnerPlayer()`, and `getRealState()` are available for bounded diagnostics.

Because `IsoZombie` is an `IsoGameCharacter` and an `IsoMovingObject`, these public signatures do not prohibit a zombie from being passed as another zombie's target/path target. This is only type-level evidence. It does **not** prove that downstream attack-state animation logic, hit processing, damage, death handling, or multiplayer ownership supports zombie-to-zombie combat.

The v0.0.6 probe therefore tests the middle of the chain directly before we modify normal candidate discovery.

## Diagnostic harness

Version 0.0.2 introduced the first test harness by extending the built-in Build 42 `ISSpawnHordeUI` admin window. Runtime tests in 0.0.2 through 0.0.4 exposed repeated problems with the vanilla bottom-button anchoring/layout lifecycle. Version 0.0.5 removed that dependency by creating independent bottom controls that call the existing Horde Manager handlers.

Source inspection established that multiplayer Horde Spawning normally sends `/createhorde2`; the server command creates zombies through `addZombiesInOutfit(...)`. That API returns the created `IsoZombie` objects, allowing the harness to tag exact test subjects rather than find them later with a proximity scan.

The extended window provides:

- `zf:vanilla`, `zf:test-red`, and `zf:test-blue` faction choices;
- `spawned faction -> zf:vanilla` relationship;
- `zf:vanilla -> spawned faction` relationship;
- `FRIENDLY`, `NEUTRAL`, and `HOSTILE` choices for each direction;
- a symmetric convenience toggle;
- in v0.0.6, an opt-in `SPIKE: force nearest HOSTILE Vanilla zombie target` toggle.

For `zf:vanilla`, the original Horde Spawning function is left unchanged. For a diagnostic faction, the client sends a namespaced Zombie Factions command to the server. The server rechecks `Capability.CreateHorde`, sets the directional relationship pair before spawning, uses `addZombiesInOutfit(...)`, assigns faction/test-run mod data to the exact returned zombie, and records a `SPIKE001-####` run ID.

## Runtime findings — 0.0.2 through 0.0.4

The faction controls consistently rendered, proving the client extension loaded. However the normal Spawn/Remove/Close controls were not visible after the window was extended.

- 0.0.2 manually shifted vanilla bottom controls after resizing and pushed them outside the visible window.
- 0.0.3 removed the duplicate shift and attempted to rely on vanilla bottom anchoring; the controls still did not render visibly.
- 0.0.4 explicitly assigned Y coordinates to the vanilla controls after resize; the window geometry and reserved bottom area were correct, but the controls still were not visible in the runtime screenshot.

The v0.0.4 screenshot showed approximately two button rows of empty space below the symmetric relationship control. This isolated the problem to the existing vanilla control lifecycle rather than insufficient window height.

## Runtime validation — 0.0.5 — PASSED

Version 0.0.5 stopped trying to reposition the vanilla bottom controls. It created independent Remove Zombies, Remove Bodies, Spawn, and Close controls after final window geometry was known; those controls call the existing `ISSpawnHordeUI` handlers.

Dedicated-server/client testing on Build 42.20.4 validated the diagnostic harness.

Observed client geometry:

```text
[ZombieFactions][UI] windowHeight=668 harnessSpawnY=635 harnessRemoveY=603 buttonWidth=168
```

The stock Vanilla spawn path continued to reach `CreateHorde2Command`, while custom faction spawns reached the Zombie Factions server path. Seven custom test runs completed successfully:

- `SPIKE001-0001`: one `zf:test-red`, `FRIENDLY -> zf:vanilla`, reciprocal `FRIENDLY`;
- `SPIKE001-0002` and `0003`: one `zf:test-red`, `HOSTILE -> zf:vanilla`, reciprocal `FRIENDLY`;
- `SPIKE001-0004`: one `zf:test-blue`, `HOSTILE -> zf:vanilla`, reciprocal `FRIENDLY`;
- `SPIKE001-0005`: one `zf:test-blue`, mutual `HOSTILE`;
- `SPIKE001-0006`: one `zf:test-red`, mutual `HOSTILE`;
- `SPIKE001-0007`: ten `zf:test-red`, mutual `HOSTILE`, `spawned=10 requested=10`.

The client received a success result for every custom run, including the 10/10 spawn. No Zombie Factions Lua exception occurred during these spawn operations, and the server shut down normally afterward.

This validates the UI, client-to-server command path, server permission/spawn path, faction selection transport, directional relationship transport/configuration, assignment call success on exact returned zombies, result reply, and multi-zombie diagnostic spawning. It does **not** yet demonstrate that assignment remains resolvable after the immediate call, propagates to the observing client, survives persistence/relevance transitions, or affects zombie AI.

## Version 0.0.6 experiments

### A — Assignment re-resolution

For every custom spawn, the server now independently calls `getZombieFaction(zombie)` and `getZombieTestRun(zombie)` immediately after assignment. It also schedules a second resolution after 30 ticks for up to 10 spawned subjects per run.

Expected server summary:

```text
[ZombieFactions][SPIKE001-....] ... assignmentImmediate=1/1 deferredSamples=1 ...
```

Expected deferred verification:

```text
[ZombieFactions][SPIKE001-....][ASSIGN] phase=deferred onlineID=... expectedFaction=zf:test-red resolvedFaction=zf:test-red resolvedRun=SPIKE001-.... owner=... ok=true
```

A client `OnZombieUpdate` observer exits immediately for ordinary zombies. For explicitly tagged SPIKE subjects only, it logs initial state and subsequent state/target/ownership changes. Seeing the correct run ID and faction in a `CLIENT_OBSERVER` line demonstrates that the test subject's mod data became visible to the observing client.

This still does not prove save/restart or relevance persistence.

### B — Forced target/path feasibility probe

The new Horde Manager toggle is:

```text
SPIKE: force nearest HOSTILE Vanilla zombie target
```

It is allowed only when `spawned faction -> Vanilla = HOSTILE`.

When enabled, the server waits 30 ticks after spawning, then for **one** test subject finds the nearest living `zf:vanilla` zombie within 12 tiles. It calls:

```text
subject:setTarget(candidate)
subject:pathToCharacter(candidate)
```

and observes the subject for 180 ticks. Diagnostics are transition-based plus one final sample and report:

- subject/candidate online IDs;
- resolved factions;
- current zombie owner player;
- whether `setTarget` and `pathToCharacter` returned without exception;
- whether the target was retained;
- `getRealState()`;
- `isZombieAttacking(candidate)`;
- distance;
- subject/candidate death state.

The candidate lookup is intentionally a one-time, bounded SPIKE operation. It may inspect the current zombie list to locate the nearest Vanilla subject because this test is explicitly measuring downstream target compatibility. This is **not** the production targeting design and must not become a recurring global scan.

### Runtime procedure for v0.0.6

Use a quiet, open area. The observing admin should be invisible/god/debug as appropriate so the player is not a competing preferred target.

1. Spawn **one Vanilla zombie** at the intended test point using the normal Horde Manager path.
2. Move the spawn point a few tiles away but remain within approximately 3–8 tiles of the Vanilla zombie.
3. Set **Number of Zombies = 1** and preferably **Radius = 0** for the custom subject.
4. Select **Test Red (`zf:test-red`)**.
5. Set `Spawned faction -> Vanilla = HOSTILE`.
6. **Uncheck Symmetric**.
7. Set `Vanilla -> spawned faction = FRIENDLY`.
8. Check **SPIKE: force nearest HOSTILE Vanilla zombie target**.
9. Spawn the Red zombie.
10. Observe for several seconds without attacking or moving the zombies manually.
11. Save the client and server logs.

The asymmetric relationship is deliberate: the test asks whether the Red subject can be forced down the target/pursuit chain while the Vanilla control is not independently intended to initiate.

### How to interpret the v0.0.6 result

A strong positive target/path result would look like:

```text
[ASSIGN] ... ok=true
[TARGET_PROBE] phase=forced ... setTarget=true pathToCharacter=true retained=true ...
[TARGET_PROBE] phase=observe ... target=<candidate> retained=true state=<pursuit state> ...
```

If the client also emits the same SPIKE run/faction, assignment propagation is confirmed for the active relevant zombie.

Possible outcomes:

- **A — target retained, pursuit and native attack/damage occur:** downstream zombie-vs-zombie support is much stronger than currently proven; next trace normal acquisition/`spotted(...)` and relationship eligibility.
- **B — target retained and pursuit occurs, but attack/damage does not:** likely attack-state or combat-processing intervention is required.
- **C — `setTarget` succeeds but target is immediately replaced/cleared:** target validation/ownership or AI update logic rejects/overwrites the zombie candidate; trace that boundary before adding discovery logic.
- **D — `pathToCharacter` or state transition rejects the target:** pursue/path layer is a blocker.
- **E — server target works briefly but client ownership overwrites it:** multiplayer zombie authority is a primary integration constraint.

Do not add a production candidate-discovery hook until this experiment identifies whether the downstream chain is viable.

## Behavioral controls after forced-target feasibility

Once forced zombie-to-zombie pursuit/attack feasibility is understood, run normal relationship controls in 1v1 conditions:

| Test | Test faction -> Vanilla | Vanilla -> Test faction | Intended behavior |
| --- | --- | --- | --- |
| Vanilla control | n/a | n/a | Vanilla zombies ignore each other |
| Friendly | FRIENDLY | FRIENDLY | Neither faction proactively attacks |
| Neutral | NEUTRAL | NEUTRAL | Neither faction proactively attacks |
| Hostile | HOSTILE | HOSTILE | Eligible for acquisition/pursuit/attack |
| Directional | HOSTILE | FRIENDLY | Test faction may initiate; Vanilla must not independently initiate |

Friendly and Neutral behavior must be enforced at a clean eligibility boundary rather than by continuously clearing targets after vanilla chooses them.

## Targeting acceptance criteria

Zombie-to-zombie hostility is not considered supported until a controlled hostile 1v1 demonstrates that one test zombie can:

1. resolve the expected custom faction identity;
2. acquire an opposing-faction zombie through the eventual faction-aware acquisition path;
3. retain that target;
4. pursue it;
5. enter an attack state;
6. apply damage;
7. reach disengagement or death;
8. synchronize correctly on a dedicated server/client pair.

Friendly and Neutral controls must demonstrate that the same nearby candidate is not proactively attacked when policy prohibits it.

## Later tests

After 1v1 behavior is understood:

- repeat at 3v3 and 5v5 to observe target replacement and dead-target cleanup;
- test save/restart and relevance unload/reload for the proposed production assignment mechanism;
- only then increase population for performance testing.

## Instrumentation rules

Diagnostics remain limited to explicitly spawned SPIKE-001 subjects and should record only what is needed to reconstruct the decision path:

- test-run ID;
- subject ID/faction;
- candidate/target ID and faction;
- resolved directional relationship;
- target set/cleared transitions;
- pursuit/attack transitions where observable;
- damage/death events;
- server/client origin and ownership where relevant.

Do not default to globally scanning zombies and repeatedly clearing `setTarget(nil)`. That remains a last-resort approach requiring explicit performance evidence.

## Deliverable

Close this spike with the exact classes/methods/events involved, the validated Horde Spawning test path, Lua-only feasibility, any deeper-hook requirement, performance implications, and multiplayer authority implications. Add an ADR only if the resulting implementation choice is significant enough to need one.
