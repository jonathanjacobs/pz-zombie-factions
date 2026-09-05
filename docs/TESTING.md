# Testing

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

## Environment

Use a dedicated Build 42.20.x server and at least one client. Capture clean client and server logs for each focused test. Do not treat an administrator's visual impression alone as sufficient evidence for multiplayer authority or damage behavior.

Mod deployment (local and remote) and clearing local/remote logs and console output before a run, plus collecting and zipping both sides' logs after, are automated by [`../scripts/pretest-setup.ps1`](../scripts/pretest-setup.ps1) and [`../scripts/posttest-cleanup.ps1`](../scripts/posttest-cleanup.ps1) — see [`../scripts/README.md`](../scripts/README.md). Server/client launch, admin login, and Horde Spawner cleanup remain manual.

The client's `DebugLog.txt` caps in place at roughly 4.3MB observed on this machine: once a session's cumulative log volume crosses that line, the file silently drops its own oldest lines, with nothing recoverable afterward. The server-side log has shown no equivalent cap. In one session mixing a small-scale test with a mass-combat stress test, this let the mass-combat volume alone push the small-scale phase's client-side detail out of the file before the session ended, leaving only server-side evidence for that phase. Run [`../scripts/snapshot-client-log.ps1`](../scripts/snapshot-client-log.ps1) right after each phase worth preserving, before starting the next — it copies the live client logs without stopping or clearing anything.

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
