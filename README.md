# HanseWatt — Agentforce Service Cloud + Data 360 (DACH Energy)

> Portfolio project: an AI-powered customer service platform for **HanseWatt GmbH**, a
> fictional Hamburg-based DACH energy retailer. Built on **Service Cloud + Agentforce +
> Data 360**. An autonomous, German-speaking service agent — grounded in unified
> consumption + billing data — explains bills, takes action, and escalates safely under
> the Einstein Trust Layer, GDPR/DSGVO-compliant.

![Platform](https://img.shields.io/badge/Platform-Salesforce-00A1E0)
![Service Cloud](https://img.shields.io/badge/Service%20Cloud-active-brightgreen)
![Agentforce](https://img.shields.io/badge/Agentforce-AI%20Agents-7f5af0)
![Data 360](https://img.shields.io/badge/Data%20360-Data%20Cloud-1798c1)
![API](https://img.shields.io/badge/API-67.0-informational)
![Phase](https://img.shields.io/badge/Phase-1%20Service%20Cloud%20core%20%E2%9C%93-brightgreen)
![ADRs](https://img.shields.io/badge/ADRs-19-blue)

**Developer:** Mustafa Aksu · [mustafaaksu.dev](https://mustafaaksu.dev)

---

## Sell vs Serve — where this fits

| | TechnoStore (done) | **HanseWatt (this)** |
|---|---|---|
| Cloud | Revenue Cloud (RLM/CLM/CPQ) | **Service Cloud + Agentforce + Data 360** |
| Theme | Quote-to-Cash (sell) | **Customer service + AI (serve)** |
| AI | rule-based | **autonomous agent + grounded LLM** |
| Shared | DACH · German · GDPR · MuleSoft · O'Hara framework · honest framing |

Together: the two halves of the enterprise — **sell** and **serve** — with the 2026 AI +
data stack on the serve side.

## The demo in one flow

```
Lena (web chat, DE): "Warum ist meine Stromrechnung so hoch?"
        │
        ▼
[Agentforce Service Agent] ── Einstein Trust Layer ──
  1. Identifies Lena (Data 360 Unified Individual)
  2. Action: GetLatestBill        → € amount + period
  3. Action: ExplainConsumption   → Data 360 CI: "+62% vs 6-mo avg, evenings → EV charging"
  4. Grounds in a cited Knowledge article (no hallucinated numbers)
        ├── resolvable → ProposeTariff → InitiateTariffChange (creates Case + contract change)
        └── not resolvable → EscalateToHuman → Omni-Channel → rep agent case summary
        ▼
[Data 360 closes the loop] → segment "high-anomaly, no tariff change 30d" → proactive outreach
```

Three beats that sell it: **grounded, not hallucinated** · **autonomous action** (creates
records) · **closed loop** (service data drives proactive prevention).

## Architecture

```
            Customer channels (Web chat · WhatsApp · Experience Cloud)
                                   │
                    ┌──────────────▼───────────────┐
                    │   Agentforce Service Agent    │  Topics · Actions · Instructions
                    │   ──  Einstein Trust Layer  ──│  (PII masking · grounding · audit)
                    └───┬───────────────────────┬───┘
       grounding (RAG)  │                       │  actions (@InvocableMethod / Flow)
        ┌───────────────▼──┐                 ┌──▼───────────────────────────┐
        │ Retrievers       │                 │ Apex Action layer (HW…Action) │
        │ · Knowledge (DE) │                 │ GetLatestBill · ExplainAnomaly│
        │ · Data 360 DMO   │                 │ CreateCase · InitiateTariff … │
        └───────────────┬──┘                 └──┬───────────────────────────┘
        ┌───────────────▼───────────────────────▼─────────────────────────┐
        │            Salesforce core (Service Cloud)                        │
        │  Account · Contact · Case (RT + SLA) · Knowledge · Omni-Channel   │
        │  Meter__c · Tariff__c · Service_Contract__c · Energy_Bill__c …    │
        └───────────────┬──────────────────────────────────────────────────┘
        ┌───────────────▼──────────────────────────────────────────────────┐
        │             Data 360 (Data Cloud)                                 │
        │  Streams → DLO → DMO → Identity Resolution → Unified Profile       │
        │  Calculated Insights (avg kWh, anomaly, churn) → Segments → Flows  │
        └───────────────┬──────────────────────────────────────────────────┘
                        │  ingestion (Ingestion API / MuleSoft)
        External systems (simulated): smart-meter MDM · SAP IS-U billing
```

## Build status

| Phase | Theme | Status |
|------|-------|--------|
| **P0** | Org + foundations | ✅ done |
| **P1** | **Service Cloud core** | ✅ **done** (1 live gate test pending schema refresh) |
| P2 | Data 360 ingestion | ⏭ next |
| P3 | Identity resolution | ▫ planned |
| P4 | Calculated Insights + chart | ▫ planned |
| P5 | Agentforce agent (grounded) | ▫ planned |
| P6 | Prompt templates + Trust Layer | ▫ planned |
| P7 | Escalation + employee agent | ▫ planned |
| 🎬 | **Minimum Wow Demo recording** | ▫ gate |
| P8–P14 | Closed loop · DSGVO · **agent eval** ⭐ · **red-team** ⭐ · ROI · WhatsApp · docs | ▫ second wave |

### Faz 1 — what's built (this repo, deployed + committed)

| Area | Components |
|------|-----------|
| Data model | 7 objects + 37 fields (`Meter__c`, `Meter_Reading__c`, `Tariff__c`, `Service_Contract__c`, `Energy_Bill__c`, `Outage__c`, `Consent__c`) + `Case.HW_Topic__c` |
| Case + SLA | 5 record types + support process · `HW_Standard_SLA` entitlement (First Response 4h, Resolution 2 business days) |
| Omni-Channel | service channel · escalation queue · routing config · presence statuses · German + Billing skills |
| Knowledge | 6-topic data-category group + **10 published, categorized articles** |
| Security | `HW_Admin` · `HW_ServiceAgent` (bill/reading read-only = system-of-record) · `HW_ReadOnly` |
| Multi-currency | EUR (corporate) + CHF |
| Seed data | 4 DACH accounts + meters, contracts, bills, readings, consent, outage |

## Documents

- [`CLAUDE.md`](./CLAUDE.md) — session guide: repo layout, commands, patterns, **Faz 1 completion + gotchas**, resumption pointer
- [`docs/adr/`](./docs/adr/) — **19 Architecture Decision Records** (Nygard format)
- [`PROJECT_BLUEPRINT.md`](./PROJECT_BLUEPRINT.md) — the design (what & how)
- [`ROADMAP.md`](./ROADMAP.md) — feedback triage + gated roadmap + full skeleton
- [`PHASES.md`](./PHASES.md) — step-by-step build checklist (P0–P14)
- [`docs/manual-setup/`](./docs/manual-setup/) — org limits + Flex-Credit burn budget
- [`TechnoStore.md`](./TechnoStore.md) — the completed reference project + reused patterns

## Repository layout (SFDX, 8 packages)

```
force-app/             core sObjects, Service Cloud config, perms, Knowledge, data categories
force-app-services/    HWBillingService, HWConsumptionService, HWComplianceService …   [P5+]
force-app-actions/     Agentforce @InvocableMethod actions (HW…Action)                 [P5+]
force-app-handlers/    trigger handlers (Kevin O'Hara framework)                       [P5+]
force-app-agent/       Agentforce metadata (Bot/GenAiPlanner/Topics/Functions)         [P5+]
force-app-datacloud/   Data 360 metadata (DataStream/DLO/DMO/CI/Segment)               [P2+]
force-app-lwc/         hwConsumptionChart, hwAgentConsole, hwComplianceActions …       [P4+]
force-app-tests/       Apex tests                                                      [P5+]
docs/                  adr · architecture · manual-setup · security · eval
scripts/               anonymous Apex (seed_demo_data, seed_knowledge, verify_gate)
```

## Run it

```bash
sf org login web --alias hansewatt
sf project deploy start --source-dir force-app --target-org hansewatt
sf apex run --file scripts/seed_demo_data.apex --target-org hansewatt
sf apex run --file scripts/seed_knowledge.apex --target-org hansewatt
```

## License

Proprietary — All rights reserved. © 2026 Mustafa Aksu. Shared for portfolio and
evaluation purposes only.

> **Honest framing:** external systems (smart-meter MDM, SAP IS-U billing) are simulated;
> the Salesforce code paths, the agent, the Data 360 model, and grounding are real.
