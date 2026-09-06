# SPIKE-005 — Sprinter locomotion during faction pursuit

Status: v0.0.40 implemented, awaiting its first runtime test. Open question 1 was
resolved from archived logs before implementation, and that resolution reversed
this document's original prediction.
Target: Project Zomboid Build 42.20.x
Implementation: v0.0.40

## Question

Can a locally owned, server-granted faction attacker with speed type `1` reach and
sustain native sprint locomotion while pursuing another zombie by coordinates, with
its native target left clear, without reintroducing the `setTarget(IsoZombie)` route
that ADR-001 forbids?

This is a *locomotion* question, not an attack-profile question. It is deliberately
separated from the posture work in [`SPIKE-004`](SPIKE-004-crawler-combat-profiles.md).

## Why this is not another SPIKE-004

SPIKE-004 succeeded because both problems it solved were *presentation inside an
action state the mod could already enter*:

| SPIKE-004 profile | Carrier state | Mod-owned entry point |
| --- | --- | --- |
| `STANDING_BITE` / `STANDING_STOMP` | `bumped` | `setBumpType()` |
| `CRAWLER_LUNGE` | `hitreaction` | `setHitReaction()` |

In both cases the mod writes a string the shipped animation graph reads as a node
condition, and the node it selects is cosmetic. Damage stays on the separate
server-authorized route.

Sprinting is different in three ways:

1. **No mod-owned entry point exists.** The relevant condition variable is computed
   by the engine, not stored, so no `setVariable()` write can select the vanilla
   sprint node in the pursuit action state the mod currently uses.
2. **The animation is not cosmetic.** The pursuit state contributes facing and
   direction only; translation comes from animation root motion. The selected node
   *is* the speed. There is no separate speed field to set, which is why every
   flag-writing approach so far has produced correct-looking counters and unchanged
   movement.
3. **It changes approach timing for every existing profile.** Faster closure
   interacts with the contact envelope, the melee-commitment gate, the impact
   cooldown, and the controller's 6-tick update interval — all of which were tuned
   against shambler closure speeds.

## Prior attempts (post-mortem)

Two sprinter attempts were made before this repository's current head. Neither was
committed here; both were rolled back. Reconstructed from their own recorded
diagnostics.

### Attempt A — force the running flag

Approach: assign speed type `1` at spawn, then have the owning client call
`setRunning(true)` on locally owned faction sprinters during coordinate pursuit and
clear it at engagement, suspension, reacquisition, or release.

Recorded result: speed type verified as `1` and unchanged; running samples
positive in every sample and non-running samples zero; measured travel still roughly
0.2–1.3 tiles/second; visibly shambling.

Why it failed: the running flag is not an input to locomotion, and both shipped
pursuit states clear it every frame. The walk-toward state assigns it `false`
unconditionally on each execute; the pathfinding behavior rewrites it from the
*global* sandbox zombie-speed setting, ignoring per-zombie speed type, so on a
shambler-default server it is forced back to `false` there too. Even held `true` it
selects nothing. A speed helper that would hard-set a sprinter's travel speed does
exist on the zombie class but is not called anywhere in this build, so no per-zombie
speed override is in play at all. The counter that was supposed to prove the fix could
only ever measure the mod's own write.

### Attempt B — mod-owned sprint animation nodes

Approach: add five mod-owned animation nodes under
`media/AnimSets/zombie/walktoward/`, inheriting the shipped sprint nodes via
`x_extends="sprintN.xml"`, selected by a mod-owned pursuit variable.

Recorded result: the five node files failed to load at startup (reported as a
server "Error 5"). Sprint intent was active in 184/184 samples while the sprint
animation was active in 0/184. Combat itself still worked; a separate grant-resolution
failure in the same run was misattributed to the sprint change at first.

Why it failed, in order:

1. `x_extends` resolves relative to the *mod's own* asset folder. The base
   `sprintN.xml` files are shipped game data and are not present in the mod package,
   so all five nodes failed to parse.
