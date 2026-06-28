# ADR-010: Multi-currency (EUR corporate + CHF) over single-currency or ACM

- Status: Accepted (built — Faz 1, 2026-06-28)
- Date: 2026-06-28

## Context

HanseWatt serves a DACH spread: Germany + Austria (EUR) and Switzerland (CHF — Studio
Alpina, Zürich). Bills and tariffs must display in the customer's currency to be credible.
Salesforce offers three postures: single currency, **multi-currency** (per-record ISO
currency + static conversion), and **Advanced Currency Management (ACM)** (dated exchange
rates). Multi-currency activation is **irreversible**, so the choice is consequential.

## Decision

Activate **Salesforce multi-currency**; set **corporate currency = EUR**; add **CHF** as an
active currency (static rate ≈ 0.96 CHF/EUR). **Do not** enable Advanced Currency Management.

Implementation note (Faz 1): `CurrencyType` rejects Apex DML (`Insert not allowed`), but the
REST API accepts it — CHF was created via `sf data create record --sobject CurrencyType`.

## Consequences

**Positive:** Swiss records (Studio Alpina) bill in CHF, DE/AT in EUR — a cheap, strong
"this person knows DACH" signal on every `Energy_Bill__c` / `Tariff__c`. Static rates are
exactly enough for a service demo.

**Negative / Trade-offs:** activation is irreversible (accepted consciously by the org
owner); multi-currency adds a CurrencyIsoCode dimension to reports and roll-ups.

## Alternatives Considered

### Single currency (EUR) + manual CHF note
Rejected: not credible for a CH customer; loses the DACH-breadth signal.

### Advanced Currency Management (dated exchange rates)
Rejected: ACM is **Opportunity/revenue-oriented** (HanseWatt is a *service* project, no
Opportunities), adds complexity, disables some currency roll-up summaries, and is hard to
reverse. Our service objects need no historical dated rates.

## References

- `PROJECT_BLUEPRINT.md` §14, `PHASES.md` Faz 1 step C7
- `docs/manual-setup/limits.md` (currency/locale note)
