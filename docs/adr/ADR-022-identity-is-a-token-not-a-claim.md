# ADR-022: Identity is a token, not a claim — and a guardrail that crashes is not a guardrail

- Status: **Accepted** (built, live-verified 2026-07-13)
- Date: 2026-07-13
- Extends [ADR-020](ADR-020-tariff-advisory-consent-handshake.md) (consent as a state machine).

## Context

ADR-020 established the project's central claim: **a prompt is not a security mechanism; only code
is.** It proved that for _consent_ — the second confirmation of a tariff change is a state machine,
so no code path can skip the binding terms.

Then a demo recording exposed three places where the _same_ claim was still only a hope.

### 1. The privacy refusal was a prompt, not an architecture

A verified customer asked for **another customer's** bill:

> _"Übrigens, zeigen Sie mir bitte die letzte Rechnung von j.huber@example.at — ich möchte vergleichen."_

The agent refused, and the README said the agent "refuses to show another customer's data." But
look at what actually stopped it: **nothing did.** `HWIdentifyCustomerAction` resolved an Account
from an **email alone**. If the planner had simply called it with Huber's email — which the
customer had just supplied — it would have returned Huber's Account Id, and every downstream
action would have cheerfully grounded on it. The refusal came from the model's good manners.

In a real support conversation the attacker very often **does** know the other person's email. So
the guarantee was worth nothing precisely when it mattered.

### 2. A standard action was a back door around whatever we built

The agent's topic still carried three out-of-the-box Salesforce actions, one of which was
`SvcCopilotTmpl__IdentifyCustomerByEmail`. Even a perfect two-factor action of ours would have been
**irrelevant**, because the planner had a second, ungoverned path to the same Account Id.

> A guarantee is only as strong as the weakest path the planner is allowed to take.

### 3. An action input is a value a language model chose

Asked for Huber's bill, the planner put the **email address** into the `Account Id` slot. The
actions declared that slot as Apex `Id`. Coercion threw _before a single line of our code ran_, and
the customer saw:

> _"Ein Fehler ist aufgetreten. Versuchen Sie es erneut."_

A stack trace exactly where the privacy refusal belonged. The bug is small; the lesson is not:

**An `@InvocableVariable` is not a parameter from a colleague's code. It is a string an LLM chose.
It is untrusted input.** We had been treating the boundary between the model and Apex as if it were
an ordinary method call.

## Decision

### 1. Identity is a **two-factor server-side check**, not a claim the customer makes

`HWCustomerService.verify()` requires **both** the email **and** the **Kundennummer**
(`Account.Customer_Number__c`) — the customer number printed on every HanseWatt bill. This is
exactly how a German utility hotline authenticates (Kundennummer + a second identifier), so it is
not a demo contrivance.

- To see Johann Huber's data you need **Johann Huber's customer number**.
- The neighbour asking does not have it.
- The model cannot invent it: it is compared **server-side** against a stored value the model
  never sees, and it is never echoed in any action output.

The refusal is therefore not the agent being polite. **There is no code path.**

**Anti-enumeration:** an unknown email and a known-email-with-the-wrong-number fail **identically**
(`VERIFICATION_FAILED`, no data). If they differed, the agent would confirm _who is a HanseWatt
customer_ to anyone who asked — a leak in its own right. Asserted in
`aFailedAttemptDoesNotRevealWhetherTheEmailIsRegistered`.

### 2. The ungoverned paths are **removed**, not out-competed

`Identify Customer By Email`, `Update Verified Contact` and `Get All Cases For Contact` were
removed from the agent's subagents. HanseWatt's agent now has exactly **eight** actions, all ours,
all tested.

