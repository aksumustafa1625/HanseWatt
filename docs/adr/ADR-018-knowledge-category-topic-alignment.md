# ADR-018: Knowledge data-categories aligned to agent topics; Summary as interim body

- Status: Accepted (built — Faz 1, 2026-06-28)
- Date: 2026-06-28

## Context

The agent's Knowledge retriever ([ADR-007](ADR-007-grounding-knowledge-data360-retriever-split.md))
needs a Knowledge base whose taxonomy lets it fetch the right article per topic. We also hit
a concrete platform constraint while seeding articles in Faz 1.

## Decision

- **One data-category group `HanseWatt_Topics`** with categories **Billing / Consumption /
  Tariff / Move / Outage / Contract**, mapped 1:1 to the agent topics — so a topic resolves
  to a category filter for retrieval. Group + categories are deployed as metadata
  (`datacategorygroups/`).
- **Ten articles**, each categorised and published `Online` via Apex
  (`scripts/seed_knowledge.apex`, idempotent on `UrlName`).
- **Article body lives in the standard `Summary` field** (≤1000 chars) for now. A custom
  rich-text `Knowledge__kav.Body__c` (Html 32768) was deployed and exists in Tooling
  `FieldDefinition`, but after the day's heavy schema changes it was **not yet exposed to
  SOQL/Apex** (active schema-cache lag); the seed therefore uses `Summary` to stay unblocked.

## Consequences

**Positive:** the retriever can scope by topic via category; the taxonomy doubles as Service
Cloud article navigation; the seed is repeatable and committed. Content is **English** (build
language, [ADR-019](ADR-019-build-language-english.md)) so every article is reviewable.

**Negative / Trade-offs:** `Summary` is plain text (no rich formatting) and length-capped —
a fidelity compromise until `Body__c` becomes query-exposed, at which point the seed swaps
the content field. Article **Language is `en_US`** (German is not yet an enabled Knowledge
language); German content is a later localization step.

## Alternatives Considered

### Wait for `Body__c` schema cache before seeding

Rejected: open-ended wait (the field stayed hidden >6 min); `Summary` unblocks Faz 1 now
with a trivial later swap.

### Free-form categories not tied to topics

Rejected: defeats topic-scoped retrieval; the whole point is topic→category alignment.

## References

- `scripts/seed_knowledge.apex`, `force-app/main/default/datacategorygroups/`
- Related: [ADR-007](ADR-007-grounding-knowledge-data360-retriever-split.md), [ADR-019](ADR-019-build-language-english.md)
