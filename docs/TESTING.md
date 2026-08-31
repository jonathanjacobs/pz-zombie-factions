# Testing

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

## Environment

Use a dedicated Build 42.20.x server and at least one client. Capture clean client and server logs for each focused test. Do not treat an administrator's visual impression alone as sufficient evidence for multiplayer authority or damage behavior.

## Baseline faction-combat procedure

1. Confirm the installed mod reports the intended version in both server and client logs.
2. Use the administrator Horde Spawning extension to create the selected diagnostic faction pair on clear, level ground.
3. Set both relationship directions to `HOSTILE`; record the intended pair and mob-size setting.
4. Observe pursuit, contact, standing bite presentation, damage, and lethal corpse handling.
5. Review `[ZombieFactions][PERF]` and `[ZombieFactions][SERVER_PERF]` summaries for errors, arm/collision counts, bite sounds, defender reactions, accepted damage, native-target clears, and distance rejections.
6. Record the observed result in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). Put a new hypothesis, rejected approach, or detailed diagnostic interpretation in a SPIKE instead.

## Focused follow-ups

- Use v0.0.34 as the accepted dedicated-server, one-client standing baseline. Regression runs should require nonzero `biteCollisions`, `impactRequests`, `biteSoundsPlayed`, `hitReactionsArmed`, and accepted server damage before adding more zombies, while retaining `impactExactTarget=0` and no `AttackState.triggerPlayerReaction` exception.
- Retain the Issue #5 regression check: open Horde Spawning, select a faction test spawn, click Spawn once, and require exactly one client success plus one server spawn request. Repeat after changing count and faction without closing the window.
- Test two-client attacker/defender ownership separation and mixed crawler crowds as follow-up scopes; neither is established by the accepted v0.0.34 run.
- Test Issue #4 with moving, dying, and retargeted defenders; distinguish a clean cancellation from a normal completed bite.
- Treat crawling zombies as deferred from the standing-only bite path unless a dedicated validation case changes that status.
- Test player behavior separately whenever faction-combat code changes.

## Issue #1 distance-envelope matrix

Version 0.0.35 exposes two diagnostic sandbox options, both measured in planar tiles:

- `ZombieFactions.ClientCollisionDistance` — owner-client request gate; default `0.80`, range `0.25`–`2.00`. A real `OnCharacterCollide` event remains mandatory.
- `ZombieFactions.ServerValidationDistance` — authoritative server distance gate; default `1.60`, range `0.25`–`2.00`. Every other server validation remains mandatory.

Restart the server after changing either option so all grants use one configuration. Confirm the server load marker, client tracking record, and both performance summaries report the intended values; require `damageConfigMismatch=0`.

For each combination, run the same sequence with clean logs:

1. Spawn a mutually hostile standing Red/Vanilla 1v1 pair on clear, level ground. Observe for at least 60 seconds or until one participant dies.
2. Record `biteCollisions`, `impactRequests`, `damageRequests`, `damageDispatched`, `damageDistanceRejected`, `damageAccepted`, and the server distance aggregates.
3. Repeat with mob size `8` and the same Red/Vanilla counts, spawn radius, observation time, and zombie-speed mix for every combination.
4. Record visible distant hits, stalled combat, deaths, client FPS, faction errors, and disconnects. Do not compare rejection ratios across runs with different crowd setup or duration.

Recommended first matrix:

| Client | Server | Purpose |
| ---: | ---: | --- |
| `0.80` | `1.60` | Accepted v0.0.35 default. |
| `0.90` | `1.25` | Accepted v0.0.34 baseline. |
| `0.90` | `1.50` | Isolate additional server latency tolerance. |
| `0.75` | `1.25` | Test whether a tighter client request gate removes late requests. |
| `1.00` | `1.50` | Explore a wider paired envelope only after the first three runs remain visually contact-driven. |

A useful candidate materially lowers `damageDistanceRejected / damageRequests` without distant-looking hits, duplicate damage, reduced sustained deaths, authority/configuration mismatches, or new errors. Record actual outcomes in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); do not infer a preferred production value from configuration alone.
