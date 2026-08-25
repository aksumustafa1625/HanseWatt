# HanseWatt — Agentforce Service Cloud + Data 360 (DACH Energy)

> **Project Blueprint / Draft v0.1** — the planning document for the next portfolio
> project. This is the broad design surface; it will later split into `CLAUDE.md`
> (session guide), ADRs, and a README once the org is live and the first phase ships.
>
> **Author:** Mustafa Aksu · mustafaaksu.dev
> **Status:** DRAFT — not yet built. Org signup in progress (Developer Edition with
> Agentforce + Data 360).
> **Created:** 2026-06-20

---

## 0. One-paragraph pitch

**HanseWatt GmbH** is a fictional Hamburg-based DACH energy retailer (Energieversorger).
This project builds its **AI-powered customer service platform** on Salesforce:
a **Service Cloud** core (Cases, Knowledge in German, Omni-Channel, SLA Entitlements),
a **Data 360** (Data Cloud) layer that ingests smart-meter consumption and billing data
and unifies it into a single customer profile, and an **autonomous Agentforce Service
Agent** that — grounded in that unified data plus a German knowledge base — answers
customer questions ("Why is my bill so high?"), explains consumption anomalies, opens
SLA-bound Cases, initiates tariff changes, and escalates to a human when it cannot
resolve. The whole flow is GDPR/DSGVO-compliant and runs under the Einstein Trust Layer.

**Why it matters for the portfolio:** it covers the single hottest 2026 DACH skill
stack — **Agentforce + Data 360 + Service Cloud** — which none of the existing projects
(TechnoStore = Revenue/Q2C, Configra = ISV/RLM, Urla Shoes = multi-feature/Einstein)
demonstrate. It deliberately complements rather than repeats them.

---

## 1. Project identity

