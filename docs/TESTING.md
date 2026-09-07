# Testing

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

## Environment

Use a dedicated Build 42.20.x server and at least one client. Capture clean client and server logs for each focused test. Do not treat an administrator's visual impression alone as sufficient evidence for multiplayer authority or damage behavior.

Mod deployment (local and remote) before a run, plus collecting and zipping both sides' logs after, are automated by [`../scripts/pretest-setup.ps1`](../scripts/pretest-setup.ps1) and [`../scripts/posttest-cleanup.ps1`](../scripts/posttest-cleanup.ps1) — see [`../scripts/README.md`](../scripts/README.md). Server/client launch, admin login, and Horde Spawner cleanup remain manual. Neither script clears logs; the game archives each session's files into a dated `logs_<date>` folder at startup, so the post-test zips accumulate history and should be cleared from the repo's `Logs/` folder by hand when they grow inconvenient.

A log file written through the game's own logger is emptied in place once it passes roughly 9.8MB. The engine checks the size after every write, and on crossing that line it closes the file, reopens the same path without append, and continues from zero. Nothing is rotated, copied, or dropped selectively — the entire contents are lost, and no archiving step runs at that moment to preserve them. A file well under the limit may therefore still be a fragment: a v0.0.40 session left a 3.3MB `DebugLog.txt` holding only its final 18 seconds, having wiped roughly once a minute under mass-combat logging at about 186KB/s.

Two consequences. Per-event mod diagnostics should be off for any mass-combat phase, since the periodic summaries carry the measurements and cost almost nothing. Where per-event detail is genuinely needed, run [`../scripts/snapshot-client-log.ps1`](../scripts/snapshot-client-log.ps1) between phases — it copies the live client logs without stopping or clearing anything, but it has to run more often than the wipe interval to be reliable.

The server's `server-console.txt` is redirected console output rather than a logger file, so it is not subject to that limit and has held complete multi-megabyte sessions. It is often the only complete record of a heavy run.

## Diagnostic verbosity

Two independent facilities produce evidence. Enable the mod's own diagnostics first; it is the only source that reports faction mob membership, target grants, and damage-probe decisions.

### Mod diagnostics

Per-event mod logging is suppressed by default, leaving only the periodic `[ZombieFactions][PERF]` and `[ZombieFactions][SERVER_PERF]` summaries. To capture per-event `ACQUISITION_PROBE`, `OWNER_PROBE`, `MOB`, `FACTION_IMPACT`, and `DAMAGE_PROBE` lines:

- Server: set `SERVER_VERBOSE_DIAGNOSTICS = true` in `TestHarness_Server.lua`.
- Client: set `verbose = true` in the `ClientCombatController.lua` controller table.

Both default to `false` and neither has an in-game toggle. Redeploy to the local and server mod folders and restart both sides. Return both to `false` before any crowd run or release build; per-event output is unbounded and will bury the summaries it exists to explain.

### Game logging

Build 42.20 reads per-category log severities from a profile file and hot-reloads it through a file watcher while the game runs:

- Client: `<cachedir>/debuglog.cfg`
- Server: `<cachedir>/debuglog-server.cfg`

`-all` clears, `+<DebugType> <LogSeverity>` enables, and a leading `=` selects the active profile:

```
factions
{
-all
+Multiplayer Debug
}
=factions
```

Categories are the `DebugType` enum values (`Zombie`, `Combat`, `Multiplayer`, `Network`, `Packet`, `Damage`, `Death`, `Lua`, `Mod`, `ActionSystem`, and others). Severities are `Trace`, `Noise`, `Debug`, `General`, `Warning`, `Error`, and `Off`. The paths and format above are read from the Build 42.20 engine and have not yet been exercised in a recorded run.

This facility reports engine state only and cannot report faction mob membership, target grants, or profile selection. Reserve it for ownership-authority and position-desync questions, and enable one category at a time; `Zombie`, `Combat`, or `Network` at `Debug` severity in a live multiplayer session produces enough volume to displace mod output.

