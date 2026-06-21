# Burn Budget — estimated Flex Credit consumption per phase

> Unit economics now known (Salesforce Agentforce pricing, May + Sept 2025 rate cards):
> - **1 Agentforce action = 20 Flex Credits** (≈ $0.10)
> - **1 prompt (Standard model, ≤2K tokens) = ~4 Flex Credits** (≈ $0.02); Basic models cheaper; 2,000 tokens included per call
> - $500 = 100,000 credits
> - Flex Credits are a single unified pool for Agentforce + Data 360.
>
> **Free balance:** not visible in this Developer Edition (Digital Wallet is Enterprise/
> Unlimited only). Dev Edition includes a "limited" test allotment — unknown exact number.
> We track *estimated spend* below and stay disciplined; if a call ever fails on quota,
> we'll know empirically. Even a full-project ~10k credits ≈ $50-equivalent, trivial in
> dollar terms — the only risk is a very small Dev free cap, which discipline keeps us under.
>
> **Free, does NOT consume credits:** Salesforce CRM → Data 360 ingestion (Internal Data
> Pipeline, included since 2025-08-07). So Faz 2 CRM ingest is free; only external-source
> ingest + Data 360 queries/CI/identity-resolution + agent actions/prompts cost credits.

| Phase | What consumes | Est. unit math | Rough credits | Discipline |
|---|---|---|---|---|
| P0–P1 | config only | — | 0 | — |
| P2 | external feed ingest + Data 360 queries | small synthetic feed | low (CRM ingest free) | 10 rows first, scale after mapping OK |
| P3 | Identity Resolution jobs | per-run | low-med | on-demand only, small dataset |
| P4 | Calculated Insights refresh | per-refresh × 3 CIs | low-med | refresh on-demand, not scheduled |
| P5 | agent actions + grounding | ~10 real runs × 3 actions × 20 | ~600 | mock-first (Apex tests free); wire to agent late |
| P6 | prompt template runs | ~4 credits/run | low | iterate text, run sparingly |
| P7 | escalation actions | ~10 runs × 3 actions × 20 | ~600 | — |
| Demo rehearsals | full flow ~5 actions + 2 prompts ≈ 108 cr | × ~10 rehearsals | ~1,080 | record incrementally |
| **P10 eval** | agent + judge per utterance | 10 utt × (≈2 act×20 + 1 resp prompt 4 + 1 judge prompt 4) ≈ 48 | **~480/run** | freeze agent first; judge vs fake transcripts; run ONCE |
| **P11 red-team** | adversarial agent runs | 8 attacks × ~48 | **~400** | reuse eval; run once |
| P12 | extra CIs (CO2, peer) | per-refresh | low-med | on-demand |
| P13 | WhatsApp agent runs | per conversation | med | second wave; first to cut if tight |

**Rough total estimate:** ~4,000–6,000 credits for the whole build with discipline.
Everything on-demand, never scheduled. Re-check empirically if any call fails on quota.
