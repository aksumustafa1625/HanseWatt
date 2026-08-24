# Security

## Scope

This is a **portfolio and demonstration project** modelling a fictional DACH
energy retailer, HanseWatt GmbH. It is not deployed to production and holds no
real customer, metering or billing data. Every account, contract, consumption
reading and invoice in the seed scripts is fabricated, and demo addresses use
domains reserved for documentation (RFC 2606).

The external systems the architecture talks about — smart-meter MDM, SAP IS-U
billing — are **simulated**. No connection to either exists in this repository.

## Credentials

**No API key, token or password exists in this repository — in the working tree
or in the git history.**

The org identifiers that once appeared in the setup and troubleshooting notes
under `docs/` — the org id and the instance subdomain — have been replaced with
placeholders and removed from the history.

## Where the security thinking is written down

This project's security posture is not a checklist bolted on at the end; it is
most of what the later ADRs are about. The ones to read:

| Concern | Record |
|---|---|
| What the agent is allowed to decide at all | [ADR-002](docs/adr/ADR-002-agentforce-service-agent-vs-custom-orchestration.md) |
| Where the system of record boundary sits | [ADR-003](docs/adr/ADR-003-data360-system-of-record-boundary.md) |
| Trust Layer guardrails, and German formal register | [ADR-008](docs/adr/ADR-008-german-sie-trust-layer-guardrails.md) |
| **DSGVO right-to-be-forgotten across systems** | [ADR-009](docs/adr/ADR-009-dsgvo-rtbf-across-systems.md) |
| Agent evaluation with an LLM judge | [ADR-012](docs/adr/ADR-012-agent-eval-llm-judge.md) |
| **Adversarial / red-team policy and evidence standard** | [ADR-013](docs/adr/ADR-013-adversarial-red-team-policy.md) |
| **Consent as a state machine, not a sentence** | [ADR-020](docs/adr/ADR-020-tariff-advisory-consent-handshake.md) |
| **Identity is two-factor; the refusal is a missing code path** | [ADR-021](docs/adr/ADR-021-identity-is-two-factor.md) |
| **Identity is a token, not a claim** | [ADR-022](docs/adr/ADR-022-identity-is-a-token-not-a-claim.md) |

The through-line across the last three: **a guardrail the model can talk its way
past is not a guardrail.** A refusal that depends on the model choosing to refuse
is a preference. A refusal that exists because the code path requires a token the
model cannot produce is a control.

## Platform posture

- Access is granted by permission set, not by widening a profile.
- The agent reaches data through defined actions, not through open queries.
- Data 360 grounding is scoped deliberately — the split between Knowledge and a
  Data 360 retriever is
  [ADR-007](docs/adr/ADR-007-grounding-knowledge-data360-retriever-split.md), and
  it is a security decision as much as a relevance one.
- Personal data handling follows the boundary set in ADR-003 and the erasure path
  in ADR-009. Both are DSGVO-relevant for the DACH market this project targets.

## Reporting a problem

If you find a security-relevant mistake — including a pattern that would be
unsafe if copied into a real org, or a guardrail that can be talked past —
please open an issue, or contact the author via https://mustafaaksu.dev. There
is no bug bounty; corrections are genuinely welcome, and a guardrail bypass is
the single most useful thing anyone could send.
