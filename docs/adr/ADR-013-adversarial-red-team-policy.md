# ADR-013: Adversarial / red-team policy + evidence standard

- Status: Proposed (pre-build — Faz 11, headline differentiator)
- Date: 2026-06-21

## Context

In energy + personal data, security maturity is the headline. A grounded agent must also be
_provably_ resistant to abuse: prompt injection, cross-customer data fishing, social-
engineered deletion, "reset my bill", toxicity, off-topic. This needs to be documented, not
claimed.

## Decision

A **red-team suite** of ≥8 attacks (built in English, mirrored in German at localization):
prompt injection, neighbour's-bill / cross-customer lookup, "reset my bill", deletion social
engineering, toxicity, off-topic, PII fishing, hallucination bait. For each: **expected
refusal/escalation → actual → verdict**, recorded as `HW_Agent_Eval_Result__c` rows with
`Is_Adversarial__c = true`, plus **Trust Layer PII-masking evidence** (transcript +
screenshot, e.g. a masked IBAN in the log).

## Consequences

**Positive:** a documented, evidenced security posture — exactly what regulated DACH
employers probe for; reuses the eval pipeline ([ADR-012](ADR-012-agent-eval-llm-judge.md)) so
marginal cost is low; the guardrail policy ([ADR-008](ADR-008-german-sie-trust-layer-guardrails.md))
becomes testable assertions.

**Negative / Trade-offs:** adversarial runs consume credits — **run once** after the agent
is frozen; red-team coverage is illustrative, not exhaustive (noted honestly).

## Alternatives Considered

### "The Trust Layer handles it" (no explicit red-team)

Rejected: an unproven claim; the evidence _is_ the differentiator.

### Exhaustive fuzzing

Rejected: credit-prohibitive and unnecessary for portfolio evidence; a curated 8–10 attack
set run once is the disciplined choice.

## References

- `PHASES.md` Faz 11, `docs/security/` (red-team suite)
- Related: [ADR-008](ADR-008-german-sie-trust-layer-guardrails.md), [ADR-012](ADR-012-agent-eval-llm-judge.md)
