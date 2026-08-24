# Contributing

This is a personal portfolio project rather than an open-source product, so
there is no roadmap to volunteer for. Corrections are welcome all the same —
and one kind more than any other.

## The most useful thing you can send

**A way past a guardrail.**

Three of the later ADRs argue that a refusal the model *chooses* is a preference,
and only a refusal the code path *requires* is a control
([020](docs/adr/ADR-020-tariff-advisory-consent-handshake.md),
[021](docs/adr/ADR-021-identity-is-two-factor.md),
[022](docs/adr/ADR-022-identity-is-a-token-not-a-claim.md)). If you can get the
agent to disclose, advise or act without the token the design says it needs, that
is not a bug report — it is a refutation of the central claim, and it is worth
more than anything else in this list.

Also valuable:

- **A mistake in the reasoning.** Twenty-two ADRs in [`docs/adr/`](docs/adr/)
  state why each decision was made. A wrong premise makes a wrong decision.
- **A mistake in the code.** A missed bulkification path, a sharing declaration
  that should not be there, a test that asserts nothing.
- **A platform change.** These files were written against Summer '26. If a newer
  release makes an approach here obsolete, saying so is a real contribution.

## Working locally

```bash
git clone https://github.com/aksumustafa1625/HanseWatt.git
cd HanseWatt
npm ci
sf org login web --alias hansewatt --set-default
sf project deploy start --test-level RunLocalTests
```

Deployment order and the steps that cannot be deployed — the agent itself, the
Data 360 configuration — are in [`docs/manual-setup/`](docs/manual-setup/).

Before pushing:

```bash
npm run prettier:verify   # formatting is checked, not suggested
npm run lint              # LWC lint
npm test                  # LWC unit tests
```

These are exactly what CI runs. CI additionally checks that every declared
package directory exists and that the ADR index lists every ADR with no
duplicate numbers — both of which have caught real mistakes.

## Structure

Eight package directories, split by role rather than by feature:

| Directory | Holds |
|---|---|
| `force-app` | Base objects, layouts, permission sets |
| `force-app-services` | Business logic |
| `force-app-actions` | Invocable actions the agent may call |
| `force-app-handlers` | Trigger handlers |
| `force-app-agent` | Agent, topics, prompt templates |
| `force-app-datacloud` | Data 360 streams and mappings |
| `force-app-lwc` | Lightning Web Components |
| `force-app-tests` | Apex test classes |

The split is deliberate: what the agent can invoke is a directory you can list,
rather than a set of annotations scattered through a services folder.

## House rules

- **The agent gets actions, not queries.** Anything it can call lives in
  `force-app-actions` and is reviewable as a set.
- **A guardrail is a code path, never an instruction.** If a refusal depends on
  wording, it is not finished.
- **Build in English, localise at the end** —
  [ADR-019](docs/adr/ADR-019-build-language-english.md). German is the product's
  language, not the identifier's.
- **Bulk-safe by default.** No SOQL or DML inside a loop.
- **Declare sharing explicitly** on every class.

## Commits

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `security:`, `test:`).
Say what changed and why; the diff already says how.

## If you change a decision

Changing an approach documented in an ADR means updating that ADR — amend it, or
add a record that supersedes it, and add the new one to the index. CI will fail
if you add an ADR and forget the index. An ADR that no longer matches the code is
worse than no ADR at all.
