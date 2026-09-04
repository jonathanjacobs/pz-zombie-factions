# Research links

External reference sources for Project Zomboid Build 42 behavior. These are
citations, not redistributed content — see [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md)
for the boundary between studying external material and copying it.

- Community wiki, Build 42.20.4: <https://pzwiki.net/wiki/Build_42.20.4>
- Unofficial Javadocs, B42.20: <https://albion.codeberg.page/PZ-JavaDocs/zombie/package-summary.html>
- Project Zomboid Wiki (main): <https://pzwiki.net/wiki/Project_Zomboid_Wiki>
- Community discussion: <https://www.reddit.com/r/projectzomboid/>

Local, gitignored copies (saved wiki pages, Discord/Reddit notes, other
Workshop mods studied for implementation ideas) belong under
[`../research-source/`](../research-source/), not here — this file is for
stable links only.

## Mods studied for reference

Other Steam Workshop mods examined for implementation *ideas* (not copied
code or assets — see [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md); public
availability of a mod does not grant redistribution rights). Listed here for
credit and traceability. If any code or asset is ever actually adapted or
copied, it must instead be recorded in
[`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) with full
provenance before release.

| Mod | Author | What we looked at it for |
| --- | --- | --- |
| [[B42] Bandits NPC](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204) | Slayer's Workshop | Hostile NPC spawning/combat framework built on B42; relevant to server-authoritative combat and threat handling patterns. |
| [Infected Player](https://steamcommunity.com/sharedfiles/filedetails/?id=2991010328) | Tchernobill's Workshop | Replaces player animation/state sets with zombie equivalents; relevant background for zombie animation-state mapping used in our combat presentation. |
| [LpB Faction & Safehouse](https://steamcommunity.com/sharedfiles/filedetails/?id=3786472321) | Warlord-Fox3's Workshop | Reimplements vanilla eligibility rules for a multi-claim safehouse/faction membership system; precedent for extending vanilla group concepts server-side. |
| [Random Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=2818577583) | belette's Workshop | Sandbox-configurable zombie-type population mix, done with a "less CPU-intensive" update approach — relevant to bounded, non-scanning performance design. |
| [Special Zombies #01 - Screamer (B42)](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282817) | OO's Workshop | A concrete custom zombie behavior (detection/scream/aggro-pull) built atop the framework below; example of layering behavior on a shared registration system. |
| [Special Zombies Framework (B42)](https://steamcommunity.com/workshop/filedetails/?id=3783282009) | OO's Workshop | Persistent special-zombie registration/spawning shared framework with exact-ID multiplayer sync; relevant to our own faction-identity persistence and sync problem. |
| [Wandering Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=2983905789) | Ryuku's Workshop | Fully configurable, B42-MP-compatible zombie wandering without spawning zombies itself; relevant to bounded, bandwidth-conscious multiplayer zombie behavior updates. |
| [Zombies Target Animals](https://steamcommunity.com/sharedfiles/filedetails/?id=3774007514) | Ugly's Workshop | Working around engine-level target-type restrictions to let zombies pursue non-player targets — same class of problem as faction-vs-faction targeting. |
