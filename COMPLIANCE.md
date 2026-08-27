# Project Compliance

Zombie Factions follows the repository rules in [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md), which is the canonical engineering/release interpretation of The Indie Stone's current Project Zomboid Modding Policy for this project.

Before adding third-party material or publishing a release, review:

- [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md)
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md)
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- [`ASSET_LICENSE.md`](ASSET_LICENSE.md)
- [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE)

## Project-specific public disclosure

Zombie Factions is an unofficial independent community mod. It is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.

## Research boundary

Decompiled Project Zomboid Build 42 source may be used privately as an implementation/research reference to understand engine behavior. Decompiled game source and extracted Project Zomboid assets must not be copied into or redistributed by this repository.

## Distribution boundary

The only deployable Project Zomboid runtime tree is intended to be:

```text
Contents/mods/pz-zombie-factions/
```

Source-control metadata, private logs/data, credentials, local test artifacts, backups, decompiled game source, and other non-public material must not enter the Workshop package.
