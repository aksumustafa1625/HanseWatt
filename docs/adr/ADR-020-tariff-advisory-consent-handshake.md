# ADR-020: Tariff advisory — a conditional recommendation, and consent as a state machine

- Status: **Accepted** (built, live-verified 2026-07-12)
- Date: 2026-07-12
- Supersedes nothing. Extends [ADR-006](ADR-006-apex-invocable-vs-flow-actions.md) (action
  standard) and [ADR-007](ADR-007-grounding-knowledge-data360-retriever-split.md) (grounding split).

## Context

Up to this point the agent could **explain** a problem (the +64.6 % consumption anomaly,
grounded in Data 360), **answer** a procedure question (from a cited Knowledge article), and
**log** a case. It could not **solve** anything. A reviewer's fair question was: *"the agent
tells the customer their bill is high — and then what?"*

The obvious next capability is the one every DACH energy retailer actually runs: a
**Tarifwechsel** (tariff change). But it raises two problems that are much harder than they
first look, and both of them are the reason this ADR exists.

### Problem 1 — a tariff recommendation is not arithmetic, it is judgement

German electricity tariffs are priced as **Arbeitspreis** (per kWh) **plus Grundpreis** (a fixed
monthly base fee). So a tariff with a *lower* per-kWh price can be **more expensive** for a given
customer, because its base fee is higher. "Switch me to a cheaper tariff" therefore cannot be
answered by picking the lowest headline price.

Worse, in HanseWatt's real seeded catalogue the break-even between the standard tariff and the
EV tariff is **375 kWh/month** — and Lena's usage *straddles it*: her trailing average is 316
kWh/month, but her latest month was 520 kWh (the anomaly the agent just explained).

So the honest answer genuinely depends on a fact the agent **does not know**: is the new load
permanent (a wallbox / heat pump) or was it a one-off?

- At 316 kWh/month → **Strom Basis** is cheapest; the EV tariff would cost **~28 € more**.
- At 520 kWh/month → **EV-Tarif** is cheapest; it saves **~70 €/year**.

A naive implementation would annualise the *anomaly month* (520 × 12) and confidently recommend
a switch. That is exactly the incoherence a Principal Engineer would catch: *the same agent that
just flagged 520 as an anomaly cannot two messages later treat it as the customer's normal usage.*

### Problem 2 — this is the first action that mutates a contract

Everything the agent did before was either a read or an append (a Case). A tariff change is a
**contractual, financial, effectively irreversible** act. It is exactly the class of action that
enterprises — and DACH enterprises in particular — will not let an LLM take unsupervised.

The tempting design is:

```apex
public class Request {
    @InvocableVariable public Id accountId;
    @InvocableVariable public Boolean customerConfirmed;   // <-- the trap
}
...
if (customerConfirmed != true) return refuse();
```

and then to write in the README: *"human-in-the-loop is enforced in code, not in the prompt."*

**That claim is false, and it is the single weakest point in the design.** The Boolean is
**filled in by the model**. The topic instruction says "set it only after the customer confirms",
so the thing deciding whether consent happened is still the LLM's judgement. A jailbroken,
confused, or simply hallucinating model can set `customerConfirmed = true` with no confirmation
at all. What the code enforces is not the *existence of consent* — only that *a flag was filled
in*. It is prompt-wishing hiding behind a parameter.

## Decision

### 1. The recommendation is **conditional**, and the agent must say so

`HWTariffService` costs **every comparable tariff in BOTH scenarios** — at the customer's
trailing average and at their latest consumption — and returns:

- `bestAtBaseline` / `bestAtCurrent` (which may differ),
- `savingAtBaseline` / `savingAtCurrent`,
- `isConditional` — true when the two scenarios disagree,
- `assumptionBasis` — the fact the answer depends on, in plain language.

When `isConditional` is true the topic instruction requires the agent to **state the assumption
and ask** ("is the higher consumption permanent — for example a wallbox?") rather than
recommending confidently. The agent's honesty is therefore not a tone-of-voice choice; it is
carried in the action's contract.

Gas tariffs are never costed against an electricity contract (type-matched comparison).

**This is why the capability is an agent action and not a Flow.** A Flow can do the arithmetic.
It cannot notice that the arithmetic is *undetermined* and ask the customer the one question that
resolves it.

### 2. Consent is a **server-issued, expiring, account-scoped state machine** — not a Boolean

The change is split into a two-step handshake across two actions:

**Step 1 — `HWProposeTariffChangeAction`** (benign write)
- Costs the catalogue, and if a genuinely cheaper tariff exists, inserts a
  **`Tariff_Change_Request__c`** with the proposed tariff, the quoted saving, the assumption the
  quote depends on, `Status = Proposed`, and `Expires_At = now + 30 min`.
- The platform mints the record's auto-number (**`TCR-00001`**). That number is returned to the
  agent. It never touches the customer's contract.

**Step 2 — `HWConfirmTariffChangeAction`** (the only mutating action in HanseWatt)
- Applies a change **only if** the presented request number:
  1. **exists**,
  2. **belongs to this account** (`WHERE Name IN :nums AND Account__c IN :accIds`),
  3. is still **`Proposed`**,
  4. has **not expired**.
- Otherwise it refuses with a machine-readable `refusalReason` and **runs zero DML**.

