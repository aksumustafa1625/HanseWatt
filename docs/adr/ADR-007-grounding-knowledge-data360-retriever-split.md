# ADR-007: Grounding — Knowledge + Data 360 retriever split

- Status: Accepted (design locked; Knowledge layer built in Faz 1)
- Date: 2026-06-21

## Context

The agent must answer grounded, not hallucinated. Two very different kinds of truth are
involved: **procedure/policy** ("how do I switch tariff?", "what happens when I move?") and
**figures** ("you used 520 kWh, 62% above your 6-month average"). A single grounding source
cannot serve both well — Knowledge has no live numbers; Data 360 has no prose procedure.

## Decision

Use a **retriever split**:

- **Knowledge retriever** over the German `Knowledge__kav` articles (data categories per
  topic) for procedure, policy, and how-to. Faz 1 shipped 10 categorized articles under the
  `HanseWatt_Topics` data-category group, aligned 1:1 to the agent topics (see
  [ADR-018](ADR-018-knowledge-category-topic-alignment.md)).
- **Data 360 retriever** over the Unified Profile + Calculated Insights for figures
  (average kWh, anomaly score, time-of-day profile).

Hard instruction guardrail: the agent **only states numbers returned by an Action or a
Calculated Insight** — it never invents a figure. Every answer surfaces a citation
(e.g. _"Quelle: Knowledge 'Why Is My Bill Higher Than Usual?' + CI Avg_Monthly_kWh"_).

## Consequences

**Positive:** the cheapest, highest-impact "no hallucination" proof — the single thing DACH
energy recruiters fear most in regulated AI. Clean separation lets each retriever be tuned
and cited independently. Categories double as Service Cloud article taxonomy.

**Negative / Trade-offs:** two retrievers to configure and keep aligned to topics; data
categories must track agent topics as both evolve.

## Alternatives Considered

### Single Knowledge retriever only

Rejected: no live, per-customer figures — the bill-anomaly explanation (the demo's core)
would be impossible without Data 360.

### Let the LLM free-generate figures

Rejected: hallucination risk; unacceptable in billing/energy where a wrong number is a
compliance and trust failure.

## References

- `ROADMAP.md` §1 (C4 retriever split), `PROJECT_BLUEPRINT.md` §9.4
- Related: [ADR-003](ADR-003-data360-system-of-record-boundary.md), [ADR-018](ADR-018-knowledge-category-topic-alignment.md)

---

## Update (2026-07-12) — how the Knowledge retriever was actually implemented

**Status: implemented, with a deliberate deviation.**

The intended Knowledge retriever was the **Agentforce Data Library** (a Data Cloud RAG /
vector index over `Knowledge__kav`, consumed by the standard
`AnswerQuestionsWithKnowledge` action). That is **not usable in this org**:

- The `AiRetriever` metadata type does not exist here (`INVALID_TYPE` from the Metadata API),
  so the library/retriever can neither be inspected nor managed from source.
- The Data Library's Data Cloud index never leaves **"Not Started"**, and without an indexed
  library the standard Knowledge action fails at runtime — while still _greedily_ winning
  action selection and stealing billing questions from the custom actions.

This is the fourth edition boundary in this Dev Edition (after the NGA publish 404,
`Case.EntitlementId`, and the read-only `IsLocal` flag).

**Decision:** deliver the procedure side with a **deterministic Apex retriever** instead:

- `HWKnowledgeService` — **one** SOQL loads the published corpus (10 articles), then scores
  each article in memory against the question's tokens (title hit ×3, body hit ×1). It is
  bulk-safe by construction: SOQL does not scale with the number of questions.
- A **German → English alias map** (umzug→moving, störung→outage, rechnung→bill, zähler→meter,
  kündigung→cancellation, …) lets a German question land on the English corpus deterministically,
  rather than relying on the model to translate.
- Below a score threshold it returns **nothing**. `HWAnswerFromKnowledgeAction` then tells the
  agent: _"do not guess the policy — offer to open a case."_ The retriever cannot invent a
  source; the citation is the real `ArticleNumber`.
- The two greedy standard Knowledge actions were removed from the topics (Tooling API), and the
  topic **description** was widened so the classifier routes how-to questions to the topic that
  owns the new action (before this, "I'm moving house" was classified `Off_Topic` → Actions: 0).

**Why this is defensible, not a workaround:** for a 10-article corpus, one query plus explainable
scoring beats a vector index on cost, latency, and auditability — and unlike RAG it is
**unit-testable for free** (13 tests, incl. German input, wrong-article discrimination, and the
"no match → no answer" case). A vector Data Library remains the right production path for a
large, multilingual corpus.

**Verified live (2026-07-12):**

- _"I'm moving house next month. What do I need to do?"_ → the Umzug article, cited
  `HanseWatt Knowledge — Moving House: Start or Stop Service (Umzug) (000001008)`.
- _"What should I do during a power outage?"_ → the Störung article (000001004) — the scorer
  discriminates between articles.
- _"Does HanseWatt also offer internet and mobile contracts?"_ → **no article, no invented
  policy.**

The figure side is unchanged and still grounded in Data 360 (+64.6 %). The split now holds
end to end: **figures → Data 360 · procedure → a cited Knowledge article.**
