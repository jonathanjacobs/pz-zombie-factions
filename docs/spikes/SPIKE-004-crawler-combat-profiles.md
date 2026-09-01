# SPIKE-004 — Crawler combat profiles

Status: v0.0.36 mixed-crowd pass / v0.0.37 sitting alert retry awaiting validation
Target: Project Zomboid Build 42.20.x
Implementation: v0.0.36-v0.0.37

## Question

Can the existing server-authorized faction combat route support crawler attackers and defenders without assigning an `IsoZombie` as a native target or relying on crawler character-collision delivery?

## Implemented probe

- `CRAWLER_LUNGE` uses the shipped `Zombie_CrawlLunge` clip in the crawler's existing targetless hit-reaction state.
- `STANDING_STOMP` uses the shipped `Bob_AttackFloorStamp` clip in the standing zombie's existing bumped state.
- `STANDING_BITE` retains its accepted real-character-collision request source.
- Crawler lunges and stomps expose one mod-owned animation contact window. The owner client may request one impact only for its exact active grant while the pair remains close, same-level, posture-consistent, and melee-authorized.
- The server independently derives the expected profile and evidence type, then retains the existing identity, policy, ownership, cooldown, liveness, distance, target-owner acknowledgement, and lethal-finalization checks.
- Crawler defenders use the shipped crawler floor-reaction path. Standing defenders of crawler lunges use a mod-owned mapping to the shipped low crawler-bite reaction.
- Version 0.0.37 treats shipped `isSitAgainstWall()` defenders as low posture for standing attackers and reuses `STANDING_STOMP`. The first runtime attempt proved stomp selection and damage but showed that writing the `alerted` animation variable did not wake the target. A second attempt selected target-owner `setTurnAlertedValues()` but failed before that method ran because the callback read an undefined client-local attacker variable. The corrected retry carries the server-validated attacker coordinates in the damage dispatch and passes those coordinates to the target-owner alert route without emitting a world sound or requiring cross-client attacker resolution. It also locks the attacking pair after the first sitting stomp until the defender completes the get-up and remains stably standing, then permits posture selection to switch to `STANDING_BITE`; a bounded timeout permits another stomp when the wake fails.

The probe does not copy native `AttackCollisionCheck`, player-reaction, voice, melee-delay, or stomp events. It does not use `setTarget(IsoZombie)`, `bAttack`, player hit packets, or timer-only damage.

## Acceptance matrix

The repeatable procedure and required counters are maintained in [`../TESTING.md`](../TESTING.md). Acceptance requires damaging crawler-to-crawler, crawler-to-standing, and standing-to-crawler outcomes; a normal corpse lifecycle; an unchanged crawler-to-player route; a standing-combat regression pass; and no native-target crash or latched presentation state.

## Runtime observation

The supplied v0.0.36 paired one-client/dedicated-server logs contain sustained traffic for all three profiles. Periodic client summaries total 354 crawler-lunge impacts, 826 stomp impacts, 702 standing-bite collisions, 564 crawler floor reactions, and 119 low standing reactions. Periodic server summaries total 1,900 requests, 1,678 dispatches, 1,677 accepted outcomes, 215 distance rejections, zero profile rejections, and zero configuration mismatches. No Zombie Factions exception or prior native-target crash signature was present. The operator reported that the tested crawler/stomp behavior worked well and identified sitting defenders as the remaining visible gap.

These mixed-crowd totals do not independently prove every isolated pairing, ordinary crawler-to-player behavior, corpse lifecycle, two-client ownership, or broader compatibility.

The first v0.0.37 sitting run recorded 11 seated stomp armings, 11 matching impacts, and seven owner-side get-up requests, but zero observed standing transitions. Direct observation confirmed that a separate sound event woke the same sitting zombies. This establishes that stomp selection and damage worked while the original animation-variable-only wake mechanism did not.

The second v0.0.37 run again produced sustained sitting stomp traffic but recorded zero alerted or standing defenders. The client repeatedly reported `getX` access on a nil value from the sitting reaction callback. The error occurred while preparing coordinates, before `setTurnAlertedValues()` executed, so this run does not test whether the native alert route wakes the defender. The corrected server-coordinate dispatch remains awaiting validation.
