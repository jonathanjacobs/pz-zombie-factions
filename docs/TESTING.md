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

- For v0.0.33, begin with standing 1v1 and require nonzero `biteCollisions`, `impactRequests`, `biteSoundsPlayed`, `hitReactionsArmed`, and accepted server damage before adding more zombies. Confirm varied shoulder/chest reactions, `impactExactTarget=0`, and no `AttackState.triggerPlayerReaction` exception. Then test two-client ownership, death, target loss, standing crowds, and finally mixed crawler crowds.
- For Issue #5, open Horde Spawning, select a faction test spawn, click Spawn once, and require exactly one client success plus one server spawn request. Repeat after changing count and faction without closing the window.
- Test Issue #4 with moving, dying, and retargeted defenders; distinguish a clean cancellation from a normal completed bite.
- Treat crawling zombies as deferred from the standing-only bite path unless a dedicated validation case changes that status.
- Test player behavior separately whenever faction-combat code changes.