| Field                 | Value                                                                                                         |
| --------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Project name**      | HanseWatt                                                                                                     |
| **Fictional company** | HanseWatt GmbH — DACH energy retailer (Strom + Gas), HQ Hamburg                                               |
| **Type**              | Salesforce DX portfolio project (not an ISV package)                                                          |
| **Primary clouds**    | Service Cloud + Agentforce + Data 360 (Data Cloud)                                                            |
| **Supporting**        | Einstein (Prompt Builder + Trust Layer), Experience Cloud (optional portal), MuleSoft (integration narrative) |
| **UI architecture**   | Standard Lightning + LWC where custom UI is needed (no OmniStudio)                                            |
| **API version**       | 64.0 (confirm against the new org's default after signup)                                                     |
| **Org type**          | Developer Edition with Agentforce and Data 360 (free, non-expiring if used every 45 days)                     |
| **Target market**     | DACH (Germany / Austria / Switzerland) — energy + utilities                                                   |
| **Language**          | Agent + Knowledge in **German**; code/comments/docs in English                                                |
| **Goal**              | Portfolio evidence for a Salesforce **Service Cloud + AI (Agentforce) + Data Cloud** role in DACH             |

### Naming conventions

```
Apex classes        : HW prefix              (HWBillingService, HWConsumptionAgentAction)
Agent actions (Apex): HW...AgentAction       (@InvocableMethod, Agentforce-callable)
Test classes        : ...Test suffix         (HWBillingServiceTest)
Custom objects      : HW__ namespace-free    (Meter__c, Meter_Reading__c, Tariff__c)
Permission sets     : HW_ prefix             (HW_ServiceAgent, HW_Admin, HW_ReadOnly)
LWC components      : hw camelCase           (hwConsumptionChart, hwAgentTranscript)
Data 360 DLO/DMO    : HW_ prefix where custom
Prompt Templates    : HW_ prefix             (HW_BillExplanation, HW_CaseSummary)
```

---

## 2. Why this project (market rationale)

The German Salesforce market in 2026 hires aggressively for **Agentforce + Data Cloud**
on the **service / customer-engagement** side — Stadtwerke, E.ON/EnBW-class utilities,
Telekom, insurers, public sector. Job specs repeatedly ask for:

- **Agentforce**: agent design (Topics, Actions, Instructions), grounding, Trust Layer,
  testing, deployment.
- **Data Cloud / Data 360**: ingestion (Data Streams), harmonization (DLO → DMO),
  identity resolution, Calculated Insights, Segments, activation.
- **Service Cloud**: Case lifecycle, Knowledge, Omni-Channel routing, Entitlements/SLA.
- **Integration + compliance**: MuleSoft, GDPR/DSGVO, German-language support.

This project is built to be **defendable in a DACH technical interview** — every design
choice has business reasoning, governor-limit awareness, test coverage, and an ADR.

### How it complements the existing portfolio

| Project              | Axis it proves                                   | Cloud                               |
| -------------------- | ------------------------------------------------ | ----------------------------------- |
| **TechnoStore**      | Quote-to-Cash, 8 integrations, MuleSoft, SAP     | Revenue Cloud (RLM/CLM/CPQ)         |
| **Configra**         | ISV / AppExchange, pure-LWC packaging            | RLM (ISV)                           |
| **Urla Shoes**       | Multi-feature breadth, Einstein prompt templates | Platform + Einstein                 |
| **HanseWatt (this)** | **Autonomous AI agents, unified data, service**  | **Service + Agentforce + Data 360** |

No overlap. Together they read as a senior generalist with a Revenue **and** Service +
AI specialization — exactly the DACH enterprise profile.

---

## 3. Business scenario

### Company

**HanseWatt GmbH** supplies electricity and gas to ~250k residential and SME customers
across Germany, with smaller books in Austria and Switzerland. Customers have smart
meters that report consumption; billing runs monthly. The contact center is overwhelmed
with repetitive "why is my bill high / when is my next reading / I'm moving house"
inquiries — the classic case for an autonomous AI agent grounded in real consumption data.

### Personas

| Persona                         | Role                 | What they touch                                                                                           |
| ------------------------------- | -------------------- | --------------------------------------------------------------------------------------------------------- |
| **Lena (Kundin)**               | Residential customer | Chats with the Agentforce agent (web + WhatsApp), reads bills, requests tariff change / Umzug (move)      |
| **Jonas (Service-Mitarbeiter)** | Contact-center agent | Picks up escalated Cases via Omni-Channel; uses an _employee_ agent + Prompt Templates for case summaries |
| **Petra (Teamleiterin)**        | Service team lead    | SLA dashboards, agent-deflection analytics                                                                |
| **Admin / Architect (you)**     | Builder              | Designs the agent, Data 360 model, flows                                                                  |

### Demo accounts (DACH spread)

| Account                  | City    | Country | Segment     | Story hook                                                 |
| ------------------------ | ------- | ------- | ----------- | ---------------------------------------------------------- |
| Lena Bergmann            | Hamburg | DE      | Residential | Consumption spike (new EV charger) → "why is my bill high" |
| Familie Huber            | Wien    | AT      | Residential | Move-out (Umzug) request                                   |
| Müller Maschinenbau GmbH | Köln    | DE      | SME         | High-usage SME, tariff renewal due                         |
| Studio Alpina            | Zürich  | CH      | Residential | Outage (Störung) inquiry + CHF billing                     |

---

## 4. The end-to-end demo narrative (the "wow" flow)

The single coherent story a recruiter watches in ~10 minutes — HanseWatt's equivalent of
TechnoStore's Quote-to-Cash recording.

```
Lena opens the HanseWatt web chat (German):
  "Warum ist meine Stromrechnung diesen Monat so hoch?"
        │
        ▼
[Agentforce Service Agent]  (Topic: Billing/Consumption Inquiry)
  1. Identifies Lena (deterministic + Data 360 unified profile)
  2. Action: GetLatestBill  → returns € amount + period
  3. Action: ExplainConsumptionAnomaly
        → reads Data 360 Calculated Insight (avg vs current kWh, anomaly score)
        → "Your usage rose 62% vs your 6-month average, mostly evenings —
            consistent with EV charging."
  4. Grounds the explanation in a German Knowledge article (Trust Layer citation)
        │
        ├── Resolvable?  → Agent offers a cheaper EV tariff (Action: ProposeTariff),
        │                  Lena accepts → Action: InitiateTariffChange creates a Case +
        │                  Order/Contract change, sends confirmation email (German).
        │
        └── Not resolvable / Lena frustrated → Agent escalates:
                 Action: EscalateToHuman → creates SLA-bound Case (Entitlement +
                 Milestone), routed via Omni-Channel to Jonas.
                          │
                          ▼
                 Jonas opens the Case → Prompt Template HW_CaseSummary
                 generates a German summary of the chat + consumption context.
                 He resolves; Milestone met; CSAT survey fires.
        │
        ▼
[Data 360 closes the loop]
  - The chat + case + consumption become engagement data back in Data 360.
  - A Segment ("high-consumption-anomaly, no tariff change in 30d") activates a
    proactive outreach journey — the system reaches out BEFORE the next bill shock.
```

**Three demo beats that sell it:**

1. **Grounded, not hallucinated** — the agent's bill explanation is backed by a real
   Data 360 Calculated Insight + a cited Knowledge article (show the Trust Layer).
2. **Autonomous action** — it doesn't just chat, it _creates records_ (Case, tariff
   change) via Apex Actions, with proper escalation.
