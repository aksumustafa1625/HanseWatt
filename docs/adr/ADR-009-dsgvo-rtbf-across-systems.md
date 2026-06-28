# ADR-009: DSGVO Right-to-be-Forgotten across Salesforce + Data 360

- Status: Proposed (pre-build — Faz 9)
- Date: 2026-06-21

## Context

Energy + personal data means GDPR/DSGVO is a headline feature, not a footnote. A data-subject
deletion request must remove or anonymize a person across **both** the Salesforce core and
the Data 360 unified profile — two stores with different deletion mechanics — and leave an
audit trail.

## Decision

A built **Right-to-be-Forgotten** tool:

1. **Consent** captured on `Consent__c` (built in Faz 1) + a Data 360 consent model.
2. An LWC button (`hwComplianceActions` → "DSGVO Löschung") triggers Apex/Flow that
   **anonymizes** the Salesforce Account/Contact, **requests Data 360 deletion** (Delete
   API), and writes an **audit Platform Event**.
3. **Agent guardrail:** any deletion/data-subject request is **routed to the DSGVO process,
   never handled inline by the LLM** ([ADR-008](ADR-008-german-sie-trust-layer-guardrails.md)).

## Consequences

**Positive:** compliance becomes a *working feature* with cross-system reach + audit — a
strong DACH differentiator; reuses TechnoStore's GDPR thinking as built code.

**Negative / Trade-offs:** two deletion mechanics to orchestrate and prove; anonymize-vs-
hard-delete trade-offs (anonymize preserves referential integrity for billing history);
Data 360 deletion is asynchronous, so the audit event records "requested", reconciled later.

## Alternatives Considered

### Salesforce-only deletion
Rejected: leaves personal data in the Data 360 profile — not actually compliant.

### Manual deletion runbook
Rejected: a documented manual process is weaker portfolio evidence than a working,
audited automation.

## References

- `PROJECT_BLUEPRINT.md` §13, `PHASES.md` Faz 9
- Related: [ADR-008](ADR-008-german-sie-trust-layer-guardrails.md), [ADR-014](ADR-014-event-driven-platform-events.md)
