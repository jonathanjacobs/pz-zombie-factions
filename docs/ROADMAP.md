# Roadmap

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

## Current milestone — productionize faction behavior

The validated diagnostic combat route is not yet normal gameplay behavior. The next milestone is persistent, server-configurable faction behavior for appropriately enrolled zombies, without relying on the admin SPIKE harness.

### Completed validation

- [x] Validate standing faction-combat presentation without a native zombie target, including isolated-pair contact, sound, damage, reactions, and absence of the prior client crash ([#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3); [SPIKE-003](spikes/SPIKE-003-synchronized-combat-presentation.md)).
- [x] Restore visible Horde Spawner controls. The controls themselves are fixed and every request reaching the button callback produces exactly one spawn. First-click reliability is not fixed: the v0.0.34 fix passed its own validation and the defect recurred, and the same happened again after v0.0.39 detached the hidden vanilla controls, so [#5](https://github.com/jonathanjacobs/pz-zombie-factions/issues/5) is open again. The remaining gap is between the physical click and the callback, which nothing currently logs.
- [x] Add independently configurable client/server combat-distance gates and adopt `0.80`/`1.60` as the defaults without weakening the remaining authority checks ([#1](https://github.com/jonathanjacobs/pz-zombie-factions/issues/1)).
- [x] Recheck stale standing-bite presentation under sustained crowd combat; the current build did not reproduce the visual defect, so no cancellation change was added ([#4](https://github.com/jonathanjacobs/pz-zombie-factions/issues/4)).
- [x] Validate the v0.0.38 dormant-mob-member fix. A follow-up mixed 24v24/240v240 run recorded a periodic-sweep reactivation of a previously dormant member three minutes after the last spawn, with no player action, and full activation of a 480-zombie double spawn within roughly ten seconds. Closed [#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2).
- [x] Add server-authoritative zombie speed assignment and establish sprinter locomotion during faction pursuit without a native zombie target ([SPIKE-005](spikes/SPIKE-005-sprinter-locomotion.md)). Speed assignment succeeded on 2,098 zombies across 23 spawn requests with no failures, covering all five selectors. Sprinters measured 2.5–2.8 times a same-run shambler control, with the mod's own animation node confirmed playing rather than only requested. Posture-based attack selection and damage authority were unaffected. A sprinter-only braking distance fixed the close-range circling this exposed; melee authorisation moved from never happening to an average pair distance of `0.51`–`0.54` tiles.

### Open follow-up work

- [ ] Validate the v0.0.37 standing-to-sitting stomp, accepted damage, native get-up transition, and subsequent standing behavior.
- [ ] Validate the v0.0.36 crawler combat matrix: crawler-to-crawler lunge, crawler-to-standing lunge, standing-to-crawler stomp, ordinary crawler-to-player regression, and standing-to-standing regression ([SPIKE-004](spikes/SPIKE-004-crawler-combat-profiles.md)).
- [ ] Close the remaining sprinter gaps left open by [SPIKE-005](spikes/SPIKE-005-sprinter-locomotion.md): the shortened `2.00` braking distance is assumed rather than measured; sprinter-versus-crawler and sprinter-versus-sitting produced only five and six samples respectively, too few to call a regression pass; and the ordinary sprinter-versus-player case was never exercised, with zero player-target events recorded in either sprinter session. The last of those is a short check and can ride along with any future run. [#6](https://github.com/jonathanjacobs/pz-zombie-factions/issues/6), [#8](https://github.com/jonathanjacobs/pz-zombie-factions/issues/8), and [#9](https://github.com/jonathanjacobs/pz-zombie-factions/issues/9) were deferred behind sprinter work and are now unblocked.
- [ ] Validate the v0.0.45 `NEUTRAL` retaliation behavior: that a Neutral zombie does not initiate, that it answers a validated attack, that hostility reaches the individual attacker and never its faction or mob, that an already-engaged victim keeps its fight while free neighbours answer, and that the authorization lapses cleanly. The discriminating case is a second attacker-faction zombie that never attacks and must be ignored throughout.
- [ ] Validate the Red/Blue/Vanilla relationship matrix across all directed pairings, including asymmetric cases such as Red → Blue `HOSTILE` with Blue → Red `NEUTRAL`.
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

Researched but deliberately parked, with the findings recorded on the issues rather than acted on:

- Faction acquisition currently uses a flat 12-tile radius with none of the line-of-sight, facing, light or probability gates the shipped game applies inside its own 10–20 tile vision range. Making it configurable, and deciding how much of that shipped shape to adopt, is [#12](https://github.com/jonathanjacobs/pz-zombie-factions/issues/12).
- Faction sprinters never stumble mid-chase, because the shipped trip roll requires a native target that faction pursuit deliberately holds clear. Reproducing it looks cheap but needs a get-up case in the safety interlock first: [#13](https://github.com/jonathanjacobs/pz-zombie-factions/issues/13).
- Combat vocalizations are absent for the same reason, tracked as [#7](https://github.com/jonathanjacobs/pz-zombie-factions/issues/7).