3. **Closed loop** — service interactions feed Data 360, which proactively prevents the
   next complaint.

---

## 5. Architecture overview

```
                         ┌─────────────────────────────────────────┐
                         │            Customer channels             │
                         │  Web chat · WhatsApp · (Experience Cloud)│
                         └───────────────────┬─────────────────────┘
                                             │
                              ┌──────────────▼───────────────┐
                              │   Agentforce Service Agent    │
                              │  Topics · Actions · Instr.    │
                              │  ── Einstein Trust Layer ──   │
                              └───┬───────────────┬───────────┘
                  grounding (RAG) │               │ actions (@InvocableMethod / Flow)
                  ┌───────────────▼──┐         ┌──▼──────────────────────────────┐
                  │  Retrievers      │         │ Apex Action layer (HW...Action) │
                  │  · Knowledge(DE) │         │ GetLatestBill · ExplainAnomaly  │
                  │  · Data 360 DMO  │         │ CreateCase · InitiateTariff ··· │
                  └───────────────┬──┘         └──┬──────────────────────────────┘
                                  │               │
        ┌─────────────────────────▼───────────────▼─────────────────────────┐
        │                       Salesforce core (Service Cloud)              │
        │  Account · Contact · Case · Knowledge · Entitlement/Milestone      │
        │  Omni-Channel routing · custom: Meter__c · Tariff__c · Contract    │
        └─────────────────────────┬──────────────────────────────────────────┘
                                  │  ingest / harmonize / identity-resolve
        ┌─────────────────────────▼──────────────────────────────────────────┐
        │                        Data 360 (Data Cloud)                        │
        │  Data Streams → DLOs → DMOs → Identity Resolution → Unified Profile  │
        │  Calculated Insights (avg kWh, anomaly score, churn risk)           │
        │  Segments → Activations (proactive journeys / Flow)                 │
        └─────────────────────────┬──────────────────────────────────────────┘
                                  │  external ingestion (MuleSoft / Ingestion API)
        ┌─────────────────────────▼──────────────────────────────────────────┐
        │  External systems (simulated): Smart-meter MDM · SAP IS-U billing   │
        │  · web/engagement events                                            │
        └─────────────────────────────────────────────────────────────────────┘
```

**Data flow principle:** Channels → Agentforce (Trust Layer) → grounds on Knowledge +
Data 360, acts via Apex Actions on Service Cloud records → service data flows back into
Data 360 → Segments drive proactive engagement. One closed loop.

---

## 6. Capability pillars

