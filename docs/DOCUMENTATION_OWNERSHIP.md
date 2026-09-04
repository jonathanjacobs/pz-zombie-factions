# Documentation ownership

This file assigns mutable project facts to one canonical source so the repository does not maintain competing copies.

| Information | Canonical source |
| --- | --- |
| Public orientation and current identity | [`../README.md`](../README.md), [`../VERSION`](../VERSION), [`../CHANGELOG.md`](../CHANGELOG.md) |
| Normative runtime behavior | [`REQUIREMENTS.md`](REQUIREMENTS.md) |
| Current implementation model | [`ARCHITECTURE.md`](ARCHITECTURE.md), [`adr/`](adr/) |
| Planned work and milestone exits | [`ROADMAP.md`](ROADMAP.md) |
| Repeatable test procedure | [`TESTING.md`](TESTING.md) |
| Observed validation outcomes | [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) |
| Bounded experimental evidence | [`spikes/`](spikes/) |
| Policy and provenance | [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md), [`../COMPLIANCE.md`](../COMPLIANCE.md), [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md), [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) |
| External reference links (wiki, API docs, community) | [`RESEARCH_LINKS.md`](RESEARCH_LINKS.md) |
| Test-cycle automation (pre/post-test scripts) | [`../scripts/README.md`](../scripts/README.md) |

## Duplication rule

Repeat only the small amount of information needed for orientation or safety. Update the canonical source first; use links instead of copying detailed procedures, evidence, roadmaps, or implementation narratives.

Deployment, release-checklist, and Workshop documents will be introduced only when the project is preparing a distributable release.
