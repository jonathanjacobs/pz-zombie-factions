# Architecture

## Design objective

Zombie Factions adds a small diplomacy layer over Build 42 zombie targeting. The core service should answer four questions without owning unrelated zombie behavior:

```text
getZombieFaction(zombie)
getRelationship(sourceFaction, targetFaction)
canTarget(attacker, candidate)
shouldRetaliate(attacker, aggressor)
```

## Core model

```text
ZombieFactionRegistry
  ├─ vanilla
  ├─ red
  ├─ blue
  └─ ...

RelationshipMatrix
  source faction -> target identity -> FRIENDLY | NEUTRAL | HOSTILE
```

Player targets are resolved through the existing Project Zomboid player-faction system. Unfactioned players are represented by a reserved target identity rather than by creating a fake vanilla Faction object.

## Reserved identities

- `zf:vanilla` — built-in default zombie faction.
- `pf:unfactioned` — player with no vanilla faction.
- `pf:<name-or-stable-id>` — existing Project Zomboid player faction identity.

Exact serialization must be validated against Build 42 APIs before it is frozen.

## Data ownership

Faction assignment should use persistent zombie-associated data if Build 42 exposes a safe mechanism that survives save/load and multiplayer relevance changes. The implementation must not rely solely on transient Lua tables keyed by object instance.

The relationship matrix is server configuration/state and should be authoritative on the server. Clients should receive only the state required for UI or diagnostics.

## Targeting integration

The preferred architecture is an eligibility hook at or immediately before vanilla target acquisition. It should reject prohibited candidates before expensive pursuit/attack behavior begins.

A fallback design that repeatedly calls `setTarget(nil)` every update is specifically disfavored because it can create target reacquisition churn and scale poorly with zombie population.

## Zombie-vs-zombie combat

Build 42 exposes generic moving-object targeting, but that does not prove the complete downstream state machine supports `IsoZombie -> IsoZombie` combat. Before implementation, research must trace:

1. target discovery and candidate filtering;
2. target assignment;
3. pathing/pursuit assumptions;
4. attack-state type assumptions;
5. hit/damage processing;
6. death handling;
7. multiplayer synchronization and authority.

The result determines whether the runtime can remain Lua-only or requires a deeper extension point.

## Scope boundaries

The faction layer must not directly own:

- outfits or appearance;
- spawn regions or population composition;
- loot;
- zombie stats or special powers;
- territory;
- NPC faction logic.

Those systems may consume the faction API later.
