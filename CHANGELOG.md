# Changelog

## 0.0.7 — 2026-08-28

SPIKE-001 multiplayer ownership probe.

- recorded the v0.0.6 dedicated-server result: faction/test-run assignment re-resolved correctly, but server-side `setTarget(...)` + `pathToCharacter(...)` only retained zombie targets briefly; every forced subject remained `idle`, never entered an attack state, and the target was cleared;
- all successfully forced subjects reported `owner=admin`, making client ownership a primary unresolved variable rather than proving that `IsoZombie` categorically rejects another zombie as a target;
- the v0.0.6 client observer loaded but produced no tagged-subject observations, so v0.0.7 no longer depends on zombie mod-data propagation to identify the test subject on the client;
- the server now sends the selected subject/candidate online IDs and run metadata to the requesting client and passively observes the server-side state instead of forcing the target itself;
- the owning client resolves those IDs with a bounded diagnostic lookup, verifies local ownership, and performs Phase A: `setTarget(...)` + `pathToCharacter(...)`;
- if Phase A remains idle/loses the target, Phase B calls `spotted(candidate, true)` before repeating target/path assignment, testing whether vanilla perception state is the missing gate;
- added bounded client and server transition logs for ownership, remote status, target retention, state, attack status, distance, and death;
- retained the existing single SPIKE checkbox and the one-time bounded Vanilla-candidate scan; no production global zombie scan or target-clearing loop was introduced.

## 0.0.6 — 2026-08-27

SPIKE-001 assignment validation and direct target probe.

- recorded the successful v0.0.5 dedicated-server harness test: custom Red/Blue spawns, asymmetric relationships, symmetric hostility, and multi-zombie requests all completed without Zombie Factions Lua errors;
- independently re-resolves faction and SPIKE run metadata immediately after assignment and again after a short delay for up to 10 sampled subjects per test run;
- added an opt-in admin `SPIKE: force nearest HOSTILE Vanilla zombie target` control;
- for that explicit diagnostic only, the server finds the nearest living `zf:vanilla` zombie within 12 tiles, calls `setTarget(...)` and `pathToCharacter(...)`, then emits bounded state/target/attack-transition observations;
- added a client `OnZombieUpdate` observer that exits immediately for ordinary zombies and logs only state changes for explicitly tagged SPIKE subjects, allowing client-side mod-data propagation and ownership/target behavior to be verified;
- the direct-target scan is diagnostic research only and is not the production faction targeting architecture;
- added otherwise-empty `AnimSets` and `actiongroups` directories under the common and Build 42 media roots to avoid Build 42 `AdvancedAnimator` missing-directory startup stack traces.

## 0.0.5 — 2026-08-27

SPIKE-001 Horde Spawner control replacement.

- runtime screenshot confirmed v0.0.4 enlarged the Horde Manager correctly but the vanilla bottom controls were still not rendered inside the visible window;
- stopped depending on post-construction behavior of the vanilla `anchorBottom` controls;
- the Zombie Factions extension now creates its own Spawn, Remove Zombies, Remove Bodies, and Close buttons after the final extended window geometry is known;
- the replacement buttons call the existing `ISSpawnHordeUI` handlers, so Vanilla still follows the stock spawn path while test factions use the Zombie Factions server command;
- updated bounded UI diagnostics to report the independent harness button coordinates.

## 0.0.4 — 2026-08-27

SPIKE-001 Horde Spawner explicit geometry fix.

- corrected the second runtime failure where the faction controls rendered but the vanilla Spawn/Remove/Close buttons were still not visible;
- confirmed from Build 42 `ISUIElement:setHeight()` that changing the window height does not provide a reliable post-construction child reposition for this patch;
- stopped relying on `anchorBottom` behavior and explicitly placed the two vanilla bottom button rows after the final extended window height was known;
- added a bounded `[ZombieFactions][UI]` geometry diagnostic containing the final window height plus Spawn and Remove row Y coordinates;
- subsequent runtime testing showed the vanilla controls still did not render, leading to the independent harness controls in 0.0.5.

## 0.0.3 — 2026-08-27

SPIKE-001 Horde Spawner layout correction attempt.

- first runtime test showed the admin Horde Spawning extension pushing the vanilla Spawn, Remove Zombies, Remove Bodies, and Close buttons below the visible window;
- removed the 0.0.2 duplicate manual shift and attempted to rely on vanilla bottom anchoring;
- added explicit client/server startup diagnostics for the SPIKE-001 harness;
- subsequent runtime testing showed the bottom controls still were not visible, leading to the explicit-coordinate fix in 0.0.4.

## 0.0.2 — 2026-08-26

SPIKE-001 diagnostic horde-spawn harness.

- extended the built-in admin Horde Spawning window with `zf:test-red` and `zf:test-blue` selections;
- added independent `spawned faction -> zf:vanilla` and `zf:vanilla -> spawned faction` relationship controls plus a symmetric convenience toggle;
- added a server-authoritative `SpawnTestHorde` command gated by `Capability.CreateHorde`;
- reused `addZombiesInOutfit(...)` and tags the exact returned `IsoZombie` objects instead of scanning nearby zombies after spawn;
- added zombie faction/test-run assignment helpers using zombie mod data;
- added bounded `SPIKE001-####` run identifiers and spawn-result logging;
- retained the original vanilla Horde Spawning path whenever `zf:vanilla` is selected;
- no faction-aware target acquisition or zombie-vs-zombie combat behavior is claimed yet.

## 0.0.1 — 2026-08-26

Initial repository foundation.

- established the Build 42 mod package structure;
- defined the Vanilla/default zombie faction concept;
- defined directional `FRIENDLY`, `NEUTRAL`, and `HOSTILE` relationships;
- documented integration with existing Project Zomboid player factions;
- established lean requirements, design, SPIKE-001, and compliance documentation;
- added the minimal shared faction registry/relationship API skeleton.
