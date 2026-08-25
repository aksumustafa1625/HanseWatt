# ADR-015: Zero-Copy / BYOL as a production vision, not built in Dev Edition

- Status: Accepted (documented as not-built)
- Date: 2026-06-21

## Context

A production-grade Data 360 architecture would often **Zero-Copy / BYOL** (Bring Your Own
Lake) against a Snowflake/Redshift/BigQuery warehouse rather than copying data in. It is a
strong "I understand production data architecture" talking point — but it **cannot be built
in a Developer Edition** (needs an external data lake).

## Decision

**Do not attempt to build** Zero-Copy/BYOL. **Document it as the production data-architecture
vision** in this ADR and the demo narrative: in production, smart-meter and billing data
would be federated via Zero-Copy from the lakehouse, avoiding duplication and egress, with
Data 360 querying in place. The portfolio build uses the **Ingestion API with a synthetic
feed** ([ADR-004](ADR-004-ingestion-api-vs-mulesoft.md)) as the honest, buildable substitute.

## Consequences

**Positive:** captures senior data-architecture awareness without over-claiming; keeps the
build honest (external systems simulated, code paths real); a clean interview talking point.

**Negative / Trade-offs:** no live Zero-Copy artifact to show — it remains narrative + ADR,
explicitly labelled as not-built.

## Alternatives Considered

### Build Zero-Copy in the Dev Edition

Rejected: impossible — there is no external lake; attempting it would be dishonest framing.

### Omit it entirely

Rejected: it's a relevant, expected production consideration; naming it (and why it's not
built) is itself a senior signal.

## References

- `ROADMAP.md` §1.3 (R6), `PROJECT_BLUEPRINT.md` honest-framing rule
- Related: [ADR-004](ADR-004-ingestion-api-vs-mulesoft.md), [ADR-003](ADR-003-data360-system-of-record-boundary.md)
