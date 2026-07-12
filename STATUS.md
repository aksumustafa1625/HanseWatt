# HanseWatt — Build Status (what is real vs. planned)

> One honest source of truth for the whole project. Everything shown in the demo video,
> screenshots, and traces is **built, deployed, and committed**. Anything marked *planned*
> is designed (ADR-documented) but **not yet code**. Nothing is claimed that the repo
> can't back up.

**Legend:** ✅ built & committed · 🟡 partial / in progress · ⬜ planned (designed, not built)

**Honest framing:** the external systems (smart-meter MDM, SAP IS-U billing) are *simulated*.
The Salesforce code paths, the agent, the Data 360 model, and the grounding are *real*.
This is a portfolio/demo build verified end-to-end in a Developer Edition org — not
production traffic.

---

## Headline: a live, grounded, German-speaking Agentforce agent

In one conversation the deployed agent runs the full service flow — **identify the customer
(email → Account) → quote the real bill → explain the +64.6 % consumption anomaly (cited to
Data 360) → open a real support Case** — and Salesforce's own Output Evaluation marks each
reply **GROUNDED**. See [`docs/demo/faz5-grounded-answer.md`](docs/demo/faz5-grounded-answer.md)
and [`docs/demo/images/`](docs/demo/images/).

---

## ✅ Built & committed

### Faz 1 — Service Cloud core
| Area | What | Where |
|------|------|-------|
| Data model | 7 objects + 37 fields (`Meter__c`, `Meter_Reading__c`, `Tariff__c`, `Service_Contract__c`, `Energy_Bill__c`, `Outage__c`, `Consent__c`) + `Case.HW_Topic__c` | `force-app/main/default/objects/` |
| Case + record types | 5 record types (Billing/Consumption/Move/Outage/Complaint) on a shared support process | `force-app/main/default/objects/Case/` |
| SLA (design) | `HW_Standard_SLA` entitlement process + First-Response (4h) & Resolution (2 business days) milestones | `force-app/main/default/` |
| Omni-Channel | service channel · escalation queue · routing (LEAST_ACTIVE) · presence · German + Billing skills | `force-app/main/default/` |
| Knowledge | 6-topic data-category group + 10 published, categorized English articles | `scripts/seed_knowledge.apex` |
| Security | `HW_Admin` · `HW_ServiceAgent` (bill/reading read-only = system-of-record) · `HW_ReadOnly` | `force-app/main/default/permissionsets/` |
| Multi-currency | EUR (corporate) + CHF | org config |
| Seed data | 4 DACH accounts + meters, contracts, bills, readings, consent, outage | `scripts/seed_demo_data.apex` |

### Faz 2 — Data 360 (Data Cloud)
| Area | What | Where |
|------|------|-------|
| Data streams | 4 DataStreamDefinitions (Account, Meter, Meter Reading, Energy Bill) → DLOs | `force-app-datacloud/main/default/dataStreamDefinitions/` |
| Anomaly grounding | Consumption anomaly proven live via the **Data 360 Query API** (SQL Calculated-Insight over the Meter Reading DLO): Lena **520 vs 316 kWh = +64.6 %** | `scripts/datacloud_ci_anomaly.sql`, `scripts/datacloud_query.ps1` |

