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
![Status](https://img.shields.io/badge/Status-Live%20grounded%20agent%20%E2%9C%93-brightgreen)
![ADRs](https://img.shields.io/badge/ADRs-19-blue)

**What's real vs. planned:** see [`STATUS.md`](./STATUS.md) — one honest source of truth.
Everything in the demo below is built, deployed, and committed.

**Developer:** Mustafa Aksu · [mustafaaksu.dev](https://mustafaaksu.dev)

---

## 🎥 Live demo

In one conversation the agent runs the whole service flow — grounded and in German —
end to end: **identify the customer (email → Account) → quote the real bill → explain the
+64.6 % consumption anomaly → open a real support Case**, under the Einstein Trust Layer.

[![Watch the 2-minute demo](https://img.youtube.com/vi/NhviJYO_874/hqdefault.jpg)](https://youtu.be/NhviJYO_874)

▶ **[Watch the 2-minute demo on YouTube](https://youtu.be/NhviJYO_874)** _(spoken in German)_

**Grounded, not hallucinated** — the reasoning trace shows the agent calling the Apex action,
which returns the real figures (520 vs 316 kWh, +64.6 %, cited to Data 360), and Salesforce's
own evaluator marks the reply **GROUNDED**:

![Grounding trace — HW Explain Consumption Anomaly output + GROUNDED verdict](docs/demo/images/grounding-trace.png)

**The full multi-turn flow** — two subagents, the ReAct reasoning trace, and the live
conversation:

![Agent architecture — subagents, reasoning trace, and conversation](docs/demo/images/agent-architecture.png)

**It takes real action** — not just an answer: the agent opens a real Case (Created By the
EinsteinServiceAgent User), linked to the customer's account, with a grounded description:

![The support Case the agent created in Salesforce](docs/demo/images/case-record.png)

**The numbers are real records** — every figure traces back to the system of record: the
customer's `Energy_Bill__c` (BILL-000004: €176.30 / 520 kWh) and the `Meter_Reading__c`
history (five months around 316 kWh, then the 520 kWh spike = +64.6 %):

![Energy bill records](docs/demo/images/source-bill.png)

![Meter reading records](docs/demo/images/source-readings.png)

> More screenshots (bill answer, anomaly answer, case answer) are in
> [`docs/demo/images/`](docs/demo/images/); the walkthrough write-up lives in
> [`docs/demo/faz5-grounded-answer.md`](docs/demo/faz5-grounded-answer.md).

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
  3. Action: ExplainConsumption   → Data 360: "+64.6% vs avg (520 vs 316 kWh)"
  4. Grounds in a cited Knowledge article (no hallucinated numbers)
        ├── resolvable → ProposeTariff → InitiateTariffChange (creates Case + contract change)
        └── not resolvable → EscalateToHuman → Omni-Channel → rep agent case summary
        ▼
[Data 360 closes the loop] → segment "high-anomaly, no tariff change 30d" → proactive outreach
```

Three beats that sell it: **grounded, not hallucinated** · **autonomous action** (creates
records) · **closed loop** (service data drives proactive prevention).

> **Built vs. planned in that diagram:** built and demoed today —
> _identify → GetLatestBill → ExplainConsumption (+64.6 %) → AnswerFromKnowledge (cited) →
> **ProposeTariffChange → ConfirmTariffChange** → CreateCase_. Still **designed, not yet code**:
> `EscalateToHuman` (Omni-Channel handoff) and the Data 360 closed-loop segment — see
> [`STATUS.md`](./STATUS.md).

### The agent doesn't just explain the high bill — it solves it, and refuses to guess

```
Lena: "Meine Rechnung ist zu hoch. Wechseln Sie mich in einen günstigeren Tarif."

Agent [HW Propose Tariff Change]:
  "Sie könnten jährlich 69,60 EUR sparen mit dem EV-Tarif. Der hat einen niedrigeren
   kWh-Preis, ABER eine höhere Grundgebühr.
   Allerdings hängt die Empfehlung davon ab, ob Ihr höherer Verbrauch von 520 kWh
   DAUERHAFT ist (z. B. eine Wallbox). Andernfalls bleibt Ihr aktueller Tarif die
   beste Wahl. Können Sie das bestätigen?"          <- it asks instead of guessing

Lena: "Ja, ich habe eine Wallbox."

Agent [HW Confirm Tariff Change  <- only against the proposal number it was issued]:
  "Der Wechsel wurde durchgeführt. Referenz: Fall 00001031."
  -> Service_Contract__c really switched · Tariff_Change_Request__c marked Applied
  -> Case opened by the EinsteinServiceAgent User · Tariff_Change_Requested__e published
```

**Same question, a different customer, the opposite answer.** Studio Alpina (165 kWh/month)
is told to switch to **Strom Basis**, *not* the EV tariff — because below the 375 kWh/month
break-even the EV tariff's higher base fee makes it more expensive. The € figure is arithmetic
over real `Tariff__c` rows at the customer's real meter readings; no model can invent it.

**And consent is not a Boolean the model fills in.** It is a server-issued, expiring,
account-scoped request number (`TCR-00001`) that exists only in the propose step's output. A
model that skipped the step, invented a number, or replayed *another customer's* number is
refused — and **zero DML runs**. See [ADR-020](docs/adr/ADR-020-tariff-advisory-consent-handshake.md).

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

Full, honest built-vs-planned matrix: **[`STATUS.md`](./STATUS.md)**. Summary:

| Phase | Theme | Status |
|------|-------|--------|
| **Faz 1** | **Service Cloud core** (7 objects/37 fields, Case RTs, SLA design, Omni-Channel, 10 Knowledge articles, perms, multi-currency, seed) | ✅ **built** |
| **Faz 2** | **Data 360** — 4 data streams → DLOs; anomaly grounded live via the Query API (**+64.6 %**) | ✅ **built** |
| **Faz 5** | **Live agent** — `HW_Energy_Agent` + **7 grounded actions** (identify · bill · explain · create-case · answer-from-Knowledge · **propose-tariff** · **confirm-tariff**) + service layer + 74 tests (**97 % coverage**); multi-turn flow, GROUNDED, incl. German | ✅ **built** |
| **Grounding split (ADR-007)** | *figures* → Data 360 (**+64.6 %**) · *procedure* → a **cited Knowledge article** (deterministic Apex retriever; live-verified: "I'm moving house" → Umzug article + citation) | ✅ **built** |
| 🟡 | live SLA milestone clock (edition-blocked) | partial (see STATUS.md) |
| ⬜ | Identity resolution · persisted CI + segments/closed loop · LWC UI · escalation action (Omni-Channel handoff) · prompt templates · agent eval ⭐ · red-team ⭐ · employee agent · DSGVO automation · WhatsApp | planned (designed, not code) |

> Honestly **partial**: the live SLA milestone clock can't bind because `Case.EntitlementId`
> isn't provisioned in this Dev-Edition flavour (edition limitation — see
> [`docs/troubleshooting/`](./docs/troubleshooting/faz1-gate-case-entitlementid.md)).
>
> **On the Knowledge side:** the Agentforce Data Library (Data Cloud RAG index) is not usable
> in this org — the `AiRetriever` metadata type doesn't exist and the index never leaves
> "Not Started". Procedure grounding is therefore delivered by a **deterministic Apex
> retriever** (`HWKnowledgeService`): one query over the 10-article corpus, in-memory scoring
> with a German→English alias map, and **no result rather than a wrong article** below the
> threshold. It is free, unit-tested, source-controlled, and cannot hallucinate a citation.
> A vector Data Library remains the production path for a large corpus (ADR-007).

### What's built (this repo, deployed + committed)

| Layer | Components |
|------|-----------|
| Service Cloud core | 7 objects + 37 fields (`Meter__c`, `Meter_Reading__c`, `Tariff__c`, `Service_Contract__c`, `Energy_Bill__c`, `Outage__c`, `Consent__c`) + `Case.HW_Topic__c` · 5 Case record types + support process · `HW_Standard_SLA` entitlement + milestones · Omni-Channel (channel, queue, routing, presence, German + Billing skills) · 6-topic Knowledge with 10 published articles · `HW_Admin`/`HW_ServiceAgent`/`HW_ReadOnly` perms · EUR + CHF · 4 DACH seed accounts |
| Data 360 | 4 DataStreamDefinitions (Account, Meter, Meter Reading, Energy Bill) → DLOs · anomaly proven live via the Data 360 Query API (SQL CI): **520 vs 316 kWh = +64.6 %** |
| Live agent (Faz 5) | `HW_Energy_Agent` (Bot + ReAct planner + 2 topics) · **5** grounded `@InvocableMethod` actions (`HWIdentifyCustomerAction`, `HWGetLatestBillAction`, `HWExplainConsumptionAction`, `HWCreateCaseAction`, `HWAnswerFromKnowledgeAction`) · **5** services (`with sharing`, `WITH USER_MODE`, bulk-safe) · `HW_Agent_Actions` perms · 10 test classes / 49 methods (99 % org-wide coverage, every class ≥ 94 %) · NGA design bundle (`HW_Service_Agent.agent`, committed as design — runtime edition-blocked) |
| Procedure grounding | `HWKnowledgeService` + `HWAnswerFromKnowledgeAction` — deterministic Knowledge retriever with a DE→EN alias map; the agent answers how-to questions **only** from the article text and quotes a real citation (`… (000001008)`), or says it doesn't know and offers a case |

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
force-app/             ✅ core sObjects, Service Cloud config, perms, Knowledge, data
                          categories — AND the live agent metadata (bots/,
                          genAiPlannerBundles/, genAiPlugins/, genAiFunctions/,
                          aiAuthoringBundles/), where the CLI created it
force-app-services/    ✅ 6 HW…Service classes (customer, billing, consumption, case, knowledge, tariff)
force-app-actions/     ✅ 7 @InvocableMethod agent actions (HW…Action)
force-app-datacloud/   ✅ Data 360 DataStreamDefinitions (4)
force-app-tests/       ✅ Apex tests (13 classes / 74 methods · 97% coverage)
force-app-handlers/    ⬜ trigger handlers (Kevin O'Hara) — reserved, empty
force-app-agent/       ⬜ reserved package (agent metadata currently lives in force-app/)
force-app-lwc/         ⬜ hwConsumptionChart, hwAgentConsole — reserved, empty
docs/                  adr · architecture · demo · manual-setup · research · troubleshooting
scripts/               anonymous Apex (seed_demo_data, seed_knowledge, datacloud_query, verify_gate)
```

> The "8 packages" is a deliberate forward-looking layout; three packages
> (`handlers`, `agent`, `lwc`) are reserved scaffolding for the planned work in
> [`STATUS.md`](./STATUS.md), not claimed as built.

## Run it

```bash
sf org login web --alias hansewatt
# deploy the built packages (core + services + actions + Data 360 + tests)
sf project deploy start \
  --source-dir force-app --source-dir force-app-services --source-dir force-app-actions \
  --source-dir force-app-datacloud --source-dir force-app-tests --target-org hansewatt
sf apex run --file scripts/seed_demo_data.apex --target-org hansewatt
sf apex run --file scripts/seed_knowledge.apex --target-org hansewatt

# verify the Apex layer (10 test classes, 49 methods, 99% org-wide coverage)
sf apex run test --code-coverage --result-format human --wait 15 --target-org hansewatt
```

## License

Proprietary — All rights reserved. © 2026 Mustafa Aksu. Shared for portfolio and
evaluation purposes only.

> **Honest framing:** external systems (smart-meter MDM, SAP IS-U billing) are simulated;
> the Salesforce code paths, the agent, the Data 360 model, and grounding are real.
