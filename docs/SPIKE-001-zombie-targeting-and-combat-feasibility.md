# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Open  
Target: Project Zomboid Build 42.20.x

## Question

Can Zombie Factions enforce directional faction relationships at a clean target-eligibility boundary, and can a vanilla `IsoZombie` reliably pursue, attack, damage, and kill another `IsoZombie` in Build 42 multiplayer?

## Evidence

Use Project Zomboid Build 42 API documentation, controlled runtime tests/logs, and the privately supplied decompiled Build 42 source as implementation research. Decompiled game source is not to be copied into this repository.

## Trace

Follow the complete path through:

1. candidate discovery and filtering;
2. target assignment;
3. pathfinding/pursuit;
4. attack-state entry and target-type assumptions;
5. hit/damage processing;
6. death handling;
7. server/client authority and synchronization;
8. save/load and relevance transitions.

## Preferred result

Find a supported hook or narrow interception point where faction policy can reject a candidate before vanilla pursuit begins:

```text
canTarget(attacker, candidate)
  -> resolve identities
  -> resolve relationship
  -> HOSTILE = eligible
```

Do not default to globally scanning zombies and repeatedly clearing `setTarget(nil)`. That remains a last-resort approach requiring explicit performance evidence.

## Acceptance probe

A successful zombie-vs-zombie feasibility test requires one hostile zombie to:

1. acquire another zombie;
2. retain the target;
3. pursue it;
4. enter an attack state;
5. apply damage;
6. reach disengagement or death;
7. synchronize correctly on a dedicated server/client pair.

## Deliverable

Close this spike with the exact classes/methods/events involved, Lua-only feasibility, any deeper-hook requirement, performance implications, and multiplayer authority implications. Add an ADR only if the resulting implementation choice is significant enough to need one.
