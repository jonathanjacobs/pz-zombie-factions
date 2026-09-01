# Changelog

## 0.0.37 — 2026-08-31

Unvalidated seated-defender extension for the next dedicated-server runtime test.

- treats a zombie whose shipped `isSitAgainstWall()` posture is active as a low defender, routing a standing attacker through the existing `STANDING_STOMP` animation-window profile instead of the standing bite collision route;
- after accepted nonlethal damage, sends the server-validated attacker coordinates to the target owner and invokes the shipped `setTurnAlertedValues()` route there so the sitting action group can use its native `getup-fromSitting` transition without broadcasting a world sound or requiring the attacker to resolve on that client;
- locks the exact attacker-defender pair after a sitting stomp, allowing the current stomp to finish but suppressing another stomp or bite until the defender has left sitting/get-up state and remained stably standing for half a second; the bounded three-second lock expires so a failed wake can be stomped again;
- adds bounded counters for seated stomp arming, seated stomp impacts, get-up alerts, successful standing transitions, and get-up timeouts;
- preserves crawler-first profile selection, server recomputation of the defender posture, and all existing damage-authority checks;
- adds a focused standing-versus-sitting damage and get-up regression procedure.

## 0.0.36 — 2026-08-31

Crawler-combat implementation for dedicated-server runtime testing.

- adds `CRAWLER_LUNGE` and `STANDING_STOMP` attack profiles while retaining the validated collision-driven `STANDING_BITE` profile;
- reuses shipped `Zombie_CrawlLunge`, `Bob_AttackFloorStamp`, and `Bob_BiteCrawlerReact` clips through mod-owned animation nodes without assigning a zombie as a native target;
- lets crawler lunges and standing stomps request damage only from their animation contact window while the exact pair remains owner-controlled, authorized, same-level, and inside the client distance gate;
- makes the server independently derive the expected posture profile and evidence type before retaining all existing policy, ownership, cooldown, liveness, distance, target-owner, and lethal checks;
- adds crawler floor reactions, low standing reactions, stomp sound selection, and profile-specific bounded diagnostics;
- defines runtime cases for crawler-versus-crawler, crawler-versus-standing, standing-versus-crawler, player regression, and standing-combat regression.

## 0.0.35 — 2026-08-30

