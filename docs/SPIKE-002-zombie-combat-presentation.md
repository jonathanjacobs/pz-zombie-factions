# SPIKE-002 — Zombie Combat Presentation

Status: Active — implementation probe added in v0.0.25
Target: Project Zomboid Build 42.20.x

## Question

Can the already validated, server-authorized zombie-versus-zombie combat route present as a readable physical fight—attack motion, target reaction, appropriate sound, and a non-abrupt death—without using unsupported animation states or changing combat authority?

## Audience

Developers validating Issue #3's observed static close-range combat.

## Use this when

Testing the diagnostic Horde Spawning harness with mutually Hostile factions after v0.0.25.

## Update this when

A controlled client/server run confirms or rejects one of the presentation paths below.

## Do not update for

Unrelated faction policy, target discovery, persistence, or damage-amount changes.

## Boundary

ADR-001 remains in force. The server still authorizes targets and impacts, validates every world-changing hit, and finalizes death. The attacker owner controls only local presentation for its exact active grant. This spike must not use player hit packets, player representations, arbitrary `BumpType` values, or client-selected damage.

## v0.0.25 implementation probe

The installed Build 42 action graphs for both standing zombies and crawlers transition to their attack state only when `bAttack` and `isFacingTarget` are true. Their attack state completes when `ZombieBiteDone` is true. For an eligible, close-range faction pair, the owner-local impact controller now:

1. faces the granted candidate;
2. sets `ZombieBiteDone=false` and `bAttack=true` at the start of its existing staggered windup;
3. sends the existing server-validated impact at the already scheduled hit point; and
4. sets `bAttack=false` and `ZombieBiteDone=true` when the windup is completed, cancelled, or superseded.

This is presentation-only. It neither selects a target nor creates damage, and it does not revive the invalid `BumpType` writes removed in v0.0.24. The controller reports `nativeAttackStarts` and `nativeAttackCompletions` in `[ZombieFactions][PERF]` so the runtime result can be correlated with observed animation.

## Controlled validation

1. Start a dedicated server and one client with clean v0.0.25 server and client logs.
2. Use the diagnostic Horde Spawning checkbox to create a 1v1 Red/Vanilla pair with both directions `HOSTILE`, on clear level ground and with a separation of several tiles.
3. Observe at least ten successful impacts. Confirm each attacker visibly enters and exits a bite/attack cycle rather than remaining with arms extended, while damage and death still synchronize.
4. Repeat with one crawler if the diagnostic spawn produces one. Confirm it follows a crawler attack path without an exception or stuck animation.
5. Confirm the five-second client summary shows nonzero, roughly paired `nativeAttackStarts` and `nativeAttackCompletions`, and `invalidAttackBumpsRecovered=0` after a clean restart.
6. Capture whether the vanilla animation emits attack and reaction sounds. Do not add guessed sound-event names if it does not.
7. Observe a lethal hit. Record whether the normal corpse lifecycle includes a visible death transition; do not replace it with a custom death or ragdoll state unless a supported, synchronized path is separately demonstrated.
8. Repeat with a small size-8 mob before treating the probe as scalable. Stop on any frozen zombie, red error, disconnect, or regression in validated damage/death synchronization.

## Acceptance

Issue #3 is not resolved by counters alone. It requires controlled multiplayer evidence that the selected presentation path produces repeated readable attack motion, does not leave a zombie frozen, preserves the ADR-001 authority boundary, and keeps existing damage/death synchronization intact. Reaction sounds, target hit reactions, crawler-specific behavior, and non-abrupt death presentation are individually unresolved until observed and recorded.
