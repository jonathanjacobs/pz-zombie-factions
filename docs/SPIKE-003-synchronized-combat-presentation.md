# SPIKE-003 — Explicitly Synchronized Combat Presentation

Status: Active — native bumped-state collision probe added in v0.0.30
Target: Project Zomboid Build 42.20.x

## Question

Can a locally owned faction zombie enter a readable native bite presentation on collision with its assigned opposing zombie, while the server retains damage authority?

## Audience

Developers validating the next presentation path for Issue #3.

## Use this when

Testing a dedicated server with v0.0.30 and mutually Hostile diagnostic factions.

## Update this when

The controlled runtime test confirms or rejects this presentation cue.

## Do not update for

Target-policy, damage-amount, or unrelated performance changes.

## Boundary

The owner client arms `BumpType=Bite` only for its locally resolved, alive, same-level assigned pair inside the existing melee envelope. A real `OnCharacterCollide` event is the only path that requests a hit. The server then revalidates the active pair, faction policy, ownership, range, cooldown, and pending-hit state before dispatching target-owner damage. The animation node lives in the existing zombie `bumped` set and reuses vanilla `Zombie_Bite_Start`; it does not attach a zombie character goal, call `pathToCharacter`, or write native `bAttack`. A short owner-local timeout clears an unconsumed bite bump.

## Controlled validation

1. Start a dedicated server and one client with clean v0.0.30 logs.
2. Spawn a 1v1 Red/Vanilla pair with both directions `HOSTILE` on clear, level ground.
3. Confirm repeated visible attacker bite motion at contact, without the previous outstretched-arm freeze or `NetworkZombieMind: goal character is not set` errors.
4. Confirm the client summary reports nonzero `biteBumpsArmed` and `biteCollisions`; if bites arm but collisions remain zero, collect logs before changing damage behavior.
5. Confirm existing damage, lethal death/corpse synchronization, and player-target behavior remain unchanged.
6. Do not treat crawler, reaction, sound, or crowd behavior as accepted until the standing 1v1 bite/collision path is observed.

## Acceptance

This spike succeeds only with direct multiplayer observation of repeated readable attacker movement and clean logs. Counters alone do not resolve Issue #3.
