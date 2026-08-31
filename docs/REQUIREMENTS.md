# Zombie Factions — Runtime Requirements

This document owns normative product/runtime behavior for Zombie Factions. Implementation strategy and current research belong in [`ARCHITECTURE.md`](ARCHITECTURE.md) and the active spike documents.

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

## Definitions

- **Zombie faction** — a Zombie Factions identity assigned to a zombie.
- **Vanilla faction** — the built-in default zombie faction, `zf:vanilla`.
- **Player faction** — an existing Project Zomboid player `Faction`; Zombie Factions does not replace that system.
- **Unfactioned player** — a player who does not belong to a Project Zomboid player faction.
- **Relationship** — a directional policy from one faction identity toward another.

## Faction identity

### R1 — Every zombie resolves to one faction

Every zombie handled by the mod must resolve to exactly one zombie faction identity at a time.

### R2 — Vanilla is the default faction

A zombie without an explicit custom assignment must resolve to `zf:vanilla`.

### R3 — Custom zombie factions are extensible

Additional zombie factions must be registrable without modifying or replacing the built-in Vanilla faction.

### R4 — Faction identity is stable

Faction identifiers must use stable string identities suitable for persistence, configuration, and interoperability with other mods.

## Relationships

### R5 — Relationships are directional

Relationships are evaluated as `source -> target`. `A -> B` may differ from `B -> A`.

### R6 — Relationship states are limited to three values

The supported relationship states are:

- `FRIENDLY`
- `NEUTRAL`
- `HOSTILE`

### R7 — Same-faction relationships default to Friendly

Unless explicitly supported otherwise in a future requirement, members of the same zombie faction must not proactively attack one another.

### R8 — Friendly suppresses aggression

A `FRIENDLY` relationship must prevent proactive targeting. Receiving damage alone must not cause retaliation against a Friendly target.

### R9 — Neutral suppresses proactive aggression

A `NEUTRAL` relationship must prevent proactive targeting. A Neutral faction may retaliate after direct aggression once retaliation behavior is implemented and validated.

### R10 — Hostile permits aggression

A `HOSTILE` relationship makes the target eligible for proactive detection, selection, pursuit, and attack, subject to what Build 42's target and combat systems actually support.

## Player integration

### R11 — Use Project Zomboid player factions

Zombie Factions must use the game's existing player-faction system when resolving faction relationships toward players. It must not create a parallel replacement player-faction system.

### R12 — Unfactioned players are independently addressable

Players who are not members of a Project Zomboid faction must be representable as a distinct relationship target.

## Vanilla compatibility

### R13 — Default installation preserves vanilla behavior

With no custom faction configuration or assignment:

- ordinary zombies resolve to `zf:vanilla`;
- vanilla zombies do not begin attacking other vanilla zombies;
- normal vanilla hostility toward players is preserved.

### R14 — Fail safely on unknown faction data

Missing, malformed, or unknown custom faction data must fall back to safe deterministic behavior rather than causing uncontrolled exceptions or undefined targeting behavior.

## Persistence and multiplayer

### R15 — Explicit zombie faction assignment must survive relevant lifecycle transitions

Once persistent assignment is implemented, a zombie's custom faction identity must remain deterministic across supported save/load, relevance, and dedicated-server lifecycle transitions.

### R16 — World-changing hostility decisions are server-authoritative

In multiplayer, targeting, retaliation, and damage decisions that affect shared world state must not depend solely on independent client-side decisions.

## Performance and integration

### R17 — Do not fight vanilla targeting every tick

The implementation must prefer rejecting invalid targets at an eligibility/acquisition boundary. A design based on continuously scanning zombies and repeatedly clearing/reassigning targets is not acceptable as the normal architecture unless research demonstrates no cleaner option and performance testing shows it is safe.

### R18 — Normal operation must remain bounded

The mod must not require full-world zombie scans, uncontrolled command traffic, or high-volume diagnostic logging during ordinary play.

## Zombie-vs-zombie combat

### R19 — Zombie combat must remain within validated authority boundaries

When zombie-to-zombie combat is enabled, it must use server-authorized pair grants, revalidated impacts, and server-finalized lethal outcomes. The project must limit compatibility and feature claims to controlled Build 42 evidence; unvalidated variants, including crawler presentation and reaction/sound behavior, must remain explicit test candidates rather than accepted behavior.

## Scope separation

### R20 — Faction diplomacy remains independent from other zombie systems

The core faction layer must not require faction-specific outfits, appearance, gameplay spawn rules, territory, loot, statistics, abilities, or NPC behavior. Those may consume the faction API later as separate systems.

## Testability

### R21 — Administrators can spawn deterministic faction test subjects

Development/test builds must provide an administrator-only mechanism for spawning zombies with an explicitly selected zombie faction so faction targeting behavior can be tested deterministically. The preferred implementation is an extension of the built-in Build 42 Horde Spawning admin tool when that can be done safely.

The diagnostic spawner must:

- assign the selected faction to the spawned zombies through the authoritative spawn path;
- support independent configuration of `spawned faction -> zf:vanilla` and `zf:vanilla -> spawned faction` relationships;
- support `FRIENDLY`, `NEUTRAL`, and `HOSTILE` for each direction;
- avoid treating this diagnostic capability as a general gameplay population/spawn system;
- remain admin-only and produce bounded diagnostics suitable for controlled tests.

## Out of scope for the MVP

- faction-specific visual appearance or uniforms;
- faction-specific gameplay spawning or population distribution, except the administrator-only diagnostic spawner required by R21;
- territory control;
- faction-specific loot, statistics, or powers;
- NPC faction integration;
- dynamic diplomacy-changing gameplay systems;
- replacing Project Zomboid's existing player-faction system.
