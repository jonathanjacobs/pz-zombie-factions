# Testing

## Validation strategy

Development proceeds from narrow engine probes to controlled multiplayer tests. No capability is considered supported until observed in Build 42 runtime behavior.

### T1 — Identity
- confirm every observed zombie resolves to `zf:vanilla` when no explicit assignment exists;
- assign one zombie to a custom faction and confirm persistence across ordinary relevance/load transitions if supported;
- verify unknown or malformed IDs fail safely.

### T2 — Relationship matrix
- verify all nine source/target combinations of `FRIENDLY`, `NEUTRAL`, and `HOSTILE` resolution;
- verify directionality (`A -> B` may differ from `B -> A`);
- verify same-faction default is friendly.

### T3 — Player targeting
- vanilla/default configuration must preserve normal zombie hostility to players;
- friendly zombie-to-player relationship must prevent proactive target acquisition;
- neutral must not proactively acquire the player and must follow the defined retaliation rule;
- hostile must preserve normal acquisition/pursuit/attack behavior.

### T4 — Zombie-to-zombie feasibility
Controlled pair tests:
1. spawn/identify two zombies;
2. assign different factions;
3. define hostile relationship;
4. observe target acquisition;
5. observe pathing;
6. observe attack animation/state;
7. confirm damage and death handling;
8. repeat on dedicated multiplayer.

If any step fails, instrument that boundary rather than adding broad per-tick overrides.

### T5 — Performance
- measure target checks per second with representative zombie populations;
- ensure no command/log spam is produced under normal operation;
- avoid full-world scans and repeated target clearing;
- compare server tick behavior with mod enabled but no custom factions configured.

### T6 — Save/load and multiplayer
- restart server with assigned custom factions;
- reconnect clients;
- move zombies out of and back into relevance;
- verify authority and faction identity remain deterministic;
- verify clients do not independently create divergent hostility decisions.

## Logging

Normal mode should log only lifecycle/configuration anomalies. A diagnostic mode may emit faction resolution and target-decision traces for bounded test subjects. Diagnostic logging must be opt-in and must not be required for normal operation.
