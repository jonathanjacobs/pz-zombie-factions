# Project Zomboid Modding Policy compliance

This document is the project's engineering and release-control policy. It does not replace The Indie Stone's authoritative policy:

- <https://projectzomboid.com/blog/modding-policy/>

Last reviewed: **2026-08-26**

## Mandatory rules

1. Repository code, documentation, and assets must be original to this project or have documented redistribution rights.
2. Public availability of another mod does not permit copying or redistribution.
3. Project Zomboid code/assets and privately supplied decompiled Build 42 source may be studied for implementation behavior but must not be copied into or redistributed by this repository.
4. Prefer runtime references to vanilla APIs and identifiers over extracting or copying Project Zomboid assets.
5. Record every distributed third-party component in [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) and every non-code asset's rights in [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) before release.
6. Do not imply official status or endorsement by The Indie Stone.
7. Do not add paid or donor-exclusive functionality, malicious behavior, licensing circumvention, piracy support, or unauthorized modpack redistribution.
8. Describe material behavior changes accurately and limit compatibility, performance, and release claims to recorded evidence.

## License and distribution boundary

Apache-2.0 applies only to material the project has the right to license. It does not relicense Project Zomboid or third-party material.

The deployable runtime tree is `Contents/mods/pz-zombie-factions/`. Do not package source-control metadata, private logs or data, credentials, backups, scratch files, saves, decompiled game source, or extracted game assets.

## Release gate

Before a tagged or Steam Workshop release:

- recheck the live Project Zomboid Modding Policy and update the review date above;
- align `VERSION`, `CHANGELOG.md`, and both `mod.info` versions;
- verify provenance and redistribution rights for every distributed file;
- confirm branding remains clearly unofficial;
- confirm default installation preserves vanilla zombie behavior;
- validate only the runtime capabilities and compatibility actually claimed;
- test multiplayer authority, save/load, and lifecycle behavior required by the intended feature set;
- confirm normal operation produces no runaway scans, command traffic, target churn, or diagnostic logging;
- add project-specific deployment, Workshop, and release-checklist documents when preparing the first distributable release.
