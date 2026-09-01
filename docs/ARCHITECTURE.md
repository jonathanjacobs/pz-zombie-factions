# Architecture

Status: Research / Pre-Alpha
Target: Project Zomboid Build 42.20.x

This document owns the current implementation model. Normative behavior belongs in [`REQUIREMENTS.md`](REQUIREMENTS.md); open work belongs in [`ROADMAP.md`](ROADMAP.md); experimental detail belongs in [`spikes/`](spikes/).

## Runtime layout

```text
Contents/mods/pz-zombie-factions/
  42/media/lua/shared/ZombieFactions/  faction identity and relationship policy
  42/media/lua/server/ZombieFactions/  enrollment, grants, validation, death
  42/media/lua/client/ZombieFactions/  owner-local pursuit and presentation
  42/media/AnimSets/                   mod-owned mappings to shipped bite clips
```

## Faction policy

The shared layer provides stable zombie-faction identity, directional relationships, and side-effect-free eligibility checks. `zf:vanilla` is the default identity; `zf:test-red` and `zf:test-blue` are diagnostic identities. Zombie assignment currently uses zombie `modData` and optional run identity. Production persistence and automatic enrollment are not yet complete.

## Authority and combat flow

The accepted authority boundary is recorded in [`adr/ADR-001-zombie-combat-authority.md`](adr/ADR-001-zombie-combat-authority.md):

1. The server resolves policy, maintains bounded mobs, selects an eligible pair, and grants that pair to the attacker’s current owner.
2. The owner client performs bounded coordinate pursuit through the broad animation envelope, stops only at the tighter contact distance, faces the granted defender, and keeps the zombie's native target clear.
3. A locally observed collision is the sole source of a hit request.
4. The server revalidates identity, policy, ownership, level, range, cooldown, liveness, and grant state.
5. The target owner applies the uniquely identified nonlethal decrement; the server verifies it and alone finalizes lethal death through the normal corpse lifecycle.

The protocol is pair-specific and state-change-driven. Ownership changes, death, pooled-object reuse, policy changes, invalid distance/level, explicit release, and no-progress recovery invalidate or replace grants. Client polling alone does not create damage authority.

## Mob discovery

Stable server-runtime mobs cap membership through `ZombieFactions.ZombieMobSize`. A leader performs bounded discovery; followers receive one bounded, load-aware selection when contact begins. Multiple attackers may share a target, while soft assignment penalties and approach positions reduce crowd clumping. Event-driven wake-up and recovery remain bounded.

## Combat presentation

For standing, non-crawling faction pairs, the owner client enters a mod-owned bumped-state mapping to the shipped `Zombie_Bite_Start` and `Zombie_Bite_Success` clips only while the attacker's native target is clear. Collision remains the trigger for the separately validated `STANDING_BITE` impact route.

Version 0.0.36 adds two posture profiles. `CRAWLER_LUNGE` maps the shipped `Zombie_CrawlLunge` clip into the crawler's existing targetless hit-reaction state. `STANDING_STOMP` maps the shipped `Bob_AttackFloorStamp` clip into the standing zombie's bumped state when its defender is crawling. Each animation emits only a mod-owned contact-window variable; it does not copy native `AttackCollisionCheck`, player-reaction, voice, melee-delay, or stomp events. The owner may request one impact from that window only while the exact grant remains authorized, same-level, close-range, and posture-consistent. The server independently derives the expected profile and evidence type before applying every existing damage-authority check. A v0.0.36 mixed-crowd run exercised both profiles with accepted damage and no profile mismatch; the remaining bounded matrix is maintained in [`TESTING.md`](TESTING.md).

Version 0.0.37 classifies a shipped `isSitAgainstWall()` defender as low posture for a standing attacker, so it reuses `STANDING_STOMP` instead of waiting for a standing-bite collision that sitting zombies do not reliably emit. After the target owner applies accepted nonlethal damage, it calls the shipped `setTurnAlertedValues()` route toward the server-supplied, validated attacker coordinates. Carrying coordinates in the dispatch avoids requiring the target-owner client to resolve an attacker that may belong to another client. The native route initializes the turn-alerted state, internal alert flag, and network update without broadcasting a world sound. The native sitting action group owns the resulting `getup-fromSitting` transition and clears the sitting posture; the mod observes but does not force that state change. At the sitting stomp's impact window, the attacker owner also arms a bounded pair-local get-up lock. The current stomp may finish, but no new presentation can arm until the defender is non-sitting, outside a native get-up-from-sitting state, and stable for 30 client ticks. The lock survives same-pair grant replacement and expires after 180 client ticks so a failed wake can be retried rather than freezing combat. Crawler attackers retain `CRAWLER_LUNGE` precedence against sitting defenders. This extension requires the focused runtime case in [`TESTING.md`](TESTING.md).

The presentation does not use player hit packets, `pathToCharacter` with a zombie target, native `setTarget(IsoZombie)`, or `bAttack` writes. After a target owner applies a server-dispatched nonlethal hit, standing defenders use either the four existing shoulder/chest reactions or a low crawler-bite reaction; crawler defenders enter their shipped floor-reaction path. Standing bites and crawler lunges use an owner-local `ZombieBite` sound, while stomps request the shipped `AttackStomp` sound.

The v0.0.31 standing presentation result was invalidated by a client crash when native `AttackState` attempted a player reaction against an `IsoZombie` target. Version 0.0.32 removed that coupling without a repeated crash but left an isolated pair outside collision range. The v0.0.34 controlled dedicated-server, one-client run validated the tighter v0.0.33 contact closure, collision-timed sound, damage, and bounded reactions without repeating the crash. The v0.0.36 mixed-crowd run extended that evidence to crawler and stomp traffic. Two-client ownership separation and the v0.0.37 sitting get-up behavior remain separately scoped work.

## Diagnostic harness

The administrator Horde Spawning extension and SPIKE checkbox are controlled-test tooling, not production enrollment. Build 42 does not reliably relocate the vanilla `anchorBottom` controls after the extension resizes the window, so the displaced originals are hidden and one independent control set is created after the final height is known. Vanilla spawning remains unchanged when the checkbox is disabled.

For Issue #1 diagnostics, the server snapshots bounded `ClientCollisionDistance` and `ServerValidationDistance` sandbox values into each pair grant. The owner client still requires a real character collision before requesting an impact and reports its measured collision distance only as diagnostic evidence. The server never trusts that reported distance: it measures the pair again and applies its configured validation envelope plus every existing authority check. Effective values and bounded distance aggregates are emitted in the normal client/server performance summaries. Procedures and results are maintained in [`TESTING.md`](TESTING.md), [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md), and [`spikes/`](spikes/).