**Why this is structural and the Boolean was not:** the request number exists *only* in the
output of step 1. A model that skipped the proposal has nothing to present. A model that
hallucinates consent and invents `TCR-99999` is refused because no such row exists. A model that
replays *another customer's* valid number is refused because the query is account-scoped. The
guarantee is enforced by the **data flow**, not by hoping the prompt held.

Consent is also now **auditable** (who, when, which proposal, which quoted saving, on what stated
assumption) and **perishable** (a stale proposal must be re-quoted, which re-states the assumption
to the customer). Confirming twice is **idempotent**: it reports the original outcome and opens
no second case.

### 3. The billing-system boundary is an explicit seam, not a hand-wave

On success the action (a) switches `Service_Contract__c.Tariff__c`, (b) opens a categorized
`Case` carrying the quoted saving and the assumption, so a human owns the follow-through, and
(c) publishes **`Tariff_Change_Requested__e`**.

That Platform Event is the **integration seam**: in production a MuleSoft subscriber forwards it
to **SAP IS-U**, which owns the actual billing registration. In this org the far side of the seam
is simulated — but the seam itself is real, published, and source-controlled. Saying *"I built the
integration point; the far side is simulated"* is a materially different claim from *"I simulated
it"*.

## Consequences

**Positive**
- The agent now completes the arc: **explain → quantify → solve**, with a € figure a CFO
  understands that the model **cannot invent** (it is arithmetic over real `Tariff__c` rows at the
  customer's real meter readings). This is the **money leg** of the grounding story:
  *figures → Data 360 · procedure → Knowledge · money → tariff arithmetic.*
- The strongest sentence in the project is now defensible rather than aspirational:
  **"An irreversible, contractual action. Human-in-the-loop is enforced by the data flow — if the
  model hallucinates a 'Ja' and invents a proposal number, the Apex refuses and nothing happens."**
- Two dormant Faz-1 objects (`Tariff__c`, `Service_Contract__c`) are finally load-bearing.
- The cross-customer guarantee is now structural on the *write* path too: a proposal minted for
  one customer can never be applied to another.
- Deliberate friction on a binding action reads as maturity, not as a missing feature.

**Negative / trade-offs**
- Two actions instead of one, plus a custom object and a platform event. More moving parts.
- The handshake costs a conversational turn. That is the point, but it is a cost.
- The agent still updates a **CRM-side** contract record; the real billing system is not called.
  Documented above and in `STATUS.md`, not glossed over.
- Consent expires after 30 minutes. A slow customer must be re-quoted. Accepted: perishable
  consent is safer than stale consent.

## Alternatives considered

**A `customerConfirmed` Boolean on the write action.** *Rejected* — the model fills it in, so it
guarantees only that a flag was set, not that consent occurred. It is the trap this ADR exists to
avoid, and it is the first thing a Principal Engineer would attack.

**An out-of-band confirmation (emailed link or 6-digit code).** *Deferred.* Architecturally this
is the most rigorous option — consent then travels on a channel the model cannot touch at all. It
was rejected **for now** because it requires an email/Flow round-trip that destroys the 30-second
demo, and because the server-issued request number already provides the property that matters:
**the model cannot fabricate the thing the code checks.** Noted as the production hardening step.

**Checking a `Consent__c` record instead.** *Rejected as insufficient on its own* — a standing
consent record proves the customer *once* agreed to tariff-change processing; it does not prove
they agreed to **this** switch, at **this** price, on **this** assumption. The request record does.
(`Consent__c` remains available as an additional gate.)

**Not acting at all — propose and escalate to a human only.** *Rejected as the default*, because
it gives up the demo's payoff and the dormant infrastructure stays dormant. But note the design
**degrades into exactly this** whenever the guardrails fire: no proposal, invented number, foreign
number, or expired number all end in "nothing changed, shall I open a case?" — which is the honest
fallback, reached automatically.

## Evidence

Proven in **free Apex tests** before a single Flex Credit was spent (25 tests; full suite 74 tests,
100 % pass, 97 % org-wide coverage):

| Claim | Test |
|---|---|
| The Grundgebühr trap is real (break-even 375 kWh/month) | `HWTariffServiceTest.grundgebuehrTrapIsReal` |
| The recommendation is conditional when usage straddles it | `recommendationIsConditionalWhenUsageStraddlesBreakEven` |
| Same question, different customer, **opposite** answer | `recommendationFlipsForALowConsumptionCustomer` |
| A gas tariff is never costed against an electricity contract | `gasTariffIsNeverComparedAgainstAnElectricityContract` |
| No consumption / no contract → refuses, does not guess | `noReadingsIsRefusedNotGuessed`, `noContractIsRefusedNotGuessed` |
| The proposal number is issued by the platform, not the model | `mintsAServerIssuedRequestNumber` |
| Already on the cheapest tariff → no switch is manufactured | `doesNotInventASwitchForACustomerAlreadyOnTheCheapestTariff` |
| **Invented number → refused, contract UNCHANGED** | `refusesAnInventedRequestNumber` |
| **Another customer's number → refused, contract UNCHANGED** | `refusesAnotherCustomersRequestNumber` |
| **Expired proposal → refused, marked Expired, UNCHANGED** | `refusesAnExpiredProposal` |
| Valid proposal → contract switched, Case opened, event published | `appliesAValidProposalAndOpensACase` |
| Confirming twice changes nothing twice | `secondConfirmIsIdempotent` |
| Bulk-safe (200 records, no DML/SOQL scaling) | `bulkStaysGovernorSafe` (×3) |