| #       | Pillar                                  | What it proves                                                 |
| ------- | --------------------------------------- | -------------------------------------------------------------- |
| **P1**  | Service Cloud core                      | Case lifecycle, Knowledge (DE), Omni-Channel, Entitlements/SLA |
| **P2**  | Data 360 ingestion & harmonization      | Data Streams, DLO→DMO mapping, Ingestion API                   |
| **P3**  | Identity resolution & unified profile   | Match/reconcile rules, Unified Individual                      |
| **P4**  | Calculated Insights & Segments          | kWh trend, anomaly score, churn risk; segment activation       |
| **P5**  | Agentforce agent                        | Topics, Actions, Instructions, grounding, testing              |
| **P6**  | Einstein Prompt Templates + Trust Layer | Bill explanation, case summary; masking/grounding              |
| **P7**  | Integration                             | MuleSoft / Ingestion API for meter + billing feeds             |
| **P8**  | DSGVO / GDPR compliance                 | consent, RtbF, audit, data-residency narrative                 |
| **P9**  | Analytics                               | Agent deflection rate, SLA, CSAT dashboards                    |
| **P10** | Documentation & demo                    | ADRs, diagrams, Notion STAR entries, recording                 |

---

## 7. Data model

### 7.1 Custom objects (Salesforce core)

| Object                | Purpose                                        | Key fields                                                                                                                     |
| --------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `Meter__c`            | Smart meter device                             | `Serial__c`, `Type__c` (Strom/Gas), `Account__c`, `Location__c`, `Installed_On__c`, `External_Meter_Id__c`                     |
| `Meter_Reading__c`    | Periodic consumption (also flows via Data 360) | `Meter__c`, `Read_Date__c`, `kWh__c`, `Source__c` (Smart/Manual), `Is_Estimated__c`                                            |
| `Tariff__c`           | Available tariffs/plans                        | `Name`, `Type__c` (Strom/Gas), `Price_per_kWh__c`, `Base_Fee__c`, `Green__c`, `Currency__c`                                    |
| `Service_Contract__c` | Customer's active tariff contract              | `Account__c`, `Tariff__c`, `Start__c`, `End__c`, `Status__c`, `Meter__c`                                                       |
| `Energy_Bill__c`      | Monthly bill                                   | `Account__c`, `Contract__c`, `Period_Start__c`, `Period_End__c`, `Amount__c`, `Consumption_kWh__c`, `Currency__c`, `Status__c` |
| `Outage__c`           | Network outage / Störung                       | `Region__c`, `Start__c`, `End__c`, `Status__c`, `Cause__c`                                                                     |

> Some of these (readings, bills) are _also_ ingested into Data 360 from external systems;
> the SF custom objects hold the demo-local copy and the action-write targets. The ADRs
> will document the "system of record" boundary per object.

### 7.2 Standard objects used

- `Account` (Geschäftspartner / customer), `Contact`
- `Case` (+ record types: Billing / Consumption / Move / Outage / Complaint)
- `Knowledge__kav` (German articles, data categories by topic)
- `Entitlement` + `Milestone` (SLA)
- `Messaging` objects (Messaging Session/EndUser) for web + WhatsApp channels
- `User`, `ServiceResource` (for Omni-Channel routing)

### 7.3 ERD sketch

```
Account ──< Contact
   │
   ├──< Meter__c ──< Meter_Reading__c
   ├──< Service_Contract__c ──> Tariff__c
   │           └──> Meter__c
   ├──< Energy_Bill__c ──> Service_Contract__c
   └──< Case ──> Entitlement ──< Milestone
                 └── (Messaging Session, Knowledge linkage)
Outage__c (region-scoped, linked to Account via region/address)
```

---

## 8. Data 360 (Data Cloud) design

### 8.1 Data Streams (ingestion)

