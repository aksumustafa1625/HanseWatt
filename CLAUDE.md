# HanseWatt — Claude Code Project Guide

AI-powered customer-service platform for **HanseWatt GmbH**, a fictional Hamburg DACH energy
retailer (Strom + Gas). Built on **Service Cloud + Agentforce + Data 360**. An autonomous,
German-speaking service agent — grounded in unified consumption + billing data — explains
bills, takes action, and escalates safely under the Einstein Trust Layer, GDPR/DSGVO-
compliant. The "serve + AI" complement to TechnoStore's "sell" (Revenue Cloud) portfolio.

> **Honest framing (inherited from TechnoStore):** external systems (smart-meter MDM, SAP
> IS-U billing) are *simulated*; the Salesforce code paths, the agent, the Data 360 model,
> and grounding are *real*.

## Build language — READ FIRST

**Everything is built in English** — metadata labels, code, comments, docs, Knowledge
content, data-category labels. **Do not change the org UI/default language** (it stays
English (US)). The builder's German is low and must be able to review every artifact. The
German customer-facing layer (agent responses, Knowledge translations) is a **single,
controlled localization step at the end**, paired with English glosses. See
[ADR-019](docs/adr/ADR-019-build-language-english.md).

## Org

| Field | Value |
|---|---|
| Alias | `hansewatt` |
| Username | _(local `sf` auth — not committed)_ |
| Instance | _(personal Dev Edition — not committed)_ |
| Edition / API | Developer Edition (Agentforce + Data 360) · **API 67.0** |
| Locale / Currency | English (US) UI · **multi-currency: EUR (corporate) + CHF** |

Single build org. **Never touch the TechnoStore / Configra orgs.**

## Repository layout (8-package SFDX)

```
force-app/             core sObjects + Service Cloud config + perms + Knowledge — AND the
                       live agent metadata (bots/, genAiPlannerBundles/, genAiPlugins/,
                       genAiFunctions/, aiAuthoringBundles/), where the CLI created it
force-app-services/    ✅ 6 HW…Service classes (customer, billing, consumption, case, knowledge, tariff)
force-app-actions/     ✅ 7 @InvocableMethod actions (HW...Action)
force-app-datacloud/   ✅ Data 360 DataStreamDefinitions (4)
force-app-tests/       ✅ Apex tests (13 classes / 74 methods · 97% coverage)
force-app-handlers/    ⬜ trigger handlers (Kevin O'Hara) — reserved, empty
force-app-agent/       ⬜ reserved package (agent metadata currently in force-app/)
force-app-lwc/         ⬜ hwConsumptionChart, hwAgentConsole — reserved, empty
docs/                  adr · architecture · demo · manual-setup · research · troubleshooting
scripts/               anonymous Apex (seed + Data 360 query + verification)
```

Full built-vs-planned truth: **`STATUS.md`** (repo root).

Planning docs: `PROJECT_BLUEPRINT.md` (design) · `ROADMAP.md` (triage + skeleton) ·
`PHASES.md` (P0–P14 step-by-step checklist) · `TechnoStore.md` (reference patterns).

## Common commands

```powershell
# Deploy a folder (deploy small, dependency-ordered units — see gotcha below)
sf project deploy start --source-dir force-app/main/default/objects/Case --target-org hansewatt

# Run anonymous Apex (seed / verify)
sf apex run --file scripts/seed_demo_data.apex   --target-org hansewatt
sf apex run --file scripts/seed_knowledge.apex   --target-org hansewatt
sf apex run --file scripts/verify_gate.apex      --target-org hansewatt

# Inspect live-org metadata shape (authoritative when the CLI registry is stale)
sf org list metadata --metadata-type ServiceChannel --target-org hansewatt
sf sobject describe --sobject Knowledge__kav --target-org hansewatt
sf data query --use-tooling-api --query "SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName='Case'" --target-org hansewatt
```

## ⚠️ Quota discipline — the standing rule

The limiter is **not** storage or Apex governor limits — it is **Flex Credits** (the single
unified pool for Agentforce actions + Data 360, ~20 credits/agent action, ~4/prompt). Dev
Edition has an undocumented "limited" allotment and **no Digital Wallet** to read the
balance. So:

1. **Mock-first** — prove Apex action logic with **Apex tests (free)** before wiring to the
   live agent. Never iterate the agent 50× to debug logic.