### Visual debug options

`debug-options.ini` holds render and behavior flags. The engine loads the file during normal startup on both the client and the dedicated server, but the options below additionally require the client to run in debug mode before they draw anything. Administrator rights in multiplayer expose the debug context menu and the Horde Spawner without enabling debug mode, and are not sufficient for these options.

Options useful during faction-combat runs, all requiring a debug-mode client:

- `Pathfind.Render.Path` — shows whether pursuit issued a usable path. Drawn from `debugRenderLast`, which the engine calls only under debug mode.
- `Multiplayer.DebugFlags.Zombie.Enable` with `.State` — distinguishes active from dormant mob members on sight.
- `Multiplayer.DebugFlags.Zombie.Position` with `.Prediction` — shows the server/client position gap behind distance rejections. This family is declared debug-only.

These change presentation only and do not affect log volume. Prefer leaving them off when a run's purpose is to compare against earlier evidence captured without debug mode; changing the client launch mode changes the run's conditions.

## Baseline faction-combat procedure

1. Confirm the installed mod reports the intended version in both server and client logs.
2. Use the administrator Horde Spawning extension to create the selected diagnostic faction pair on clear, level ground.
3. Set both relationship directions to `HOSTILE`; record the intended pair and mob-size setting.
4. Observe pursuit, contact, standing bite presentation, damage, and lethal corpse handling.
5. Review `[ZombieFactions][PERF]` and `[ZombieFactions][SERVER_PERF]` summaries for errors, arm/collision counts, bite sounds, defender reactions, accepted damage, native-target clears, and distance rejections.
6. Record the observed result in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). Put a new hypothesis, rejected approach, or detailed diagnostic interpretation in a SPIKE instead.

## Focused follow-ups

- Use v0.0.34 as the accepted dedicated-server, one-client standing baseline. Regression runs should require nonzero `biteCollisions`, `impactRequests`, `biteSoundsPlayed`, `hitReactionsArmed`, and accepted server damage before adding more zombies, while retaining `impactExactTarget=0` and no `AttackState.triggerPlayerReaction` exception.
- Retain the Issue #5 regression check: open Horde Spawning, select a faction test spawn, click Spawn once, and require exactly one client success plus one server spawn request. Repeat after changing count and faction without closing the window.
- Test two-client attacker/defender ownership separation after the v0.0.36 one-client crawler matrix; neither crawler behavior nor two-client crawler ownership is established by the accepted v0.0.34 run.
- Retain a standing-bite coherence regression check with moving, dying, and retargeted defenders; flag any bite completed at a departed target without adding timer-only damage.
- Retain the v0.0.36 crawler and stomp counters as regression evidence. The supplied mixed-crowd run exercised all three profiles, but it does not replace isolated posture cases or two-client ownership testing.
- Test player behavior separately whenever faction-combat code changes.

## Version 0.0.36 crawler combat matrix

Use a dedicated server with one client, clear level ground, mob size `1`, and the accepted `0.80` client / `1.60` server distance values. Use directional Red/Vanilla relationships to isolate the intended attacker whenever possible. Observe each case until at least one accepted damage result and preferably one normal lethal corpse outcome.

| Attacker | Defender | Expected profile | Expected presentation |
| --- | --- | --- | --- |
| Red crawler | Standing Vanilla | `CRAWLER_LUNGE` | crawler lunge plus low standing reaction |
| Standing Vanilla | Red crawler | `STANDING_STOMP` | standing stomp plus crawler floor reaction |
| Red crawler | Vanilla crawler | `CRAWLER_LUNGE` | crawler lunge plus crawler floor reaction |
| Standing Red | Standing Vanilla | `STANDING_BITE` | accepted collision-driven standing baseline |

For each faction pair:

