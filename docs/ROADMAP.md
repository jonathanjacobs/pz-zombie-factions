# Roadmap

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

## Current milestone — productionize faction behavior

The validated diagnostic combat route is not yet normal gameplay behavior. The next milestone is persistent, server-configurable faction behavior for appropriately enrolled zombies, without relying on the admin SPIKE harness.

### Open follow-up work

- [ ] Revalidate standing faction-combat presentation without a native zombie target and close the client-crash regression ([#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3); [SPIKE-003](spikes/SPIKE-003-synchronized-combat-presentation.md)).
- [ ] Prevent stale faction bite presentations without truncating a valid bite ([#4](https://github.com/jonathanjacobs/pz-zombie-factions/issues/4)).
- [ ] Restore event-driven recovery for a dormant member while another mob member remains active ([#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2)).
- [ ] Reduce server distance-rejected impact requests without weakening validation ([#1](https://github.com/jonathanjacobs/pz-zombie-factions/issues/1)).
- [ ] Validate the Red/Blue/Vanilla relationship matrix, including expected Neutral behavior.
- [ ] Profile client FPS and server load at mob size `8`, then test larger mobs only if the evidence supports it.
- [ ] Validate real ownership transfer, save/restart, and relevance lifecycle transitions.

## Production faction behavior

- [ ] Enroll naturally spawned and relevance-loaded zombies outside the diagnostic harness.
- [ ] Persist faction assignment across supported lifecycle transitions.
- [ ] Make relationship behavior persistent and server-configurable rather than a diagnostic checkbox.
- [ ] Resolve Project Zomboid player factions and unfactioned players.
- [ ] Retain bounded diagnostics suitable for real servers.

## Deferred layers

Appearance, population rules, territory, abilities, loot, NPC integrations, and a public third-party API are separate layers. They are not prerequisites for the current faction-behavior milestone.
