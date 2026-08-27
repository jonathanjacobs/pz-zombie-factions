# Release Checklist

Use this checklist before any public GitHub release or Steam Workshop publication/update.

## Identity and metadata
- [ ] `VERSION` and all `mod.info` files agree.
- [ ] Project Zomboid Mod ID remains exactly `pz-zombie-factions`.
- [ ] README and docs identify the correct release stage and tested Build 42 baseline.

## Package structure
- [ ] The deployable runtime tree is only `Contents/mods/pz-zombie-factions/`.
- [ ] No decompiled Project Zomboid source, extracted PZ assets, private logs, credentials, backups, or scratch files are packaged.

## Policy / provenance
- [ ] Recheck the current Project Zomboid Modding Policy.
- [ ] Every distributed file has known provenance and redistribution rights.
- [ ] `THIRD_PARTY_NOTICES.md`, `ASSET_LICENSE.md`, `LICENSE`, and `NOTICE` are accurate.
- [ ] No third-party mod code/assets or Project Zomboid code/assets are redistributed without an explicit rights basis.
- [ ] Branding does not imply official status or endorsement.

## Technical validation
- [ ] Default installation preserves vanilla zombie behavior.
- [ ] Faction identity and relationship resolution tests pass.
- [ ] Multiplayer authority and save/load behavior have been tested for the claimed feature set.
- [ ] Zombie-vs-zombie combat is not claimed unless pursuit, attack, damage, death, and synchronization have been demonstrated.
- [ ] No runaway target churn, full-world scanning, command spam, or diagnostic log spam occurs in normal operation.
- [ ] Compatibility claims are limited to tested evidence.

Release decision: **GO / CONDITIONAL GO / NO-GO**

Reviewer/date: ____________________
