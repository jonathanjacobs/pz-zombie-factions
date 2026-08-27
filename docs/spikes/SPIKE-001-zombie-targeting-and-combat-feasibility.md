# SPIKE-001 — Zombie Targeting and Combat Feasibility

Status: Open  
Target baseline: Project Zomboid Build 42.20.x

## Question

Can Zombie Factions enforce directional faction relationships at a clean target-eligibility boundary, and can a vanilla `IsoZombie` reliably pursue, attack, damage, and kill another `IsoZombie` in Build 42 multiplayer?

## Evidence sources

- Project Zomboid Build 42 Java/Lua API documentation;
- runtime logs and controlled tests;
- privately supplied decompiled Build 42 source used only as implementation research;
- official/community documentation where needed to resolve API behavior.

No decompiled Project Zomboid source is to be copied into this repository.

## Investigation plan

Trace the full pipeline:

1. candidate discovery;
2. target filtering / eligibility;
3. target assignment;
4. pathfinding and pursuit;
5. attack-state entry;
6. attack target type assumptions;
7. hit/damage processing;
8. death handling;
9. server/client authority and synchronization;
10. save/load and relevance transitions.

## Preferred result

Identify a hook or supported Lua event/API that lets the mod reject invalid candidates before target acquisition. The desired decision is conceptually:

```text
canTarget(attacker, candidate)
    -> resolve attacker faction
    -> resolve candidate faction/player faction
    -> relationship == HOSTILE ? eligible : ineligible
```

## Explicitly disfavored fallback

Do not adopt a design that globally scans zombies each update and repeatedly clears `zombie:setTarget(nil)` when a relationship is non-hostile unless no cleaner mechanism exists and performance tests justify it. Such a design risks reacquisition churn and unnecessary work proportional to active zombie population.

## Zombie-vs-zombie acceptance probe

A successful feasibility result requires one hostile zombie to:

1. identify another zombie as a valid target;
2. retain that target;
3. path toward it;
4. enter an attack state;
5. apply damage;
6. repeat until disengagement or death;
7. synchronize correctly on a dedicated server/client pair.

## Deliverable

Close this spike with:

- exact classes/methods/events involved;
- Lua-only feasibility assessment;
- any required Java/native extension assessment;
- performance implications;
- multiplayer authority implications;
- proposed ADR for the implementation strategy.
