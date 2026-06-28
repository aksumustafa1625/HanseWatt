# ADR-006: Apex `@InvocableMethod` actions vs Flow actions for the agent

- Status: Accepted (design locked, pre-build — Faz 5/7)
- Date: 2026-06-21

## Context

Agentforce can call two kinds of Actions: **Apex** (`@InvocableMethod`) and **Flow**. The
agent needs both data-bound reads/writes (latest bill, consumption anomaly, create Case,
initiate tariff change) and declarative multi-step processes (start a Move/Umzug, schedule
a callback). We need a rule for which action type each capability uses.

## Decision

- **Apex `@InvocableMethod`** for data-bound actions that read Data 360 / SObjects or write
  records with precise control: `HWGetLatestBillAction`, `HWExplainConsumptionAction`,
  `HWProposeTariffAction`, `HWInitiateTariffChangeAction`, `HWCreateCaseAction`,
  `HWEscalateToHumanAction`, `HWCheckOutageAction`.
- **Flow** for declarative, branchy, admin-tunable processes: `HWStartMoveAction`,
  `HWScheduleCallbackAction`.

Apex code standard (non-negotiable): `with sharing`, SOQL `WITH USER_MODE`, DML `as user`,
bulk-safe, no DML-in-loop, ≥80% test coverage with `HttpCalloutMock`.

## Consequences

**Positive:** Apex actions are **unit-testable for free** (Apex tests burn no Flex Credits)
— central to the quota discipline: action logic is proven by tests *before* it is ever
wired to the live agent. Precise FLS/sharing enforcement (`WITH USER_MODE` / `as user`)
gives a defensible security story. Flow keeps simple processes admin-editable.

**Negative / Trade-offs:** two action paradigms to document and test; Apex requires
disciplined coverage. Mixed ownership (dev vs admin) of the action layer.

## Alternatives Considered

### All-Flow actions
Rejected: hard to unit-test deterministically, weaker for complex SOQL/Data 360 reads and
bulk-safe DML, and no free pre-agent verification path — every iteration would burn credits.

### All-Apex actions
Rejected: loses declarative agility for genuinely simple, branchy processes (Move,
callback) that benefit from admin tuning without a deploy.

## References

- `PROJECT_BLUEPRINT.md` §9.3 (Actions table)
- Related: [ADR-002](ADR-002-agentforce-service-agent-vs-custom-orchestration.md)