1. Spawn the two explicit subjects with one direction `HOSTILE` and the reverse direction `FRIENDLY`; record which faction is expected to attack.
2. Confirm pursuit closes to contact without attaching the defender as a native zombie target.
3. Require the expected `crawlerLungesArmed` / `crawlerLungeImpacts`, `stompsArmed` / `stompImpacts`, or standing `biteBumpsArmed` / `biteCollisions` counters.
4. Require a matching `FACTION_IMPACT` request with the expected profile and evidence: `animation-window` for crawler lunges and stomps, `character-collision` for standing bites.
5. Require server `damageDispatched` and `damageAccepted` to increase while `damageProfileRejected=0`, `damageConfigMismatch=0`, and no distant-looking hit is observed.
6. Confirm a nonlethal defender reaction appropriate to its posture and, when the run reaches lethal damage, the normal server-finalized corpse lifecycle.
7. Confirm no `AttackState.triggerPlayerReaction` exception, stuck custom hit reaction, frozen stomp, repeated impact from one animation cycle, or Zombie Factions error.

Separately spawn or encounter an ordinary crawler attacking the player. Confirm its native pursuit, lunge, and player damage remain unchanged and that the faction impact controller does not replace the player target or send a crawler faction-impact request for that encounter.

## Version 0.0.37 sitting-defender case

Use the Horde Spawner's shipped `isSitting` option to create one sitting Red zombie and one standing Vanilla zombie on clear level ground. Set Vanilla-to-Red `HOSTILE` and Red-to-Vanilla `FRIENDLY`, enable the bounded faction acquisition probe, and retain the accepted `0.80` client / `1.60` server distances.

Before each spawn, explicitly clear posture options left from the preceding case. Selecting the Vanilla faction does not reset `isCrawler`, `isKnockedDown`, `isSitting`, or other Horde Spawner controls.

1. Confirm the standing attacker closes to the sitting defender without acquiring it as a native zombie target.
2. Require `sittingStompsArmed`, `sittingStompImpacts`, `sittingDefendersAlerted`, and `sittingGetupLocksArmed` to increase.
3. Require a `STANDING_STOMP` / `animation-window` request followed by server-dispatched and accepted damage with `damageProfileRejected=0`.
4. Confirm the defender visibly uses the shipped sitting get-up animation and reaches standing; require `sittingDefendersStood`, `sittingGetupAttackPauses`, and `sittingGetupLocksReleased` to increase while `sittingGetupsExpired=0` and `sittingGetupLocksExpired=0`.
5. Confirm that no second stomp or standing bite begins during the get-up. After the lock releases, require the same standing attacker to use `STANDING_BITE` rather than `STANDING_STOMP` if hostility remains active.
6. Confirm the now-standing defender can move and react normally. With the reverse relationship still `FRIENDLY`, it must not retaliate; after explicitly changing that direction to `HOSTILE`, ordinary standing combat may begin.
7. Confirm no latched sitting, frozen stomp, duplicate impact from one stomp, native-target crash signature, or Zombie Factions error.

As a failure-path check, repeat once with a sitting defender that does not stand. Require `sittingGetupLocksExpired` to increase after approximately three seconds and confirm that another stomp can then be attempted; the lock must not permanently strand the attacker.

## Version 0.0.40 sprinter locomotion matrix

Version 0.0.40 adds a "Spawn speed" selector to the Horde Spawner. Its values are the
shipped selectors: `1` sprinter, `2` fast shambler, `3` shambler, `4` random, plus a
"Use sandbox speed" default that applies nothing. Selecting any explicit speed routes
the spawn through the harness even for the Vanilla faction, because the vanilla
asynchronous spawn returns no handle to apply a speed to.

Use mob size `1`, the accepted `0.80` client / `1.60` server distances, clear level
outdoor ground, and a spawn radius of 2–3 rather than 0 so the pair does not stack.
Clear posture options left over from a previous case before every spawn. Confirm each
spawn reports `speedApplied` and `speedVerified` equal to the requested count with
`speedFailed=0` before drawing any conclusion from the run.

