# Research — Salesforce Data 360 (Data Cloud) setup for HanseWatt (Faz 2)

> **Purpose:** a researched, source-cited playbook for setting up Data 360 (Data Cloud)
> end-to-end for HanseWatt — ingesting smart-meter + billing + CRM data, building a unified
> profile and Calculated Insights, and grounding the Agentforce agent — **while burning the
> fewest possible Flex Credits** in a Developer Edition.
>
> **Compiled:** 2026-06-29 from official Salesforce docs/Trailhead + community sources
> (Salesforce Ben, Salesforce Architects, SFDC Gym, Salesforce Break, Jitendra Zaa,
> salesforceblogger, et al). Sources listed at the bottom; key claims link inline.
>
> **Method note:** the automated deep-research workflow failed on its schema step, so this
> was compiled via direct web search + source fetch (5 search angles, ~15 sources, top
> sources fetched and cross-checked).

---

## 0. TL;DR — the five things that matter for us

1. **Rebrand:** "Data Cloud" was renamed **Data 360** on **2026-10-14**. Same product;
   docs/UI mix both names. ([salesforcetutorial], [medium-mapping])
2. **Salesforce-native ingestion is FREE.** Pulling Sales/Service Cloud (incl. our custom
   objects) into Data 360 via the **Salesforce CRM connector** consumes **no credits** —
   it's the "Salesforce Core" free pipeline. This is our cheapest path and we already have
   the connection live. ([sf-pricing-blog], [salesforceben-pricing])
3. **The expensive things are Identity Resolution and streaming/often-refreshed Calculated
   Insights.** Identity Resolution ≈ **100,000 credits / million rows**; a CI on **streaming
   costs ~53× a batch CI** (≈800 vs ≈15 credits). Our discipline: tiny data, **batch + daily
   (or manual) refresh**, run identity resolution **on-demand once**. ([jitendrazaa])
4. **The setup order is fixed:** Connection → Data Stream → **DLO** → map to **DMO** →
   Identity Resolution → Calculated Insight → grounding/activation. ([salesforcebreak],
   [sf-help-dataobjects])
5. **Most of it IS source-controllable** (DataStreamDefinition, DLOs, custom DMOs, CIs,
   identity rules, data transforms) via **DevOps Data Kits + SFDX CLI** — but **Data Spaces
   and Connections are click-only** and must be created by hand per org. ([salesforceblogger],
   [sf-dev-datakit])

---

## 1. Terminology (so the rest reads cleanly)

| Term                        | What it is                                                                                                                                                                  |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Connection**              | An auth'd link to a source (e.g. the Salesforce CRM "home org"). We have **1 live** (`Home`, Active).                                                                       |
| **Data Stream**             | The configured flow of one source object's records into Data 360. One per object (e.g. one for `Meter_Reading__c`).                                                         |
| **DSO**                     | Data _Source_ Object — the raw landing shape of a stream (often glossed over).                                                                                              |
| **DLO** (`__dll`)           | **Data Lake Object** — raw, untransformed ingested data. Can't power segmentation/identity/CI on its own. ([medium-mapping], [jthathapudi])                                 |
| **DMO** (`__dlm`)           | **Data Model Object** — the _harmonized_ canonical model. You **map DLO → DMO**; downstream tools (identity res, CI, segments, retrievers) consume DMOs. ([medium-mapping]) |
| **Identity Resolution**     | Match + reconciliation rules that merge source profiles into one **Unified Individual**. ([sf-help])                                                                        |
| **Calculated Insight (CI)** | A derived metric/aggregation over DMOs (e.g. avg kWh, anomaly score). Batch or streaming.                                                                                   |
| **Retriever**               | The RAG component that returns relevant DMO/CI rows (or search-index chunks) to ground a prompt/agent. ([salesforceben-rag])                                                |
| **Data Space**              | A partition for data governance. We have **1**.                                                                                                                             |

---

## 2. The end-to-end setup sequence (authoritative order)

From the Salesforce Break roadmap and Salesforce Help, the canonical order is:
([salesforcebreak], [sf-help-dataobjects])

