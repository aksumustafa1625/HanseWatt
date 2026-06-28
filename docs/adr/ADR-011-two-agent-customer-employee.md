# ADR-011: Two agents (customer + employee) over single- or four-agent designs

- Status: Accepted (design locked, pre-build — Faz 7)
- Date: 2026-06-21

## Context

"Multi-agent" is a strong portfolio signal, but it invites scope creep. The review surfaced
a four-agent vision (Billing / Outage / Retention / Employee). We need a design that proves
multi-agent collaboration without ballooning the build.

## Decision

Ship **two agents**:

1. **HW_Service_Agent** — customer-facing, autonomous (web/WhatsApp). Owns Billing,
   Consumption, Tariff, Move, Outage, Complaint topics.
2. **HW_Employee_Agent** (for Jonas, the rep) — case summary + next-best-action on escalated
   Cases (`HW_CaseSummary` prompt template).

Retention and Outage are **topics/actions inside the customer agent**, not separate agents.

## Consequences

**Positive:** proves multi-agent + a clean human-handoff demo (customer agent escalates →
Omni-Channel → employee agent summarises) without four agents' worth of config and credit
burn. Maps to two distinct Agentforce product SKUs (Service Agent + Agentforce for Service
reps).

**Negative / Trade-offs:** the four-agent "agent fleet" narrative is deferred to the roadmap
(R4); retention/outage live as topics, which is slightly less flashy than dedicated agents.

## Alternatives Considered

### Single agent
Rejected: no multi-agent signal; no rep-side handoff story.

### Four-agent fleet (Billing/Outage/Retention/Employee)
Rejected: over-engineered for a portfolio demo; 4× the config, testing, and Flex-Credit
burn for marginal narrative gain. Revisit only via roadmap R4.

## References

- `ROADMAP.md` §1.4 (rejected four-agent), §1.2 (E-list)
- Related: [ADR-002](ADR-002-agentforce-service-agent-vs-custom-orchestration.md)
