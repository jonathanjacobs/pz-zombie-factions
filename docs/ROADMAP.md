# Roadmap

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

## Current milestone — productionize faction behavior

The validated diagnostic combat route is not yet normal gameplay behavior. The next milestone is persistent, server-configurable faction behavior for appropriately enrolled zombies, without relying on the admin SPIKE harness.

### Completed validation

- [x] Validate standing faction-combat presentation without a native zombie target, including isolated-pair contact, sound, damage, reactions, and absence of the prior client crash ([#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3); [SPIKE-003](spikes/SPIKE-003-synchronized-combat-presentation.md)).
- [x] Restore visible Horde Spawner controls and confirm one server spawn for each first-click client success ([#5](https://github.com/jonathanjacobs/pz-zombie-factions/issues/5)).
- [x] Add independently configurable client/server combat-distance gates and adopt `0.80`/`1.60` as the defaults without weakening the remaining authority checks ([#1](https://github.com/jonathanjacobs/pz-zombie-factions/issues/1)).
- [x] Recheck the suspected dormant active-mob member defect under explicit mutual hostility; the stress run did not reproduce a player-visible failure, so no speculative recovery change was added ([#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2)).
- [x] Recheck stale standing-bite presentation under sustained crowd combat; the current build did not reproduce the visual defect, so no cancellation change was added ([#4](https://github.com/jonathanjacobs/pz-zombie-factions/issues/4)).

### Open follow-up work

- [ ] Validate the v0.0.37 standing-to-sitting stomp, accepted damage, native get-up transition, and subsequent standing behavior.
- [ ] Validate the v0.0.36 crawler combat matrix: crawler-to-crawler lunge, crawler-to-standing lunge, standing-to-crawler stomp, ordinary crawler-to-player regression, and standing-to-standing regression ([SPIKE-004](spikes/SPIKE-004-crawler-combat-profiles.md)).
- [ ] Validate the Red/Blue/Vanilla relationship matrix, including expected Neutral behavior.
- [ ] Profile client FPS and server load at mob size `8`, then test larger mobs only if the evidence supports it.
- [ ] Validate two-client attacker/defender ownership separation, real ownership transfer, save/restart, and relevance lifecycle transitions.

## Production faction behavior

- [ ] Enroll naturally spawned and relevance-loaded zombies outside the diagnostic harness.
- [ ] Persist faction assignment across supported lifecycle transitions.
- [ ] Make relationship behavior persistent and server-configurable rather than a diagnostic checkbox.
- [ ] Resolve Project Zomboid player factions and unfactioned players.
- [ ] Retain bounded diagnostics suitable for real servers.

## Deferred layers

Appearance, population rules, territory, abilities, loot, NPC integrations, and a public third-party API are separate layers. They are not prerequisites for the current faction-behavior milestone.
