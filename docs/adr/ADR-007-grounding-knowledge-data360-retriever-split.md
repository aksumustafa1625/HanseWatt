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
(e.g. *"Quelle: Knowledge 'Why Is My Bill Higher Than Usual?' + CI Avg_Monthly_kWh"*).

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