1. **Plan / start small** — one or two use cases. (Ours: "explain a high bill from consumption.")
2. **Connection** — pick the connector (Salesforce CRM for us; Ingestion API / Zero-Copy for external). _Done — home-org CRM connection is live._
3. **Data Stream** — define schema + format for each object ingested.
4. **DLO** — raw data lands as Data Lake Objects on stream creation.
5. **DMO mapping** — transform/map DLOs onto standard or custom DMOs (the canonical model).
6. **Identity Resolution** — match + reconciliation rules → Unified Individual.
7. **Calculated Insights** — aggregations enriching the unified profile.
8. **Segmentation / Activation / Grounding** — segments to activation targets, or **retrievers**
   to ground Agentforce.

> Beginner best practices repeatedly stressed: **clean upstream first** ("Data Cloud is a
> unification tool, not a cleansing tool"); **plan data types carefully** (schema mistakes are
> hard to reverse after ingestion); **ensure unique keys per row** (prevents bad merges);
> **stay cost-conscious** (identity resolution + batch transforms are credit-heavy).
> ([salesforcebreak])

---

## 3. Ingesting our data — CRM connector + custom objects (the FREE path)

### 3.1 Salesforce CRM ingestion is free

Salesforce made **structured ingestion from its own clouds free**: **Salesforce Core (Sales +
Service Cloud)**, **Marketing Cloud Engagement**, **Marketing Cloud Personalization**, and
**Commerce Cloud**. Syncing our Account/Contact/Case/Knowledge **and our custom objects**
(`Meter__c`, `Meter_Reading__c`, `Energy_Bill__c`, …) through the CRM connector **does not burn
credits**. ([sf-pricing-blog], [salesforceben-pricing])

> Implication for HanseWatt: **do the whole Faz 2 ingestion via the Salesforce CRM connector**,
> not the Ingestion API. The "external smart-meter feed via Ingestion API" stays an honest
> _narrative_ (ADR-004) — but for the actual build, our seeded Salesforce data is the source,
> and it's free. The Ingestion API would be the path for genuinely external data and _can_
> cost credits (external ingestion ≈ 2,000 credits/M rows). ([jitendrazaa])

### 3.2 Bundles vs. custom data streams

- **Standard Data Bundles** (Sales Cloud, Service Cloud) ship **pre-mapped** data streams +
  DMO mappings for standard objects — "everything comes mapped, minimal setup." Installing the
  **Service Cloud bundle** would auto-bring Account/Contact/Case/etc. mapped to standard DMOs.
  ([cloudkettle], [salesforce-architects])
- **Custom objects have no bundle** — for `Meter_Reading__c` etc. you **create a custom data
  stream**, which lands a **DLO**, then you **map that DLO to a DMO** (usually a **custom DMO**
  you create, or extend a standard one). ([sfdcgym], [salesforce-architects])

> Recommendation: **don't bulk-install the full Service Cloud bundle** (it brings many objects
> we don't need = noise + storage). Instead create **targeted custom data streams** for exactly
> the objects we need (Account, Contact, Meter, Meter_Reading, Energy_Bill, Service_Contract,
> Tariff). Small, intentional, easy to reason about — matches our quota discipline.

### 3.3 ⚠️ The #1 gotcha — field permissions

Fields **won't appear in Data Cloud** unless the integration/running user has **Read + "View
All"** on the object and **Read** on each field. Grant FLS first or the data stream shows no
fields. ([sfdcgym])

### 3.4 Unique key

Every stream needs a **primary/unique key** (the record Id works) and an **event/date field**
for time-series (`Read_Date__c` for readings) so DMO/CI time logic works. ([salesforcebreak])

---

## 4. DLO → DMO mapping (standard vs custom DMO)

- **Use standard DMOs** where a clean fit exists: `Account/Contact` → **Individual** +
  **Contact Point Email/Phone**; this is what identity resolution + the agent's "who is this
  customer" grounding rides on.
- **Use custom DMOs** for domain data with no standard equivalent: an **`Energy Usage` DMO**
  (from `Meter_Reading__c`) and a **`Billing` DMO** (from `Energy_Bill__c`). The DMO is also how
  you **merge the same concept from multiple sources** later. ([salesforce-architects],
  [cloudkettle])
- Mapping is done from the **DLO page → Mapping section**; bundle data arrives pre-mapped, custom
  data you map field-by-field. ([cloudkettle])

---

## 5. Identity Resolution (unify the messy customer)

- An identity ruleset has **Match rules** (how records are judged "the same" — exact
  email/phone first, then fuzzy name/address) and **Reconciliation rules** (which source wins
  per attribute — e.g. most-recent-wins for contact info, source-priority for billing id). It
  produces the **Unified Individual**. ([sf-help])
