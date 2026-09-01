# TechnoStore — Project Summary (COMPLETED reference project)

> Companion document to `PROJECT_BLUEPRINT.md`. This is the **finished** portfolio
> project that HanseWatt is designed to complement. It captures _what TechnoStore is_,
> _what was built and verified_, and _which patterns/lessons carry over_ — so the new
> project can reuse the hard-won discipline without repeating the scope.
>
> **Status:** ✅ COMPLETE — demo-verified, recording-ready. Must NOT be touched further.
> **Org:** `hansewatt-demo@example.com` (separate from HanseWatt / Configra orgs).
> **Created (this summary):** 2026-06-20

---

## 0. One-paragraph identity

**TechnoStore GmbH** is a fictional B2B electronics retailer serving the DACH market
(Germany / Austria / Switzerland) — workstations, peripherals, cables, software licenses
for enterprise IT buyers. The project is a **production-grade Salesforce DX portfolio
build** of TechnoStore's full **Quote-to-Cash (Q2C) lifecycle** on **Revenue Lifecycle
Management (RLM) + Contract Lifecycle Management (CLM) + Industries CPQ**, orchestrated
with **MuleSoft** across **8 external systems**, following the **Kevin O'Hara trigger
framework** in a **six-package SFDX layout**. It is not a feature inventory — it is one
coherent Q2C narrative flowing through 8 systems in real time, recorded as a ~12-minute
demo and documented as a **50-entry STAR-format Notion portfolio**.

**Axis it proves:** Revenue Cloud + enterprise integration architecture.
**What HanseWatt adds (the gap):** Service Cloud + Agentforce + Data 360.

---

## 1. Business scenario

TechnoStore GmbH sells to DACH enterprise IT. The catalog is **account-context-aware** —
a 50-employee customer in Köln sees only the Entry-tier workstation, while a 1200-employee
enterprise in Frankfurt sees four tiers including Mission-Critical Xeon-class machines.

| Demo account             | City      | Industry           | Employees | Visible tiers                             |
| ------------------------ | --------- | ------------------ | --------- | ----------------------------------------- |
| Hamburg DataWorks        | Hamburg   | Technology         | 200       | Entry + Standard + Pro + Mission-Critical |
| München Industrial GmbH  | Munich    | Manufacturing      | 350       | Entry + Standard + Pro                    |
| Frankfurt FinTech Hub AG | Frankfurt | Financial Services | 1200      | Entry + Standard + Pro + Mission-Critical |
| Köln Retail Cloud SE     | Cologne   | Retail             | 50        | Entry tier only                           |

**DACH specifics baked in:** 19% VAT (DE), DHL shipping preference, DE/AT/CH address
handling, German-language customer-facing emails, EUR/CHF awareness.

---

## 2. The end-to-end Quote-to-Cash flow (the demo narrative)

~12 minutes from rep click to delivery:

```
Browse Catalog (account-filtered via Product Qualification)
   └ Bundle Configure (RAM / SSD / GPU attribute pricing)
      └ Quote (19% VAT shown via formula fields)
         └ Order activation
            ├── JIRA ticket            (Apex direct callout)
            ├── Slack #warehouse       (Platform Event → MuleSoft)
            ├── DocuSign envelope      (Apex + Named Credential)
            ├── Stripe PaymentIntent   (MuleSoft outbound)
            └── Orange INVOICE email   (Flying Saucer VF PDF)
                 └ Customer pays on Stripe-hosted page
                    └ Stripe webhook (HMAC-verified, MuleSoft)
                       ├── Order.Status = Paid
                       ├── Green RECEIPT email
                       ├── Slack #payments-team
                       └── MuleSoft Choice Router:
                            ├── Physical: Sendcloud v3 → DHL → shipping email
                            └── Digital:  License key + welcome email
                               └ Customer signs DocuSign
                                  └ Connect webhook → Contract.Status = Signed
                                     └ Asset created via Autolaunched subflow
```

The integration tool per system follows an explicit **Mule-vs-Apex decision matrix**:
Mule when _integration IS the product_ (fan-out, webhooks, complex transforms); Apex when
_integration SERVES CRM logic_ (trigger callouts, record-bound, one-shot).

