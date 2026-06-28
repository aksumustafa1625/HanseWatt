# ADR-002: Agentforce Service Agent vs custom LLM/Apex orchestration

- Status: Accepted (design locked, pre-build — Faz 5)
- Date: 2026-06-20

## Context

The core of the project is an autonomous, German-speaking customer-service agent that
explains bills, takes action on records, and escalates safely. Two ways to build it:

1. **Agentforce Service Agent** — Salesforce's native agentic runtime (Atlas reasoning
   engine): Topics + Actions + Instructions, with the Einstein Trust Layer, grounding
   retrievers, and the Agentforce Testing Center built in.
2. **Custom orchestration** — Apex (or an external service) calling an LLM API directly,
   with hand-built prompt assembly, tool routing, grounding, masking, and audit.

The portfolio's thesis is the **2026 DACH Agentforce + Data 360** skill set, and the agent
must run under a credible, governable, GDPR-defensible AI layer.

## Decision

Build the customer-facing agent as an **Agentforce Service Agent**. Apex is used **only**
for the Action layer (`@InvocableMethod`, see [ADR-006](ADR-006-apex-invocable-vs-flow-actions.md));
reasoning, planning, grounding, masking, and audit are delegated to the platform.

## Consequences

**Positive:** native Einstein Trust Layer (PII masking, toxicity, grounding, audit) — the
exact "no hallucination" story DACH energy recruiters want; native Knowledge + Data 360
retrievers; Testing Center for eval; far less code to own; the resume line maps 1:1 to job
specs ("Agentforce: Topics, Actions, Instructions, grounding, Trust Layer, testing").

**Negative / Trade-offs:** platform constraints (agent behaviour is config + instructions,
not arbitrary code); every agent action/prompt consumes **Flex Credits** — mitigated by the
mock-first, freeze-then-eval quota discipline in `PHASES.md`; some agent config is
click-heavy and not fully source-trackable (captured in `docs/manual-setup/`).

## Alternatives Considered

### Custom LLM + Apex orchestration
Rejected: re-invents the Trust Layer, grounding, and audit that are the *point* of the
demo; more code, weaker governance story, and no native Testing Center. Would read as
"bolted-on AI", not "AI-native platform".

### Einstein Bots (classic)
Rejected: rule/intent-based, not generative or autonomous; cannot ground on Data 360 or
reason over Calculated Insights. Wrong altitude for the thesis.

## References

- `PROJECT_BLUEPRINT.md` §9 (Agentforce design)
- Related: [ADR-006](ADR-006-apex-invocable-vs-flow-actions.md), [ADR-007](ADR-007-grounding-knowledge-data360-retriever-split.md), [ADR-011](ADR-011-two-agent-customer-employee.md)
