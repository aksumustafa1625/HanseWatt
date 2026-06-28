# ADR-016: No OmniStudio — custom UI is LWC

- Status: Accepted (design locked)
- Date: 2026-06-21

## Context

The agent console, the consumption chart, and the compliance actions need custom UI. The
Salesforce options are **OmniStudio** (FlexCards / OmniScripts — declarative, but a heavy,
licensed, hard-to-source-track runtime) or **Lightning Web Components** (code-first, fully
source-trackable). The sister ISV project (Configra) already took a deliberate "pure-LWC, no
OmniStudio" stance.

## Decision

All custom UI is **LWC**: `hwConsumptionChart` (Chart.js), `hwAgentConsole`,
`hwComplianceActions`, `hwAgentScorecard`, `hwRoiDashboard`. No OmniStudio anywhere.

## Consequences

**Positive:** everything is in git and code-reviewable; consistent with the portfolio's
stated engineering philosophy; no extra licensing or OmniStudio data-model overhead; Jest
unit tests possible.

**Negative / Trade-offs:** more hand-written UI code than a FlexCard would need; we forgo
OmniStudio's declarative speed for the few screens involved (acceptable — the screen count
is small and the components are reused across pages).

## Alternatives Considered

### OmniStudio FlexCards for the agent console
Rejected: contradicts the project's pure-LWC stance, adds licensing + a non-source-trackable
runtime, and weakens the "everything in git" story.

## References

- `ROADMAP.md` §1.4 (rejected OmniStudio)
- `PROJECT_BLUEPRINT.md` §1 (UI architecture: "Standard Lightning + LWC, no OmniStudio")
