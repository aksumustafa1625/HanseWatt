# Faz 5 demo — the grounded consumption answer

**Date:** 2026-07-02 · **Org:** `hansewatt` · **Agent:** HW Energy Agent (live, Active)
**Surface:** Agent Builder Conversation Preview (`sf agent preview -n HW_Energy_Agent --use-live-actions`)

This is the headline moment of the project: the agent stops guessing and answers from the
customer's **real unified consumption data**, with a citation.

## Transcript

> **Customer:** Why is my electricity bill so high this month?
>
> **HW Energy Agent:** Your electricity usage this month was **520.00 kWh**, which is
> **64.6% higher** than your trailing average of **316.0 kWh**. This significant increase
> could be due to the recent addition of a high-energy appliance, such as an electric
> vehicle (EV) charger or a heat pump. If you've recently made changes to your home or
> appliances, that might explain the spike. Let me know if you'd like tips on managing
> energy consumption!

## What the trace shows (why this is real, not a hallucination)

1. **Subagent Selection** → routes to `High Energy Consumption Insights`.
2. **Action Selection** → the planner is offered 3 actions and picks
   `HW_Explain_Consumption_Anomaly` (our custom Apex invocable, `HWExplainConsumptionAction`).
3. **Action output** (from Data 360 / unified Meter Reading data):
   ```json
   {
     "latestKwh": 520,
     "averageKwh": 316,
     "anomalyPercent": 64.6,
     "explanation": "Your latest usage was 520.00 kWh — 64.6% above your 316.0 kWh trailing average. The increase is recent and pronounced, consistent with a new high-draw appliance such as an EV charger or heat pump.",
     "citation": "Data 360 — Meter Reading (unified consumption)"
   }
   ```
4. **Output Evaluation: GROUNDED** — "The response accurately reflects the data retrieved
   from the function call, including the specific electricity usage, the percentage increase,
   and the possible reasons for the anomaly."

The `+64.6%` figure matches the Data 360 Query-API validation from Faz 2
(`scripts/datacloud_ci_anomaly.sql`, Lena = 520 vs 316 kWh avg) and the Apex test
`HWConsumptionServiceTest.actionReturnsGroundedResult` — three independent confirmations of
the same number.

## The grounding chain

```
Customer question
  → GenAiPlanner (ReAct) picks the topic
  → HW_Explain_Consumption_Anomaly (GenAiFunction)
  → HWExplainConsumptionAction (@InvocableMethod)
  → HWConsumptionService.anomaliesByAccount  (SOQL WITH USER_MODE, Database.queryWithBinds)
  → Meter_Reading__c (present in both Salesforce core and the Data 360 Meter Reading DLO)
  → {520, 316, +64.6%, citation} → grounded natural-language reply
```

See `memory/faz5-status-2026-06-30.md` for the wiring gotchas (UI Add Action, agent-user
permission set, the `tmpVar1` bind fix).
