# ADR-019: Build in English; German as a final, reviewable localization step

- Status: Accepted (2026-06-28)
- Date: 2026-06-28

## Context

HanseWatt is a German DACH energy retailer, and the original blueprint says "Agent +
Knowledge in **German**". But the builder's German proficiency is low and they must be able
to read and review every artifact as it is created. There is a tension between the project's
German _premise_ and the need for a comprehensible _build language_.

## Decision

**Build everything in English** — metadata labels, code, comments, docs, Knowledge content,
data-category labels. **Keep the org UI/default language English** (do not switch Locale to
German). German customer-facing content (agent responses, Knowledge translations) is a
**single, controlled localization step at the end**; when added, German is paired with an
English gloss so it stays reviewable.

## Consequences

**Positive:** the builder can review and trust every artifact; internal consistency (record
types, topics, categories are all English already); the German layer becomes one deliberate,
auditable pass rather than scattered un-reviewable prose.

**Negative / Trade-offs:** the demo's German "voice" arrives late, not incrementally; we must
remember to localize the customer-facing surfaces before the final recording. The DACH-German
authenticity is deferred (but proper nouns, addresses, and currency already carry the DACH
signal).

## Alternatives Considered

### German content from the start (per original blueprint)

Rejected: the builder cannot review German prose, breaking the trust/verification loop.

### Switch the org Locale/Language to German

Rejected: makes the whole admin surface unreadable to the builder for zero functional gain;
content language ≠ org UI language.

## References

- Memory: `build-language-english.md`
- Related: [ADR-008](ADR-008-german-sie-trust-layer-guardrails.md), [ADR-018](ADR-018-knowledge-category-topic-alignment.md)