### Faz 5 — The live agent + grounded actions
| Area | What | Where |
|------|------|-------|
| Live agent | `HW_Energy_Agent` (Bot + ReAct planner bundle + 2 topics) — deployed, previewable, source-controlled | `force-app/main/default/bots/`, `genAiPlannerBundles/`, `genAiPlugins/` |
| Grounded actions (5) | `HWIdentifyCustomerAction` (email→Account) · `HWGetLatestBillAction` · `HWExplainConsumptionAction` (+64.6 %) · `HWCreateCaseAction` (opens a real Case) · **`HWAnswerFromKnowledgeAction`** (cited help article) | `force-app-actions/main/default/classes/` |
| Service layer (5) | `HWCustomerService` · `HWBillingService` · `HWConsumptionService` · `HWCaseService` · **`HWKnowledgeService`** — `with sharing`, `WITH USER_MODE`, bulk-safe | `force-app-services/main/default/classes/` |
| **Procedure grounding (ADR-007)** | The other half of the grounding split: *figures* come from Data 360, *procedure* comes from a **cited Knowledge article**. `HWKnowledgeService` is a deterministic retriever — ONE query loads the 10-article corpus, then in-memory scoring (title hits ×3, body ×1) with a **German→English alias map** (umzug→moving, störung→outage, rechnung→bill …) so a German question lands on the English corpus. Below the score threshold it returns **nothing** rather than a bad article, and the action tells the agent *"do not guess the policy — offer to open a case."* **Verified live:** "I'm moving house next month" → the Umzug article + citation `HanseWatt Knowledge — Moving House: Start or Stop Service (Umzug) (000001008)`; "power outage" → the Störung article (000001004); an off-topic question → no invented policy. | `force-app-services/`, `force-app-actions/` |
| Agent-user perms | `HW_Agent_Actions` permission set (class access + USER_MODE FLS) | `force-app/main/default/permissionsets/` |
| Tests | 10 test classes / 49 test methods — one per service **and** one per action (1:1), all branches + 200-record bulk-safety tests; **99 % org-wide coverage**, every class ≥ 94 %; assert the grounded +64.6 % and the cited article before any live agent run | `force-app-tests/main/default/classes/` |
| Multi-turn flow | identify → bill → anomaly → create-case in one session, every reply GROUNDED; also runs fully in German | `docs/demo/faz5-grounded-answer.md` |
| NGA design bundle | `HW_Service_Agent.agent` (modern Agent-Script) committed as **design documentation** — its runtime publish is edition-blocked here (see gotchas) | `force-app/main/default/aiAuthoringBundles/` |

---

## 🟡 Partial / in progress

| Item | State |
|------|-------|
| SLA live milestone clock | Entitlement + milestones are deployed and source-controlled, but the live clock can't bind because `Case.EntitlementId` is **not provisioned in this Dev-Edition flavour** (edition limitation, not a config gap — see `docs/troubleshooting/faz1-gate-case-entitlementid.md`). Binds normally in a Service Cloud Enterprise/Developer org. |
| Data Cloud RAG Data Library | Not usable here: the `AiRetriever` metadata type does not exist in this org and the Data Library index never leaves "Not Started" (edition limitation). Procedure grounding is delivered instead by a deterministic Apex retriever — see the Faz 5 table above. |

---

## ⬜ Planned (designed / ADR-documented, **not yet built**)

These are the intended target architecture. They are **not** in the repo as code; the
package dirs `force-app-handlers/`, `force-app-lwc/`, and `force-app-agent/` are reserved
scaffolding for them.

| Component | Notes | ADR |
|-----------|-------|-----|
| Identity Resolution → Unified Individual (Data 360) | streams + DLOs exist; identity resolution not run | — |
| Persisted Calculated Insight + Segments + closed-loop proactive outreach | anomaly proven as ad-hoc SQL, not a persisted CI/segment | — |
| LWC UI (`hwConsumptionChart`, `hwAgentConsole`) | `force-app-lwc/` is empty scaffolding | ADR-016 |
| Trigger handlers (Kevin O'Hara framework) | `force-app-handlers/` is empty scaffolding | — |
| Additional agent actions: ProposeTariff · InitiateTariffChange · EscalateToHuman | only identify / bill / explain / create-case are built | — |
| Prompt templates | agent uses topic instructions today | — |
| Agent evaluation / LLM-as-judge (`HW_AgentJudge`) | design only | ADR-012 |
| Adversarial red-team suite | design only | ADR-013 |
| Employee agent ("Jonas") | design only | ADR-011 |
| DSGVO right-to-be-forgotten automation | design only | — |
| WhatsApp / additional channels | agent runs in Builder preview today | — |

---

## Where the metadata actually lives (note for reviewers)

The 8-package SFDX layout (see `sfdx-project.json`) is intentional, but not every package
has content yet. The **live agent's metadata is committed under the core `force-app`
package** (`bots/`, `genAiPlannerBundles/`, `genAiPlugins/`, `genAiFunctions/`,
`aiAuthoringBundles/`), because that is where the CLI created/retrieved it. The dedicated
`force-app-agent/`, `force-app-handlers/`, and `force-app-lwc/` packages are reserved for
the planned work above and currently hold only scaffolding.
