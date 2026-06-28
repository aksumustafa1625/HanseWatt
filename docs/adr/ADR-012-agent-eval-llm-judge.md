# ADR-012: Agent evaluation — LLM-as-judge rubric + regression

- Status: Proposed (pre-build — Faz 10, headline differentiator)
- Date: 2026-06-21

## Context

Almost no portfolio agent is *measured*. "I built an agent" is common; "I built a system
that scores my agent's quality and catches regressions" is rare and senior. The challenge is
doing it without burning the Flex-Credit budget on endless live runs.

## Decision

Build an **LLM-as-judge evaluation pipeline**:

- `HW_Agent_Eval_Result__c` object with rubric fields (grounding, hallucination, correct-
  action, trust, tone, escalation).
- `HW_AgentJudge` prompt template — a **second LLM** scores the agent's transcript against
  the rubric.
- `HWAgentEvalService` runs a small **8–10 utterance suite** → agent → judge → result rows;
  surfaced in an `hwAgentScorecard` LWC + a Notion "Agent Quality Scorecard".
- **Regression:** re-run when the agent changes.

**Quota sequencing (hard rule):** freeze the agent first; tune the judge rubric against
**hand-written fake transcripts** (no agent runs = no credits); then run the real pipeline
**once** and save the result rows + screenshot.

## Consequences

**Positive:** the single biggest differentiator — turns "trust me" into a measured
scorecard; the artifact (result rows) is what's shown, not a live run; reusable for the
red-team pass ([ADR-013](ADR-013-adversarial-red-team-policy.md)).

**Negative / Trade-offs:** an LLM judge is itself imperfect (mitigated by an explicit rubric
+ small, curated suite); each full run costs credits, so it is run **once** after freeze.

## Alternatives Considered

### Manual spot-checking
Rejected: not reproducible, not a regression guard, weak portfolio evidence.

### Large automated suite on a schedule
Rejected: burns the credit budget for marginal coverage; an 8–10 case curated suite run once
is the disciplined choice.

## References

- `PHASES.md` Faz 10 (quota warning), `ROADMAP.md` §1.2 (E1)
- Related: [ADR-013](ADR-013-adversarial-red-team-policy.md)
