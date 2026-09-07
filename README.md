# Zombie Factions

A Project Zomboid Build 42 framework for zombie-faction identity and directional `FRIENDLY`, `NEUTRAL`, and `HOSTILE` relationships.

- Status: **Research / Pre-Alpha**
- Current version: **v0.0.51**
- Target baseline: **Project Zomboid Build 42.20.x**

## Current state

SPIKE-001 established faction-aware zombie pursuit, synchronized damage, and normal lethal corpse handling in dedicated-server testing. SPIKE-003 closed successfully for the dedicated-server, one-client standing-zombie scope. A v0.0.36 mixed-crowd run exercised crawler lunges, standing stomps, and standing bites with accepted server damage and no profile mismatch or Zombie Factions exception. Version 0.0.37 added an unvalidated seated-defender rule: standing attackers stomp sitting zombies, which then use the shipped get-up transition after accepted nonlethal damage. Version 0.0.38 fixes [#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2): idle members of an already-active mob now get individually swept for a fresh target instead of being permanently skipped by the maintenance pass. A follow-up dedicated-server run confirmed the sweep reactivating a previously dormant member on its own, and closed the issue. Version 0.0.39 hardens the Horde Spawner first-click fix: the vanilla controls behind the harness buttons are now fully detached rather than only hidden. A follow-up run recorded ten clicks producing exactly ten spawns, though the underlying defect has since recurred and [#5](https://github.com/jonathanjacobs/pz-zombie-factions/issues/5) is open again. That run also surfaced a close-range combat stall between two mutually hostile zombies, tracked as [#10](https://github.com/jonathanjacobs/pz-zombie-factions/issues/10).

Versions 0.0.40 through 0.0.43 add sprinter support. Speed can be assigned server-side and selected in the Horde Spawner, and faction sprinters reach native sprint locomotion without a native zombie target, using mod-owned animation nodes. A dedicated-server run measured sprinters at 2.5–2.8 times a same-run shambler control across 2,098 assigned zombies with no assignment failures, leaving posture-based attack selection and damage authority unchanged. That run also reproduced [#10](https://github.com/jonathanjacobs/pz-zombie-factions/issues/10) at speed, where a converging sprinter pair crossed the whole engagement band between two controller passes and circled instead of connecting; a sprinter-only braking distance addressed it, moving melee authorisation from never happening to roughly half a tile.

The current implementation remains diagnostic tooling. The administrator Horde Spawning extension creates selected test factions and an opt-in SPIKE harness; ordinary vanilla spawning remains unchanged when it is disabled. Production enrollment, persistence, and relationship behavior outside the harness remain planned work.

## Scope and current limits

- Zombies resolve to one zombie faction; `zf:vanilla` is the default.
- Relationships are directional and use `FRIENDLY`, `NEUTRAL`, or `HOSTILE`.
- Default installation preserves normal vanilla behavior.
- Zombies can be shamblers, fast shamblers or sprinters; speed is assigned server-side and sprinters use native sprint locomotion during faction pursuit.
- Standing bites, the v0.0.36 mixed-crowd crawler/stomp route, the v0.0.38 dormant-mob-member fix, and v0.0.40–0.0.43 sprinter speed assignment and locomotion have dedicated-server runtime evidence. The v0.0.37 seated-stomp/get-up extension has server-side profile-transition evidence consistent with a working get-up but no confirming client-side counters.
- Not yet established: two-client ownership separation, sprinter behavior against crawling and sitting defenders beyond a handful of samples, the ordinary sprinter-versus-player regression, and the v0.0.45 `NEUTRAL` retaliation behavior, which is implemented but has no runtime evidence yet.
- Only explicitly enrolled diagnostic zombies participate today.

## Documentation

[`docs/DOCUMENTATION_OWNERSHIP.md`](docs/DOCUMENTATION_OWNERSHIP.md) is the authoritative map. Start with:

- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative behavior.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — current implementation and multiplayer authority model.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — open work and productionization path.
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — observed test outcomes.
- [`docs/spikes/`](docs/spikes/) and [`docs/adr/`](docs/adr/) — experimental evidence and durable decisions.
- [`COMPLIANCE.md`](COMPLIANCE.md) and [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md) — policy, provenance, and release controls.

Original project source is licensed under Apache-2.0. Project Zomboid assets and code are not redistributed or relicensed by this repository. Zombie Factions is an unofficial independent community mod.

## Other Workshop mods by this author

Published under Steam account [`bioinformer`](https://steamcommunity.com/id/bioinformer/myworkshopfiles/?appid=108600):

- [Trader Vending Machines - Network Tuner](https://steamcommunity.com/sharedfiles/filedetails/?id=3793134223)
- [Enshrouded Sleep - Release Candidate](https://steamcommunity.com/sharedfiles/filedetails/?id=3786842301)