- **Worked example (our C5 case):** Lena as `"L. Bergmann"` (SAP/billing), `lena.b@gmx` (web),
  `Lena Bergmann` (CRM) → exact-email + fuzzy-name/address match rules collapse to one Unified
  Individual; reconciliation keeps the freshest contact info. (Design per **ADR-005**.)
- **Cost warning:** identity resolution is **the single most expensive operation** (~100,000
  credits/M rows) and runs **incrementally in auto-mode** (adding 10k records can re-evaluate
  20–30k profiles). On a Dev Edition with ~tens of records this is negligible, but **never scale
  it up casually**. ([jitendrazaa])

---

## 6. Calculated Insights (the agent's "evidence")

- A CI is an aggregation over DMOs. Authored via the **CI Builder (no-code UI)** or **SQL**.
  Ours (per blueprint): `Avg_Monthly_kWh`, `Consumption_Anomaly_Score`, `Time_of_Day_Profile`.
- **Batch vs streaming:** **batch ≈ 15 credits**, **streaming ≈ 800 credits** for the same CI —
  **~53× more**. **Refresh frequency** is the big lever: hourly→**daily ≈ 96% cheaper**;
  weekly ≈ 99.4% cheaper. ([jitendrazaa])
- **Our rule:** all CIs **batch**, refreshed **manually/on-demand** during dev (never scheduled
  hourly). Re-affirms the standing quota discipline.

---

## 7. Grounding Agentforce on Data 360 (how the agent uses our data)

- A **Retriever** returns relevant rows/chunks to augment the LLM prompt. Two flavours:
  - **Structured** — over a **DMO or Calculated Insight** (our figures: bill amount, avg kWh,
    anomaly). This is the **Data 360 retriever** half of our ADR-007 split.
  - **Unstructured** — over a **Search Index** (PDFs, Knowledge, transcripts) — the **Knowledge**
    half. ([salesforceben-rag])
- **No-code setup:** **Data Cloud → Einstein Studio → Retrievers → New Retriever** → pick
  _Individual Retriever_, source = DMO/Search Index, set #results (default 20), choose return
  fields + the **Chunk** field, optionally SourceRecordId/DataSource for **citations**. Filters:
  up to **10 conditions**. ([salesforceben-rag])
- **Wire to the agent:** test the retriever in **Prompt Builder** (swap the default dynamic
  retriever for yours), then attach it to the agent via a **custom data library** in agent
  setup. CIs can also drive **Flow**-based automation/triggers. ([salesforceben-rag])
