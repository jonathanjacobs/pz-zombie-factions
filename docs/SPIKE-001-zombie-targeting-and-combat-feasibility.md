# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Open — Horde test UI loads; 0.0.2 layout defect fixed in 0.0.3; faction spawn validation pending  
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

Version 0.0.2 introduced the first test harness by extending the built-in Build 42 `ISSpawnHordeUI` admin window. Version 0.0.3 fixes the first runtime-discovered UI layout defect.

Source inspection established that multiplayer Horde Spawning normally sends `/createhorde2`; the server command creates zombies through `addZombiesInOutfit(...)`. That API returns the created `IsoZombie` objects, allowing the harness to tag exact test subjects rather than find them later with a proximity scan.

The extended window adds:

- `zf:vanilla`, `zf:test-red`, and `zf:test-blue` faction choices;
- `spawned faction -> zf:vanilla` relationship;
- `zf:vanilla -> spawned faction` relationship;
- `FRIENDLY`, `NEUTRAL`, and `HOSTILE` choices for each direction;
- a symmetric convenience toggle.

For `zf:vanilla`, the original Horde Spawning function is left unchanged. For a diagnostic faction, the client sends a namespaced Zombie Factions command to the server. The server rechecks `Capability.CreateHorde`, sets the directional relationship pair before spawning, uses `addZombiesInOutfit(...)`, assigns faction/test-run mod data to the exact returned zombie, and records a `SPIKE001-####` run ID.

### Runtime finding — 0.0.2

The first enabled-mod dedicated-server test confirmed that the Zombie Factions controls rendered in the built-in Horde Spawning window, but the normal bottom buttons were no longer visible. The extension had enlarged the window and also manually shifted `add`, `closeButton2`, `removezombies`, and `clearbodies` downward.

Build 42's vanilla `ISSpawnHordeUI` already declares those four controls with `anchorBottom = true`. Increasing the window height therefore moves them automatically. The additional manual shift moved them a second time and placed them below the visible window.

Version 0.0.3 removes the manual repositioning and relies on the existing vanilla bottom anchors. It also adds explicit client/server startup diagnostic lines. The actual custom faction-spawn command has still not been runtime-validated because the 0.0.2 layout defect prevented the Spawn button from being clicked.

## First runtime test

Use a quiet open area and an observing admin who is invisible/god/debug as needed so the player does not become the preferred zombie target.

### A — Harness smoke test

1. Open the normal admin **Horde Spawning** tool.
2. Confirm the new Zombie Factions controls appear below the vanilla health controls and the normal Spawn/Remove/Close controls remain visible at the bottom.
3. Leave `zf:vanilla` selected and spawn one zombie; confirm the ordinary vanilla path still works.
4. Select `zf:test-red`, leave both relationships `FRIENDLY`, and spawn one zombie.
5. Confirm the server log contains one bounded line with a `SPIKE001-####` run ID, requested/spawned counts, faction, and directional relationships.
6. Confirm there is no Lua exception on server or client.

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

At v0.0.3 the faction and relationship state exists, but no target-acquisition hook has yet been implemented. Therefore the current expected result for Hostile is still vanilla non-aggression between zombies. That negative control is useful: it confirms the harness itself is not accidentally changing AI behavior before the targeting work begins.

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