| Stream                 | Source                                  | Cadence            | Lands in (DLO)          |
| ---------------------- | --------------------------------------- | ------------------ | ----------------------- |
| Smart-meter readings   | External MDM (Ingestion API / MuleSoft) | hourly/daily batch | `HW_Meter_Reading__dll` |
| Billing                | SAP IS-U (simulated CSV/API)            | monthly            | `HW_Bill__dll`          |
| CRM (Account/Contact)  | Salesforce connector                    | streaming          | standard DLOs           |
| Engagement (chat/case) | Salesforce connector + Web SDK          | streaming          | standard DLOs           |

### 8.2 Harmonization (DLO → DMO)

Map raw DLOs onto Data 360 standard/custom **Data Model Objects**:

- Individual / Contact Point (from Account/Contact)
- `HW_Energy_Usage__dmo` (from meter readings)
- `HW_Billing__dmo` (from bills)
- Engagement DMOs (from chat/case)

### 8.3 Identity resolution

- **Match rules:** exact email + fuzzy name/address; external meter/billing customer id
  → reconcile to the **Unified Individual**.
- **Reconciliation:** most-recent-wins for contact info; source-priority for billing id.
- Output: a single unified profile the agent grounds on, even though billing customer id
  ≠ Salesforce Contact id.

### 8.4 Calculated Insights (the agent's "evidence")

| CI                          | Definition                        | Used by                |
| --------------------------- | --------------------------------- | ---------------------- |
| `Avg_Monthly_kWh`           | trailing 6-month mean per meter   | anomaly explanation    |
| `Consumption_Anomaly_Score` | current vs avg, z-score style     | "why is my bill high"  |
| `Time_of_Day_Profile`       | day vs evening split              | EV-charging hypothesis |
| `Churn_Risk_Score`          | complaints + price delta + tenure | proactive retention    |
| `Customer_Lifetime_Value`   | cumulative billed                 | prioritization/routing |

### 8.5 Segments & Activation

| Segment                  | Rule                                               | Activation                     |
| ------------------------ | -------------------------------------------------- | ------------------------------ |
| High-consumption anomaly | anomaly score > threshold, no tariff change in 30d | proactive email/journey (Flow) |
| Renewal due              | contract end within 45d                            | renewal outreach               |
| Churn risk               | churn score high + recent complaint                | route to retention queue       |

---

## 9. Agentforce design

### 9.1 Agent

- **Type:** Agentforce **Service Agent** (customer-facing, autonomous) — primary.
- **Secondary:** an **Employee/Service-rep agent** (Agentforce for Service reps) for
  Jonas — case summaries, next-best-action.
- **Channels:** web (Messaging for In-App/Web) + WhatsApp (reuse the Twilio learning from
  TechnoStore as a stretch goal).
- **Language:** German primary, English fallback.

### 9.2 Topics

| Topic                  | Scope                           | Sample utterance (DE)                      |
| ---------------------- | ------------------------------- | ------------------------------------------ |
| Billing & Consumption  | explain bills, usage, anomalies | "Warum ist meine Rechnung so hoch?"        |
| Tariff Change          | compare + switch tariffs        | "Gibt es einen günstigeren Tarif?"         |
| Move (Umzug)           | start/stop service at address   | "Ich ziehe um."                            |
| Outage (Störung)       | check outage status by region   | "Bei mir ist der Strom weg."               |
| Contract & Renewal     | terms, renewal, cancellation    | "Wann läuft mein Vertrag aus?"             |
| Complaint / Escalation | dissatisfaction → human handoff | "Ich will mit einem Mitarbeiter sprechen." |

### 9.3 Actions (Apex `@InvocableMethod` + Flow)