The decisive evidence is the `[ZombieFactions][SPRINT_PERF]` line, not visual
impression. `sprintTilesPerSecond` must be materially above `shamblerTilesPerSecond`
measured in the same run, with both sample counts non-trivial. From v0.0.41 both sides
of every tracked pair are sampled while the engine reports them moving, so a shambler
defender supplies the control without needing its own grant; a run that still reports
`shamblerTravelSamples=0` had no moving shambler in it and cannot establish the
comparison.

`sprintNodeLoopsPerSecond` separates "the mod asked for a sprint" from "the game
actually played one". Expect roughly one to two loops per second while sprint intent
is held. Zero means the node never won selection. Do not read the raw loop count on its
own. Require `sprintVariableErrors=0` throughout.

From v0.0.42, three counters cover braking. `sprintBrakeDistanceAvg` reports where
sprint was actually dropped; it reads lower than the configured distance because the
brake fires on the first pass at or inside it and a converging pair closes about `0.68`
tiles per pass. `sprintMeleeAuthDistanceAvg` reports the pair distance at the first
melee authorization of each engagement, and is the figure that shows whether braking
worked — a v0.0.42 run recorded `0.51`–`0.54` where an unbraked pair had never been
authorized at all. `sprintOvershoots` counts passes where a pair inside the engagement
band got further apart while sprint was active, so it should stay near zero; before
v0.0.43 it was gated on speed type rather than sprint state and also counted ordinary
jostling at melee range.

Per-event diagnostics are unbounded. Either disable them before any mass-combat phase
or snapshot between phases; a v0.0.40 session lost all but its final 18 seconds of
client log to the in-place cap described above, including the evidence for its own
isolated pair cases.

Run these cases separately, capturing logs per phase with
[`../scripts/snapshot-client-log.ps1`](../scripts/snapshot-client-log.ps1):

1. **Sprinter versus shambler.** One speed-`1` Red attacker against one sandbox-speed
   Vanilla defender, Red-to-Vanilla `HOSTILE` and the reverse `FRIENDLY`. This is the
   primary locomotion case and the source of the control figure. Confirm a visible
   sprint during approach, a clean stop at contact, `STANDING_BITE`, and accepted
   damage.
