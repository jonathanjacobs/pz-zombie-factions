# Changelog

## 0.0.3 — 2026-08-27

SPIKE-001 Horde Spawner layout correction.

- fixed the admin Horde Spawning extension pushing the vanilla Spawn, Remove Zombies, Remove Bodies, and Close buttons below the visible window;
- root cause: the vanilla buttons already use `anchorBottom = true`, so increasing the window height automatically repositions them; the 0.0.2 patch then moved them a second time manually;
- removed the duplicate manual button repositioning and now relies on the vanilla bottom anchoring behavior;
- added explicit client/server startup diagnostics for the SPIKE-001 harness.

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
