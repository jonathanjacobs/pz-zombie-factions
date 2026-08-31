# SPIKE-002 — Zombie Combat Presentation

Status: Closed — rejected; superseded by the successful SPIKE-003 standing-bite path
Target: Project Zomboid Build 42.20.x

## Question

Can the already validated, server-authorized zombie-versus-zombie combat route present as a readable physical fight—attack motion, target reaction, appropriate sound, and a non-abrupt death—without using unsupported animation states or changing combat authority?

## Audience

Historical record for the rejected presentation paths evaluated for closed Issue #3.

## Use this when

Reviewing why direct `bAttack` writes and zombie-target `pathToCharacter` were not retained.

## Update this when

Do not update this closed record. Record future presentation hypotheses in a new SPIKE.

## Do not update for

Unrelated faction policy, target discovery, persistence, or damage-amount changes.

## Boundary

ADR-001 remains in force. The server still authorizes targets and impacts, validates every world-changing hit, and finalizes death. The attacker owner controls only local presentation for its exact active grant. This spike must not use player hit packets, player representations, arbitrary `BumpType` values, or client-selected damage.

## v0.0.25 result

v0.0.25 did not satisfy the visible-fight acceptance criterion. Its direct writes to `bAttack` and `ZombieBiteDone` produced no Zombie Factions error, but controlled play showed no attack animation. The counters recorded variable-write attempts, not action-state entry, so they are not evidence of a native attack cycle. Those writes have been removed.

## v0.0.26 result

v0.0.26 did not satisfy the visible-fight acceptance criterion. Its one-shot `pathToCharacter(candidate)` prime did enter native-looking attack state on some clients, but it did not produce observed zombie-versus-zombie fighting. The dedicated-server client log recorded 209 `NetworkZombieMind: goal character is not set` errors.

Build 42's multiplayer zombie-path representation serializes a character goal only for a player target, so it cannot safely carry a zombie target. The native path prime and its metrics were removed in v0.0.27. The existing faction target, server-authorized impact, and death routes remain unchanged.

## Outcome

The next investigation used a mod-owned, explicitly synchronized visual presentation rather than the vanilla player-target attack path. SPIKE-003 validated the standing collision-driven bite route while retaining server-authorized damage. This record remains the evidence for rejecting the earlier paths.

## Historical acceptance boundary

Any future presentation experiment must not use a native character-path command with a zombie target. Treat `NetworkZombieMind: goal character is not set` as a failed route. New work must retain the ADR-001 authority boundary and use its own controlled acceptance criteria.

## Closeout

SPIKE-003 superseded these rejected paths, but its initial v0.0.31 closeout was later invalidated by a client crash and Issue #3 was reopened. This SPIKE remains closed because its own `bAttack` and zombie-target `pathToCharacter` approaches are still rejected.