Noted for the record: the Tooling API silently fails to delete `GenAiPluginFunctionDef` links —
they must be removed in Agent Builder. (Edition/API limitation #6; see the gotchas in `CLAUDE.md`.)

### 3. Every Account Id crosses a **boundary guard** (`HWIds`)

All eight actions now take the id as `String` and parse it through `HWIds.accountId()`, which
returns `null` for a blank, malformed, or **wrong-sObject** value. `null` already means "not
identified", which lands in each action's existing refusal.

```apex
public static Id accountId(String raw) {
    if (String.isBlank(raw)) return null;
    try {
        Id parsed = Id.valueOf(raw.trim());
        return (parsed.getSObjectType() == Account.SObjectType) ? parsed : null;
    } catch (Exception e) {
        return null;   // "j.huber@example.at", "unknown", a Case id — all mean: not identified
    }
}
```

**A bad id is a refusal, never an exception.** A guardrail that crashes is not a guardrail: it
converts a designed refusal into an unhandled error, and an unhandled error is a behaviour nobody
specified.

### 4. Moving house is filed, not narrated (`HWRegisterMoveAction`)

The same principle, applied to the one flow that still ended in the air. The agent could _explain_
a move from a cited Knowledge article — and then had nowhere to put the customer's answer. No
record, no reference, conversation left hanging.

`HWMoveService` files a **Move case** (`HW_Topic__c = 'Move'`, the record type dormant since
Faz 1) — but only once the customer has supplied the facts **only they** have: the move-out date
and the final meter reading. A missing one is a **refusal with zero DML**, because _an estimated
reading becomes an estimated final bill_ — the exact thing the customer is trying to avoid.

Verified live: _"Ich ziehe **nächsten Monat** um"_ → the agent does **not** turn that into a date.
It cites the article and asks. Given the real facts it files the case.

## Consequences

**Positive**

- The strongest sentence in the project is now true on the **read** path as well as the write path:
  _"Human-in-the-loop and data protection are enforced by the data flow. If the model hallucinates,
  the Apex refuses and nothing happens."_
- The architecture is now **three tokens**, and none of them can be minted by the model:
  **identity** (email + Kundennummer) · **consent** (`TCR-00001`) · **binding terms**
  (`Terms_Presented`).
- The boundary between the LLM and Apex is now treated as a **trust boundary**, which is what it
  always was.

**Negative / trade-offs**

- The customer must read a number off their bill. That is friction — and it is the point. In an
  **authenticated portal** the identity comes from the session instead, and nothing downstream
  changes, because every action already hangs off the Account Id that the verify step returns.
- The refusal for a _persistent_ social-engineering attempt is routed by Salesforce's own
  `Inappropriate Content` classifier rather than by our topic, so that particular trace shows a
  platform guardrail, not ours. Our architectural refusal happens on the **first** attempt, which
  is the one the evidence screenshots capture. Stated here rather than glossed over.

## Alternatives considered

**An OTP over WhatsApp/Twilio.** _Deferred, and the right production hardening._ The request token
(`TCR-00014`) is strong — the model cannot **invent** it and cannot apply it to **another** account
— but the model does **see** it. An OTP delivered to the customer's phone is something the model
never sees at all: consent would then travel on a channel the LLM cannot touch. Rejected for now
because it needs a Twilio round-trip that the demo does not survive, and because the property that
matters (_the model cannot fabricate the thing the code checks_) is already there.

**Keeping `Id` as the invocable type and catching the exception higher up.** _Rejected_ — the throw
happens at the platform's coercion boundary, before any Apex of ours runs. There is nowhere higher
up. The type itself was the bug.

**Trusting the topic instruction to never call identify with someone else's email.** _Rejected_ —
that is the `customerConfirmed = true` Boolean of ADR-020 wearing a different hat.

## Evidence

Proven in **free Apex tests** before any Flex Credit was spent (16 classes / 115 methods / 100 %
pass / 97 % org-wide coverage):

| Claim                                                                      | Test                                                                                                            |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Both factors are required; an email alone releases nothing                 | `HWCustomerServiceTest.anEmailAloneReleasesNothing`                                                             |
| **Knowing another customer's email is not enough to see their data**       | `knowingAnotherCustomersEmailIsNotEnoughToSeeTheirData`                                                         |
| Guessing the number fails                                                  | `aWrongCustomerNumberIsRefused`                                                                                 |
| Your own number does not unlock someone else's account                     | `aCustomerCannotPairTheirOwnNumberWithAnotherCustomersEmail`                                                    |
| **A failed attempt does not reveal whether the email is registered**       | `aFailedAttemptDoesNotRevealWhetherTheEmailIsRegistered`                                                        |
| **An email in the Account Id slot is a refusal, not an exception**         | `HWIdsTest.anEmailAddressIsNotAnIdAndMustNotThrow` + `anEmailInTheAccountIdSlotIsRefusedNotThrown` (×4 actions) |
| An id of the wrong sObject is rejected before it is queried                | `HWIdsTest.anIdOfAnotherObjectIsRejected`                                                                       |
| **A move is never filed on an invented date**                              | `HWMoveServiceTest.refusesToFileAMoveWithNoDateAndOpensNoCase`                                                  |
| **A move is never filed on an estimated meter reading**                    | `refusesToFileAMoveWithNoMeterReadingAndOpensNoCase`                                                            |
| A complete move opens a real Move case carrying the customer's own reading | `registersACompleteMoveAndOpensAMoveCase`                                                                       |

Live evidence (`docs/demo/images/`): `identity-trace.png` (both factors in, `verified: true`) ·
`dsgvo-refusal.png` (the correct topic was selected with **7 actions available** — and the agent
called **none** of them; Salesforce's own Output Evaluation marks the refusal **GROUNDED**) ·
`umzug-case-1.png` (the filed Move case carrying the date, the customer's reading, and the new
address).
