# SPIKE-006 — Faction identity persistence across virtualization, restart, and clients

Status: Core question answered from source study, with a survey of four shipping mods that attempt the same thing. Faction identity stored in zombie `modData` does not survive virtualization, chunk unload, or a server restart. One engine field does survive all three, and there is a shipped precedent for using it. No runtime measurement has been taken in this project yet; a confirming procedure is recorded at the end. Target: Project Zomboid Build 42.20.x Implementation: none yet, current head v0.0.57

## Question

[`ROADMAP.md`](../ROADMAP.md) requires that faction assignment persist across supported lifecycle transitions, and [#19](https://github.com/jonathanjacobs/pz-zombie-factions/issues/19) is blocked on a narrower version of the same question: does faction `modData` survive virtualization? A v0.0.56 disconnect test left a 48-against-48 fight inert after reconnect, and identity loss is one of two candidate explanations for that.

The question needs to be asked about four transitions rather than one, because faction identity has to survive all of them:

1. virtualization while no player is in range;
2. chunk unload and reload while a player is nearby but the chunk cycles;
3. a server restart;
4. a second client arriving after the assignment was made.

## Boundary

Claims about engine behavior come from reading the decompiled Build 42.20 source under [`../PZ_MODDING_POLICY.md`](../PZ_MODDING_POLICY.md) rule 3. The survey section additionally reads four third-party mods under rules 2 and 3, and carries its own provenance note. Nothing is transcribed from either source; what appears here are descriptions of control flow, field lists, and conclusions the mod authors recorded in their own comments.

Per [`../../AGENTS.md`](../../AGENTS.md), no observed runtime outcome is claimed by this document, and nothing has been added to [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md) on the strength of it.

## Answer

Identity is lost to virtualization and it is lost to a restart. The two cannot be told apart by testing, because both go through the same 21-byte record described below, and the faction has never been written into that record.

### Zombies are not saved as objects

`IsoZombie` inherits a save format that does serialize `modData`. `IsoMovingObject.save` writes the `table` field when it is non-empty, and `IsoMovingObject.load` reads it back. That is probably why storing faction in `modData` looked like it would work.

The live code does not use that path for zombies. When a chunk unloads, `IsoChunk.removeFromWorld` walks the square's moving objects and calls `removeFromWorld()` on each one without serializing any of them. Only static moving objects and world objects are written to meta. `IsoZombie.save` remains reachable through the legacy object-factory route, registered as the `"Zombie"` factory under class id `3` in `IsoObject`, but the chunk path does not exercise it.

### The only zombie persistence is a fixed 21-byte record

Just before that teardown, `IsoChunk.removeFromWorld` calls `ZombiePopulationManager.requestSaveCell` for the containing population cell. That takes a snapshot of every live, non-reanimated zombie in the cell and passes it to `writeCellSnapshot`, which writes six values per zombie:

| Field | Type | Bytes |
| --- | --- | --- |
| x | float | 4 |
| y | float | 4 |
| z | float | 4 |
| direction | byte | 1 |
| descriptorID (persistent outfit id) | int | 4 |
| state flags | int | 4 |

Twenty-one bytes, handed to the native population store through `n_beginSaveRealZombies`, `n_saveRealZombies`, and `n_saveCell`. The layout is fixed on both sides of the JNI boundary, so there is no extension point, no trailing blob, and no per-zombie key.

That store is also what a restart reloads. The faction was never written into it, so a restart has nothing to lose.

### Virtualization writes the same shape

`ZombiePopulationManager` virtualizes a zombie by handing the native layer its position, direction ordinal, persistent outfit id, and state flags, plus a path target for zombies that are moving. That is the `n_addZombie(float, float, float, byte, int, int, int, int)` signature. It then calls `removeFromWorld()` and `removeFromSquare()` on the Java object. Coming back, `addZombieStanding` and `addZombieMoving` read those same eight values and build a zombie from them, because there is nothing else available to read.

Chunk unload, virtualization, and restart therefore all converge on one record with one shape.

### The rematerialized zombie is a different object, and its modData is cleared

`VirtualZombieManager.createRealZombieAlways` either allocates a fresh `IsoZombie` or takes one from its `reusableZombies` pool. Objects enter that pool through `reuseZombie`, which calls `IsoZombie.resetForReuse`, and that method wipes `modData` along with `onlineId`, `persistentOutfitId`, `indoorZombie`, and the rest of the per-life state.

That wipe prevents a worse problem than the one being investigated here. Zombie objects are recycled, so if `modData` were left in place, a newly spawned zombie could come back carrying the faction of the dead zombie whose object it reused. The faction is lost instead of being wrongly inherited.

### `onlineId` is a transient handle

`onlineId` is allocated from `ServerMap.getUniqueZombieId` when a zombie enters the world on a server, released in `removeFromWorld`, and reset by `resetForReuse`. It is a recycled 16-bit value that addresses a zombie only while that zombie is real. It cannot serve as a persistence key or as a key across a restart. The survey below includes a shipping mod that uses it as one anyway, and the consequences.

### Multiple clients is a smaller and separate problem

`transmitModData` does work for zombies, which is not obvious from the Lua side and is worth recording. `ObjectModDataPacket` addresses its subject through the `MovingObject` network field, which has a dedicated zombie case keyed on `getOnlineID` and resolved through `ServerMap.zombieMap` on the server and `GameClient.IDToZombieMap` on the client. The `pcall`-wrapped `zombie:transmitModData()` call in [`Assignment.lua`](../../Contents/mods/pz-zombie-factions/42/media/lua/shared/ZombieFactions/Assignment.lua) does reach clients.

It sends once, to whichever clients are near the zombie at the moment of the call, through `sendToRelativeClients` in `processServer`. Nothing sends it again afterwards. The client-side creation path in `NetworkZombieSimulator.parseZombie` builds its zombie through `createRealZombieAlways` and fills in outfit, position, health, speed, and target, with no `modData` involved. A client that arrives after an assignment sees an unfactioned zombie and has no way to learn otherwise.

In this case the server does still know the faction. The problem is only that a late-arriving client never gets told. Any design that assigns the faction when a zombie materializes fixes this without extra work, because `OnZombieCreate` runs on the client as well and the client assigns it for itself.

## The one field that does survive

The population record carries `descriptorID`, which is the persistent outfit id. A mod can put its own meaning into that field, because a mod can define the outfits it refers to.

`PersistentOutfits.pickOutfit` builds the id by packing a female flag, an outfit index, and a variant number into a single int, as `femaleBit | outfitIndex << 16 | variant + 1`. `getOutfit` unpacks the same layout. When a zombie is realized, `createRealZombieAlways` resolves the id through `PersistentOutfits.getOutfit` and `dressInPersistentOutfitID` dresses the zombie from it, after which `getOutfitName()` returns the outfit's name from the zombie's `HumanVisual`.

The outfit index therefore makes a full round trip through virtualization, chunk unload, and restart, and it is readable from Lua at both ends. It is the only per-zombie value in the engine that does this.

Outfits themselves are moddable from Lua. `ZombiesZoneDefinition` reads its zone table directly out of the Lua environment through `LuaManager.env.rawget("ZombiesZoneDefinition")`, so a mod can register its own outfits and attach them to zones by editing that global table. When a zombie is created on a server with no outfit id supplied, `ZombiesZoneDefinition.pickPersistentOutfit` picks one based on the square's coordinates.

This is how appearance survives a restart when nothing else about an individual zombie does, and a mod can add its own outfits to the same table.

## Design options

### Option A — derive faction from territory at materialization

Keep a persistent faction territory map. `ModData.getOrCreate` is backed by `GlobalModData`, which saves to `global_mod_data.bin` under the save and offers `transmit` and `request` for multiplayer synchronization. Hook `OnZombieCreate`, which `VirtualZombieManager` fires for every materialization on both server and client, and resolve each arriving zombie's faction from its square.

Nothing per-zombie is stored, so nothing per-zombie can be lost. Identity is reconstructed on arrival, which covers all four transitions including late-joining clients. It also changes what the enrollment sweep in #19 is for, since zombies would arrive already enrolled.

The consequence to accept is that a zombie's faction is decided by where it is standing. A zombie that wanders across a border and back changes faction. For a mod about territorial factions that behavior is probably wanted, but it should be chosen on purpose rather than accepted because the implementation forced it.

A smaller operational note: `GlobalModData.transmit` broadcasts the whole named table to every connection, so the territory map needs to stay small and be transmitted when it changes rather than per zombie.

### Option B — encode faction in the persistent outfit (recommended, and complements Option A)

Register faction outfits through `ZombiesZoneDefinition` and read the faction back at `OnZombieCreate`, either from `getOutfitName()` or from the outfit index packed into the id. The faction is then stored in the outfit id, which is one of the six values the population record saves, so it survives virtualization, chunk unload, and restart without needing a separate table or a rule for reconstructing it.

The difference from Option A is that the faction stays attached to the zombie instead of being looked up from its current position each time. A zombie that wanders out of Red territory stays Red. Which of those two behaviors is wanted is a design decision, and it should be settled before either option is built.

The two options combine well. `ZombiesZoneDefinition` already maps zones to outfits, so listing faction outfits against zones there is one way of writing down the territory map that Option A needs. Option B then keeps the result attached to each zombie afterwards.

Three costs to weigh:

- **It uses appearance as the carrier.** Faction zombies have to wear a faction outfit. For a faction mod that is plausibly desirable, since telling Red from Blue on sight is useful, but it constrains visual design and it conflicts with any other mod that assigns outfits.
- **The id is index-keyed rather than name-keyed.** `outfitIndex` is a position in the outfit table. If the set of installed outfits changes, indices shift, and zombies saved under the old ordering resolve to different outfits. Adding or removing an outfit-providing mod on a live server would scramble existing assignments.
- **There is a size limit.** `outfitIndex` is a short, and the variant seed table is 500 entries.

### Option C — a durable per-zombie id with a side table

This is the design most people reach for first, and no reliable version of it exists. It needs a stable per-zombie key that round-trips through the population store, and the store has six fields that all already mean something. The survey below covers two mods that tried it, one of which withdrew its attempt and one of which still carries the defect.

### Option D — exempt faction zombies from virtualization

`IsoZombie.keepItReal` exists and is honored in `VirtualZombieManager.update`. It is checked only inside the branch that runs when the process is neither a client nor a server, so it does not guard the dedicated-server virtualization path in `ZombiePopulationManager`, and it does nothing across a restart. Recorded here so it is not rediscovered and mistaken for a solution.

### Option E — durable class tag plus an explicitly ephemeral override

Whichever of A or B provides the durable layer, add a server-side side table keyed on `onlineId` for state that only means anything while the zombie is real. The retaliation authorization from the `NEUTRAL` work in [#17](https://github.com/jonathanjacobs/pz-zombie-factions/issues/17) is the obvious candidate. Separating the two stops "must persist" and "must be cheap to look up" from being treated as one requirement, which is what put faction identity in `modData` in the first place.

## Survey of four shipping mods

Four Steam Workshop mods that assign per-zombie traits were read for this spike, pinned locally under `research-source/community-mods/` with provenance files. They were studied under [`../PZ_MODDING_POLICY.md`](../PZ_MODDING_POLICY.md) rules 2 and 3; no code was copied, and any pattern adopted here has to be reimplemented independently. See [`../RESEARCH_LINKS.md`](../RESEARCH_LINKS.md) for credit and links.

Taken together they cover three of the four options above, and the results line up with what the source predicts.

### Special Zombies Framework — tried and withdrew a heuristic

Two versions were compared, 1.15.3 and the later 1.16.0 reupload, and the change between them is the most useful evidence in the survey.

The author has now tried three mechanisms. Version 1 used `PersistentOutfitID` as a unique per-zombie identity, and their schema notes record that this was wrong because the id is reusable and could turn unrelated ordinary zombies into saved specials. Through 1.15.3 the framework used heuristic reassociation instead: a registry in `ModData.getOrCreate` holding type, position, health, and a visual signature built from item visuals, sex, outfit name, hair, beard, and skin index, with arriving zombies matched to unclaimed entries by exact position within half a tile or by signature match within thirty tiles, and a weak claim table preventing double claims.

Version 1.16.0 removes all of that. Schema 12 clears the recovery entries as unsafe, and the comment replacing them states that position, outfit and `PersistentOutfitID` are reusable attributes rather than identities, that a missing marker means there is no safe recovery route, and that losing a stale designation is preferable to converting an unrelated ordinary zombie or NPC body.

What remains is a worn marker item, promoted to a real clothing item in 1.16.0 on the reasoning that worn items are part of the serialized outfit. That reasoning is sound for the routes that run through `IsoZombie.save`, but it does not help across the population store, which never calls it. The only field in the 21-byte record that could carry an outfit is `descriptorID`, and it resolves through `PersistentOutfits`, whose entire save format is 500 longs of shared template seeds with no per-zombie storage of any kind. A marker added to one zombie at runtime has nowhere to go, so it only lasts while that zombie stays loaded, and `resetForReuse` clears it when the object is recycled.

The useful part is the order these were tried in. The author started by using the outfit id, replaced that with position and appearance matching, and then replaced that with accepting the loss whenever the marker is missing. Each replacement does less than the one before it. The source explains why that kept happening, which is that there is no per-zombie storage to build any of it on.

### CDDA Zombies — the same defect, still live

CDDA keeps a global registry in `ModData.getOrCreate("CZList")` and resolves a zombie's type by looking it up, keyed on `getOnlineID()` in multiplayer and `getID()` in single player. Per-zombie `modData` is used only to cache a `TextDrawObject` for the floating name label, so the registry is the whole of its persistence.

That key is the recycled 16-bit handle described above. The same defect Special Zombies removed in schema 12 is present here, and it should show up as zombies acquiring types belonging to dead ones after enough churn. It is included in this survey to show what the defect looks like in shipped code, not as a pattern to copy.

### Random Zombies — no persistence at all, by design

Random Zombies hashes `getOnlineID()` into a bucket and applies a type distribution to it, walking the loaded zombies in batches on `OnTick` with a generation counter so each zombie is processed once per pass. Nothing is written to global mod data, and per-zombie `modData` is used only for bookkeeping within a pass.

Assignment is therefore stable while a zombie stays real and re-derived from scratch otherwise. The distribution persists because it is configuration; the assignment does not persist at all. This confirms a claim made earlier in this project's notes on the basis of the mod's description rather than its code.

### Occult Zombies — the declarative route, and a shipped precedent for Option B

Occult Zombies contains no runtime Lua of the kind the others have. There are no event handlers and no state. It adds entries to `ZombiesZoneDefinition.Default` naming its own outfits with spawn chances, and registers matching hair and beard rules in `HairOutfitDefinitions`.

Everything after that is the engine's own work. The zone table decides which outfit a zombie gets based on where it spawns, the outfit index is packed into the persistent outfit id, the id rides in the population record, and the zombie is dressed from it again on the way back. The trait survives virtualization and restart with no persistence code written by the mod at all.

This is Option B already working in a released mod, which is the main reason Option B is recommended here.

### Three ordering hazards worth taking regardless

- `OnZombieCreate` fires before `onlineId` is assigned, on both sides. `VirtualZombieManager` triggers the event and then allocates the server id, and `NetworkZombieSimulator.parseZombie` sets the client id after `createRealZombieAlways` returns. A handler must not key on `getOnlineID` at that moment.
- `OnZombieCreate` can also fire before `OnGameStart` while a save is loading. Special Zombies handles this with a second restoration pass over the cell's zombie list in `OnGameStart`, after clearing claims left by a previous world in the same process, because Lua globals survive a return to the main menu.
- Sandbox settings are not guaranteed to exist during those load-time creation callbacks. Version 1.16.0 adds a readiness flag whose only purpose is suppressing spawn rolls until `OnGameStart` completes, with a comment warning against rolling against an invented default value. That applies directly here, because server-configurable faction behavior is a milestone requirement and would be read in the same window.

## Consequences for the current implementation

[`Assignment.lua`](../../Contents/mods/pz-zombie-factions/42/media/lua/shared/ZombieFactions/Assignment.lua) stays useful as a per-life cache and as the carrier that makes a faction visible to the client. It stops being the authority on what a zombie's faction is.

The `modData` write is not wasted work either, because reading a faction has to be cheap and it sits on the hot path in [`TargetPolicy.lua`](../../Contents/mods/pz-zombie-factions/42/media/lua/shared/ZombieFactions/TargetPolicy.lua). What has to change is that a cache miss becomes something the code can resolve rather than a final answer of `zf:vanilla`.

The open question on #19 is answered, and its premise narrows. Continuous enrollment is still wanted for zombies that were never enrolled, but it is no longer the mechanism that repairs a reconnect, because under either recommended option there is nothing to repair.

The v0.0.56 reconnect observation now has a sufficient explanation on its own. Whether ownership handling contributed as well is still open and worth knowing separately.

There is also a scope consequence that should be decided rather than absorbed. [`ROADMAP.md`](../ROADMAP.md) currently lists territory among the deferred layers and states that it is not a prerequisite for the faction-behavior milestone. Both recommended options pull some form of it forward, because the durable state they depend on is a mapping from place to faction. The minimum version is small, being a set of zones with a faction each and a default for everywhere else, and it is much less than the deferred territory layer implies with capture, contest, and display. It is still more than the milestone currently claims, and the roadmap should be updated to say so if either option is taken.

## Runtime confirmation still outstanding

The source reading is unambiguous, but this project records observed outcomes only after a run. The confirming procedure is short and can ride along with any future session:

1. Spawn a faction batch and record the resolved faction for a known set of zombies.
2. Walk far enough away for the population manager to virtualize them, return, and log the resolved faction on arrival.
3. Repeat across a server restart with the zombies left in place.
4. Reconnect a second client into an area with an established fight and log which factions it resolves.

The prediction is that steps 2, 3 and 4 all resolve to `zf:vanilla` under the current implementation. A result that contradicts any of them invalidates this document, and per [`../../AGENTS.md`](../../AGENTS.md) the run is the stronger evidence.

A second, cheaper check is worth running at the same time if Option B is under consideration: log `getPersistentOutfitID()` and `getOutfitName()` for a known zombie before and after a virtualization round trip, which tests the claim that the outfit index survives without requiring any of the mod's own machinery to be built first.