---

## 3. What was built — the 8 external integrations

| #   | System                | Tool            | What it does                                                                                   |
| --- | --------------------- | --------------- | ---------------------------------------------------------------------------------------------- |
| 1   | **Stripe**            | MuleSoft        | PaymentIntent (form-encoded outbound) + webhook (HMAC verify + Scatter-Gather fan-out)         |
| 2   | **Sendcloud / DHL**   | MuleSoft        | v3 Orders API (bare-array payload, street splitter, ISO country map) → DHL pickup              |
| 3   | **Slack (×2)**        | MuleSoft        | #warehouse (inventory approval) + #payments-team (Block Kit messages)                          |
| 4   | **DocuSign**          | Apex            | Bidirectional: send envelope (Named Credential) + Connect webhook → Contract signed            |
| 5   | **JIRA**              | Apex            | `@future` callout creating tickets on inventory reject + Done→Activate webhook back            |
| 6   | **Notion**            | Apex            | 50-entry STAR portfolio publisher (multi-call nested-toggle orchestration)                     |
| 7   | **SAP S/4HANA**       | Apex (7 phases) | ATP / Sales Order / Tax / Payment Recon / Material + Customer Master Sync / Event Mesh inbound |
| 8   | **WhatsApp (Twilio)** | Apex REST       | Inbound WhatsApp message → Salesforce Lead in real time                                        |

---

## 4. Major completed sprints (chronological highlights)

### 4.1 Core Q2C + first 5 integrations — ✅

Browse Catalog → Bundle Configure → Quote → Order → Contract+DocuSign → Stripe → Mule
choice (Physical=Sendcloud+DHL | Digital=License). Two-stage branded PDF/email
(orange INVOICE pre-payment → green RECEIPT post-payment). Demo recording produced.

### 4.2 SAP Integration Sprint — ✅ (2026-05-18, one Saturday, 7 phases)

All 7 SAP showcases shipped in a single session against the **SAP API Hub Sandbox**:

| Phase | Showcase                   | SAP endpoint             | Service                                             |
| ----- | -------------------------- | ------------------------ | --------------------------------------------------- |
| 1     | ATP / inventory check      | `API_MATERIAL_STOCK_SRV` | `SapMaterialStockService`                           |
| 2     | Sales Order acknowledgment | `API_SALES_ORDER_SRV`    | `SapSalesOrderService` (platform-event async)       |
| 3     | Tax determination          | `API_DETERMINE_TAX_SRV`  | `SapTaxCalculationService` (SAP → country fallback) |
| 4     | Payment reconciliation     | CAMT.053 (ISO 20022)     | `SapPaymentReconciliationService`                   |
| 5     | Material master sync       | `API_PRODUCT_SRV`        | `SapMaterialMasterSyncService`                      |
| 6     | Customer master sync       | `API_BUSINESS_PARTNER`   | `SapCustomerMasterSyncService`                      |
| 7     | SAP Event Mesh inbound     | CloudEvents 1.0 POST     | `SapEventWebhook` + dispatcher                      |

Shared patterns: **SAP-first / SF-fallback** with the engine path captured in audit fields
(`Status_In_SAP`, `Tax_Engine_Used`, `SAP_Payment_Reference`); **platform-event
indirection** for outbound after commit; one `SAP_Config__c` Custom Setting everywhere.
Only Phase 8 (Invoice → SAP FI full migration, ~4-6 weeks) is left as a documented
production gap (ADR-018).

### 4.3 DACH Finance Integration — ✅ (2026-05-21)

Closes Q2C into German accounting on the standard **Invoice** object:

- **lexoffice** (Lexware Office) — real REST API, **event-driven**: `InvoiceTrigger` on
  `Stripe_Payment_Status__c = Paid` → `@future` → Rechnung auto-created in lexoffice UI.
  Verified live.
- **DATEV** — file-based CSV (SKR04 Buchungsstapel, UTF-8 BOM, German comma/DDMM),
  generated via LWC button for the Steuerberater to import. No DATEV-account dependency
  (closed-by-design: DATEVconnect needs partner registration).

