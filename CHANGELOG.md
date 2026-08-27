# Changelog

## 0.0.4 — 2026-08-27

SPIKE-001 Horde Spawner explicit geometry fix.

- corrected the second runtime failure where the faction controls rendered but the vanilla Spawn/Remove/Close buttons were still not visible;
- confirmed from Build 42 `ISUIElement:setHeight()` that changing the window height does not provide a reliable post-construction child reposition for this patch;
- stopped relying on `anchorBottom` behavior and now explicitly places the two vanilla bottom button rows after the final extended window height is known;
- added a bounded `[ZombieFactions][UI]` geometry diagnostic containing the final window height plus Spawn and Remove row Y coordinates;
- updated client/server startup diagnostics to v0.0.4.

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
