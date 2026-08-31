# SPIKE-003 — Explicitly Synchronized Combat Presentation

Status: Active — reopened after the v0.0.31 client crash; v0.0.32 correction awaits validation
Target: Project Zomboid Build 42.20.x

## Question

Can a locally owned faction zombie play a readable native bite and a target-owner zombie reaction without attaching the defender as a native target or allowing player-oriented `AttackState` to own the interaction?

## Boundary

ADR-001 remains in force. The server owns faction policy, pair grants, impact validation, and lethal finalization. Client presentation is best-effort and cannot create damage authority.

Version 0.0.32 uses coordinate pursuit, stops and faces the defender inside the melee envelope, and requires the attacker's native target to remain clear. A mod-owned `bumped` sequence maps to the shipped `Zombie_Bite_Start` and `Zombie_Bite_Success` clips. A real `OnCharacterCollide` event remains the only hit-request source. After a server-dispatched nonlethal hit is applied, the target owner may play a separate mod-owned `Zombie_ShotShoulder_L` reaction.

The probe must not use `setTarget(IsoZombie)`, `pathToCharacter` with a zombie target, player hit packets, native `bAttack`, native hit-reaction state transitions, or standing clips for crawlers.

## v0.0.31 invalidation

The initial v0.0.31 test showed the full standing bite and server-validated damage, so Issue #3 was closed. A later mixed-crowd stress test invalidated that closeout. The client threw `ClassCastException: IsoZombie cannot be cast to IsoPlayer` at `AttackState.triggerPlayerReaction`, then force-disconnected with reason `crash`. The server only observed the resulting disconnect.

The crash occurred because the melee controller attached the zombie defender through `setTarget(candidate)`, allowing native player-oriented `AttackState` to receive an animation event. Crawler pairs were being deferred (`crawlerBitesDeferred=35` immediately before the crash); crawler spawning is not established as the cause.

## v0.0.32 hypothesis

Removing native zombie-target attachment should prevent `AttackState` from treating a faction defender as a player while preserving coordinate pursuit, mod-owned bite presentation, collision-driven requests, and server validation. A separate target-owner bumped reaction should provide readable feedback without entering native hit-reaction state or adding damage effects.

## Controlled validation

1. Start a dedicated server and one client with clean v0.0.32 logs.
2. Spawn a standing 1v1 Red/Vanilla pair with both directions `HOSTILE` on clear, level ground.
3. Confirm repeated Start-to-Success bites, nonzero `biteCollisions`, accepted server damage, and visible target reactions when `hitReactionsArmed` increments.
4. Require `impactExactTarget=0` throughout the accepted run. Investigate any `nativeZombieTargetsCleared` count; it is a recovered invariant violation, not normal engagement behavior.
5. Treat any `AttackState.triggerPlayerReaction`, `IsoZombie`-to-`IsoPlayer` cast, crash, disconnect, frozen bump, duplicate damage, or player-behavior regression as a failure.
6. Repeat with two clients so attacker and defender ownership can differ; confirm one damage application and at most one reaction per hit ID.
7. Test target movement, target death, ownership loss, release, and stale grants.
8. Stress standing crowds before introducing mixed crawler crowds. Crawlers remain deferred and should increment `crawlerBitesDeferred` without entering standing presentation.

## Acceptance

SPIKE-003 remains open until direct multiplayer observation confirms the v0.0.32 no-native-target invariant, readable bite/reaction presentation, clean ownership behavior, and absence of the v0.0.31 crash. Issue #4 continues to track non-crashing stale/air-bite polish separately.
