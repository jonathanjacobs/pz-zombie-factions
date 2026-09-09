# Spikes

Spikes preserve bounded feasibility investigations and uncertain engine behavior. They are evidence records, not release claims.

## Index

- [`SPIKE-001 — Zombie targeting and combat feasibility`](SPIKE-001-zombie-targeting-and-combat-feasibility.md) — **Closed successfully** with v0.0.24.
- [`SPIKE-002 — Zombie combat presentation`](SPIKE-002-zombie-combat-presentation.md) — **Closed, rejected**, and superseded by SPIKE-003.
- [`SPIKE-003 — Explicitly synchronized combat presentation`](SPIKE-003-synchronized-combat-presentation.md) — **Closed successfully** for dedicated-server, one-client standing zombies with v0.0.34.
- [`SPIKE-004 — Crawler combat profiles`](SPIKE-004-crawler-combat-profiles.md) — **Open**; v0.0.36 mixed-crowd pass and a later confirmed sitting get-up, with the isolated posture matrix and the first-versus-second stomp timing ([#9](https://github.com/jonathanjacobs/pz-zombie-factions/issues/9)) still outstanding.
- [`SPIKE-005 — Sprinter locomotion during faction pursuit`](SPIKE-005-sprinter-locomotion.md) — **Core question answered** with v0.0.40–v0.0.43; sprinters measured 2.5–2.8 times a same-run shambler control, with braking added for close-range convergence. Remaining gaps are recorded in [`../ROADMAP.md`](../ROADMAP.md).
- [`SPIKE-006 — Faction identity persistence`](SPIKE-006-faction-identity-persistence.md) — **Core question answered from source study**, with a survey of four shipping mods; no runtime measurement yet. Zombie `modData` cannot survive virtualization, chunk unload, or a restart, because the only zombie persistence is a fixed 21-byte population record. Three routes avoid that: the persistent outfit id for bulk faction membership, which one of the surveyed mods already relies on and which the spike recommends; the reanimated-player save path for a bounded number of individuals, which keeps full `modData` but stops those zombies from ever virtualizing; and having the mod despawn and respawn its own zombies, which removes the identity problem but takes on part of population management.

Use a numbered filename such as `SPIKE-004-short-topic.md`. State the question, boundary, environment, procedure, evidence, outcome, and next decision. Promote durable conclusions into requirements, architecture, or an ADR.
