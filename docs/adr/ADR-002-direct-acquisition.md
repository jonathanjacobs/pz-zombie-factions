# ADR-002 — Direct acquisition replaces mob-and-leader targeting

Status: Accepted

Date: 2026-09-07

## Context

Faction target acquisition has used a mob-and-leader model since v0.0.18. A mob is a
stable, server-runtime grouping of nearby same-faction zombies with an elected leader.
The leader performs the spatial scan and members inherit the enemy faction, so a crowd
does not run one full scan per zombie. [`../spikes/SPIKE-001-zombie-targeting-and-combat-feasibility.md`](../spikes/SPIKE-001-zombie-targeting-and-combat-feasibility.md)
records it as replacing "duplicate discovery within a local faction crowd".

The model was weakened twice by its own consequences. Full target sharing collapsed
mobs onto single candidates, leaving leases producing no damage for seconds at a time,
so v0.0.22 returned each member to its own local selection against the cached index.
After that change both a leader scan and a member selection call
`findNearestEligibleZombie`, so most of the original saving was given back while the
membership, election, arbitration and maintenance costs remained.

The arbitration also produced defects. [#11](https://github.com/jonathanjacobs/pz-zombie-factions/issues/11)
strands a member whose mob is considered active, and mob arbitration was the reason
v0.0.45 `NEUTRAL` retaliation recruits took between twenty seconds and several minutes
to engage: `queueTargetSubject` queues the mob leader rather than the zombie it is given.

No measurement of the remaining benefit existed. This decision is based on one.

## Decision

Acquire targets per zombie. Each zombie receives its own probe and its own grant.
Membership, leader election, shared-target arbitration and the maintenance sweep are
not used. `ZombieFactions.DirectAcquisition` defaults to on; the mob path remains
switchable for comparison and is retained, unused, pending the removal in the audit
below.

Nothing else changes. Server authority over policy, grants, revalidation and lethal
outcomes is unaffected, and [`ADR-001-zombie-combat-authority.md`](ADR-001-zombie-combat-authority.md)
stands in full.

## Evidence

A single-session v0.0.51 dedicated-server run, 240 against 240 mutually hostile, in
three phases. Phases ran for different numbers of summary windows, so figures below are
normalised by work done or are duration-independent.

| | direct | mob size 1 | mob size 8 |
| --- | --- | --- | --- |
| ms per damage request | 6.20 | 7.57 | 8.60 |
| worst single server pass | 30 ms | 81 ms | 115 ms |
| peak dormant members | 0 | 9 | 420 |
| full spatial scans | 2,504 | 1,994 | 1,439 |
| accepted damage | 1,795 | 1,553 | 991 |

Direct acquisition costs about 28% less per unit of combat than mob size 8. Its worst
single pass is roughly a quarter of mob size 8's, which is the figure that governs
whether the server hitches under load and is unaffected by phase length.

Mob size 8 does perform the fewest scans, so leader sharing does still reduce scan
count. It costs more time while doing so, which indicates the scans were not the
expensive part; the bookkeeping around them was.

Dormancy is the clearest result. Peak dormant members were 420 under mob size 8 and
zero under direct acquisition, which is [#11](https://github.com/jonathanjacobs/pz-zombie-factions/issues/11)
observed as a measurement. That defect cannot occur without mobs to arbitrate.

An earlier v0.0.49 comparison appeared to show mob size 1 costing far more than size 8
and was read as evidence that cost tracks mob count. Its populations were unmatched,
720 against 480. With populations matched the two configurations cost the same, and
that earlier reading is withdrawn.

## Consequences

Combat behavior is unchanged. Posture selection and sprint locomotion are independent
of this decision: [`ImpactProbe_Client.lua`](../../Contents/mods/pz-zombie-factions/42/media/lua/client/ZombieFactions/ImpactProbe_Client.lua)
contains no mob reference at all, so standing bites, crawler lunges, standing stomps and
sitting get-up are untouched, and sprint braking lives in the pursuit controller rather
than in acquisition.

`NEUTRAL` retaliation improves without further work. Recruits receive their own pinned
probes instead of waiting to be selected by mob machinery, which was the cause of the
v0.0.45 latency.

Shared target selection is lost. Co-located zombies no longer inherit one enemy faction
from a leader, and each chooses independently. Global target-load balancing is
unaffected, since `buildTargetLoads` was never mob-scoped.

The evidence is one session with one run per configuration. It is consistent and the
margins are wide, but it is not repeated measurement.

If scan cost later proves to matter at larger populations than tested, the shape to
reach for is a per-bucket scan cache rather than a return to mobs. A cache shares a
result among co-located zombies without a leader to elect, a membership to maintain, or
anyone to strand — the properties that produced every defect above.

## Audit: code that exists only for mobs

Retained but unused under direct acquisition, recorded here so removal is a decision
rather than an excavation. Roughly 458 lines, about 17% of the server harness.

| Function | Lines |
| --- | --- |
| `chooseMobLeader` | 82 |
| `processPendingMobWakeups` | 58 |
| `ensureStableMobMembership` | 58 |
| `shareTargetWithMob` | 51 |
| `maintainStableMobs` | 49 |
| `selectMobMemberTarget` | 33 |
| `enqueueMobWakeup` | 23 |
| `activateMobMemberAgainstCurrent` | 22 |
| `nearestRecruitableMob` | 19 |
| `refreshPendingLeader` | 13 |
| `mobHasActiveProbe` | 10 |
| `removeMobWakeupAt`, `pendingProbeForMobId`, `memberIsValid`, `findMobMember` | 7 each |
| `stableMobBySubjectId`, `nextMobId`, `mobHasRoom` | 4 each |

State tables that become dead: `ZombieFactions.TargetProbeMobs`,
`TargetProbeMobBySubjectId`, `TargetProbeMobSequence`, `PendingMobWakeups`,
`MobWakeupBySubjectId`.

Three items need care rather than deletion:

- `selectMobMemberTarget` holds the `NEUTRAL` retaliation pin. The pin must move to the
  direct path before this function is removed, or retaliation stops aiming at the
  provoker.
- `mobTargetRetentionRadius` is still used by `beginOwnerTargetProbe` to bound the
  preferred-candidate distance check. It survives removal and should be renamed rather
  than deleted.
- `zombieMobSize` remains referenced by the Horde Spawner reply and the performance
  summary. The sandbox option should stay until those are updated, and its tooltip
  should say it is ignored under direct acquisition.

The client needs almost nothing. `ImpactProbe_Client.lua` has no mob references.
`TargetProbeObserver_Client.lua` has five: three parsing `mobId`, `mobLeaderId` and
`mobMemberIndex` from the grant payload, and two using them in the approach-offset seed.
Under direct acquisition those two terms become constants, so offset variation comes
from the subject and candidate ids alone. The 24 approach slots still spread, with less
entropy than before, and this is worth watching for clumping rather than treating as
settled.

## Alternatives considered

**Keep mobs and set `ZombieMobSize` to 1.** Already the shipped default, and it needs no
new code. Rejected: it pays the full membership, election and maintenance cost once per
zombie while getting no sharing at all, and measured no cheaper than size 8.

**Keep mobs and fix the arbitration defects.** Rejected on the evidence: the layer costs
more and hitches worse while delivering the benefit it exists for only marginally, so
repairing it preserves a cost the measurement does not justify.

**Per-bucket scan cache.** Not rejected, deferred. It is the better shape if scan cost
ever becomes the constraint, and it is orthogonal to this decision.
