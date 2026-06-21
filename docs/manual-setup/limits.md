# Org Limits & Quota Baseline (Faz 0 — D2 gate)

> Measured from the live org Setup on 2026-06-21. The consumption-discipline plan
> (`ROADMAP.md` / `PHASES.md`) depends on these. Update whenever re-checked.

## Org identity
- **Edition:** Developer Edition (with Agentforce + Data 360)
- **Org ID:** 00Dxx0000000000XXX · **Instance:** CAN96 · **API:** 67.0
- **Username:** hw-service-agent@example.com · alias `hansewatt`
- **Org Name (current):** "Configra GmbH" → ⚠️ rename to **HanseWatt GmbH** (cosmetic)
- **Default Locale:** English (US) · **Language:** English · **Currency:** USD
  → ⚠️ for DACH realism set **Locale = German (Germany)**, **Currency = EUR**; keep
    **Language = English** (UI English + EUR/German formats). Do in Faz 1 (C7).

## Platform limits (won't stop us — confirms storage/governor are NOT the risk)
| Limit | Value | Source |
|---|---|---|
| API Requests / month | 450,000 (Monthly) | Usage-based Entitlements |
| API Requests / 24h | 15,000 (36 used) | Company Information |
| Maximum Next Best Action Requests | 5,000 (Monthly) | Usage-based Entitlements |
| Maximum Orchestration Runs | 600 (Yearly) | Usage-based Entitlements |
| Data storage | ~7% used (342 KB) | Storage Usage |
| File storage | ~0% (17 KB) | Storage Usage |

## Agentforce — licensed & available ✅
| Permission Set License | Total | Used |
|---|---|---|
| Agentforce (Default) | 5 | 1 |
| Agentforce Service Agent Builder | 10,000 | 1 |
| Agentforce Service Agent User | 200 | 0 |
| Agent platform builder | 5 | 0 |

- **Einstein:** ON (Einstein Setup → Turn on Einstein = On)
- **Prompt Builder:** available (22 standard templates present)
- **Testing Center:** available (Einstein Generative AI → Testing Center; 0 tests) — our P10 eval home
- **Agentforce Agents toggle:** OFF (Agentforce Studio) → turn on at P5
- **Global Languages (prompt templates):** OFF → turn on for German at P6
- **Einstein Bots:** 25 conversations/month per chat user (older Bots, not Agentforce runtime)

## Permission Set License seats (licensing is generous — NOT the constraint)
> These are **seats**, not consumption credits. They confirm everything is licensed;
> the real limiter is credits in Digital Wallet.
- Data Cloud: 200,000 (2 used) · Customer Data Cloud for Marketing: 200,000
- Einstein Prompt Templates: 5 (1 used)
- Agentforce: see table above
- Field Service (Dispatcher/Mobile/Scheduling/Standard): available → roadmap R1 feasible
- CPQ, B2B/D2C Commerce, Payments, Order Mgmt, Scheduler, Voice: all available (unused)

## Data 360 / Data Cloud — NOT provisioned yet ⚠️
- "Welcome to Data Cloud" — instance must be created via **Get Started** (automated,
  runs in background). Faz 2 prerequisite.
- Conversation Transcripts on Data Cloud: Disabled (enable later for engagement data).

## KEY FACT — unified "Flex Credits" pool
Per the in-org Agentforce: **Agentforce and Data 360 credits are ONE shared pool called
"Flex Credits"** (used interchangeably for Data 360 + agent actions/voice/prompts). So
burn-budget tracks a single pool, not two. Reset period/date are contract-defined, in
Digital Wallet.
**Access:** App Launcher → **Digital Wallet** → **Consumption Cards** tab (NOT the Data
Cloud setup link).

## ❓ STILL NEEDED — the 4 quota numbers (open Digital Wallet)
⚠️ **Digital Wallet requires Data Cloud to be provisioned first** — the link gives
"Page doesn't exist" until "Get Started" (Data Cloud Setup) completes. So: provision
Data Cloud → then open Digital Wallet → capture the 4 numbers **before Faz 2 ingestion**
(the first credit-consuming step). Faz 1 is zero-consumption, safe to build meanwhile.
Reach it via the **"Open Digital Wallet"** link on the Data Cloud setup page. Record:
- [ ] (a) Agentforce action/credit ceiling (total + remaining)
- [ ] (b) Data 360 credit ceiling (total + remaining)
- [ ] (c) reset period (monthly / daily)
- [ ] (d) reset calendar day (1st of month vs activation date)

> Until these 4 are filled, the consumption-discipline rules (mock-first, on-demand,
> small eval suite) are our safety net. Fill them before the most expensive phases (P10/P11).