2. **Sprinter versus sprinter.** Both sides speed `1`, mutually `HOSTILE`. Expect this
   case to stress close-range convergence; a stall here that does not appear in case 1
   belongs to [#10](https://github.com/jonathanjacobs/pz-zombie-factions/issues/10)
   rather than to locomotion.
3. **Sprinter versus crawler.** Speed-`1` attacker against an `isCrawler` defender.
   Require `STANDING_STOMP` selection and accepted damage; the attacker's speed must
   not change profile selection.
4. **Sprinter versus sitting defender.** Speed-`1` attacker against an `isSitting`
   defender. Require the v0.0.37 sequence unchanged: one stomp, get-up lock, native
   get-up, then `STANDING_BITE` after the lock releases.
5. **Player regression.** One speed-`1` Vanilla sprinter with the faction probe
   disabled. Remove invisibility and confirm its ordinary player chase is unchanged.
   Require `sprintActivations=0` for that phase, since the mod must not be requesting
   anything.

A faction sprinter will not stumble the way a player-chasing sprinter does. The shipped
trip roll requires a native target, which faction pursuit deliberately holds clear, so
its absence is expected behavior in this build rather than a test failure. See
[`spikes/SPIKE-005-sprinter-locomotion.md`](spikes/SPIKE-005-sprinter-locomotion.md).

## Version 0.0.45 Neutral retaliation matrix

Use mob size `8`, the accepted `0.80`/`1.60` distances, clear level ground, and the
default `RetaliationRadius=8` / `RetaliationSeconds=60`. Server diagnostics on; the run
is short enough that the client log will survive.

Relationships: Red → Vanilla `HOSTILE`, Vanilla → Red `NEUTRAL`. Disable the symmetric
mirror so the two directions differ.

The discriminating case is the third one. The first two only show that retaliation
happens at all; the third is what proves hostility stayed individual.

1. **A Neutral zombie does not initiate.** Spawn one Vanilla and one Red about ten
   tiles apart with the target probe enabled. The Red must attack; the Vanilla must not
   attack first. Require `retaliationsFormed=0` until the first accepted hit lands.
2. **A free victim answers.** After the first accepted hit, require `retaliationsFormed`
   and `retaliationPinnedSelections` to increase, and the Vanilla to fight back against
   the Red that hit it. Confirm the `RETALIATION` line reports `victimFree=true`.
3. **Hostility does not spread.** Add a second Red that never attacks, standing within
   the retaliation radius. The retaliating Vanilla must ignore it entirely. If it
   attacks the second Red, hostility leaked to the faction and the design has failed.
   This is the case worth repeating.
4. **An engaged victim keeps its fight, friends answer.** Give the Vanilla a hostile of
   its own to fight first, then have a Red hit it, with a spare free Vanilla within the
   radius. The victim must not switch targets; the spare must retaliate. With no spare
   in range, expect no retaliation at all — that is intended, not a failure.
5. **It lapses.** Stop attacking and wait past `RetaliationSeconds`. Require
   `retaliationsExpired` to increase, the retaliation grants to be released, and the
   Vanilla to visibly disengage rather than finish the fight.
6. **The timer refreshes.** Attack repeatedly at intervals shorter than the duration and
   confirm `retaliationsRefreshed` increases while `retaliationsExpired` stays at zero.

Throughout, require `damageProfileRejected=0`, `damageConfigMismatch=0`, and no Zombie
Factions exception. Note how long recruits take to receive their first grant: they are
picked up by the mob maintenance sweep, which runs once a second, so a visible delay of
about that order is expected and anything much longer is worth reporting.

## Issue #1 distance-envelope matrix

Version 0.0.35 exposes two diagnostic sandbox options, both measured in planar tiles:

- `ZombieFactions.ClientCollisionDistance` — owner-client request gate; default `0.80`, range `0.25`–`2.00`. A real `OnCharacterCollide` event remains mandatory.
- `ZombieFactions.ServerValidationDistance` — authoritative server distance gate; default `1.60`, range `0.25`–`2.00`. Every other server validation remains mandatory.

Restart the server after changing either option so all grants use one configuration. Confirm the server load marker, client tracking record, and both performance summaries report the intended values; require `damageConfigMismatch=0`.

For each combination, run the same sequence with clean logs:

1. Spawn a mutually hostile standing Red/Vanilla 1v1 pair on clear, level ground. Observe for at least 60 seconds or until one participant dies.
2. Record `biteCollisions`, `impactRequests`, `damageRequests`, `damageDispatched`, `damageDistanceRejected`, `damageAccepted`, and the server distance aggregates.
3. Repeat with mob size `8` and the same Red/Vanilla counts, spawn radius, observation time, and zombie-speed mix for every combination.
4. Record visible distant hits, stalled combat, deaths, client FPS, faction errors, and disconnects. Do not compare rejection ratios across runs with different crowd setup or duration.

Recommended first matrix:

| Client | Server | Purpose |
| ---: | ---: | --- |
| `0.80` | `1.60` | Accepted v0.0.35 default. |
| `0.90` | `1.25` | Accepted v0.0.34 baseline. |
| `0.90` | `1.50` | Isolate additional server latency tolerance. |
| `0.75` | `1.25` | Test whether a tighter client request gate removes late requests. |
| `1.00` | `1.50` | Explore a wider paired envelope only after the first three runs remain visually contact-driven. |

A useful candidate materially lowers `damageDistanceRejected / damageRequests` without distant-looking hits, duplicate damage, reduced sustained deaths, authority/configuration mismatches, or new errors. Record actual outcomes in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); do not infer a preferred production value from configuration alone.
