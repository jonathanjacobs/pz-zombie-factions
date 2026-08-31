# Validation history

This is a concise record of observed outcomes. Detailed hypotheses, raw diagnostic interpretation, and rejected approaches remain in the linked SPIKE records.

| Date | Version | Scope | Outcome | Evidence |
| --- | --- | --- | --- | --- |
| 2026-08-30 | 0.0.24 | Dedicated-server crowd combat | Passed the SPIKE-001 feasibility closeout: synchronized pursuit, validated damage, and lethal corpse handling worked without a reported Zombie Factions exception in the recorded run. | [SPIKE-001](spikes/SPIKE-001-zombie-targeting-and-combat-feasibility.md) |
| 2026-08-30 | 0.0.31 | Standing faction bite presentation | Failed final stress validation. Readable bites and validated damage were observed, but native `AttackState` attempted to cast an `IsoZombie` target to `IsoPlayer`, crashed the client, and forced a disconnect. | [SPIKE-003](spikes/SPIKE-003-synchronized-combat-presentation.md) |
