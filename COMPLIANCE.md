# Project Compliance

Zombie Factions is developed under The Indie Stone's current Project Zomboid Modding Policy and applicable distribution-platform rules.

Authoritative policy: https://projectzomboid.com/blog/modding-policy/  
Last reviewed: **2026-08-26**

## Development rules

- Repository code, documentation, and assets must be original to this project or have redistribution rights documented before release.
- Public availability of another mod does not grant permission to copy or redistribute it.
- Project Zomboid code/assets and privately supplied decompiled Build 42 source may be studied for implementation behavior but must not be copied into or redistributed by this repository.
- Prefer runtime use of vanilla APIs/identifiers over extracting Project Zomboid assets.
- Apache-2.0 applies only to material this project has the right to license.
- The project must not imply official status or endorsement by The Indie Stone.
- Do not add paid/donor-exclusive functionality, malicious behavior, piracy/licensing circumvention, or unauthorized modpack redistribution.

If third-party code/assets are ever introduced, their source, author, license/permission, modifications, redistribution terms, and required attribution must be documented before distribution in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and, for assets, [`ASSET_LICENSE.md`](ASSET_LICENSE.md).

## Distribution boundary

The deployable runtime tree is:

```text
Contents/mods/pz-zombie-factions/
```

Do not package source-control metadata, private logs/data, credentials, backups, scratch files, decompiled game source, or extracted Project Zomboid assets.

## Release gate

Before a public GitHub or Steam Workshop release:

- confirm `VERSION` and all `mod.info` versions agree;
- recheck the current Indie Stone modding policy;
- verify provenance/redistribution rights for every distributed file;
- confirm branding remains clearly unofficial;
- validate only the runtime capabilities actually claimed;
- confirm default installation preserves vanilla zombie behavior;
- test multiplayer authority/save-load behavior for the claimed feature set;
- validate acquisition, pursuit, attack presentation, damage, death, and synchronization for every zombie-vs-zombie capability claimed;
- confirm normal operation produces no runaway target churn, world scans, command spam, or diagnostic log spam;
- keep compatibility claims limited to tested Build 42 evidence.

Zombie Factions is an unofficial independent community mod and is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.