2. Even had they loaded, the inherited conditions would not have been satisfiable.
   The shipped `walktoward` sprint nodes require a condition the engine derives from
   "has a native target, or is reacting to a sound source that is not a zombie."
   Faction pursuit deliberately holds the native target clear, and the enemy is a
   zombie, so both alternatives are closed by construction.
The follow-up recommendation (standalone, non-inheriting nodes with `intrees=false`
and matching walk types) was implemented but never validated, and is not in this
repository. Measurement has since confirmed that attempt B chose the correct
animation set; only its inheritance mechanism and its choice of condition were
wrong. That recommendation is now the leading candidate.

### What the two attempts have in common

Both instrumented mod-owned intent rather than engine outcome. Neither run measured
which action state the zombie was in, which animation node was selected, or what
walk type the owning client actually held. Every reported "positive" counter was the
mod observing its own write. The single decisive measurement — distance travelled per
second, cross-checked against a shambler control — was only added at the very end.

A third, unrelated defect (client grant resolution timing out and the server retaining
stale active grants) was live during the same sessions and repeatedly confused
attribution. That defect has since been addressed by the v0.0.39 acknowledgement work
and by [#2](https://github.com/jonathanjacobs/pz-zombie-factions/issues/2), but any
sprinter run must still separate "did not sprint" from "was never controlled."

## Engine findings

Derived from the installed Build 42.20.x asset files and shipped API surface. No
decompiled material is reproduced here.

**Measured: faction pursuit animates in `walktoward`, not `pathfind`.** Three archived
one-client dedicated-server sessions were re-read for the `state=` field the mod
already records. Across `phase=coordinate-pursuit` lines, every one of which also
recorded `targetClear=true`, the animator state was `walktoward` in 3,322 samples,
`idle` in 859, `bumped` in 761, and `pathfind` in only 131. The independent
`CLIENT_OBSERVER` sampling agrees: `controlMode=pursuit` gave 1,652 `walktoward`
against 82 `pathfind`, and `controlMode=contact-closing` gave 1,413 against 16.

Two checks make those counts load-bearing. The reported state is derived from the
animator's current state name, not from a lagging network guess; and the enum it
passes through falls back to `idle` for any unrecognised name, so `walktoward` can
only appear when the animator is literally in `walktoward`. The `idle` counts are
correspondingly ambiguous and should not be relied on. The shipped animator
transition from `pathfind` to `walktoward` fires on `bPathfind` false with `bMoving`
true, which is reachable from the pathfinding behavior's own variable writes; the AI
state and the animator state therefore need not agree, and it is the animator state
that selects the node.

**Consequence: the `walktoward` animation set governs node selection during pursuit,**
and its sprint nodes carry the target-derived condition described above. That
condition cannot be satisfied while the native target is held clear against a zombie
enemy. This closes the cheapest possible route.

**The same set explains the observed behavior exactly.** `media/AnimSets/zombie/walktoward/`
also ships `sprintWalk1`–`sprintWalk5`: the same walk types as the sprint nodes, with
the sprint condition inverted, playing `Zombie_Walk`. A speed-type-`1` faction zombie
in `walktoward` with the sprint condition false selects precisely these. That is a
complete mechanical explanation for "sprinters shamble toward each other but sprint at
players," and it means no amount of speed-type or flag correction can change the
outcome on its own.

**A mod-owned node in `walktoward` remains available.** The shipped sprint nodes there
match on the sprint condition, `intrees`, and walk type. A standalone node matching on
`intrees`, walk type, and one mod-owned pursuit variable carries the same number of
conditions as `sprintWalk*` plus one, which is the mechanism by which it would be
selected instead. Whether node selection actually resolves that way, and whether an
explicit priority is needed, is unverified.

**The `pathfind` set would not have needed this.** `media/AnimSets/zombie/pathfind/`
ships `sprintPathfind1`–`sprintPathfind5` gated only on `bMoving`, `intrees`, and walk
type, with no target condition at all. This document originally predicted that pursuit
ran there and that sprinting would therefore already work. The measurement above
disproves that. It is recorded here only so the possibility is not re-proposed:
holding the zombie in the pathfinding animator state for the whole approach is a
distinct and much larger change, not a shortcut.

**`zombieWalkType` is settable through the shipped API.** It is a read-only animation
variable backed by a normal field with public `getWalkType()` / `setWalkType(String)`
accessors, and `doZombieSpeed(1)` sets it to `sprint1`–`sprint5` as a side effect of
assigning speed type `1`. It also replicates: the network walk-type enum carries all
five sprint values, and falls back to `1` for anything unrecognised.

**`bMoving` is set true by the pathfinding behavior while a path is being followed**,
so the remaining node condition is satisfiable.

Taken together: a locally owned speed-type-`1` zombie following a coordinate path
should already select a shipped sprint node without any mod asset at all. That
prediction has never been tested, because this repository has never had a way to make
a spawned zombie a sprinter.

**This repository has no sprinter assignment path.** There is no speed selector in the
Horde Spawner extension, no `doZombieSpeed` call in the server harness, and no speed
sandbox option. The spawn-speed dropdown described in the prior attempts was never
committed here. Sprinters currently only exist if the server's global sandbox speed
setting produces them.

**Two collateral findings worth recording:**

- The `pathToLocationF=%s` field in `OWNER_PROBE` lines is the `pcall` result, not
  evidence that a path was issued. The shipped implementation silently ignores a
  repath request while an internal repath-delay timer is running and the zombie is
  already pathfinding. Existing logs cannot distinguish "repathed" from "ignored".
- The shipped collision handler suppresses door/wall thumping when the zombie has no
  native target and is not chasing a sound, explicitly stopping the pathfind instead.
  That is the direct mechanism behind
  [#6](https://github.com/jonathanjacobs/pz-zombie-factions/issues/6) and is out of
  scope here.

## Does a sprinter need a new attack profile?

No. `attackProfile()` classifies on posture only (`isCrawling`, `isSitAgainstWall`);
speed type is not read on either side, and the server derives the same classification
independently. A standing sprinter attacking a standing defender is `STANDING_BITE`,
against a crawler or sitter it is `STANDING_STOMP`, and a crawler attacking a sprinter
is `CRAWLER_LUNGE`. The existing `CHANGELOG` note that sprinters "just bite" is
accurate and should stay true.

What a sprinter changes is **approach and contact timing**, not attack selection. The
close-range constants were all tuned at shambler closure speeds:

| Constant | Value | Where |
| --- | --- | --- |
| Controller update interval | 6 ticks (~10 Hz) | `ClientCombatController.lua` |
| `ENGAGEMENT_DISTANCE` | 1.20 | `TargetProbeObserver_Client.lua` |
| `MELEE_COMMITMENT_DISTANCE` | 0.65 | `TargetProbeObserver_Client.lua` |
| `CONTACT_DISTANCE` | 0.50 | `TargetProbeObserver_Client.lua` |
| `PROGRESS_DISTANCE` / no-progress window | 0.35 / ~5 s | `TargetProbeObserver_Client.lua` |
| Approach offset radius | 0.25 / 0.40 across 24 slots | `TargetProbeObserver_Client.lua` |
| Client collision / server validation | 0.80 / 1.60 | sandbox defaults |
| Impact cooldown | 60 ticks | `ImpactProbe_Client.lua` |

Melee authorization is granted only on a controller pass that observes the pair at or
inside 0.65 tiles, and it expires at the end of that pass. A pair that crosses the
0.65-to-0.50 band entirely between two passes is never authorized. The risk is that a
sprinter's per-pass displacement becomes comparable to the width of that band, so
authorization becomes intermittent. This is the same failure mode already reported in
[#10](https://github.com/jonathanjacobs/pz-zombie-factions/issues/10) for two
shamblers, and sprinters should be expected to make it worse rather than to introduce
something new. Actual per-pass displacement must be measured, not assumed.

## Proposed scope boundary

### In scope

1. A server-authoritative way to assign zombie speed type, and a Horde Spawner control
   to select it for a spawn. Speed values `1` sprinter, `2` fast shambler, `3` shambler,
   `4` random, plus "use sandbox speed" as the default. Without this there is nothing
   to test.
2. Read-only pursuit instrumentation that records engine outcome rather than mod
   intent: walk type as held by the owning client, `intrees`, `bMoving`, planar
   displacement per second, and a shambler control measured the same way in the same
   run. Action state is already answered and needs only a cheap confirmation that it
   has not changed.
3. One mod-owned animation node set under `media/AnimSets/zombie/walktoward/`, selected
   by walk type, `intrees`, and a single mod-owned pursuit variable the owning client
   sets and clears. No `x_extends`, no inheritance from shipped nodes, no
   animation-emitted diagnostic variables, and no reuse of the shipped sprint
   condition. An explicit priority is added only if selection testing shows condition
   count alone does not beat `sprintWalk*`.
4. Whatever close-range timing correction the measured displacement proves necessary
   for a sprinter to obtain melee authorization reliably — bounded to the pursuit and
   authorization path, not to damage authority.
5. Posture regression across the existing profiles with a sprinter on each side.

### Out of scope

- Any change to `setTarget`, `bAttack`, grant lifecycle, damage validation, or lethal
  finalization. ADR-001 holds unchanged.
- Any new attack profile, faster bite cadence, or sprinter-specific damage.
- `setRunning`, `setSprinting`, speed modifiers, or `MoveDelta` writes. Attempt A
  establishes that these do not select locomotion.
- Sprinter trip-and-fall behavior. The shipped trip state is not modified; whether the
  native trip calculation runs at all during targetless pursuit is recorded as an open
  question, not a deliverable.
- Restoring vanilla bulk horde spawning, grant backpressure
  ([#8](https://github.com/jonathanjacobs/pz-zombie-factions/issues/8)), obstacle
  routing ([#6](https://github.com/jonathanjacobs/pz-zombie-factions/issues/6)),
  combat vocalizations ([#7](https://github.com/jonathanjacobs/pz-zombie-factions/issues/7)),
  and neutral retaliation. Prior attempts repeatedly bundled these with sprinters and
  lost attribution as a result.
- Fake-dead, burning, and knocked-down attackers. Separate posture work.

### Sequencing

Steps 1, 2 and 3 ship together as one build: the animation node is no longer
conditional, because the shipped node is now known not to be selectable. Step 4 is
sized from step 2's measured numbers rather than guessed in advance. Each step ends in
a recorded run before the next begins.

## Acceptance matrix

Acceptance requires, on a dedicated server with one client, mob size 1, clear level
outdoor ground, and the 0.80/1.60 distance defaults:

| Case | Required outcome |
| --- | --- |
| Sprinter → standing shambler | Visible sprint during approach; clean stop at contact; `STANDING_BITE`; accepted damage |
| Standing shambler → sprinter | Unchanged existing behavior; accepted damage |
| Sprinter → sprinter | Both sprint; converge to melee without a third arrival; accepted damage |
| Sprinter → crawler | `STANDING_STOMP`; accepted damage |
| Sprinter → sitting defender | `STANDING_STOMP`, get-up lock, then `STANDING_BITE` |
| Crawler → sprinter | `CRAWLER_LUNGE`; accepted damage |
| Sprinter → player, faction probe off | Vanilla sprint chase unchanged |
| Shambler → shambler | Unchanged regression control |

Plus, for every case: measured sprinter displacement materially above the shambler
control in the same run; no faction runtime exception; no native-target crash
signature; zero profile rejections and zero configuration mismatches; and distance
rejections not materially worse than the shambler control.

Mixed-crowd and 4v4 runs come after the isolated matrix passes, not instead of it.

## Open questions

1. ~~**Which action state does faction pursuit actually occupy?**~~ **Resolved:**
   `walktoward`, by a wide margin, in three archived sessions. See Engine findings. A
   mod-owned animation node is therefore required, and the shipped sprint nodes are
   unusable.
2. **Does a mod-owned `walktoward` node actually win selection against `sprintWalk*`?**
   The mod node would carry one more matched condition. Whether the shipped selector
   resolves on condition count, declared priority, or file order is unverified, and
   this is now the primary implementation risk.
3. **What walk type does the *owning client* hold?** Speed type reading `1` on the
   client implies a sprint walk type, but the two are set through different paths and
   the network simulator may rewrite walk type from packets. Both must be logged
   separately, on the owner. This is now load-bearing: the mod node is keyed on walk
   type, so a rewritten walk type would silently disable it.
4. **What is a sprinter's real per-controller-pass displacement**, and how does it
   compare to the 0.65 → 0.50 authorization band? This determines whether the
   controller interval, the band, or the approach offsets need to change — and whether
   [#10](https://github.com/jonathanjacobs/pz-zombie-factions/issues/10) must be fixed
   before sprinters can pass at all.
5. **Do the 24 approach-offset slots still make sense at sprint speed?** They exist to
   reduce clumping; at higher closure they may cause orbiting.
6. ~~**Does the shipped sprinter trip calculation run during targetless pursuit?**~~
   **Resolved: no.** The shipped periodic trip roll requires a sprinter speed type, an
   empty bump type, a non-remote zombie, *and a non-null native target*. Faction
   pursuit holds the target clear, so the trip can never fire during it. The
   observable effect is a behavioral gap rather than a defect: faction sprinters will
   never stumble, while the same zombie chasing a player still will. Reproducing it is
   inexpensive, because the shipped trip is entered purely by setting a bump type that
   the mod's presentation layer already writes for bites and stomps. It is deliberately
   excluded from the first build for two reasons: a random mid-approach stumble would
   corrupt the tiles-per-second measurement that build exists to produce, and it must
   not be armed while an attack presentation owns the same bump type. Before adding it,
   `getup` must join the safety interlock's state matcher, which currently covers
   `fall`, `knock`, `stagger`, `attack`, `lunge`, `hitreaction`, and `death`. Recorded
   as follow-up work, not as part of this spike's acceptance.
7. **Does speed assignment need to survive relevance transitions and restart**, or is
   spawn-time assignment sufficient for this spike? Proposal: spawn-time only here;
   persistence belongs with production enrollment.
8. **Should speed assignment be reusable as a post-spawn operation?** A
   `setZombieSpeedType(zombie, speedType)` server operation costs little now and is
   the same primitive a later reassignment feature needs. Proposal: build the server
   operation, expose only the spawner path in this spike.

## Relationship to existing work

- [`ADR-001`](../adr/ADR-001-zombie-combat-authority.md) — unchanged; nothing here
  touches the authority boundary.
- [`SPIKE-004`](SPIKE-004-crawler-combat-profiles.md) — supplies the posture profiles a
  sprinter reuses unchanged.
- [#10](https://github.com/jonathanjacobs/pz-zombie-factions/issues/10) — close-range
  convergence stall; a likely blocker for the sprinter-vs-sprinter case.
- [#6](https://github.com/jonathanjacobs/pz-zombie-factions/issues/6),
  [#8](https://github.com/jonathanjacobs/pz-zombie-factions/issues/8),
  [#9](https://github.com/jonathanjacobs/pz-zombie-factions/issues/9) — all deferred
  behind this work and all explicitly out of scope for it.
