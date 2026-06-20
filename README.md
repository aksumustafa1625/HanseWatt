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
![Status](https://img.shields.io/badge/Status-In%20Development%20(P0)-yellow)

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

## Documents

- [`PROJECT_BLUEPRINT.md`](./PROJECT_BLUEPRINT.md) — the design (what & how)
- [`ROADMAP.md`](./ROADMAP.md) — triage of enhancements + gated roadmap + full skeleton
- [`PHASES.md`](./PHASES.md) — step-by-step build checklist (P0–P14)
- [`TechnoStore.md`](./TechnoStore.md) — the completed reference project + reused patterns

## Repository layout (SFDX, 8 packages)

```
force-app/             core sObjects, Service Cloud config, flows, perms, layouts
force-app-services/    HWBillingService, HWConsumptionService, HWComplianceService...
force-app-actions/     Agentforce @InvocableMethod actions (HW...Action)
force-app-handlers/    trigger handlers (Kevin O'Hara framework)
force-app-agent/       Agentforce metadata (Bot/GenAiPlanner/Topics/Functions)
force-app-datacloud/   Data 360 metadata (DataStream/DLO/DMO/CI/Segment)
force-app-lwc/         hwConsumptionChart, hwAgentConsole, hwComplianceActions...
force-app-tests/       Apex tests
docs/                  adr · architecture · manual-setup · security · eval
```

## Build status

Currently **P0 (Foundations)** — repo skeleton is scaffolded; awaiting the live
**Developer Edition with Agentforce + Data 360** org to connect and deploy.

```bash
# once the org is provisioned:
sf org login web --alias hansewatt
sf project deploy start --source-dir force-app --target-org hansewatt
```

See [`PHASES.md`](./PHASES.md) for the full step-by-step plan.

## License

Proprietary — All rights reserved. © 2026 Mustafa Aksu. Shared for portfolio and
evaluation purposes only.

> **Honest framing:** external systems (smart-meter MDM, SAP IS-U billing) are simulated;
> the Salesforce code paths, the agent, the Data 360 model, and grounding are real.