| Action                         | Type      | Reads / writes                             |
| ------------------------------ | --------- | ------------------------------------------ |
| `HWGetLatestBillAction`        | Apex      | reads `Energy_Bill__c`                     |
| `HWExplainConsumptionAction`   | Apex      | reads Data 360 CI (anomaly + profile)      |
| `HWProposeTariffAction`        | Apex      | reads `Tariff__c`, ranks by usage          |
| `HWInitiateTariffChangeAction` | Apex      | writes Case + `Service_Contract__c` change |
| `HWCheckOutageAction`          | Apex      | reads `Outage__c` by region                |
| `HWStartMoveAction`            | Flow      | creates Move Case + tasks                  |
| `HWCreateCaseAction`           | Apex      | creates SLA-bound Case (Entitlement)       |
| `HWEscalateToHumanAction`      | Apex/Flow | sets Case for Omni-Channel routing         |
| `HWScheduleCallbackAction`     | Flow      | books a callback slot                      |

> All Apex actions: `with sharing`, `WITH USER_MODE` on SOQL, `as user` on DML where the
> running user is the customer/agent context; bulk-safe; no DML-in-loop; full test coverage.

### 9.4 Grounding

- **Knowledge retriever** over German `Knowledge__kav` (data categories per topic).
- **Data 360 retriever** over the unified profile + Calculated Insights.
- Citations surfaced so the demo can show _where_ an answer came from.

### 9.5 Instructions (guardrails)

- Always identify the customer before disclosing bill/consumption data.
- Never invent figures — only state numbers returned by an Action or CI.
- Respond in the customer's language (DE default).
- Escalate on: explicit human request, repeated dissatisfaction, payment disputes,
  anything touching personal data deletion (route to DSGVO process).

### 9.6 Testing

- **Agentforce Testing Center** test cases per topic (utterance → expected topic/action).
- Apex tests for every Action class.
- Adversarial prompts (jailbreak, off-topic, PII-fishing) documented as test evidence.

---

## 10. Service Cloud setup

- **Case** record types + a German support process; auto-response rules in German.
- **Knowledge**: German articles, data-category structure mirroring agent topics;
  article → case attach; used as grounding source.
- **Omni-Channel**: routing config, presence statuses, a service queue for escalations;
  skills-based routing (language, topic).
- **Entitlements + Milestones**: SLA per Case record type (e.g. First Response 4h,
  Resolution 2 business days); Milestone tracker on the Case page.
- **CSAT**: post-resolution survey (simple flow + custom object or standard).

---

## 11. Einstein / Prompt Templates

| Template             | Type                   | Use                                                       |
| -------------------- | ---------------------- | --------------------------------------------------------- |
| `HW_BillExplanation` | Flex/Sales-email style | Drafts the German bill-anomaly explanation grounded in CI |
| `HW_CaseSummary`     | Record summary         | German summary of chat + consumption for the rep          |
| `HW_KnowledgeDraft`  | Field generation       | Drafts/updates Knowledge articles from resolved cases     |

All run through the **Trust Layer** (PII masking, toxicity, grounding, audit). Deployed as
`GenAiPromptTemplate` metadata (reuse the lesson from Urla Shoes that prompt templates are
deployable).

---

## 12. Integration layer

- **Ingestion**: smart-meter readings + SAP IS-U billing into Data 360 via the
  **Ingestion API** (and/or MuleSoft as the orchestration narrative — reuse TechnoStore's
  Mule story). Honest framing: external systems simulated, code paths real.
