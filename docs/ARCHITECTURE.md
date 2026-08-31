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

For standing, non-crawling faction pairs, the owner client enters a mod-owned bumped-state mapping to the shipped `Zombie_Bite_Start` and `Zombie_Bite_Success` clips only while the attacker's native target is clear. The presentation does not use player hit packets, `pathToCharacter` with a zombie target, native `setTarget(IsoZombie)`, or `bAttack` writes. Collision remains the trigger for the separately validated impact route and one owner-local `ZombieBite` sound. After a target owner applies a server-dispatched nonlethal hit, it may select one of four mod-owned bumped reactions mapped to shipped left/right shoulder and chest clips.

The v0.0.31 standing presentation result was invalidated by a client crash when native `AttackState` attempted a player reaction against an `IsoZombie` target. Version 0.0.32 removed that coupling without a repeated crash, but an isolated pair stopped outside collision range. Version 0.0.33 tightens contact closure and awaits controlled validation. Crawlers and stale-presentation cancellation remain separately scoped work.

## Diagnostic harness

The administrator Horde Spawning extension and SPIKE checkbox are controlled-test tooling, not production enrollment. Build 42 does not reliably relocate the vanilla `anchorBottom` controls after the extension resizes the window, so the displaced originals are hidden and one independent control set is created after the final height is known. Vanilla spawning remains unchanged when the checkbox is disabled. Procedures and results are maintained in [`TESTING.md`](TESTING.md), [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md), and [`spikes/`](spikes/).
