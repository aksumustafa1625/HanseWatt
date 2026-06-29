# Faz 2 — Data 360 (Data Cloud) build log

> What was built, what's source-controlled vs click-only, and how the agent's figures
> are grounded in Data 360. Honest-framing per the project standard.
> **Date:** 2026-06-29 · Org: `hansewatt` (Dev Edition, Agentforce + Data 360).

## What exists in the org

| Layer | Item | How it was made | Source-controlled? |
|---|---|---|---|
| Provisioning | Data Cloud instance (1 Data Space `default`, tenant endpoint) | auto-provisioned ("Get Started" already done) | ❌ click-only |
| Connection | `Home` — Salesforce CRM home-org connector (Active) | auto / UI | ❌ click-only |
| Data Streams | `Account_Home`, `Meter_c_Home`, `Meter_Reading_c_Home`, `Energy_Bill_c_Home` | UI wizard (Salesforce CRM, free pipeline) | ✅ `force-app-datacloud/.../dataStreamDefinitions/` |
| DLOs | `Account_Home__dll`, `Meter_c_Home__dll`, `Meter_Reading_c_Home__dll`, `Energy_Bill_c_Home__dll` | auto-created by the streams | ❌ (not retrievable in this Dev Edition) |
| Categories | Account = **Profile**; Meter/Meter_Reading/Energy_Bill = **Other** | set in the stream wizard (irreversible) | (captured in stream def) |

Ingested record counts (verified): Account **17** (4 DACH demo + 13 pre-existing org accounts),
Meter **4**, Meter_Reading **24**, Energy_Bill **4**. **Zero credits** — Salesforce CRM
ingestion is free.

## Grounding the agent's figures — Query API (no UI Calculated Insight)

The DLO/DMO/Calculated-Insight modeling canvas is **UI-first** and not cleanly authorable via
blind CLI metadata in this Dev Edition (`MktDataModelObject` / `MktDataLakeObject` don't list
or retrieve; no template). So instead of building a UI Calculated Insight, the figures-half
grounding ([ADR-007](../adr/ADR-007-grounding-knowledge-data360-retriever-split.md)) runs the
**CI logic as SQL against the Data 360 Query API**:

```
POST {instanceUrl}/services/data/v64.0/ssot/queryv2   body: {"sql": "<SQL>"}
```

- Helper: `scripts/datacloud_query.ps1`
- CI SQL: `scripts/datacloud_ci_anomaly.sql`

**Validated result (2026-06-29)** — per-meter latest vs trailing-average anomaly, queried
live from the Data 360 Meter Reading DLO:

| Meter | Latest kWh | Avg prior | Anomaly |
|---|---|---|---|
| Huber (Wien) | 200 | 204 | −2% |
| Alpina (Zürich) | 165 | 164.6 | +0.2% |
| Müller (Köln, SME) | 4800 | 4754 | +1% |
| **Lena (Hamburg)** | **520** | **316** | **+64.6%** |

Lena's **+64.6%** is the demo's anomaly (blueprint said "~62%"). The data lives in Data 360,
the computation runs in Data 360 — proven via CLI, zero UI.

> DLO column note: a custom field `X__c` lands in the DLO as `X_c__c` (e.g. `kWh__c` →
> `kWh_c__c`, `Read_Date__c` → `Read_Date_c__c`, `Meter__c` → `Meter_c__c`).

## Deferred (optional polish, UI-first)

- Formal **custom DMOs** (Energy Usage / Billing) + DLO→DMO field mapping.
- **Identity Resolution** ruleset → Unified Individual (needs Contact ingested too — its
  email is the match key, [ADR-005](../adr/ADR-005-identity-resolution-match-reconcile.md)).
- A saved **Calculated Insight** object + a **Data Cloud retriever** for the agent.

These are deferred because the Query-API path already delivers the grounded figure the agent
needs (Faz 5 will call it from an Apex action / retriever). When built, capture them via a
**DevOps Data Kit** (research §10).

## Repro

```powershell
pwsh scripts/datacloud_query.ps1 -SqlFile scripts/datacloud_ci_anomaly.sql
# or any ad-hoc SQL:
pwsh scripts/datacloud_query.ps1 -Sql "SELECT count(*) FROM Meter_Reading_c_Home__dll"
```
