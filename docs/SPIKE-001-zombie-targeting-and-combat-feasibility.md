# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Open — Horde test UI loads; v0.0.5 independent bottom controls awaiting runtime validation  
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

## Diagnostic harness

Version 0.0.2 introduced the first test harness by extending the built-in Build 42 `ISSpawnHordeUI` admin window. Runtime tests in 0.0.2 through 0.0.4 exposed repeated problems with the vanilla bottom-button anchoring/layout lifecycle. Version 0.0.5 removes that dependency for the diagnostic harness.

Source inspection established that multiplayer Horde Spawning normally sends `/createhorde2`; the server command creates zombies through `addZombiesInOutfit(...)`. That API returns the created `IsoZombie` objects, allowing the harness to tag exact test subjects rather than find them later with a proximity scan.

The extended window adds:

- `zf:vanilla`, `zf:test-red`, and `zf:test-blue` faction choices;
- `spawned faction -> zf:vanilla` relationship;
- `zf:vanilla -> spawned faction` relationship;
- `FRIENDLY`, `NEUTRAL`, and `HOSTILE` choices for each direction;
- a symmetric convenience toggle.

For `zf:vanilla`, the original Horde Spawning function is left unchanged. For a diagnostic faction, the client sends a namespaced Zombie Factions command to the server. The server rechecks `Capability.CreateHorde`, sets the directional relationship pair before spawning, uses `addZombiesInOutfit(...)`, assigns faction/test-run mod data to the exact returned zombie, and records a `SPIKE001-####` run ID.

### Runtime findings — 0.0.2 through 0.0.4

The faction controls consistently rendered, proving the client extension loaded. However the normal Spawn/Remove/Close controls were not visible after the window was extended.

- 0.0.2 manually shifted vanilla bottom controls after resizing and pushed them outside the visible window.
- 0.0.3 removed the duplicate shift and attempted to rely on vanilla bottom anchoring; the controls still did not render visibly.
- 0.0.4 explicitly assigned Y coordinates to the vanilla controls after resize; the window geometry and reserved bottom area were correct, but the controls still were not visible in the runtime screenshot.

The v0.0.4 screenshot showed approximately two button rows of empty space below the symmetric relationship control. This indicates the remaining problem is tied to the existing vanilla control lifecycle rather than insufficient window height.

### Version 0.0.5 approach

Version 0.0.5 stops trying to reuse/reposition the vanilla bottom controls. After the final extended window geometry is known, Zombie Factions creates its own diagnostic bottom controls:

- Remove Zombies;
- Remove Bodies;
- Spawn;
- Close.

These controls call the existing `ISSpawnHordeUI` handlers. Therefore selecting `zf:vanilla` still invokes the original PZ `onSpawn` path, while selecting a test faction invokes the Zombie Factions server-authoritative spawn command.

The client emits one bounded geometry line for these independent controls:

```text
[ZombieFactions][UI] windowHeight=<h> harnessSpawnY=<y> harnessRemoveY=<y> buttonWidth=<w>
```

The custom faction-spawn command has not yet been runtime-validated because previous UI failures prevented any faction-aware Spawn click.

## First runtime test

Use a quiet open area and an observing admin who is invisible/god/debug as needed so the player does not become the preferred zombie target.

### A — Harness smoke test

1. Open the normal admin **Horde Spawning** tool.
2. Confirm the Zombie Factions controls and the new bottom Spawn/Remove/Close controls are visible.
3. Confirm the client log contains the bounded `[ZombieFactions][UI]` geometry line.
4. Leave `zf:vanilla` selected and spawn one zombie; confirm the ordinary vanilla path still works.
5. Select `zf:test-red`, leave both relationships `FRIENDLY`, and spawn one zombie.
6. Confirm the server log contains one bounded line with a `SPIKE001-####` run ID, requested/spawned counts, faction, and directional relationships.
7. Confirm there is no Lua exception on server or client.

If this fails, stop here and fix the harness before testing combat.

### B — Assignment control

Spawn one `zf:test-red` subject and verify server-side faction resolution returns `zf:test-red`. Repeat with `zf:test-blue`. Ordinary unassigned zombies must resolve to `zf:vanilla`.

### C — Behavioral controls

Run the following in 1v1 conditions first:

| Test | Test faction -> Vanilla | Vanilla -> Test faction | Initial expectation |
| --- | --- | --- | --- |
| Vanilla control | n/a | n/a | Vanilla zombies ignore each other |
| Friendly | FRIENDLY | FRIENDLY | Neither faction proactively attacks |
| Neutral | NEUTRAL | NEUTRAL | Neither faction proactively attacks |
| Hostile | HOSTILE | HOSTILE | Intended future result: acquisition/pursuit/attack |
| Directional | HOSTILE | FRIENDLY | Test faction may initiate; Vanilla must not independently initiate |

At v0.0.5 the faction and relationship state exists, but no target-acquisition hook has yet been implemented. Therefore the current expected result for Hostile is still vanilla non-aggression between zombies. That negative control is useful: it confirms the harness itself is not accidentally changing AI behavior before the targeting work begins.

## Targeting acceptance probe

Once a faction-aware target hook exists, a successful hostile 1v1 must demonstrate that one test zombie can:

1. resolve the expected custom faction identity;
2. acquire an opposing-faction zombie;
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
- repeat successful cases on a dedicated server with an observing client;
- test save/restart and relevance unload/reload for the proposed production assignment mechanism;
- only then increase population for performance testing.

## Instrumentation

Diagnostics should remain limited to explicitly spawned SPIKE-001 subjects and should record only what is needed to reconstruct the decision path:

- test-run ID;
- subject ID/faction;
- candidate/target ID and faction;
- resolved directional relationship;
- target set/cleared transitions;
- pursuit/attack transitions where observable;
- damage/death events;
- server/client origin where relevant.

Do not default to globally scanning zombies and repeatedly clearing `setTarget(nil)`. That remains a last-resort approach requiring explicit performance evidence.

## Deliverable

Close this spike with the exact classes/methods/events involved, the validated Horde Spawning test path, Lua-only feasibility, any deeper-hook requirement, performance implications, and multiplayer authority implications. Add an ADR only if the resulting implementation choice is significant enough to need one.
