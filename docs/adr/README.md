# Architecture Decision Records (ADRs)

Significant architectural decisions for HanseWatt, in [Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
format. **Immutable once Accepted** — superseded by a new ADR rather than edited in place.

## Catalogue (planned — see ROADMAP §5.9)

| ADR | Decision | Status |
|---|---|---|
| [001](ADR-001-scope-service-agentforce-data360.md) | Service + Agentforce + Data 360 scope | Accepted |
| [003](ADR-003-data360-system-of-record-boundary.md) | Data 360 system-of-record boundary | Accepted |
| [004](ADR-004-ingestion-api-vs-mulesoft.md) | Ingestion API (primary) vs MuleSoft vs Connector | Accepted |
| 002 | Agentforce Service Agent vs custom LLM/Apex orchestration | planned |
| 005 | Identity resolution match/reconcile design | planned |
| 006 | Apex `@InvocableMethod` actions vs Flow actions | planned |
| 007 | Grounding: Knowledge + Data 360 retriever split | planned |
| 008 | German "Sie" form + Trust Layer guardrail policy | planned |
| 009 | DSGVO RtbF across SF + Data 360 | planned |
| 010 | Multi-currency EUR/CHF for AT/CH | planned |
| 011 | Two-agent (customer + employee) over single/four-agent | planned |
| 012 | Agent evaluation: LLM-as-judge rubric + regression | planned |
| 013 | Adversarial/red-team policy + evidence standard | planned |
| 014 | Event-driven backbone: Platform Events | planned |
| 015 | Zero-Copy/BYOL as production vision, not built in Dev Edition | planned |
| 016 | Why no OmniStudio (LWC console) | planned |

## Template

```markdown
# ADR-NNN: <title>

- Status: Proposed | Accepted | Superseded by ADR-XXX
- Date: YYYY-MM-DD

## Context
<the forces at play>

## Decision
<what we decided>

## Consequences
<positive + negative outcomes>

## Alternatives Considered
<options weighed and why rejected>

## References
<links>
```
