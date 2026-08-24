# Architecture Decision Records (ADRs)

This directory contains the **Architecture Decision Records** for HanseWatt — concise,
immutable records of the significant architectural decisions behind an Agentforce + Data 360
+ Service Cloud platform.

## What is an ADR?

An ADR is a short markdown document capturing a single architectural decision: the
**context** that motivated it, the **decision** itself, the **consequences**, and the
**alternatives considered**. ADRs are version-controlled next to the code so the *reasoning*
behind past decisions stays discoverable — not just the *shape* of the result.

This project follows the [Michael Nygard ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
with light extensions (**Alternatives Considered** + **References**).

## Why ADRs here?

A project spanning Service Cloud, an autonomous agent, a Data Cloud model, and a GDPR
deletion flow accumulates non-obvious decisions fast. ADRs solve four problems:

1. **Onboarding** — read the ADRs in order and learn the architecture's reasoning.
2. **Audit** — when a security/compliance review asks "why this approach?", the ADR answers
   with date + alternatives. (DACH architecture standards like arc42 treat ADRs as
   first-class.)
3. **Interview defense** — every design choice in this repo has a written, defensible
   rationale with the alternatives that were weighed and rejected.
4. **Continuity** — the build is phased over many sessions; ADRs are the durable memory of
   *why*, complementing `CLAUDE.md` (the *how/where* session guide).

## Catalogue

> Status legend: **Accepted** = decided & in effect · **Proposed** = design locked in the
> blueprint, pre-build for its phase · **Superseded by ADR-NNN** = replaced.

| ADR | Decision | Status | Date | Phase |
|-----|----------|--------|------|-------|
| [001](ADR-001-scope-service-agentforce-data360.md) | Scope: Service + Agentforce + Data 360 (vs Field Service) | Accepted | 2026-06-20 | P0 |
| [002](ADR-002-agentforce-service-agent-vs-custom-orchestration.md) | Agentforce Service Agent vs custom LLM/Apex orchestration | Accepted | 2026-06-20 | P5 |
| [003](ADR-003-data360-system-of-record-boundary.md) | Data 360 system-of-record boundary | Accepted | 2026-06-20 | P2 |
| [004](ADR-004-ingestion-api-vs-mulesoft.md) | Ingestion API (primary) vs MuleSoft vs Connector | Accepted | 2026-06-20 | P2 |
| [005](ADR-005-identity-resolution-match-reconcile.md) | Identity resolution — match + reconcile design | Proposed | 2026-06-21 | P3 |
| [006](ADR-006-apex-invocable-vs-flow-actions.md) | Apex `@InvocableMethod` vs Flow actions | Accepted | 2026-06-21 | P5 |
| [007](ADR-007-grounding-knowledge-data360-retriever-split.md) | Grounding — Knowledge + Data 360 retriever split | Accepted | 2026-06-21 | P5 |
| [008](ADR-008-german-sie-trust-layer-guardrails.md) | German "Sie" register + Trust Layer guardrail policy | Proposed | 2026-06-21 | P5/6 |
| [009](ADR-009-dsgvo-rtbf-across-systems.md) | DSGVO Right-to-be-Forgotten across SF + Data 360 | Proposed | 2026-06-21 | P9 |
| [010](ADR-010-multi-currency-eur-chf.md) | Multi-currency EUR + CHF (no Advanced Currency Mgmt) | **Accepted (built)** | 2026-06-28 | P1 |
| [011](ADR-011-two-agent-customer-employee.md) | Two agents (customer + employee) over single/four-agent | Accepted | 2026-06-21 | P7 |
| [012](ADR-012-agent-eval-llm-judge.md) | Agent evaluation — LLM-as-judge rubric + regression | Proposed | 2026-06-21 | P10 ⭐ |
| [013](ADR-013-adversarial-red-team-policy.md) | Adversarial / red-team policy + evidence standard | Proposed | 2026-06-21 | P11 ⭐ |
| [014](ADR-014-event-driven-platform-events.md) | Event-driven backbone — Platform Events | Proposed | 2026-06-21 | P8 |
| [015](ADR-015-zero-copy-byol-production-vision.md) | Zero-Copy / BYOL as production vision, not built | Accepted | 2026-06-21 | — |
| [016](ADR-016-no-omnistudio-lwc-console.md) | No OmniStudio — custom UI is LWC | Accepted | 2026-06-21 | — |
| [017](ADR-017-sla-entitlement-omnichannel-routing.md) | SLA via Entitlement + Milestones, Omni-Channel routing | **Accepted (built)** | 2026-06-28 | P1 |
| [018](ADR-018-knowledge-category-topic-alignment.md) | Knowledge data-categories aligned to agent topics | **Accepted (built)** | 2026-06-28 | P1 |
| [019](ADR-019-build-language-english.md) | Build in English; German as a final localization step | Accepted | 2026-06-28 | — |
| [020](ADR-020-tariff-advisory-consent-handshake.md) | Tariff advisory — a conditional recommendation, and consent as a state machine | **Accepted** (built, live-verified 2026-07-12) | 2026-07-12 | P12 |
| [021](ADR-021-identity-is-two-factor.md) | Identity is two-factor — the privacy refusal must be a missing code path, not a polite model | **Accepted** (built, live-verified 2026-07-12) | 2026-07-12 | P12 |
| [022](ADR-022-identity-is-a-token-not-a-claim.md) | Identity is a token, not a claim — and a guardrail that crashes is not a guardrail | **Accepted** (built, live-verified 2026-07-13) | 2026-07-13 | P12 |

⭐ = headline differentiators (agent evaluation + red-team — rare in portfolios).

## When to write a new ADR

Add one when the decision:

- Affects multiple subsystems, or
- Rejects a viable alternative (preserve the rejection rationale), or
- Has non-obvious trade-offs future engineers will question, or
- Locks in a constraint future features must respect.

Skip ADRs for routine code-style choices (Prettier/PMD), easily reversible details, or
single-class decisions.

## ADR lifecycle

- **Proposed** — design locked in the blueprint, awaiting its build phase.
- **Accepted** — decided and in effect (and, where noted, **built**).
- **Deprecated** — no longer applies, kept for history.
- **Superseded by ADR-NNN** — replaced by a newer decision.

Once **Accepted**, an ADR is **immutable** — supersede it with a new ADR rather than editing
it, so the chain preserves architectural history.

## Template

```markdown
# ADR-NNN: <Short decision title>

- Status: Proposed | Accepted | Superseded by ADR-XXX
- Date: YYYY-MM-DD

## Context
<the forces at play — 3-6 sentences>

## Decision
<what we decided — short, declarative>

## Consequences
**Positive:** ...
**Negative / Trade-offs:** ...

## Alternatives Considered
### <Alternative> — why rejected

## References
<blueprint sections, related ADRs, memory, external links>
```

## Related documentation

- [`../../README.md`](../../README.md) — project overview + Faz 1 "what's built" status
- [`../../CLAUDE.md`](../../CLAUDE.md) — Claude Code session guide (repo layout, commands, patterns, gotchas, resumption pointer)
- [`../architecture/`](../architecture/) — architecture views (C4 context, …)
- [`../../PROJECT_BLUEPRINT.md`](../../PROJECT_BLUEPRINT.md) · [`../../ROADMAP.md`](../../ROADMAP.md) · [`../../PHASES.md`](../../PHASES.md)
