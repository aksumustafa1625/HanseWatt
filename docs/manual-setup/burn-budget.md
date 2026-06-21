# Burn Budget — estimated consumption per phase (Faz 0 deliverable)

> Fill the "credit" columns once Digital Wallet numbers are in `limits.md`. Until then
> this tracks *what consumes* per phase so we spend deliberately. Reset day from
> Digital Wallet decides when to run the expensive phases (P10/P11).

| Phase | What consumes | Engine | Rough cost | Notes |
|---|---|---|---|---|
| P0 | nothing (config only) | — | 0 | foundations |
| P1 | nothing AI (Service Cloud config) | — | 0 | objects, Knowledge, Omni-Channel |
| P2 | Data 360 ingestion | Data 360 | low (small synthetic feed) | ingest 10 rows first, scale after mapping OK |
| P3 | Identity Resolution jobs | Data 360 | per-run | on-demand only, small dataset |
| P4 | Calculated Insights refresh | Data 360 | per-refresh | 3 CIs; refresh on-demand |
| P5 | agent actions + grounding | Agentforce | per conversation | mock-first; bind to agent late |
| P6 | prompt template runs | Agentforce/Einstein | per run | iterate text, run sparingly |
| P7 | agent actions (escalation) + judge none | Agentforce | per conversation | — |
| P8 | segment refresh + flow | Data 360 | per-refresh | on-demand, not scheduled |
| P9 | RtbF (Data 360 delete) | Data 360 | low | — |
| **P10** | **agent + judge (2nd LLM)** | **Agentforce** | **HIGH** | freeze agent first; judge vs fake transcripts; 8-10 utterances; run ONCE |
| **P11** | **adversarial agent runs** | **Agentforce** | **HIGH** | 8+ attacks; reuse eval; run once |
| P12 | extra CIs (CO2, peer) | Data 360 | per-refresh | — |
| P13 | WhatsApp agent runs | Agentforce | per conversation | second wave; first to cut if tight |

**Rule:** run P10/P11 right after a quota reset (date from `limits.md`). Everything
on-demand, never scheduled. Record remaining credits in `limits.md` before each
agent-heavy session.
