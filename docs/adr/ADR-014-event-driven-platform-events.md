# ADR-014: Event-driven backbone — Platform Events

- Status: Proposed (pre-build — Faz 8)
- Date: 2026-06-21

## Context

The closed-loop story (anomaly → proactive outreach), escalation, outage broadcast, and the
DSGVO audit trail all benefit from decoupling producers from consumers. TechnoStore proved
the Platform Event indirection pattern; HanseWatt needs the same backbone for its async,
fan-out flows.

## Decision

Use **Platform Events** as the integration backbone for cross-subsystem signals:
`Consumption_Anomaly__e`, `Outage__e`, `Escalation__e`, and a DSGVO **audit** event
([ADR-009](ADR-009-dsgvo-rtbf-across-systems.md)). Producers (agent actions, CIs, flows)
publish; consumers (proactive journeys, routing, audit log) subscribe — no synchronous
coupling.

## Consequences

**Positive:** clean decoupling enables proactive flows and audit without blocking the
publishing transaction; mirrors a proven enterprise pattern; lets the SAP/MDM ingestion and
the agent actions evolve independently.

**Negative / Trade-offs:** eventual-consistency semantics to reason about; Platform Event
delivery + replay limits to respect; another moving part to document.

## Alternatives Considered

### Synchronous Apex calls between subsystems
Rejected: tight coupling, transaction-boundary problems (DML-then-callout), and no natural
fan-out for proactive journeys.

### Change Data Capture only
Rejected: CDC is record-change-shaped; bespoke domain events (anomaly, escalation) model the
business signal more clearly.

## References

- `PROJECT_BLUEPRINT.md` §8.5 / `PHASES.md` Faz 8 (E7)
- Related: [ADR-009](ADR-009-dsgvo-rtbf-across-systems.md)
