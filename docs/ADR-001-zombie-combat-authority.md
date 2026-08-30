# ADR-001 — Zombie combat authority

Status: Accepted

Date: 2026-08-30

## Context

Zombie Factions needs directional faction policy and zombie-on-zombie combat in Project Zomboid Build 42 multiplayer. Runtime testing established that server-side target injection does not remain authoritative for a client-owned zombie, while the owning client can control pursuit and close-range engagement. Vanilla zombie attack behavior can target another zombie visually but does not provide a reliable synchronized zombie-damage packet; the exposed hit route is player-oriented.

The mod must not trust a client to choose faction policy, arbitrary targets, damage amounts, or lethal outcomes. It must also avoid recurring all-zombie-versus-all-zombie scans and unbounded packet bursts.

## Decision

Use a split, server-authorized combat model:

- The server owns faction identity, directional relationship policy, candidate eligibility, runtime mob membership, target grants, cooldown validation, and lethal finalization.
- The current zombie owner client performs bounded pursuit and close-range engagement control for the exact server-granted pair.
- An attacker owner may request an impact only for its current authorized grant. The server revalidates identity, ownership, policy, level, distance, cooldown, and liveness.
- The target zombie's current owner applies a uniquely identified nonlethal decrement and acknowledges before/after health. The server rejects invalid acknowledgements and never accepts a health increase.
- The server synchronizes the validated result and alone invokes the normal lethal death/corpse lifecycle.
- Discovery, controller passes, target wakeups, impact requests, and retries remain explicitly budgeted. Client-local polling does not itself generate network traffic.

Do not use player hit packets for faction zombies, represent faction zombies as players, or rely on unsupported `BumpType` values for attack presentation.

## Consequences

This model works with vanilla `IsoZombie` objects and the available Lua/API surface; no deeper engine hook is required for the validated diagnostic mechanics. It preserves server authority over policy and outcomes while respecting Build 42 zombie ownership.

The tradeoff is a custom synchronization protocol and additional validation traffic. Ownership transfer, save/restart persistence, automatic enrollment, multi-member mob scaling, and visual attack presentation require separate production hardening. Impact timing should also be refined to reduce requests rejected after the pair has moved outside the server distance envelope.

## Evidence

[`SPIKE-001-zombie-targeting-and-combat-feasibility.md`](SPIKE-001-zombie-targeting-and-combat-feasibility.md) records the controlled experiments through v0.0.24 and the final dedicated-server crowd result.