### 4.4 Multi-tier discount approval — ✅

3-tier matrix: 20-30% → Sales Manager; 30-50% → +Finance Director; 50%+ → +VP Sales.
(Salesforce active-process step lock forced a new process API name.)

### 4.5 WhatsApp (Twilio) inbound — ✅ (2026-05-25, 8th integration)

Public Apex REST webhook: secret auth + MessageSid idempotency + email regex extraction →
Lead. Verified with a real WhatsApp message. Honestly labeled a webhook integration (not
"Headless Identity").

---

## 5. Architecture patterns established (reused in HanseWatt)

| Pattern                                            | Description                                                                                                       | Reused for                          |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| **Kevin O'Hara TriggerHandler**                    | One trigger per sObject → handler class; recursion control + bypass API                                           | HanseWatt trigger handlers          |
| **Site + Guest User + Platform Event indirection** | Guest user can't write standard fields → publishes Platform Event → trigger subscriber does DML in system context | inbound webhook pattern             |
| **Async after DML**                                | `Approval.process()` does DML → callouts must be `@future`/Queueable                                              | same governor discipline            |
| **Two-stage PDF/email**                            | Pre-payment orange INVOICE → post-payment green RECEIPT                                                           | branded German comms                |
| **Mule-vs-Apex decision matrix**                   | Mule for fan-out/webhooks/transforms; Apex for record-bound/one-shot                                              | HanseWatt Ingestion API vs Mule ADR |
| **Custom Metadata over native engine**             | `Techno_Attribute_Price_Rule__mdt` + `@future` worked around a broken RLM Pricing Procedure                       | config-as-data discipline           |
| **Org-Wide Email Address**                         | Avoids German B2B spam filters vs consumer Gmail From-header                                                      | HanseWatt outbound email            |
| **Honest framing**                                 | "demo verified" / "local end-to-end" — never claim production traffic                                             | HanseWatt production-gap statement  |
| **Idempotency + audit**                            | `WebhookEventLogger`, `Integration_Error__c`, Integration Health dashboard                                        | HanseWatt ingestion idempotency     |

---

## 6. Technical inventory (what's in the org)

### Six-package SFDX layout

- `force-app/` — sObjects, fields, flows, layouts, sites, approval processes, perms
- `force-app-controllers/` — VF + LWC controllers, REST resources
- `force-app-services/` — external API callout services (Stripe, DocuSign, Sendcloud, JIRA, Slack, Notion, SAP, lexoffice)
- `force-app-handlers/` — Kevin O'Hara handlers + REST webhooks
- `force-app-actions/` — `@InvocableMethod` Flow-callable services
- `force-app-tests/` — Apex tests (CI test-only deploys)
- plus `mulesoft/` (Anypoint Studio project) + `interview-prep/` (228 Q&A)

### Key custom objects / settings

Platform Events (`Inventory_Check_Requested__e`, `DocuSign_Signed__e`, `Order_Activated__e`),
Protected Custom Settings (`Jira_Config__c`, `DocuSign_Config__c`, `SAP_Config__c`,
`Notion_Config__c`, `Lexoffice_Config__c`), Custom Metadata
(`Techno_Attribute_Price_Rule__mdt`), plus extensive custom fields on Order / Contract /
Quote / QuoteLineItem / Invoice / Account / Product2.

### UI

Branded TechnoStore Sales App, Flying Saucer VF PDFs (orange invoice / green receipt /
contract), reusable VF components, 4 custom CLM lifecycle screen flows (Submit / Sign /
Approve / Activate), warehouse approval VF page (separation of duties).

### MuleSoft flows

`stripe-create-paymentintent`, `stripe-webhook-receive` (HMAC + Scatter-Gather),
`sendcloud-create-order-v3`, `slack-payments-notify`, `slack-warehouse-notify`,
`post-payment-fulfillment-router` (Choice: Physical / Digital / Mixed).

---

## 7. Documentation artifacts (portfolio polish — reuse for HanseWatt)

