# ADR-004: Ingestion API (primary) vs MuleSoft vs Connector per feed

- Status: Accepted
- Date: 2026-06-20

## Context

External data must reach Data 360 from a smart-meter MDM (high-volume readings) and SAP
IS-U (monthly billing). TechnoStore established a Mule-vs-Apex decision matrix; we need the
Data 360 equivalent: when to use the Ingestion API, MuleSoft, or a native Connector.

## Decision

- **Smart-meter readings → Data 360 Ingestion API (primary).** High-volume, schema-stable,
  append-only streaming. The Ingestion API is the modern, scalable default.
- **SAP IS-U billing → MuleSoft → Ingestion API** when transformation/orchestration is
  needed (format mapping, batching, retry/DLQ); otherwise a direct streaming/bulk ingest.
  This mirrors TechnoStore's principle: **Mule when integration IS the work** (transform,
  fan-out, reliability), direct API when it's a simple feed.
- **Salesforce CRM + Engagement → native Data Cloud Connector.** No reason to hand-build
  what the platform connector does.

For the portfolio demo, the meter feed is a **synthetic generator script** posting to the
Ingestion API — the production code path, with simulated source data (honest framing).

## Consequences

**Positive:** scalable primary path; Mule reserved for genuine orchestration value; native
connector for CRM; consistent with the TechnoStore reasoning recruiters already see.

**Negative:** two ingestion mechanisms to document; Ingestion API connector setup is
click-heavy (capture in `docs/manual-setup/`).

## Alternatives Considered

- **MuleSoft for everything** — rejected: over-engineered for a stable append-only feed.
- **Apex callouts into Data 360** — rejected: wrong tool for bulk time-series; governor
  limits (see ADR-003).

## References

- `ROADMAP.md` §5.3 (Data 360 artifacts)
- TechnoStore Mule-vs-Apex decision matrix (`TechnoStore.md`)
