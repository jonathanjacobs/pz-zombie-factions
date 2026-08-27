# Project Zomboid Modding Policy Compliance

This repository is developed under a project-wide compliance rule: work intended for distribution as a Project Zomboid mod must comply with The Indie Stone's current Project Zomboid Modding Policy, the Project Zomboid Terms and Conditions incorporated by that policy, and applicable distribution-platform rules.

Authoritative policy:

- https://projectzomboid.com/blog/modding-policy/

Last reviewed for this repository: **2026-08-26**.

This document is an engineering and release-control policy for this repository. It does not replace the authoritative Indie Stone policy.

## Mandatory development rules

1. Code, art, audio, models, text, data, and other material added to the repository must be original to this project or have a documented license/permission that allows the intended use and redistribution.
2. Public availability of another mod does not imply permission to copy or redistribute its contents.
3. Studying another mod or decompiled game source for behavior, interoperability, API discovery, or prior art does not authorize copying its implementation or assets.
4. Any incorporated third-party component must be recorded in `THIRD_PARTY_NOTICES.md` before distribution.
5. Project Zomboid code and assets remain property of The Indie Stone and are not relicensed by this repository's Apache-2.0 license.
6. Prefer references to vanilla APIs, identifiers, tiles, sprites, sounds, or other resources at runtime over copying/extracting those resources into this repository.
7. The project must not call itself "Official" or imply endorsement by The Indie Stone.
8. Access to the mod or in-mod functionality must not be sold or restricted to donors unless expressly permitted by The Indie Stone.
9. The mod must not intentionally damage users' devices, bypass login/licensing controls, facilitate piracy, or use invasive circumvention techniques merely to obtain functionality.
10. Do not publish or redistribute another author's mod in a public or unlisted modpack without required permission.

## Research-source boundary

A privately supplied decompiled Project Zomboid Build 42 source tree may be used to verify engine behavior. Decompiled source remains research material only and must not be copied into, committed to, or redistributed by this repository.

## License boundary

The repository's Apache License 2.0 applies only to material for which this project has the right to grant that license. It does not relicense Project Zomboid content or third-party material.

## Release gate

A release is not considered publishable until `docs/RELEASE_CHECKLIST.md` has been reviewed for the release candidate. The live Indie Stone Modding Policy must be rechecked before the first Steam Workshop release and periodically thereafter because the policy may change.