| Artifact                      | What it is                                                                       |
| ----------------------------- | -------------------------------------------------------------------------------- |
| **Notion portfolio**          | 50 STAR-format entries, published via `NotionPublishService.publishEnterprise()` |
| **ADRs**                      | docs/adr/ — Michael Nygard format, contiguous 001-031                            |
| **Architecture diagrams**     | 5 Mermaid diagrams (Context / Container / Q2C Sequence / Data Model / CI-CD)     |
| **OpenAPI specs**             | technostore-webhooks.yaml + technostore-mule.yaml                                |
| **Postman collection**        | 17 requests across 8 folders                                                     |
| **Solution Blueprint**        | docs/SOLUTION_BLUEPRINT.md — arc42, 12 sections, 626 lines                       |
| **Copado integration plan**   | Honest "not currently on Copado" production-scaling migration path               |
| **GitHub professional setup** | README + LICENSE (proprietary) + CONTRIBUTING + CI (PMD + scratch-org tests)     |

This documentation pipeline (Notion + ADRs + diagrams + arc42) is itself a reusable asset —
HanseWatt should mirror it.

---

## 8. Hard-won lessons (gotchas worth remembering)

- **RLM Pricing Procedure** registered 0 steps despite valid metadata (Builder UI bug,
  ~6h) → Custom Metadata + `@future` workaround with 1:1 schema parity to native.
- **commercetax adapter only fires at Invoice** (not Quote) → Quote VAT shown via 4
  formula fields; Invoice keeps the full adapter for legal tax.
- **Flying Saucer can't render emoji/unicode** → PNG logo via Static Resource.
- **Guest User can't write `Contract.Status`** (FLS) → Platform Event indirection.
- **Dev Edition Site limit** blocks new Sites → reuse one shared webhook Site (renaming
  its label auto-renames the guest user, cleaning Created By on all webhook records).
- **Twilio sends form-urlencoded** → on Sites the body lands in `RestRequest.params`
  (requestBody empty); code merges params + raw-body parse.
- **New fields need permission-set FLS for SOQL reads** (Apex DML bypasses FLS, SOQL
  doesn't).
- **SAP trial Communication Arrangements blocked** → kept sandbox + Postman as the
  recruiter-reproducer; events honestly narrated as simulated.

---

## 9. Production-gap honesty statement (the recruiter cue)

> _"This demo is intentionally Salesforce-centered. The integration code paths are fully
> working end-to-end against sandboxes/test accounts, but some external systems are
> read-mostly or license-gated (SAP sandbox writes don't persist; SAP tax module is
> license-gated; SAP Event Mesh is BTP-only). Production exercises the same code paths
> with real data; audit fields make the engine-vs-fallback distinction explicit on every
> record. No mocking; transparent fallbacks."_

This honesty discipline is **inherited by HanseWatt** (external meter/billing systems
simulated; the Salesforce code paths and the agent are real).

---

## 10. Why TechnoStore + HanseWatt together are strong

|             | TechnoStore (done)                                                            | HanseWatt (next)                       |
| ----------- | ----------------------------------------------------------------------------- | -------------------------------------- |
| Cloud       | Revenue Cloud (RLM/CLM/CPQ)                                                   | Service Cloud + Agentforce + Data 360  |
| Theme       | Quote-to-Cash (sell)                                                          | Customer service + AI (serve)          |
| AI          | none (rule-based)                                                             | autonomous agent + grounded LLM        |
| Data        | transactional SF                                                              | unified Data 360 profile + insights    |
| Integration | 8 systems (Mule + Apex)                                                       | Ingestion API / Mule (meter + billing) |
| Shared      | DACH, German, GDPR, MuleSoft, honest framing, docs pipeline, O'Hara framework |

Two projects, two halves of the enterprise: **sell** and **serve** — with the 2026 AI +
data stack layered on the serve side. That combination is precisely the senior DACH
Salesforce profile.

---

_This summary reflects TechnoStore as of 2026-06-20. The project is complete and frozen;
it is referenced here only as the reuse/lessons baseline for HanseWatt._
