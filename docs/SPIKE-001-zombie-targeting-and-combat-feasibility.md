# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Open  
Target: Project Zomboid Build 42.20.x

## Question

Can Zombie Factions enforce directional faction relationships at a clean target-eligibility boundary, and can a vanilla `IsoZombie` reliably pursue, attack, damage, and kill another `IsoZombie` in Build 42 multiplayer?

## Evidence

Use Project Zomboid Build 42 API documentation, controlled runtime tests/logs, and the privately supplied decompiled Build 42 source as implementation research. Decompiled game source is not to be copied into this repository.

## Trace

Follow the complete path through:

1. candidate discovery and filtering;
2. target assignment;
3. pathfinding/pursuit;
4. attack-state entry and target-type assumptions;
5. hit/damage processing;
6. death handling;
7. server/client authority and synchronization;
8. save/load and relevance transitions.

## SPIKE-001 diagnostic harness

Testing requires a deterministic way for an administrator to create zombies with known faction identities. The preferred harness is a Zombie Factions extension to the built-in Build 42 admin Horde Spawning tool rather than a gameplay spawning system.

The faction-aware horde spawn mode should provide at minimum:

- **Faction** — faction identity assigned to every zombie created by that spawn operation, defaulting to `zf:vanilla`;
- **Spawned faction -> Vanilla** — `FRIENDLY`, `NEUTRAL`, or `HOSTILE`;
- **Vanilla -> spawned faction** — `FRIENDLY`, `NEUTRAL`, or `HOSTILE`;
- **Symmetric relationship** convenience toggle, which mirrors the first relationship into the reverse direction when enabled;
- ordinary Horde Spawning controls such as count/location should remain usable.

The two relationship directions must be independently configurable because Zombie Factions relationships are directional.

If safely extending the existing Horde Spawning UI proves brittle, an admin-only Zombie Factions spawn panel may reproduce only the small subset of Horde Spawning behavior required by the spike. It must still use the normal server-authoritative zombie spawning path rather than fabricate client-only zombies.

Faction identity must be attached to each spawned zombie immediately enough that vanilla targeting cannot observe the test zombie as `zf:vanilla` first and then have it change factions afterward.

## Controlled test setup

Use a quiet, open test area with no unrelated zombies. The observing administrator should use admin invisibility/god/debug facilities as needed so the player does not become the preferred zombie target and confound the experiment.

Create two controlled populations:

- **Group A:** ordinary `zf:vanilla` zombies;
- **Group B:** zombies spawned as a test faction such as `zf:test-red`.

Start with small groups (for example 1v1, then 3v3 or 5v5) so target ownership, movement, and damage can be traced unambiguously before any population/performance test.

## Test matrix

### T1 — Assignment control

Spawn `zf:test-red` zombies and verify every spawned subject resolves to `zf:test-red`. Spawn ordinary zombies and verify they resolve to `zf:vanilla`.

### T2 — Vanilla control

`zf:vanilla -> zf:vanilla = FRIENDLY` by default. Nearby vanilla zombies must retain ordinary non-aggression toward one another.

### T3 — Mutual Friendly

```text
zf:test-red -> zf:vanilla = FRIENDLY
zf:vanilla  -> zf:test-red = FRIENDLY
```

Place the populations within normal detection distance. Neither group should acquire the other as an aggressive target.

### T4 — Mutual Neutral

```text
zf:test-red -> zf:vanilla = NEUTRAL
zf:vanilla  -> zf:test-red = NEUTRAL
```

Neither group should proactively acquire the other. Neutral retaliation is tested only after a reliable zombie-to-zombie aggression/damage mechanism exists; absence of proactive aggression is the first acceptance condition.

### T5 — Mutual Hostile

```text
zf:test-red -> zf:vanilla = HOSTILE
zf:vanilla  -> zf:test-red = HOSTILE
```

At least one zombie must acquire an opposing zombie, retain it, pursue it, enter an attack state, apply damage, and continue through disengagement or death.

### T6 — Directionality

```text
zf:test-red -> zf:vanilla = HOSTILE
zf:vanilla  -> zf:test-red = FRIENDLY
```

The test faction may initiate aggression against Vanilla while Vanilla must not independently initiate aggression against the test faction. This test distinguishes real directional relationship enforcement from a symmetric team/faction shortcut.

Repeat later with `NEUTRAL` in the reverse direction to validate retaliation semantics after the damage path is understood.

### T7 — Dedicated multiplayer

Repeat the successful 1v1 and small-group cases on a dedicated server with at least one observing client. Verify faction identity, target choice, pursuit, attack, damage, death, and visible state do not diverge between server and client.

### T8 — Lifecycle

For any faction assignment mechanism proposed for production, save/restart or move test zombies through relevant unload/reload boundaries and verify faction identity remains deterministic.

### T9 — Performance sanity

Only after behavior works, repeat with larger controlled populations and inspect server tick/log/network behavior. The diagnostic harness must not require full-world scans or high-frequency network/log spam.

## Instrumentation

For explicitly spawned SPIKE-001 subjects, bounded diagnostics should record enough information to reconstruct the decision path without logging every zombie in the world:

- subject identifier;
- resolved faction;
- candidate/target identifier and faction;
- resolved directional relationship;
- target set/cleared transition;
- pursuit/attack-state transitions where observable;
- damage/death events;
- server/client origin for multiplayer-relevant observations.

A test-run identifier or spawned-subject marker is preferred so diagnostic output can be restricted to the current experiment.

## Preferred result

Find a supported hook or narrow interception point where faction policy can reject a candidate before vanilla pursuit begins:

```text
canTarget(attacker, candidate)
  -> resolve identities
  -> resolve relationship
  -> HOSTILE = eligible
```

Do not default to globally scanning zombies and repeatedly clearing `setTarget(nil)`. That remains a last-resort approach requiring explicit performance evidence.

## Acceptance probe

A successful zombie-vs-zombie feasibility result requires the controlled horde-spawner test to demonstrate that one hostile zombie can:

1. resolve the expected custom faction identity;
2. acquire an opposing-faction zombie;
3. retain the target;
4. pursue it;
5. enter an attack state;
6. apply damage;
7. reach disengagement or death;
8. synchronize correctly on a dedicated server/client pair.

Friendly and Neutral controls must also demonstrate that the same nearby candidate is not proactively attacked when policy prohibits it.

## Deliverable

Close this spike with the exact classes/methods/events involved, the Horde Spawning integration path used for the test harness, Lua-only feasibility, any deeper-hook requirement, performance implications, and multiplayer authority implications. Add an ADR only if the resulting implementation choice is significant enough to need one.
