# ADR-008: German "Sie" register + Trust Layer guardrail policy

- Status: Proposed (pre-build — Faz 5/6)
- Date: 2026-06-21

## Context

A DACH energy customer agent must speak correctly and behave safely. Two concerns: the
**linguistic register** (German formal "Sie", not "Du") and the **guardrail policy** (when
the agent must refuse, mask, or escalate rather than answer). Note the build language is
English ([ADR-019](ADR-019-build-language-english.md)); this ADR governs the _customer-facing_
German layer added at localization time.

## Decision

- **Register:** customer-facing German uses the formal **"Sie"** throughout; English is the
  fallback language. (Built in English first, localized to German "Sie" at the end.)
- **Trust Layer guardrails (agent instructions):**
  - Always **identify the customer** before disclosing any bill/consumption data.
  - **Never invent figures** — only state numbers returned by an Action or Calculated
    Insight ([ADR-007](ADR-007-grounding-knowledge-data360-retriever-split.md)).
  - **Escalate**, never handle inline: explicit human request, repeated dissatisfaction,
    payment disputes, and **anything touching personal-data deletion** (route to the DSGVO
    process, [ADR-009](ADR-009-dsgvo-rtbf-across-systems.md)).
  - Run everything through the Einstein Trust Layer (PII masking, toxicity, grounding, audit).

## Consequences

**Positive:** correct German business register + an explicit, testable guardrail policy —
the safety story DACH energy + personal-data recruiters expect; guardrails become red-team
test assertions ([ADR-013](ADR-013-adversarial-red-team-policy.md)).

**Negative / Trade-offs:** the German "Sie" layer is validated late (post-localization);
guardrails must be kept in sync with the actions and the DSGVO process as they evolve.

## Alternatives Considered

### Informal "Du"

Rejected: wrong register for a German utility's customer service — reads as unprofessional.

### Soft guardrails (LLM discretion)

Rejected: deletion/PII requests are too sensitive for model discretion — they must be hard-
routed to a deterministic process.

## References

- `PROJECT_BLUEPRINT.md` §9.5 (instructions/guardrails)
- Related: [ADR-007](ADR-007-grounding-knowledge-data360-retriever-split.md), [ADR-009](ADR-009-dsgvo-rtbf-across-systems.md), [ADR-013](ADR-013-adversarial-red-team-policy.md), [ADR-019](ADR-019-build-language-english.md)
