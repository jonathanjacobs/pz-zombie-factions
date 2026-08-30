# SPIKE-003 — Explicitly Synchronized Combat Presentation

Status: Active — custom action-state probe added in v0.0.29
Target: Project Zomboid Build 42.20.x

## Question

Can a server-validated faction impact trigger a readable zombie attack presentation on every relevant client without using a zombie character-path goal?

## Audience

Developers validating the next presentation path for Issue #3.

## Use this when

Testing a dedicated server with v0.0.29 and mutually Hostile diagnostic factions.

## Update this when

The controlled runtime test confirms or rejects this presentation cue.

## Do not update for

Target-policy, damage-amount, or unrelated performance changes.

## Boundary

The server sends a cue only after it has validated the exact active pair, range, policy, ownership, and impact cooldown. The cue cannot select a target or damage a zombie. Clients apply it only to locally resolved, alive, same-level pairs inside the existing server maximum impact range. A client sets a temporary, mod-owned action-graph variable that routes the attacker through vanilla `Zombie_Bite_Start` and `Zombie_Bite_Success` clips; it does not attach a zombie target, call `pathToCharacter`, write native `bAttack`, or emit vanilla player-hit events. The XML action nodes clear the variable at the end of the bite, with a bounded Lua recovery path for interrupted animation.

## Controlled validation

1. Start a dedicated server and one client with clean v0.0.29 logs.
2. Spawn a 1v1 Red/Vanilla pair with both directions `HOSTILE` on clear, level ground.
3. Confirm repeated visible attacker bite/lunge motion at validated impacts without `NetworkZombieMind: goal character is not set` errors.
4. Confirm client summaries report nonzero `presentationCues`, `presentationStarts`, and `presentationRetired`; investigate any unexpected high `presentationSuppressed` count.
5. Confirm existing damage, lethal death/corpse synchronization, and player-target behavior remain unchanged.
6. Do not test crawlers, target reaction, sound, or crowd scaling as acceptance for this spike until the standing 1v1 presentation is observed.

## Acceptance

This spike succeeds only with direct multiplayer observation of repeated readable attacker movement and clean logs. Counters alone do not resolve Issue #3.