2. **Small data sets** — validate CI / identity mapping on ~10 records, then scale.
3. **On-demand, never scheduled** — trigger CI / Identity Resolution / Segment by hand; no
   nightly refresh (the sneakiest credit leak).
4. **Freeze, then eval once** — for Faz 10/11, stabilize the agent, tune the judge against
   fake transcripts, run the real suite **once**.
5. **Record incrementally** — capture each phase's demo snippet as you go.

Full rules: `PHASES.md` (kota disiplini) · `docs/manual-setup/burn-budget.md`.

## Key patterns & code standard

- **Apex actions:** `with sharing`, SOQL `WITH USER_MODE`, DML `as user`, bulk-safe, no
  DML-in-loop, ≥80% coverage with `HttpCalloutMock`. See [ADR-006](docs/adr/ADR-006-apex-invocable-vs-flow-actions.md).
- **Grounding:** Knowledge retriever for procedure, Data 360 retriever for figures; the agent
  never invents a number. [ADR-007](docs/adr/ADR-007-grounding-knowledge-data360-retriever-split.md).
- **Naming:** Apex `HW` prefix; actions `HW...Action`; tests `...Test`; perms `HW_` prefix;
  LWC `hw` camelCase; objects namespace-free (`Meter__c`).
- **UI:** LWC only, no OmniStudio. [ADR-016](docs/adr/ADR-016-no-omnistudio-lwc-console.md).

## What NOT to do

- Don't change the org Locale/Language to German (build language is English).
- Don't deploy large mixed batches — Salesforce **rolls back the whole batch on any one
  failure** (`rollbackOnError` default), and the SF-CLI source-tracking can then mark a
  rolled-back component as "Unchanged" and silently skip redeploying it. Deploy small,
  dependency-ordered units; re-verify with `sf org list metadata` / SOQL, not the deploy
  summary alone. (Bit us twice in Faz 1 — see gotchas.)
- Don't trust the CLI's local metadata registry for field/enum shapes — **describe the live
  org** (`describeValueType` via SOAP, or `sf sobject describe`).
- Don't schedule any Data 360 / agent job during dev (credit leak).
- Don't claim production traffic — say "demo verified" / "local end-to-end test".

## Faz 1 — Service Cloud core — COMPLETE (2026-06-28)

The zero-credit foundation. All metadata is **source-deployable** and committed; only the
live SLA gate test awaits an org schema-cache refresh.

### What's in the org

