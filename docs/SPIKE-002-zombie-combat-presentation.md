# SPIKE-002 — Zombie Combat Presentation

Status: Active — v0.0.25 and v0.0.26 rejected; custom presentation path required
Target: Project Zomboid Build 42.20.x

## Question

Can the already validated, server-authorized zombie-versus-zombie combat route present as a readable physical fight—attack motion, target reaction, appropriate sound, and a non-abrupt death—without using unsupported animation states or changing combat authority?

## Audience

Developers validating Issue #3's observed static close-range combat.

## Use this when

Evaluating a supported, explicitly synchronized zombie-versus-zombie presentation path after v0.0.27.

## Update this when

A controlled client/server run confirms or rejects one of the presentation paths below.

## Do not update for

Unrelated faction policy, target discovery, persistence, or damage-amount changes.

## Boundary

ADR-001 remains in force. The server still authorizes targets and impacts, validates every world-changing hit, and finalizes death. The attacker owner controls only local presentation for its exact active grant. This spike must not use player hit packets, player representations, arbitrary `BumpType` values, or client-selected damage.

## v0.0.25 result

v0.0.25 did not satisfy the visible-fight acceptance criterion. Its direct writes to `bAttack` and `ZombieBiteDone` produced no Zombie Factions error, but controlled play showed no attack animation. The counters recorded variable-write attempts, not action-state entry, so they are not evidence of a native attack cycle. Those writes have been removed.

## v0.0.26 result

v0.0.26 did not satisfy the visible-fight acceptance criterion. Its one-shot `pathToCharacter(candidate)` prime did enter native-looking attack state on some clients, but it did not produce observed zombie-versus-zombie fighting. The dedicated-server client log recorded 209 `NetworkZombieMind: goal character is not set` errors.

Build 42's multiplayer zombie-path representation serializes a character goal only for a player target, so it cannot safely carry a zombie target. The native path prime and its metrics were removed in v0.0.27. The existing faction target, server-authorized impact, and death routes remain unchanged.

## Next presentation direction

The next spike must use a mod-owned, explicitly synchronized visual presentation instead of the vanilla player-target attack path. It must remain separate from target selection and server-authorized damage, and it must demonstrate a safe client-visible attack cycle before reaction, sound, crawler, or death embellishments are added.

## Controlled validation

1. Start a dedicated server and one client with clean v0.0.27 server and client logs.
2. Do not use a native character-path command with a zombie target. Treat any `NetworkZombieMind: goal character is not set` line as a failed presentation experiment.
3. First demonstrate a mod-owned, explicitly synchronized attacker animation in a 1v1 Red/Vanilla pair with both directions `HOSTILE`, on clear level ground.
4. Confirm at least ten visible attacker cycles with no frozen zombie while existing server-authorized damage and death remain synchronized.
5. Only after that baseline, test target reaction, sound, crawlers, a lethal hit, and a small size-8 mob separately. Stop on any red error, disconnect, or presentation regression.

## Acceptance

Issue #3 is not resolved by counters alone. It requires controlled multiplayer evidence that the selected presentation path produces repeated readable attack motion, does not leave a zombie frozen, preserves the ADR-001 authority boundary, and keeps existing damage/death synchronization intact. Reaction sounds, target hit reactions, crawler-specific behavior, and non-abrupt death presentation are individually unresolved until observed and recorded.
