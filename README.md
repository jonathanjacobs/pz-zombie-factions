# Zombie Factions

A Project Zomboid Build 42 framework for zombie-faction identity and directional `FRIENDLY`, `NEUTRAL`, and `HOSTILE` relationships.

- Status: **Research / Pre-Alpha**
- Current version: **v0.0.38**
- Target baseline: **Project Zomboid Build 42.20.x**

## Current state

SPIKE-001 established faction-aware zombie pursuit, synchronized damage, and normal lethal corpse handling in dedicated-server testing. SPIKE-003 closed successfully for the dedicated-server, one-client standing-zombie scope. A v0.0.36 mixed-crowd run exercised crawler lunges, standing stomps, and standing bites with accepted server damage and no profile mismatch or Zombie Factions exception. Version 0.0.37 added an unvalidated seated-defender rule: standing attackers stomp sitting zombies, which then use the shipped get-up transition after accepted nonlethal damage. Version 0.0.38 fixes [#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2): idle members of an already-active mob now get individually swept for a fresh target instead of being permanently skipped by the maintenance pass. A follow-up dedicated-server run confirmed the sweep reactivating a previously dormant member on its own, and closed the issue.

The current implementation remains diagnostic tooling. The administrator Horde Spawning extension creates selected test factions and an opt-in SPIKE harness; ordinary vanilla spawning remains unchanged when it is disabled. Production enrollment, persistence, and relationship behavior outside the harness remain planned work.

## Scope and current limits

- Zombies resolve to one zombie faction; `zf:vanilla` is the default.
- Relationships are directional and use `FRIENDLY`, `NEUTRAL`, or `HOSTILE`.
- Default installation preserves normal vanilla behavior.
- Standing bites, the v0.0.36 mixed-crowd crawler/stomp route, and the v0.0.38 dormant-mob-member fix have dedicated-server runtime evidence. The v0.0.37 seated-stomp/get-up extension has server-side profile-transition evidence consistent with a working get-up but no confirming client-side counters; two-client ownership also remains follow-up work.
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
