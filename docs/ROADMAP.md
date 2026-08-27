# Roadmap

## Phase 0 — Repository foundation

- [x] establish Build 42 Workshop-compatible repository layout;
- [x] define MVP requirements and architecture boundaries;
- [x] add compliance/provenance framework;
- [x] create initial research spike for zombie targeting/combat feasibility.

## Phase 1 — Engine feasibility

- [ ] trace Build 42 zombie target acquisition and candidate filtering;
- [ ] identify a clean interception point for faction-aware target eligibility;
- [ ] validate whether zombie targets may be other zombies through pursuit and attack states;
- [ ] trace hit/damage/death processing for zombie-on-zombie combat;
- [ ] determine Lua-only versus deeper-hook requirements;
- [ ] document findings and commit an ADR for the implementation strategy.

## Phase 2 — Faction core

- [ ] implement faction registry;
- [ ] implement persistent zombie faction assignment;
- [ ] implement directional relationship matrix;
- [ ] integrate vanilla player factions and unfactioned players;
- [ ] add bounded diagnostics;
- [ ] preserve vanilla behavior when no custom factions are configured.

## Phase 3 — Targeting behavior

- [ ] Friendly target suppression;
- [ ] Neutral target suppression and retaliation policy;
- [ ] Hostile candidate selection;
- [ ] zombie-vs-zombie pursuit/attack if supported by the engine;
- [ ] dedicated-server authority and synchronization validation.

## Phase 4 — Administration/API

- [ ] stable public Lua API for other mods;
- [ ] server configuration format;
- [ ] admin inspection/assignment tools;
- [ ] compatibility documentation.

## Future, explicitly outside MVP

- faction-specific outfits/appearance;
- spawn/population rules;
- territories;
- faction-specific zombie stats or abilities;
- faction-specific loot;
- NPC integration;
- diplomacy-changing gameplay systems.