- **Other read paths** for validation: the **Query API** / Data 360 APIs let you query DMOs +
  CIs directly (we'll use this to _verify_ CI values before wiring the agent — mock-first).
  ([salesforceben-extract])

---

## 8. The Flex Credit / consumption model (what costs what)

Unit costs (community-sourced, directional — confirm in Digital Wallet): ([jitendrazaa])

| Operation                                                           | Rough cost                    | Notes                                                                      |
| ------------------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------------------- |
| **Salesforce-native ingestion** (Sales/Service Cloud, MC, Commerce) | **FREE**                      | Our whole Faz 2 ingestion path. ([sf-pricing-blog])                        |
| External ingestion (Ingestion API, etc.)                            | ~2,000 credits / M rows       | Only if we ingest truly external data.                                     |
| **Identity Resolution**                                             | **~100,000 credits / M rows** | Most expensive; ~50× external ingest. On-demand, tiny data.                |
| Calculated Insight — **batch**                                      | ~15 credits                   | Default.                                                                   |
| Calculated Insight — **streaming**                                  | ~800 credits                  | ~53× batch — avoid.                                                        |
| Data query                                                          | ~2 credits / M rows           | Cheap, but **always filter + LIMIT** (unfiltered 100M scan ≈ 200 credits). |
| Storage                                                             | priced separately             | Pay for what you store → keep datasets tiny.                               |

**Reference points:** the **Data 360 Starter SKU** lists ~**$60k/yr for 10M credits + 5 TB**;
**sandbox credits are ~20% discounted** vs production. (Context only — our Dev Edition has a
small undocumented allotment.) ([sf-pricing-blog], [cube84])

**Credit-frugal tactics (apply all):** ([jitendrazaa], [salesforcebreak])

- Ingest **only via the free Salesforce connector**; keep row counts tiny (validate on ~10–50 rows).
- **Batch** everything; **manual/daily** refresh, **never hourly/scheduled** during dev.
- Run **Identity Resolution on-demand, once**, after the model is right.
- **Filter upstream** (drop nulls / inactive); removing null rows saves 10–30%.
- **Always filter + LIMIT** queries; preview on samples.
- Group related fields in DMOs to cut join complexity (−20–40% on downstream).

---

## 9. Developer Edition (Agentforce + Data 360) — limits & gotchas

- **Our org is already provisioned** (instance live, **1 Data Space**, **1 CRM connection**;
  tenant endpoint present). "Get Started" is done — we go straight to data streams.
- **Service/Sales Cloud Standard Data Bundles show "Installed Version: --"** → not installed
  (we'll use targeted custom streams instead, §3.2).
- **"Go to Data Cloud" sometimes 404s** ("Page doesn't exist") — a known transient/URL quirk;
  reach the Data Cloud app via **App Launcher → Data Cloud**, or retry the link. (Observed in
  our org.)
- **Permissions:** ensure the user holds a **Data Cloud Admin**-type permission set (the
  "Assign Permissions" button on Data Cloud Setup Home) before building. The legacy "(Legacy)
  Data Cloud *" perm sets exist but prefer the current Data Cloud admin set.
- **Digital Wallet** (credit tracking) becomes reachable once Data Cloud is provisioned —
  "Check credit consumption → Open Digital Wallet" on the setup home. Capture the balance.
- **SOQL/Tooling won't show `ssot__`/`__dlm` objects until you build streams/mappings** — an
  empty data space has no DMOs, so absence ≠ "not provisioned" (this misled us once).

---

## 10. Source control — what's deployable vs click-only

**Deployable as metadata** (via **DevOps Data Kits** + SFDX CLI / package.xml):
([salesforceblogger], [sf-dev-datakit], [metazoa])

- `DataStreamDefinition` (streams), **DLOs**, **custom DMOs** (`MktDataModelObject`),
  **Calculated Insights**, **Identity Resolution rules**, **Data Transforms**, **Segments**,
  **Data Actions**, **Data Graphs**.
- Flow: Data Cloud Setup → **Developer Tools → Data Kits** → add components → download
  `package.xml` → `sf project retrieve start --manifest …` → commit → `sf project deploy start`.

**NOT deployable (manual per org):** **Data Spaces** and **Connections** — must be created by
hand and re-authenticated. ([salesforceblogger])

> For our repo (`force-app-datacloud/`): we capture stream/DLO/DMO/CI/identity metadata via a
> Data Kit and commit it; the **Connection + Data Space are documented in
> `docs/manual-setup/`** (honest-framing, like the rest of the click-heavy config).

---

## 11. Recommended credit-frugal Faz 2 plan for HanseWatt

Mapped to our phases/ADRs; every step here is **free or near-zero credits**:

1. **Assign Data Cloud permissions** to the builder (Setup Home → Assign Permissions). _(free)_
2. **Capture credit balance** in Digital Wallet → record in `docs/manual-setup/burn-budget.md`. _(free)_
3. **(Optional) Enrich the seed** — extend `scripts/seed_demo_data.apex` to 6 months of
   `Meter_Reading__c` (Lena's EV evening spike, Müller steady, holiday dips). Apex = free. _(free)_
4. **Create targeted Salesforce CRM data streams** (free connector) for: Account, Contact,
   `Meter__c`, `Meter_Reading__c`, `Energy_Bill__c`, `Service_Contract__c`, `Tariff__c` — after
   granting FLS (§3.3). Lands DLOs. _(free)_
5. **Map DLOs → DMOs:** Account/Contact → **Individual + Contact Point**; create custom
   **`Energy Usage`** (from readings) and **`Billing`** (from bills) DMOs. _(free)_
6. **Identity Resolution** — one ruleset (exact email + fuzzy name/address), run **on-demand
   once** on the tiny set → Unified Individual (validates ADR-005's Lena case). _(tiny → ~free)_
7. **Calculated Insights** (batch, manual refresh): `Avg_Monthly_kWh`,
   `Consumption_Anomaly_Score` over the Energy Usage DMO. _(≈15 credits each, once)_
8. **Validate via Query API** that the CI returns Lena's anomaly — _before_ any agent wiring
   (mock-first). _(≈free)_
9. **Capture as metadata** via a Data Kit into `force-app-datacloud/`; document the
   Connection + Data Space in `docs/manual-setup/`. _(free)_
10. Hand the **Energy Usage / CI DMO to a Data 360 retriever** in Faz 5 when the agent is built
    (ADR-007 figures-half). _(deferred)_

> Net: Faz 2 can be done almost entirely on the **free Salesforce pipeline**, with the only real
> credit spend being a handful of one-off batch CI runs and a single small identity-resolution
> run.

---

## Sources

- [salesforcetutorial] Salesforce Data Cloud Guide 2026 — https://www.salesforcetutorial.com/salesforce-data-cloud/
- [medium-mapping] Data Mapping in Data Cloud (Data 360) — https://medium.com/@tumuvenkateswarareddy193/data-mapping-in-salesforce-data-cloud-data-360-the-foundation-for-segmentation-identity-f2cfcddb1cd0
- [jthathapudi] DSOs, DLOs, DMOs explained — https://www.jthathapudi.com/blog/from-raw-to-ready-understanding-dsos-dlos-and-dmos-in-salesforce-data-cloud
- [salesforcebreak] Getting Started with Data Cloud roadmap — https://salesforcebreak.com/2025/07/16/get-started-salesforce-data-cloud/
- [sf-help-dataobjects] Data Objects in Data Cloud (Salesforce Help) — https://help.salesforce.com/s/articleView?id=sf.c360_a_data_lake_objects.htm
- [sfdcgym] Connect Salesforce CRM Custom Objects to Data Cloud — https://sfdcgym.com/blog/datacloud/how-to-connect-salesforce-crm-custom-object-to-data-cloud.html
- [salesforce-architects] Making Data Cloud Work With Your Existing CRM Data — https://medium.com/salesforce-architects/making-data-cloud-work-with-your-existing-salesforce-crm-data-0f2ad272f407
- [cloudkettle] Data Ingestion for Salesforce Data Cloud — https://www.cloudkettle.com/blog/data-ingestion-for-salesforce-data-cloud/
- [sf-crm-connector] Salesforce CRM Connector (Salesforce Help) — https://help.salesforce.com/s/articleView?id=sf.c360_a_salesforce_crm_connector.htm
- [sf-pricing-blog] Salesforce — Updates to Data Cloud Pricing (free Salesforce ingestion) — https://www.salesforce.com/blog/data-cloud-pricing-updates/
- [salesforceben-pricing] New Pricing for Salesforce Data Cloud — https://www.salesforceben.com/new-pricing-for-salesforce-data-cloud-is-here-what-you-need-to-know/
- [jitendrazaa] Data 360 Credit Optimization Guide (Mar 2026) — https://www.jitendrazaa.com/blog/salesforce/salesforce-data-360-credit-optimization-guide-march-2026/
- [cube84] Salesforce Data Cloud Pricing in 2025 — https://cube84.com/blog/salesforce-data-cloud-pricing-in-2025-what-every-enterprise-needs-to-know
- [salesforceben-rag] Connecting Agentforce to Data Cloud for Grounding With RAG — https://www.salesforceben.com/connecting-agentforce-to-data-cloud-for-grounding-with-rag/
- [salesforceben-extract] 6 Ways to Extract Data from Data Cloud (2026) — https://www.salesforceben.com/6-ways-to-extract-data-from-salesforce-data-cloud/
- [sf-grounding-trail] Grounding Agents in Data 360 (Trailhead) — https://trailhead.salesforce.com/content/learn/modules/advanced-rag-with-data-360-and-agentforce/get-started-with-grounding-agents-in-data-360
- [salesforceblogger] Master Data Cloud Metadata Deployments with SFDX CLI — https://www.salesforceblogger.com/2025/03/31/master-data-cloud-metadata-and-process-definition-deployments-with-sfdx-cli-and-metadata-api/
- [sf-dev-datakit] Deploy Data 360 with Data Kits via CLI (Salesforce Developers) — https://developer.salesforce.com/docs/data/data-cloud-dev/guide/dc-deploy_data_kit_using_cli.html
- [metazoa] DataStreamDefinition metadata type — https://support.metazoa.com/hc/en-us/articles/35371065195021-DataStreamDefinition