| Area | Components | ADR |
|------|-----------|-----|
| **Data model** | 7 objects + 37 fields: `Meter__c`, `Meter_Reading__c`, `Tariff__c`, `Service_Contract__c`, `Energy_Bill__c`, `Outage__c`, `Consent__c` + `Case.HW_Topic__c` | — |
| **Case record types** | Billing / Consumption / Move / Outage / Complaint on shared `HW_Support_Process` | [017](docs/adr/ADR-017-sla-entitlement-omnichannel-routing.md) |
| **Omni-Channel** | `HW_Case_Channel`, `HW_Escalations` queue, `HW_Case_Routing` (LEAST_ACTIVE, cap 1), Available/Busy presence, `HW_German` + `HW_Billing` skills | [017](docs/adr/ADR-017-sla-entitlement-omnichannel-routing.md) |
| **SLA** | `HW_Standard_SLA` entitlement process (exit on `IsClosed`) + `HW_First_Response` (4h) + `HW_Resolution` (2 business days) milestones | [017](docs/adr/ADR-017-sla-entitlement-omnichannel-routing.md) |
| **Knowledge** | `HanseWatt_Topics` data-category group (6 topics) + `Body__c` rich-text field + **10 English articles published & categorized** (`scripts/seed_knowledge.apex`) | [018](docs/adr/ADR-018-knowledge-category-topic-alignment.md) |
| **Security** | Permission sets `HW_Admin`, `HW_ServiceAgent` (bill/reading read-only = SoR), `HW_ReadOnly` | — |
| **Multi-currency** | Activated; corporate **EUR** + **CHF** (REST insert; Apex DML blocked) | [010](docs/adr/ADR-010-multi-currency-eur-chf.md) |
| **Seed data** | 4 DACH accounts (Lena/Hamburg-DE, Huber/Wien-AT, Müller GmbH/Köln-DE, Studio Alpina/Zürich-CH) + meters, contracts, bills (Lena's = the spike), readings, consent, outage | — |

### Gotchas learned (so we don't repeat the deploy cycles)

- **Live-schema enum names differ from intuition.** `ServiceChannel` uses `relatedEntityType`
  (not `relatedEntity`); `QueueRoutingConfig.routingModel` is **required** and its enum is
  **SCREAMING_SNAKE** (`LEAST_ACTIVE` / `MOST_AVAILABLE` / `EXTERNAL_ROUTING`), not CamelCase.
  Found via the Metadata WSDL (`/services/wsdl/metadata`, sid-cookie auth) + `describeValueType`.
- **`BusinessProcess`** decomposed file needs an explicit `<fullName>` element.
- **Entitlement process** needs an exit criterion (`exitCriteriaFormula = IsClosed`); deploy
  `MilestoneType` **before** the `EntitlementProcess` in a *separate successful* deploy (else
  rollback drops the milestone types the process references).
- **`Knowledge__kav.Body__c` schema-cache lag.** New rich-text field appears in Tooling
  `FieldDefinition` but lagged the Apex/SOQL active schema; Knowledge body stored in `Summary`
  for now.
- **`Case.EntitlementId` is NOT provisioned in this Dev Edition (Agentforce + Data 360).**
  Confirmed after fixing the Service Cloud User license + a full disable/re-enable cycle (UI
  *and* metadata): the standard Case entitlement lookup never instantiates (catalogued in
  Tooling `FieldDefinition`, absent from `fields.getMap()`). The live SLA milestone clock
  can't bind here — edition limitation, not our config. `verify_gate.apex` guards on the
  field. Full diagnosis: `docs/troubleshooting/faz1-gate-case-entitlementid.md`.
- **`CurrencyType`** rejects Apex DML; create currencies via the **REST API**
  (`sf data create record --sobject CurrencyType`).

### Faz 1 gate — resolved (infrastructure complete; live clock = edition limitation)

`scripts/verify_gate.apex` reports **"INFRASTRUCTURE COMPLETE — live milestone clock NOT
testable here"**: the SLA design (`HW_Standard_SLA` + milestones) and Omni-Channel routing
are deployed and source-controlled, but the live `CaseMilestone` clock can't bind because
`Case.EntitlementId` is not provisioned in this Dev-Edition flavor (see gotcha above +
`docs/troubleshooting/`). It binds normally in a Service Cloud Enterprise/Developer org — a
clean future-verification path. This does not block Faz 2 or any headline feature.

## Current status — Faz 1 + 2 + 5 built (see `STATUS.md`)

Since the Faz 1 note above, **Faz 2 (Data 360)** and **Faz 5 (the live agent)** are also
built and committed:

- **Faz 2:** 4 DataStreamDefinitions → DLOs; the consumption anomaly is grounded live via
  the Data 360 Query API (SQL CI over the Meter Reading DLO) — Lena **520 vs 316 kWh =
  +64.6 %** (`scripts/datacloud_ci_anomaly.sql`, `scripts/datacloud_query.ps1`).
- **Faz 5:** `HW_Energy_Agent` (Bot + ReAct planner + 2 topics) with **4 grounded actions**
  — `HWIdentifyCustomerAction`, `HWGetLatestBillAction`, `HWExplainConsumptionAction`,
  `HWCreateCaseAction`, `HWAnswerFromKnowledgeAction` — over 5 services + `HW_Agent_Actions` perms + 49 tests (99% cov). The
  multi-turn flow (identify → bill → anomaly → create-case) runs grounded, including in
  German. Wiring recipe + gotchas: `MEMORY.md` / memory `faz5-status`.

**Next:** finish Knowledge Data Library grounding (RAG index for procedure answers). The
full built-vs-planned matrix — and everything still designed-only (identity resolution,
LWC UI, agent eval, red-team, employee agent, DSGVO automation, WhatsApp) — lives in
**`STATUS.md`**.

## Memory

Persistent memory at `C:\Users\DELL\.claude\projects\c--Users-DELL-Documents-Projects-HanseWatt\memory\`,
indexed in `MEMORY.md`. Key files: `build-language-english.md`, `faz1-status-2026-06-28.md`.
Update after significant decisions; don't duplicate code-/git-derivable facts.
