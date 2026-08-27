# Requirements

## R1 — Faction identity

1. Every zombie shall resolve to exactly one zombie faction.
2. Zombies without explicit assignment shall resolve to the built-in `vanilla` faction.
3. Faction IDs shall be stable string identifiers.
4. Custom zombie factions shall be registrable without modifying the built-in faction.

## R2 — Relationship model

1. Relationships shall be directional: source faction -> target faction.
2. Valid values shall be `FRIENDLY`, `NEUTRAL`, and `HOSTILE`.
3. A faction's relationship toward itself shall default to `FRIENDLY`.
4. Missing custom relationships shall fall back to safe defaults rather than causing an error.

## R3 — Behavioral semantics

- `FRIENDLY`: do not proactively target and do not retaliate solely because damage was received.
- `NEUTRAL`: do not proactively target; retaliation may occur after direct aggression.
- `HOSTILE`: candidate may be proactively detected, selected, pursued, and attacked.

These semantics describe intended policy. Actual Build 42 hooks must be validated before runtime behavior is claimed.

## R4 — Player integration

1. Zombie factions shall be able to resolve relationships toward Project Zomboid player factions.
2. Unfactioned players shall be addressable as a distinct relationship target.
3. Zombie Factions shall not replace or fork Project Zomboid's player-faction system.

## R5 — Vanilla compatibility

1. Installing the mod with no custom faction configuration shall preserve ordinary vanilla zombie behavior toward players.
2. Vanilla zombies shall not begin attacking other vanilla zombies by default.
3. The implementation shall avoid per-tick target clearing/reassignment loops that fight the vanilla AI.

## R6 — Multiplayer authority

Targeting, hostility, retaliation, and damage decisions that affect world state must have an authoritative server-side design. Client-side presentation may mirror state but must not be the sole authority.

## R7 — Scope separation

Faction identity and diplomacy shall remain independent from zombie appearance, outfit, spawn rules, territory, loot, skills, or special abilities. Those may be layered on later.

## MVP acceptance criteria

The MVP is complete when controlled Build 42 multiplayer testing demonstrates:

1. a vanilla zombie and custom-faction zombie can be assigned deterministic faction identities;
2. friendly relationships suppress prohibited targeting;
3. neutral relationships suppress proactive targeting and implement the chosen retaliation rule;
4. hostile relationships permit intended targeting;
5. at least one supported zombie-vs-zombie hostile encounter completes pursuit and damage reliably, or the project explicitly documents an engine limitation preventing that feature;
6. vanilla behavior is unchanged when no custom configuration is active;
7. no material server-stability or runaway-command/logging issue is introduced.