Distance-envelope tuning harness for [#1](https://github.com/jonathanjacobs/pz-zombie-factions/issues/1).

- adds bounded `Client Collision Distance` and `Server Validation Distance` sandbox options, with `0.80` and `1.60` tiles adopted as the accepted defaults;
- snapshots both values into each server grant so the owner client and server evaluate one consistent test configuration;
- retains real character collision as the only request source and retains server distance, identity, policy, ownership, level, cooldown, and liveness validation;
- logs the effective values on load, grants, client summaries, collision requests, server summaries, dispatches, and distance rejections;
- adds server-side distance averages, rejected-distance maximum, client collision-distance averages, and configuration-mismatch counts for controlled 1v1 and mob-size comparisons.

## 0.0.34 — 2026-08-30

Horde Spawner visibility correction for [#5](https://github.com/jonathanjacobs/pz-zombie-factions/issues/5).

- restores the proven post-resize independent bottom controls because Build 42 does not reliably relocate the vanilla `anchorBottom` controls after the extension changes the final window height;
- explicitly disables and hides the displaced vanilla controls so only one interactive control set exists;
- allows the independent Spawn button to process mouse-up when window focus consumes the corresponding mouse-down, addressing the reported intermittent second-click requirement;
- retains the v0.0.33 contact, sound, and reaction changes unchanged;
- passes controlled dedicated-server, one-client validation for isolated standing combat and Horde Spawner visibility/first-click behavior, closing the tested scopes of Issues #3 and #5.

## 0.0.33 — 2026-08-30

Contact, sound, reaction-variety, and Horde Spawner input corrections for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3) and [#5](https://github.com/jonathanjacobs/pz-zombie-factions/issues/5).

- continues coordinate pursuit through the broad animation envelope and stops only at a tighter contact distance, with smaller distributed approach slots, so an isolated pair can produce the collision required for a damage request;
- emits the shipped `ZombieBite` sound from the locally owned attacker once per collision-driven request;
- randomizes cosmetic target-owner reactions across shipped left/right shoulder and chest clips using four mod-owned bumped nodes;
- reuses and lays out the vanilla Horde Spawner controls instead of placing duplicate controls over them;
- records the stable v0.0.32 no-native-target result and the isolated-pair collision gap while keeping SPIKE-003 open for v0.0.33 validation.

## 0.0.32 — 2026-08-30

Native-target crash containment and synchronized reaction probe for reopened [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- removes the melee-range `setTarget(IsoZombie)` transition and requires the attacker native target to remain clear while coordinate pursuit, facing, bumped-state presentation, collision requests, and server damage validation remain separate;
- suppresses faction bite presentation during native attack, lunge, reaction, stagger, fall, knockdown, death, traversal, or crawler states;
- adds a target-owner cosmetic reaction using a mod-owned `bumped` node mapped to the shipped `Zombie_ShotShoulder_L` clip after a successfully applied server-dispatched nonlethal hit;
- adds bounded cleanup and `nativeZombieTargetsCleared` / `hitReactions*` diagnostics for the new safety invariants;
- records the v0.0.31 `AttackState.triggerPlayerReaction` `IsoZombie`-to-`IsoPlayer` crash and reopens SPIKE-003 validation;
- normalizes documentation around explicit ownership for requirements, architecture, roadmap, testing, validation history, ADRs, and SPIKE evidence.

## 0.0.31 — 2026-08-30

Standing bite-sequence correction for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- chains the native standing `Zombie_Bite_Start` wind-up into `Zombie_Bite_Success` inside the proven `bumped` state and completes the bump only after the follow-through;
- removes the immediate collision-time `setBumpDone()` that truncated the start clip into the observed raised-arm motion;
- keeps sprint approach/lunge behavior outside this close-range visual route, where sprinters use the same standing bite sequence at contact;
- defers bite presentation for crawler participants using the engine `isCrawling()` predicate rather than forcing a standing clip or relying on crawler collision delivery;
- adds visible client-summary counters for armed, suppressed, expired, and collided bites plus deferred crawler pairs.

## 0.0.30 — 2026-08-30

Native bumped-state faction-bite probe for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- replaces the rejected custom `zombiefactions-attack-network` presentation route with a `BumpType=Bite` node in the existing zombie `bumped` animation set, reusing the shipped `Zombie_Bite_Start` clip;
- arms the bite only for a validated, locally owned faction attacker inside the existing melee envelope and lets `OnCharacterCollide` become the only client-side damage-request trigger;
- keeps faction policy, ownership, range, cooldown, pending-hit, target-owner application, acknowledgment, and server-finalized death checks intact; no animation event carries damage authority;
- adds explicit `biteBumpsArmed`, `biteCollisions`, and `biteBumpsExpired` diagnostics so the next test can distinguish a missing collision from a rejected server hit.

## 0.0.29 — 2026-08-30

Build 42 custom faction-combat action-state probe for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- adds a mod-owned `zombiefactions-attack-network` action state and transitions from common standing/movement states only while the temporary faction-presentation variable is true;
- drives a vanilla `Zombie_Bite_Start` then `Zombie_Bite_Success` sequence from two mod-owned animation variables, without bundling third-party animation assets or using Blender-created content;
- sends the presentation variable only from the existing server-validated faction-impact cue, keeps faction damage outside animation events, and retains a bounded recovery clear for interrupted action graphs;
- removes target attachment and perception refresh from the presentation cue, avoiding a zombie character path goal and the player-oriented native `bAttack` route;
- renames the presentation metric to `presentationStarts` to distinguish action-state starts from target attachment.

## 0.0.28 — 2026-08-30

Explicitly synchronized combat-presentation probe for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- broadcasts a presentation cue only when the server has already validated and dispatched a faction impact;
- each receiving client locally attaches the exact cue pair only when safe and relevant, refreshes the remote target vector without a character-path goal, and retires the temporary presentation target after the short cue window;
- preserves existing owner pursuit, server-authorized damage, and death handling; the cue carries no target-selection or damage authority;
- adds presentation cue, attachment, suppression, and retirement counters to the client summary for runtime correlation.

## 0.0.27 — 2026-08-30

Rejected native zombie-target melee prime for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- recorded the v0.0.26 multiplayer result: the one-shot `pathToCharacter(candidate)` prime did not produce visible zombie-versus-zombie fighting and emitted `NetworkZombieMind: goal character is not set` errors;
- removed that prime because Build 42's network zombie path representation supports player character goals, not zombie character goals;
- removed `nativeMeleePrimes` and `nativeAttackStateEntries`, as remote-client attack state cannot prove that a faction candidate was the target;
- retained the established target, server-authorized impact, and synchronized death routes while SPIKE-002 evaluates a mod-owned, explicitly synchronized presentation path.

## 0.0.26 — 2026-08-30

Native melee-animation priming probe for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- recorded the v0.0.25 result: direct `bAttack` and `ZombieBiteDone` writes produced no observed attack animation; their counters measured write attempts rather than entry into a native attack state;
- removed those writes because Build 42 derives attack eligibility from internal zombie state rather than treating those variables as animation commands;
- after the existing exact target attachment inside the clear melee envelope, issues one native `pathToCharacter(candidate)` prime and never refreshes it while the target is attached;
- reports `nativeMeleePrimes` plus actual rising `isZombieAttacking(candidate)` transitions as `nativeAttackStateEntries` in the five-second client summary;
- retains existing server-authorized impact, validation, and death handling; native collision remains outside the faction damage route.

## 0.0.25 — 2026-08-30

Zombie combat presentation probe for [#3](https://github.com/jonathanjacobs/pz-zombie-factions/issues/3).

- added an owner-local SPIKE-002 probe that drives the shipped zombie/crawler attack action-graph variables (`bAttack` and `ZombieBiteDone`) only while an existing faction impact is authorized;
- retained the accepted server-authorized target, validation, owner-mediated damage, and server-finalized death path unchanged;
- explicitly avoids the unsupported `BumpType` values that caused the v0.0.23 frozen-arm regression;
- added native attack start/completion counters to the five-second client summary;
- recorded attack, reaction, sound, crawler, and death-presentation validation as unverified runtime work rather than a completed behavior claim.

## 0.0.24 — 2026-08-30

Invalid zombie bump-state recovery.

- recorded the v0.0.23 crowd result: combat was less clumped and produced 219 server-accepted damage events without a Zombie Factions runtime exception, but many combatants froze with outstretched arms;
- identified the freeze as misuse of `setBumpType("Bite")` / `setBumpType("BiteLow")`: Build 42 reserves zombie bump types for collision reactions and therefore never emitted the completion event for either unsupported value;
- removed the invalid bump-type write while retaining the staggered melee timing, authorization, cooldown, request budget, and server-validated damage path;
- added a narrowly scoped compatibility recovery that completes and clears only the two invalid bump values written by v0.0.23, leaving vanilla bump states untouched;
- added `invalidAttackBumpsRecovered` to the five-second client performance summary.
- closed SPIKE-001 after the final dedicated-server crowd run reached 142 enrolled zombies, accepted 496 validated damage events, and produced no Zombie Factions exception or recurring frozen-animation state;
- recorded the accepted server-authorized, owner-mediated multiplayer combat model in ADR-001 and moved multi-member mob scaling, ownership transfer, persistence, and attack presentation into follow-on development.

## 0.0.23 — 2026-08-30

Explicit animation-timed melee engagement.

- recorded the v0.0.22 result: distributed discovery worked and produced no mod exceptions, but 1,172 no-progress reacquisitions and more than 5,000 missing-exact-target samples per five-second client window starved late combat of damage;
- made targeting and impact callbacks deterministic, with targeting completing before impact in every shared controller pass;
- added a pass-scoped melee authorization for the exact server-granted subject/candidate pair after same-floor, distance, obstacle, traversal, and ownership checks;
- introduced a staggered owner-local bite cycle whose hit point can request damage without requiring vanilla `getTarget()` to survive multiple updates;
- made a clear pair within 0.90 tile a sticky melee commitment so lack of movement at contact no longer causes target churn;
- retained the one-second per-attacker cooldown and added a four-request-per-controller-pass client budget to bound packet bursts;
- added melee commitment, custom attack, exact/cleared target, authorization, cancellation, and impact-budget metrics.

## 0.0.22 — 2026-08-30

Distributed mob engagement and path-cancellation correction.

- fixed the engagement-backoff controller typo that passed an undefined `subject` variable to `getPathFindBehavior2()`, producing 1,597 client exceptions in the v0.0.21 crowd test;
- retained one recurring discovery leader per stable mob while treating its result as enemy-faction contact rather than one mandatory shared target;
- assigns each waking member a nearby eligible opponent from the detected enemy faction through the shared spatial index and existing soft target-load score;
- permits pile-ons when opponents are scarce while distributing members across alternatives when available;
- performs a bounded member-local replacement selection after candidate death or owner-reported no progress, without enabling recurring follower scans;
- validates queued assignments against the mob's active enemy faction instead of requiring every member to match the leader's candidate ID;
- added `memberSelections`, `memberRetargets`, and `distributedAssignments` server metrics.

## 0.0.21 — 2026-08-29

Stable leader-scanned faction mobs.

- replaced temporary target-sharing leases with stable server-side mob membership: each enrolled zombie is recruited once and remains assigned until death, identity reuse, or faction change;
- retained **Zombie Mob Size** as the membership cap and uses vanilla `ZombieConfig.RallyTravelDistance` as the one-time recruitment radius;
- restricted recurring discovery to one elected leader per mob while followers remain dormant until a target is granted;
- added automatic leader election when the current leader is dead, unavailable, or separated from the mob center;
- wakes a dormant defending mob with the known attacker when one of its members is targeted or damaged, avoiding a duplicate discovery scan;
- lets late recruits join an already active local mob without running discovery and keeps target grants owner-specific;
- limits follower wake-up grants to eight per server tick, preventing an unlimited mob from creating one packet/pathfinding burst;
- added mob, membership, dormant-follower, leader-scan, recruitment, leader-change, and reactive-wakeup server metrics.

## 0.0.20 — 2026-08-29

Persistent faction-hostility lifetime.

- removed the inherited 60-second server, target-controller, and impact-controller expiration paths;
- grants now carry an explicit persistent-lifetime flag rather than a large artificial timeout;
- pending discovery and active hostility continue until death, identity reuse, ownership transition, relationship or floor changes, excessive separation, explicit release, or stalled-target reacquisition;
- retained bounded acknowledgement timeouts, damage cooldowns, scan budgets, and reacquisition backoff because those constrain individual operations rather than ending faction hostility.

## 0.0.19 — 2026-08-29

SPIKE-001 crowd convergence and stalled-engagement correction.

- recorded the v0.0.18 result: size-8 mob sharing produced 837 inherited assignments, 1,133 grants, and 362 accepted damage events without a crash or kick, validating shared discovery;
- identified a high-density convergence failure where roughly 265 active subjects pursued shared candidates but generated no damage for repeated five-second intervals before their leases expired;
- changed candidate selection from nearest-only to distance plus a soft active-attacker load penalty, distributing new mobs when alternatives exist without forbidding many attackers from sharing one enemy;
- assigned every granted subject a deterministic inner/outer approach position around its candidate instead of pathing every member to the candidate's exact center coordinate;
- added staggered client no-progress detection and one owner-authenticated reacquisition request, with the previous candidate strongly deprioritized when another eligible target exists;
- added a half-second exact-target reattachment backoff, preventing the owner controller from reinstalling a game-cleared zombie target on every scheduler pass;
- added `loadBalancedSelections`, `stuckReacquires`, and `reattachBackoffs` performance counters;
- corrected Vanilla spawn summaries to report that relationship configuration was unchanged instead of printing a misleading Vanilla-to-Vanilla Hostile relationship.

## 0.0.18 — 2026-08-29

SPIKE-001 shared-target mob acquisition experiment.

- added the Sandbox Admin option **Zombie Mob Size**, defaulting to `1`; `1` preserves individual acquisition, values above `1` cap the local same-faction mob including its scanner, and `0` allows every eligible nearby member to share the target;
- changed successful discovery into a mob lease: one leader scans for a hostile candidate and nearby pending same-faction subjects can inherit that exact candidate without repeating the world-candidate scan;
- retained shared-target combat, so several mobs—or every member of an unlimited mob—may attack the same enemy;
- staggered follower reacquisition behind its leader after a candidate dies, reducing synchronized rescan bursts;
- removed the temporary 64-per-requester and 32-per-faction diagnostic enrollment limits so mob size, rather than an unrelated controller cap, determines membership;
- added mob-leader and shared-assignment counts to the five-second server performance summary for direct scan-reduction validation.

## 0.0.17 — 2026-08-29

SPIKE-001 client performance and enrollment-budget pass.

- recorded the successful v0.0.16 crash result: no fence-lunge or zombie-mind exception occurred and the client exited normally, but a 100-Red plus 100-Vanilla stress run became unplayable;
- identified client-side diagnostic work as the leading bottleneck: the retained log contained more than 20,000 faction lines, with roughly 7,700 lines written in one ten-second stress interval, while the server maintained 9.97 ticks per second;
- replaced both per-zombie combat callbacks with one shared owner-client scheduler running every six client ticks and operating only on tracked subjects;
- disabled detailed per-subject logs by default and replaced them with one aggregate client and server performance record every five seconds;
- added one shared, lazy online-ID index for resolving all pending grants in a controller pass instead of repeatedly scanning the complete client zombie list;
- limited obstacle evaluation to the melee envelope, cached results until either participant changes squares, and refreshes pursuit only after meaningful candidate movement or a five-second fallback;
- fixed a lost-target state where a record could remain in engagement mode with `target=-1`, and now reattaches the exact candidate when the clear melee conditions still hold;
- requires two stable close-range controller samples, an exact retained target, and at most 0.90 client distance before requesting damage; client request cooldown is one second;
- replaced the per-run 64-subject allowance with a cross-run 64-subject requester budget and a 32-subject-per-faction share, preventing overlapping runs from silently doubling owner-client control work while reserving participation for both sides.

## 0.0.16 — 2026-08-29

SPIKE-001 targetless pursuit and melee-only zombie target attachment.

- recorded the second v0.0.15 stress result: the traversal interlock suspended ten unsafe pairs and prevented the earlier zero-vector exception, but the client still crashed in `ClimbOverFenceState.OnAnimEvent_CheckAttack` at roughly 237 loaded zombies because polling could not clear an attached zombie target before the animation event;
- removed owner-side `spottedNew(otherZombie, false)` acquisition, which installed unsupported zombie character goals and produced `NetworkZombieMind: goal character is not set` errors;
- split owner control into targetless coordinate pursuit and close-range engagement: pursuit clears any zombie target before refreshing `pathToLocationF`, while engagement cancels the coordinate path and attaches the exact authorized target only within 1.20 tiles on the same or adjacent unobstructed squares;
- added 1.35-tile disengagement hysteresis and clears the zombie target before resuming coordinate pursuit; no path command is issued while a zombie target is attached;
- made traversal suspension and probe release clear any zombie target, including a stale crowd-reassigned target, while preserving an existing player target by pausing faction control;
- retained the server scheduler, relationship policy, targeted grants, and owner-mediated damage protocol without adding network packets.

## 0.0.15 — 2026-08-29

SPIKE-001 traversal and crowd-overlap crash interlock.

- recorded the v0.0.14 stress result: combat remained active with roughly 410 loaded zombies, but the client crashed rather than being kicked or timing out;
- traced the fatal path through Build 42's player-specific obstacle-lunge logic: a faction zombie in `climbfence` reached `attackFromWindowsLunge(...)`, which dereferenced player Moodles on a zombie target; a separate `LungeState` zero-vector exception also appeared under crowd overlap;
- added an owner-local, transition-logged safety interlock that clears only the authorized faction target while either participant is in a climb/fence/window/vault state, while a lunge reports a zero target vector, or while the pair is separated by less than 0.10 tile;
- native spotting, direct target control, location-path refresh, and diagnostic impact requests are suspended while the pair is unsafe and resume after it clears, without adding network packets or per-tick log spam;
- corrected the impact observer to convert the server-provided lifetime in seconds to client ticks, matching the target observer's v0.0.14 correction.

## 0.0.14 — 2026-08-29

SPIKE-001 direct Vanilla enrollment, identity hardening, and timing correction.

- recorded the successful v0.0.13 dedicated-server evidence: reciprocal Red/Vanilla combat, repeated owner-mediated damage and death, and mass-combat runs all operated through the bounded scheduler;
- when the SPIKE checkbox is enabled, Vanilla Horde Spawning now uses the diagnostic server path and directly enrolls every spawned Vanilla zombie instead of relying on another subject to discover and reciprocally enqueue it;
- pinned pending and active probe records to immutable zombie online IDs, rejecting unaddressable subjects and terminating stale records when a pooled Java zombie object is reused with a different ID;
- corrected scheduler constants for the observed 10 Hz server tick: discovery retries every second, the shared spatial index refreshes twice per second, and an explicit run lasts 60 seconds;
- added an explicit seconds-based grant lifetime so the 10 Hz server duration maps correctly onto the owning client's approximately 60 Hz update loop;
- retained the exact authorized zombie as the combat target while using a refreshed location path for pursuit. Decompiled Build 42.20.x source confirms that zombie-mind networking serializes location goals but logs an error when a character path goal points to anything other than an `IsoPlayer`;
- kept the four-scans-per-server-tick budget, shared candidate selection, targeted state-change instructions, and owner-mediated damage protocol unchanged.

## 0.0.13 — 2026-08-29

SPIKE-001 bounded discovery and ownership-reacquisition probe.

- recorded the v0.0.12 dedicated-server result: owner-mediated hits synchronized health `1.0 -> 0.75 -> 0.50 -> 0.25 -> 0.0` and the server successfully finalized the lethal death/corpse lifecycle;
- replaced the one-shot, first-subject lookup with a bounded scheduler for up to 64 explicitly requested subjects per run, limited to four due scans per server tick;
- added a short-lived spatial bucket index so all due subject scans reuse one loaded-zombie snapshot instead of independently traversing the full zombie list;
- subjects without a current candidate retry once per second for the 30-second diagnostic window, allowing a custom zombie spawned first to discover a later Vanilla zombie;
- reverse-hostile pairs enqueue one reciprocal subject probe, and candidates may be shared by multiple attackers instead of being exclusively reserved;
- ownership loss now pauses the grant and a later owner receives a targeted regrant; candidate death, policy changes, floor changes, and excessive separation release the pair and queue bounded rediscovery;
- the owning client maintains the exact authorized zombie target, retries native `spottedNew(...)`, falls back to `setTarget + pathToCharacter`, and periodically refreshes the target path without clearing the target into a location-only walk;
- acquisition, release, and damage instructions are sent only to the relevant owner connection and only on state changes or validated attacks; no per-zombie-per-tick network update was added;
- bounded the client duplicate-hit acknowledgement cache to 256 entries. Byte packing and lower-level storage optimization remain deferred until profiling demonstrates a need.

## 0.0.12 — 2026-08-28

SPIKE-001 owner-mediated zombie damage synchronization probe.

- recorded the v0.0.11 result: native `spottedNew(candidate, false)` committed the exact server-granted zombie target and reached pursuit/attack, but a server-only `applyDamage(0.25)` change was subsequently replaced by the target owner's stale health packet;
- changed each accepted faction impact into a uniquely identified server instruction routed to the target zombie's current simulation owner;
- the target owner now applies the fixed damage locally and acknowledges its before/after health, allowing its normal zombie packets to carry the same reduced value instead of restoring stale health;
- the server verifies the current target owner and exact health decrement, never accepts a health increase, rejects duplicate/stale acknowledgements, and times out or cancels hits across ownership changes;
- lethal acknowledgements remain server-finalized through the normal `die()`/`ZombieDeath` corpse path; this owner-mediated damage route now requires dedicated-server validation.

## 0.0.11 — 2026-08-28

SPIKE-001 faction-aware acquisition-entry probe.

- source tracing established that Build 42's ordinary zombie discovery is player-driven, exposes no zombie-to-zombie candidate-filter callback, and serializes zombie character targets as players only;
- added the shared, directional, side-effect-free `canTarget(attacker, candidate)` policy for zombie candidates; Hostile alone is eligible, while Friendly, Neutral, unset, self, and unsupported actor kinds fail closed;
- replaced the delayed request-value gate and hard-coded Vanilla predicate with one explicit server scan for one requested subject, filtering candidates through the current shared registry policy before issuing an exact-ID owner grant;
- the owner now tries bounded non-forced `spottedNew(candidate, false)` calls from `OnZombieUpdate`, then uses the already-proven `setTarget + pathToCharacter` path only as the control if native acquisition does not commit;
- acquisition rejects cross-floor candidates, candidates already reserved by another active probe, and zombie IDs that collide with active player IDs; damage repeats the current `canTarget` and same-floor checks;
- active grants are revoked on subject ownership change, relationship inputs are validated before either directional update, and client/server probe lifetimes are aligned;
- this remains one-shot research instrumentation, not recurring or autonomous production target acquisition.

## 0.0.10 — 2026-08-28

SPIKE-001 relationship-policy gate controls.

- the target-probe checkbox now accepts `FRIENDLY`, `NEUTRAL`, and `HOSTILE` spawned-faction relationships instead of rejecting non-Hostile runs;
- the server records `phase=policy-suppressed` and sends no candidate lookup or client AI instruction for Friendly and Neutral;
- only an explicit Hostile relationship can enter the existing forced-target and impact diagnostics;
- this validates the bounded harness policy gate, not autonomous faction-aware target acquisition.

## 0.0.9 — 2026-08-28

SPIKE-001 lethal-impact death replication probe.

- recorded the v0.0.8 dedicated-server result: server-side `applyDamage(0.25)` reduced the Vanilla candidate from health `1.00` to `0.00`, but the client continued to observe local candidate health `1.00` and no visible death;
- source inspection confirmed that `applyDamage(...)` only changes the server object's health and does not enter the normal zombie kill/death lifecycle or emit a general zombie-health packet;
- added a bounded lethal-impact follow-up that attributes the candidate to the SPIKE subject and calls `die()` after a successful lethal impact;
- v0.0.9 dedicated-server testing confirmed two lethal probe runs with `deathLifecycleInvoked=true`; the client received the matching result and later displayed the two resulting zombie corpses;
- nonlethal zombie-health replication remains an open engine boundary; this probe does not claim it is supported.

## 0.0.8 — 2026-08-28

SPIKE-001 attack-state and server-authoritative impact probe.

- recorded the v0.0.7 dedicated-server result: owner-side `setTarget(...) + pathToCharacter(...)` successfully retained another `IsoZombie` target and advanced through `walktoward`, `lunge`, `face-target`, and `attack` states;
- `isZombieAttacking(candidate)` repeatedly became true at melee range, demonstrating that Build 42 can drive a client-owned zombie through native pursuit and attack-state logic against another zombie;
- no candidate health/death change was observed during those native attack states, isolating the next blocker to hit/damage/death handling rather than target retention or pursuit;
- server observation saw the same state transitions but did not retain the client-side zombie target, and the client repeatedly logged `NetworkZombieMind: goal character is not set`, confirming that native MP mind synchronization is not representing the zombie target cleanly;
- client-side faction lookup still resolved the tagged test subject as `zf:vanilla` while the server correctly resolved the custom faction, so production client identity cannot rely on zombie `modData` propagation alone;
- added a bounded client `ImpactProbe` that listens only to explicit SPIKE subject/candidate IDs and requests a server impact on a rising native attack event at melee distance;
- the server validates active run IDs, ownership, exact online IDs, server-side faction identity, HOSTILE relationship, candidate faction, distance, cooldown, and liveness before calling `IsoGameCharacter.applyDamage(0.25)` on the Vanilla candidate;
- server/client diagnostics report candidate health before/after each accepted impact and whether the candidate dies, allowing the next runtime test to determine whether server-side zombie health/death changes synchronize without a native zombie-to-zombie hit packet;
- the impact probe is research instrumentation only; it is not yet the production combat/damage architecture.

## 0.0.7 — 2026-08-28

SPIKE-001 multiplayer ownership and target-path boundary probe.

- recorded the v0.0.6 dedicated-server result: faction/test-run assignment re-resolved correctly, but server-side `setTarget(...)` + `pathToCharacter(...)` only retained zombie targets briefly; every forced subject remained `idle`, never entered an attack state, and the target was cleared;
- all successfully forced subjects reported `owner=admin`, making client ownership a primary unresolved variable rather than proving that `IsoZombie` categorically rejects another zombie as a target;
- the v0.0.6 client observer loaded but produced no tagged-subject observations, so v0.0.7 no longer depends on zombie mod-data propagation to identify the test subject on the client;
- the server now sends the selected subject/candidate online IDs and run metadata to the requesting client and passively observes server-visible state instead of forcing the target itself;
- the owning client resolves those IDs with a bounded diagnostic lookup, verifies local ownership, and performs Phase A: `setTarget(...)` + `pathToCharacter(...)`;
- source/API research found a documented Build 42 defect in `spottedNew(...)` when the target is an `IsoZombie`, so the probe does not call `spotted()`/`spottedNew()` with zombie targets;
- if Phase A stalls, Phase B uses the explicitly older `spottedOld(candidate, true)` path before repeating target/path assignment, purely as a bounded diagnostic of whether perception state is the missing gate;
- if both target-specific phases stall, Phase C clears the target and calls `pathToLocationF(...)` toward the candidate coordinates to distinguish generic movement/pathing from zombie-target-specific path behavior;
- added bounded client and server transition logs for ownership, remote status, target retention, state, attack status, distance, observed movement, and death;
- retained the existing single SPIKE checkbox and the one-time bounded Vanilla-candidate scan; no production global zombie scan or target-clearing loop was introduced.

## 0.0.6 — 2026-08-27

SPIKE-001 assignment validation and direct target probe.

- recorded the successful v0.0.5 dedicated-server harness test: custom Red/Blue spawns, asymmetric relationships, symmetric hostility, and multi-zombie requests all completed without Zombie Factions Lua errors;
- independently re-resolves faction and SPIKE run metadata immediately after assignment and again after a short delay for up to 10 sampled subjects per test run;
- added an opt-in admin `SPIKE: force nearest HOSTILE Vanilla zombie target` control;
- for that explicit diagnostic only, the server finds the nearest living `zf:vanilla` zombie within 12 tiles, calls `setTarget(...)` and `pathToCharacter(...)`, then emits bounded state/target/attack-transition observations;
- added a client `OnZombieUpdate` observer that exits immediately for ordinary zombies and logs only state changes for explicitly tagged SPIKE subjects, allowing client-side mod-data propagation and ownership/target behavior to be verified;
- the direct-target scan is diagnostic research only and is not the production faction targeting architecture;
- added otherwise-empty `AnimSets` and `actiongroups` directories under the common and Build 42 media roots to avoid Build 42 `AdvancedAnimator` missing-directory startup stack traces.

## 0.0.5 — 2026-08-27

SPIKE-001 Horde Spawner control replacement.

- runtime screenshot confirmed v0.0.4 enlarged the Horde Manager correctly but the vanilla bottom controls were still not rendered inside the visible window;
- stopped depending on post-construction behavior of the vanilla `anchorBottom` controls;
- the Zombie Factions extension now creates its own Spawn, Remove Zombies, Remove Bodies, and Close buttons after the final extended window geometry is known;
- the replacement buttons call the existing `ISSpawnHordeUI` handlers, so Vanilla still follows the stock spawn path while test factions use the Zombie Factions server command;
- updated bounded UI diagnostics to report the independent harness button coordinates.

## 0.0.4 — 2026-08-27

SPIKE-001 Horde Spawner explicit geometry fix.

- corrected the second runtime failure where the faction controls rendered but the vanilla Spawn/Remove/Close buttons were still not visible;
- confirmed from Build 42 `ISUIElement:setHeight()` that changing the window height does not provide a reliable post-construction child reposition for this patch;
- stopped relying on `anchorBottom` behavior and explicitly placed the two vanilla bottom button rows after the final extended window height was known;
- added a bounded `[ZombieFactions][UI]` geometry diagnostic containing the final window height plus Spawn and Remove row Y coordinates;
- subsequent runtime testing showed the vanilla controls still did not render, leading to the independent harness controls in 0.0.5.

## 0.0.3 — 2026-08-27

SPIKE-001 Horde Spawner layout correction attempt.

- first runtime test showed the admin Horde Spawning extension pushing the vanilla Spawn, Remove Zombies, Remove Bodies, and Close buttons below the visible window;
- removed the 0.0.2 duplicate manual shift and attempted to rely on vanilla bottom anchoring;
- added explicit client/server startup diagnostics for the SPIKE-001 harness;
- subsequent runtime testing showed the bottom controls still were not visible, leading to the explicit-coordinate fix in 0.0.4.

## 0.0.2 — 2026-08-26

SPIKE-001 diagnostic horde-spawn harness.

- extended the built-in admin Horde Spawning window with `zf:test-red` and `zf:test-blue` selections;
- added independent `spawned faction -> zf:vanilla` and `zf:vanilla -> spawned faction` relationship controls plus a symmetric convenience toggle;
- added a server-authoritative `SpawnTestHorde` command gated by `Capability.CreateHorde`;
- reused `addZombiesInOutfit(...)` and tags the exact returned `IsoZombie` objects instead of scanning nearby zombies after spawn;
- added zombie faction/test-run assignment helpers using zombie mod data;
- added bounded `SPIKE001-####` run identifiers and spawn-result logging;
- retained the original vanilla Horde Spawning path whenever `zf:vanilla` is selected;
- no faction-aware target acquisition or zombie-vs-zombie combat behavior is claimed yet.

## 0.0.1 — 2026-08-26

Initial repository foundation.

- established the Build 42 mod package structure;
- defined the Vanilla/default zombie faction concept;
- defined directional `FRIENDLY`, `NEUTRAL`, and `HOSTILE` relationships;
- documented integration with existing Project Zomboid player factions;
- established lean requirements, design, SPIKE-001, and compliance documentation;
- added the minimal shared faction registry/relationship API skeleton.
