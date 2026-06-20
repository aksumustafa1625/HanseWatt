# ADR-003: Data 360 System-of-Record boundary

- Status: Accepted
- Date: 2026-06-20

## Context

Several data types (meter readings, bills) exist both as Salesforce custom objects and as
Data 360 objects. An interviewer will immediately ask: "Same data in two places — which is
authoritative? How do you avoid double-writes? How does the agent read it at scale?"
We need an explicit, defensible boundary.

## Decision

Define system-of-record per data type:

| Data | System of Record | Why |
|---|---|---|
| Account / Contact | Salesforce | customer master, transactional CRM |
| `Meter__c`, `Tariff__c`, `Service_Contract__c`, `Outage__c` | Salesforce | low-volume operational/dimension data, written by UI + agent actions |
| `Meter_Reading__c` (history) | **Data 360** | high-volume time-series; SF keeps only a small recent copy for display |
| `Energy_Bill__c` (history) | **Data 360** (from SAP IS-U feed) | external billing system feed; SF holds latest for action reads |
| `Consent__c`, `HW_Agent_Eval_Result__c` | Salesforce | governance/audit, written by SF logic |

**Agent reads Calculated Insights, never raw time-series rows.** High-volume aggregation
(averages, anomaly scores) is computed in Data 360 and exposed as CIs; the agent's actions
query CIs. This is also the governor-limit answer (see ADR-014 / ROADMAP §C9): aggregating
months of hourly readings for 250k customers in Apex would blow governor limits — Data 360
is the correct engine.

## Consequences

**Positive:** no ambiguity on authority; no double-write risk (each type has one writer);
the agent stays within limits by reading CIs; clean migration story to production.

**Negative:** a small recent-copy sync for display data must be maintained; eventual
consistency between Data 360 history and the SF recent copy must be acknowledged in the
demo narrative.

## Alternatives Considered

- **Everything in Salesforce** — rejected: time-series volume + governor limits.
- **Everything in Data 360, nothing in SF** — rejected: agent actions need record-bound SF
  writes (Case, Service_Contract changes); record pages need local display data.

## References

- `ROADMAP.md` §5.2 (data model + SoR), §C9 (scale rationale)