- **Outbound**: tariff-change confirmation email (German, Org-Wide Email Address — reuse
  TechnoStore's deliverability lesson), optional WhatsApp confirmation.
- **ADR** will document Ingestion API vs MuleSoft vs Connector per feed.

---

## 13. DSGVO / GDPR compliance

- **Consent** capture on Account/Contact + Data 360 consent DMO.
- **Right to be Forgotten**: Apex/Flow tool that deletes/anonymizes across SF + requests
  Data 360 deletion; audit via Platform Event.
- **Data residency narrative**: EU operating focus; document Hyperforce EU.
- **Agent guardrail**: any deletion/data-subject request → routed to the DSGVO process,
  never handled inline by the LLM.
- Reuse TechnoStore's GDPR roadmap thinking; here it becomes a built feature.

---

## 14. Security model

| Object                | OWD                          | Notes                     |
| --------------------- | ---------------------------- | ------------------------- |
| `Meter__c` / readings | Private/Controlled by Parent | customer-scoped           |
| `Energy_Bill__c`      | Private                      | customer-scoped           |
| `Service_Contract__c` | Private                      |                           |
| `Outage__c`           | Public Read                  | non-personal network data |

**Permission sets:** `HW_ServiceAgent`, `HW_Admin`, `HW_ReadOnly`, plus a guest/automated
context for ingestion. All Apex `with sharing`; user-facing flows `WITH USER_MODE` + DML
`as user`; privileged ingestion stays system mode (documented).

---

## 15. SFDX repository structure (planned)

```
HanseWatt/
├── sfdx-project.json                 # multi-package, mirrors TechnoStore discipline
├── force-app/                        # core sObjects, Service Cloud config, flows, perms
├── force-app-services/               # HWBillingService, HWConsumptionService, ...
├── force-app-actions/                # Agentforce @InvocableMethod actions (HW...Action)
├── force-app-handlers/               # trigger handlers (Kevin O'Hara framework)
├── force-app-agent/                  # Agentforce metadata (Bot/GenAiPlanner/Topics/Actions)
├── force-app-datacloud/              # Data 360 metadata (DataStream/DLO/DMO/CI/Segment)
├── force-app-lwc/                    # hwConsumptionChart, hwAgentTranscript, ...
├── force-app-tests/                  # Apex test classes
├── docs/
│   ├── adr/                          # Architecture Decision Records
│   ├── architecture/                 # Mermaid diagrams
│   └── SOLUTION_BLUEPRINT.md         # arc42 (later)
├── scripts/                          # anonymous Apex setup + seed data (gitignored secrets)
├── config/                           # scratch/dev-org definition
└── README.md
```

> Note: some Data 360 + Agentforce config is click-heavy and not fully source-trackable;
> the repo captures what is retrievable as metadata and documents the manual setup in
> `docs/` + ADRs (honest framing, like TechnoStore's "demo verified" discipline).

---

## 16. Phased delivery plan

Each phase ships independently and ends in a committable, demoable state.

| Phase   | Theme                          | Deliverables                                                                             | Exit criteria                                 |
| ------- | ------------------------------ | ---------------------------------------------------------------------------------------- | --------------------------------------------- |
| **P0**  | Org + foundations              | Org signup, SFDX init, package dirs, CLAUDE.md, base perms                               | `sf` deploys; org reachable                   |
| **P1**  | Service Cloud core             | Custom objects + fields, Case record types, German Knowledge, Omni-Channel, Entitlements | A Case routes + meets SLA end-to-end          |
| **P2**  | Data 360 ingestion             | Data Streams, DLOs, DMO mapping for meter + billing                                      | External data visible in Data 360             |
| **P3**  | Identity + unified profile     | Match/reconcile rules, Unified Individual                                                | One unified profile across sources            |
| **P4**  | Calculated Insights + Segments | CIs (avg/anomaly/churn), 2-3 segments + activation                                       | CI values queryable; segment activates a flow |
| **P5**  | Agentforce agent               | Agent + topics + Apex actions + grounding                                                | Agent answers "why is my bill high" grounded  |
| **P6**  | Prompt Templates + Trust Layer | HW_BillExplanation, HW_CaseSummary; masking/grounding shown                              | Templates run live under Trust Layer          |
| **P7**  | Escalation + employee agent    | EscalateToHuman → Omni-Channel → rep agent summary                                       | Full hand-off demo works                      |
| **P8**  | Integration                    | Ingestion API / MuleSoft feed, outbound confirmations                                    | Meter feed lands automatically                |
| **P9**  | DSGVO                          | Consent + RtbF tool + agent guardrail                                                    | RtbF removes/anonymizes a subject             |
| **P10** | Analytics                      | Deflection / SLA / CSAT dashboards                                                       | Dashboard reads real demo data                |
| **P11** | Docs + recording               | ADRs, diagrams, Notion STAR, ~10-min recording                                           | Portfolio-ready                               |

**Suggested first working session after org is live:** P0 + start P1.

---

## 17. Testing strategy

- **Apex**: every service + action class ≥ 80% with `HttpCalloutMock` for ingestion;
  trigger handlers tested through DML.
- **Agentforce Testing Center**: per-topic test suites (utterance → topic/action).
- **Trust Layer evidence**: capture masking + grounding in screenshots for the portfolio.
- **Adversarial**: documented jailbreak/off-topic/PII-fishing attempts and the agent's
  refusals/escalations.

---

## 18. ADR catalogue (planned)

| ADR | Decision                                                             |
| --- | -------------------------------------------------------------------- |
| 001 | Service + Agentforce + Data 360 scope (vs Field Service alternative) |
| 002 | Agentforce Service Agent vs custom LLM/Apex orchestration            |
| 003 | Data 360 system-of-record boundary (which data lives where)          |
| 004 | Ingestion API vs MuleSoft vs Connector per feed                      |
| 005 | Identity resolution match/reconcile rule design                      |
| 006 | Apex `@InvocableMethod` actions vs Flow actions for the agent        |
| 007 | Grounding sources: Knowledge + Data 360 retriever split              |
| 008 | German-language + Trust Layer guardrail policy                       |
| 009 | DSGVO RtbF across SF + Data 360                                      |
| 010 | Multi-currency (EUR/CHF) handling for AT/CH accounts                 |

(Michael Nygard format, immutable once accepted — same discipline as TechnoStore.)

---

## 19. Demo recording plan

~10-minute single narrative (section 4), recorded once P1–P7 are live:

1. Customer asks in German → grounded answer (show Trust Layer citation).
2. Autonomous action (tariff change creates records).
3. Escalation → Omni-Channel → rep agent case summary.
4. Data 360 closed loop → proactive segment outreach.
5. 30-second "production gap" honesty statement (external systems simulated, code real).

---

## 20. Portfolio positioning / interview talking points

- _"I built an autonomous Agentforce service agent grounded in Data 360 — it explains
  bills from real calculated insights, acts on records, and escalates safely under the
  Trust Layer, all GDPR-compliant and in German."_
- Talk tracks ready: agent topic/action design; Data 360 identity resolution; CI vs
  segment; grounding & hallucination control; SLA/Omni-Channel; DSGVO RtbF across systems.
- Publishes as Notion STAR entries + ADRs + diagrams (reuse TechnoStore's documentation
  pipeline).

---

## 21. Roadmap / future

- **Experience Cloud** self-service portal (bill history + agent embedded).
- **Field Service** dispatch for physical meter faults (extends Outage__c).
- **Proactive outage comms** via segments + journeys.
- **Multi-agent** (billing agent + retention agent collaborating).
- **Voice** channel (Agentforce + Service Cloud Voice) — stretch.

---

## 22. Glossary

| Term                | Meaning                                                                    |
| ------------------- | -------------------------------------------------------------------------- |
| Data 360            | New name for Salesforce Data Cloud                                         |
| DLO / DMO           | Data Lake Object / Data Model Object (Data 360 ingest vs harmonized layer) |
| CI                  | Calculated Insight (Data 360 aggregate metric)                             |
| Identity Resolution | Unifying records from many sources into one profile                        |
| Topic / Action      | Agentforce units: what the agent can discuss / what it can do              |
| Grounding           | Feeding the LLM real, cited data (Knowledge + Data 360)                    |
| Trust Layer         | Einstein's masking / grounding / toxicity / audit guardrails               |
| Energieversorger    | German for energy retailer/utility                                         |
| Störung / Umzug     | Outage / Move (house) — common service topics                              |
| DSGVO               | German GDPR                                                                |

---

_Draft v0.1 — to be split into CLAUDE.md + README + ADRs once the org is live and P0/P1
ship. Honest-framing rule inherited from TechnoStore: external systems may be simulated;
the Salesforce code paths and agent are real._
