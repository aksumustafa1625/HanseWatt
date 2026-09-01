# ADR-017: SLA via Entitlement + Milestones, routed by Omni-Channel queue

- Status: Accepted (built — Faz 1, 2026-06-28)
- Date: 2026-06-28

## Context

The Faz 1 exit criterion is "a Case routes via Omni-Channel and meets an SLA milestone".
Salesforce offers several SLA/routing primitives (Entitlements + Milestones, Case
escalation rules, Omni-Channel queue vs skills-based routing). We need a minimal, source-
deployable configuration that an escalated agent Case will flow through.

## Decision

- **SLA:** one **Entitlement Process** `HW_Standard_SLA` (exits on `IsClosed`) with two
  milestones against the Default business hours — **First Response 4h** and **Resolution 2
  business days** (`HW_First_Response`, `HW_Resolution`).
- **Routing:** **Omni-Channel** with a `HW_Case_Channel` service channel, an `HW_Escalations`
  queue, a `HW_Case_Routing` config (**LEAST_ACTIVE**, capacity 1), and Available/Busy
  presence statuses. Skills `HW_German` + `HW_Billing` are defined for future skills-based
  routing; Faz 1 uses queue-based routing.
- **Categorisation:** five Case **record types** (Billing/Consumption/Move/Outage/Complaint)
  on a shared support process; the agent sets `Case.HW_Topic__c` on create/escalate.

## Consequences

**Positive:** fully **source-deployable** (no managed package), so the whole Service Cloud
core lives in git. Clean handoff target for the escalation action ([ADR-011](ADR-011-two-agent-customer-employee.md)).
The live milestone clock is the visible SLA proof.

**Negative / Trade-offs:** the routing **enum is `LEAST_ACTIVE`/`MOST_AVAILABLE`
(SCREAMING_SNAKE) and `routingModel` is required** — discovered only against the live org
schema, not the CLI's stale metadata; documented so future routing configs don't repeat the
deploy cycle. **The live SLA milestone clock could not be bound in this org:** the standard
`Case.EntitlementId` lookup is **not provisioned** in this Developer Edition (Agentforce +
Data 360) flavor — even with Entitlement Management on, a Service Cloud User license, and a
full UI disable/re-enable cycle. It is catalogued in Tooling `FieldDefinition` but never
instantiated on Case. So the gate is recorded as **infrastructure complete; live clock
deferred (edition limitation)**; `scripts/verify_gate.apex` guards on the field and reports
gracefully. Binds normally in a Service Cloud Enterprise/Developer org. Full diagnosis:
`docs/troubleshooting/faz1-gate-case-entitlementid.md`.

## Alternatives Considered

### Case escalation rules instead of Entitlements

Rejected: weaker SLA modelling, no milestone clock, less aligned to the Service Cloud
job-spec vocabulary recruiters expect.

### Skills-based routing in Faz 1

Deferred: real value later (language + topic skills are defined), but queue routing is the
minimal path to the gate; skills-based routing is a Faz 7 enhancement.

## References

- `PHASES.md` Faz 1, `scripts/verify_gate.apex`
- Related: [ADR-007](ADR-007-grounding-knowledge-data360-retriever-split.md)
