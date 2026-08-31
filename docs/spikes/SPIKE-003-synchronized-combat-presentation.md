# SPIKE-003 — Explicitly Synchronized Combat Presentation

Status: Closed successfully — 2026-08-30 (dedicated server, one client, standing zombies)
Target: Project Zomboid Build 42.20.x

## Question

Can a locally owned faction zombie play a readable native bite and a target-owner zombie reaction without attaching the defender as a native target or allowing player-oriented `AttackState` to own the interaction?

## Boundary

ADR-001 remains in force. The server owns faction policy, pair grants, impact validation, and lethal finalization. Client presentation is best-effort and cannot create damage authority.

Version 0.0.34 uses the v0.0.33 combat candidate unchanged: coordinate pursuit through the broad animation envelope, a tighter contact distance, and a clear attacker native target. A mod-owned `bumped` sequence maps to the shipped `Zombie_Bite_Start` and `Zombie_Bite_Success` clips. A real `OnCharacterCollide` event remains the only hit-request source and emits one owner-local shipped `ZombieBite` sound. After a server-dispatched nonlethal hit is applied, the target owner may select one of four mod-owned reactions mapped to shipped left/right shoulder and chest clips.

The probe must not use `setTarget(IsoZombie)`, `pathToCharacter` with a zombie target, player hit packets, native `bAttack`, native hit-reaction state transitions, or standing clips for crawlers.

## v0.0.31 invalidation

The initial v0.0.31 test showed the full standing bite and server-validated damage, so Issue #3 was closed. A later mixed-crowd stress test invalidated that closeout. The client threw `ClassCastException: IsoZombie cannot be cast to IsoPlayer` at `AttackState.triggerPlayerReaction`, then force-disconnected with reason `crash`. The server only observed the resulting disconnect.

The crash occurred because the melee controller attached the zombie defender through `setTarget(candidate)`, allowing native player-oriented `AttackState` to receive an animation event. Crawler pairs were being deferred (`crawlerBitesDeferred=35` immediately before the crash); crawler spawning is not established as the cause.

## v0.0.32 hypothesis

Removing native zombie-target attachment should prevent `AttackState` from treating a faction defender as a player while preserving coordinate pursuit, mod-owned bite presentation, collision-driven requests, and server validation. A separate target-owner bumped reaction should provide readable feedback without entering native hit-reaction state or adding damage effects.

## v0.0.32 result and v0.0.33 hypothesis

The controlled v0.0.32 run did not repeat the faction crash. Across the run, `impactExactTarget=0` and `nativeZombieTargetsCleared=0`; crowd contact produced collision requests, accepted damage, deaths, and occasional reactions. This supports the no-native-target safety hypothesis.

The isolated opening pair repeatedly armed and completed bite presentation while `biteCollisions=0` and `impactRequests=0`. Damage began only after larger groups forced physical contact. The controller was canceling coordinate pursuit at the broad `1.20` animation envelope while damage still required real collision. Version 0.0.33 retains the envelope for obstacle checks, arms presentation at `0.65` while continuing toward smaller distributed approach slots, and stops only at `0.50` contact distance.

The same run produced no faction bite sound and only one reaction clip. Version 0.0.33 emits `ZombieBite` once per collision-driven request and randomly selects four bounded reaction clips. The Horde Spawner also reused duplicate bottom coordinates; v0.0.33 removes the duplicate controls and lays out the original controls after resizing.

## v0.0.34 result

The controlled dedicated-server, one-client run passed the standing scope. Before reinforcements were spawned, the isolated opening pair produced six collision-driven requests and sounds on the client, while the server had already accepted two damage applications. Across the full run, the client recorded 218 collisions, 218 impact requests, 218 bite sounds, and 17 armed reactions. The server accepted 132 damage acknowledgments. `impactExactTarget=0` and `nativeZombieTargetsCleared=0` remained true, and neither faction controller errors nor the v0.0.31 crash signature appeared.

The Horde Spawner rendered its independent post-resize controls. Four client spawn successes matched four server spawn events, and direct observation confirmed successful first-click behavior. The server rejected 81 requests by distance; that tuning remains tracked by Issue #1 and does not invalidate the accepted hits. This run did not exercise two-client ownership separation or crawler presentation.

## Controlled validation

1. Start a dedicated server and one client with clean v0.0.34 logs. Confirm the four bottom Horde Spawner controls are visible and one Spawn click produces exactly one spawn before beginning combat validation.
2. Spawn a standing 1v1 Red/Vanilla pair with both directions `HOSTILE` on clear, level ground.
3. Before spawning reinforcements, confirm repeated Start-to-Success bites, nonzero `biteCollisions`, `impactRequests`, `biteSoundsPlayed`, accepted server damage, and varied target reactions when `hitReactionsArmed` increments.
4. Require `impactExactTarget=0` throughout the accepted run. Investigate any `nativeZombieTargetsCleared` count; it is a recovered invariant violation, not normal engagement behavior.
5. Treat any `AttackState.triggerPlayerReaction`, `IsoZombie`-to-`IsoPlayer` cast, crash, disconnect, frozen bump, duplicate damage, or player-behavior regression as a failure.
6. Repeat with two clients so attacker and defender ownership can differ; confirm one damage application and at most one reaction per hit ID.
7. Test target movement, target death, ownership loss, release, and stale grants.
8. Stress standing crowds before introducing mixed crawler crowds. Crawlers remain deferred and should increment `crawlerBitesDeferred` without entering standing presentation.
9. Independently verify that one Spawn-button click creates exactly one client success and one server spawn request.

## Closeout

SPIKE-003 answers its question affirmatively for standing zombies in the tested dedicated-server, one-client configuration. A locally owned attacker can present a shipped native bite, collision-timed sound, and server-validated damage while the target owner presents bounded reactions, without attaching the defender as a native target or entering player-oriented `AttackState` behavior. Issue #3 may close for that original standing-animation scope, and Issue #5 may close for the validated Horde Spawner correction.

Two-client ownership separation and crawler presentation remain explicit follow-up validation rather than implied closeout evidence. Issue #4 continues to track non-crashing stale/air-bite polish, and Issue #1 continues to track distance-rejected requests.
