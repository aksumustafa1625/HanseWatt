# ADR-005: Identity resolution — match + reconcile rule design

- Status: Proposed (pre-build — Faz 3)
- Date: 2026-06-21

## Context

The same customer arrives from three sources with no shared key: CRM (Account/Contact, e.g.
"Lena Bergmann"), SAP IS-U billing ("L. Bergmann", a billing customer id), and web/
engagement ("lena.b@gmx"). Data 360 must resolve them into one **Unified Individual** the
agent can ground on — and identity resolution only _impresses_ when the data is messy.

## Decision

- **Match rules:** exact **email** match (highest confidence) + **fuzzy name + address**
  match + an **external meter/billing customer id** bridge to reconcile billing records whose
  id ≠ the Salesforce Contact id.
- **Reconciliation:** **most-recent-wins** for contact details; **source-priority** for the
  billing customer id (SAP authoritative). Output: one Unified Individual.
- A deliberate **dirty-data test case**: Lena as "L. Bergmann" (SAP) + lena.b@gmx (web) +
  Lena Bergmann (CRM) must collapse to a single profile, shown live.

## Consequences

**Positive:** the unified profile is the agent's single grounding identity; the messy-data
demo is what makes identity resolution credible; sets up the system-of-record story
([ADR-003](ADR-003-data360-system-of-record-boundary.md)).

**Negative / Trade-offs:** fuzzy matching needs tuning to avoid over-merging; identity
resolution runs consume Flex Credits — run **on-demand on a small set**, never scheduled,
per the quota discipline.

## Alternatives Considered

### Exact-key join only

Rejected: there is no shared key across SAP/CRM/web — the whole point is reconciling without
one.

### Deterministic email-only matching

Rejected: misses the SAP billing record (different id, abbreviated name) — the most
interesting reconciliation.

## References

- `PROJECT_BLUEPRINT.md` §8.3, `PHASES.md` Faz 3 (C5 dirty-data case)
- Related: [ADR-003](ADR-003-data360-system-of-record-boundary.md)
