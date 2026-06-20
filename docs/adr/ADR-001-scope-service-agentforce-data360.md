# ADR-001: Scope — Service Cloud + Agentforce + Data 360 (vs Field Service alternative)

- Status: Accepted
- Date: 2026-06-20

## Context

The portfolio already proves the **sell** side (TechnoStore: Revenue Cloud / Quote-to-Cash
+ 8 integrations) and ISV packaging (Configra: RLM unlocked package). The gap is the 2026
DACH-hottest **serve + AI + data** stack: Agentforce (autonomous agents) and Data 360
(Data Cloud), neither demonstrated elsewhere.

We need a scenario that (a) generates rich, real data for an agent to ground on, (b) is
credible in the DACH market, and (c) showcases Service Cloud, Agentforce, and Data 360 in
one coherent narrative.

## Decision

Build an **AI-powered customer service platform** for a fictional DACH **energy retailer**
(HanseWatt GmbH) on **Service Cloud + Agentforce + Data 360**. Energy/utilities is chosen
because smart-meter consumption + billing produces high-volume, time-series data that is
the ideal grounding substrate for an agent ("why is my bill high?"), and it maps to a real
DACH hiring market (Stadtwerke, E.ON/EnBW-class, Energiewende).

## Consequences

**Positive:** zero overlap with TechnoStore/Configra; covers the highest-demand 2026 skill
set; one demo narrative; rich grounding data; DACH + GDPR + German-language story built in.

**Negative:** large surface (Service + AI + Data Cloud); much Data 360 / Agentforce config
is click-heavy and not fully source-trackable (mitigated by `docs/manual-setup/` discipline
and a phased "Minimum Wow Demo" gate). Dev-Edition feature limits must be verified early.

## Alternatives Considered

- **Field Service Cloud** (dispatch/technician) — strong but separate licensing + a large
  surface; deferred to the roadmap (R1) as an extension of `Outage__c`.
- **Financial Services / Manufacturing Cloud** — viable, but energy gives the richest,
  most intuitive grounding data (consumption anomalies) and the clearest DACH ESG angle.
- **Staying on the sell side** (extend TechnoStore) — rejected; would not close the
  serve + AI gap the portfolio needs.

## References

- `ROADMAP.md` §1 (triage), §2 (Minimum Wow Demo gate)
- `PROJECT_BLUEPRINT.md` §2 (market rationale)
