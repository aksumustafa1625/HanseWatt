/**
 * Tests for HWConfirmTariffChangeAction — the consent guardrail (ADR-020).
 *
 * This is the most important test class in HanseWatt. It proves the two claims a Principal
 * Engineer attacks hardest:
 *
 *   1. "A `customerConfirmed = true` Boolean is not a structural guardrail — the model fills
 *       it in." Correct. So consent here is a **server-issued, expiring, account-scoped
 *       request number**. Presented with nothing, an invented number, another customer's
 *       number, or a stale one, the Apex refuses and **ZERO DML runs** — asserted by checking
 *       the contract is unchanged in every refusal path.
 *
 *   2. "An instruction that says 'ask twice' is also prompt-wishing — nothing stops the model
 *       acting on the first Ja." Correct. So the second confirmation is a **state machine**:
 *
 *          Proposed --confirm#1--> Terms_Presented --confirm#2--> Applied
 *                   (applies NOTHING;                (applies)
 *                    returns the binding terms)
 *
 *      `firstConfirmationPresentsTermsAndChangesNothing` proves the first call is incapable
 *      of changing the contract. The customer is therefore guaranteed to see the binding
 *      terms — not because the agent was asked nicely, but because no code path skips them.
 */
@isTest
private class HWConfirmTariffChangeActionTest {
  @TestSetup
  static void seed() {
    List<Tariff__c> tariffs = new List<Tariff__c>{
      new Tariff__c(
        Name = 'Test Basis',
        Type__c = 'Strom',
        Price_per_kWh__c = 0.32,
        Base_Fee__c = 9.90
      ),
      new Tariff__c(
        Name = 'Test EV',
        Type__c = 'Strom',
        Price_per_kWh__c = 0.28,
        Base_Fee__c = 24.90
      )
    };
    insert tariffs;
    Id basis = tariffs[0].Id;

    Account lena = new Account(Name = 'Test Lena'); // high usage -> EV proposal
    Account huber = new Account(Name = 'Test Huber'); // a DIFFERENT customer
    insert new List<Account>{ lena, huber };

    Meter__c mL = new Meter__c(
      Name = 'M-L',
      Serial__c = 'T-L',
      Type__c = 'Strom',
      Account__c = lena.Id
    );
    Meter__c mH = new Meter__c(
      Name = 'M-H',
      Serial__c = 'T-H',
      Type__c = 'Strom',
      Account__c = huber.Id
    );
    insert new List<Meter__c>{ mL, mH };

    List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
    for (Integer i = 0; i < 5; i++) {
      reads.add(
        new Meter_Reading__c(
          Meter__c = mL.Id,
          kWh__c = 600,
          Source__c = 'Smart',
          Read_Date__c = DateTime.now().addMonths(-(5 - i))
        )
      );
      reads.add(
        new Meter_Reading__c(
          Meter__c = mH.Id,
          kWh__c = 600,
          Source__c = 'Smart',
          Read_Date__c = DateTime.now().addMonths(-(5 - i))
        )
      );
    }
    insert reads;

    insert new List<Service_Contract__c>{
      new Service_Contract__c(
        Account__c = lena.Id,
        Tariff__c = basis,
        Status__c = 'Active'
      ),
      new Service_Contract__c(
        Account__c = huber.Id,
        Tariff__c = basis,
        Status__c = 'Active'
      )
    };
  }

  private static Id acc(String n) {
    return [SELECT Id FROM Account WHERE Name = :n LIMIT 1].Id;
  }

  private static String tariffOf(Id accountId) {
    return [
      SELECT Tariff__r.Name
      FROM Service_Contract__c
      WHERE Account__c = :accountId
      LIMIT 1
    ]
    .Tariff__r.Name;
  }

  private static String statusOf(String tcrNumber) {
    return [
      SELECT Status__c
      FROM Tariff_Change_Request__c
      WHERE Name = :tcrNumber
    ]
    .Status__c;
  }

  /** Mint a real proposal the way the agent would: via the propose action. */
  private static String propose(Id accountId) {
    HWProposeTariffChangeAction.Request p = new HWProposeTariffChangeAction.Request();
    p.accountId = accountId;
    return HWProposeTariffChangeAction.run(
        new List<HWProposeTariffChangeAction.Request>{ p }
      )[0]
      .requestNumber;
  }

  private static HWConfirmTariffChangeAction.Result confirm(
    Id accountId,
    String tcrNumber
  ) {
    HWConfirmTariffChangeAction.Request c = new HWConfirmTariffChangeAction.Request();
    c.accountId = accountId;
    c.requestNumber = tcrNumber;
    return HWConfirmTariffChangeAction.run(
      new List<HWConfirmTariffChangeAction.Request>{ c }
    )[0];
  }

  // ====== THE SECOND-CONFIRMATION GATE: the first call is incapable of applying ======

  @isTest
  static void firstConfirmationPresentsTermsAndChangesNothing() {
    // The model may believe one "Ja" is enough. The CODE does not let it be enough.
    Id lena = acc('Test Lena');
    String tcrNumber = propose(lena);

    Test.startTest();
    HWConfirmTariffChangeAction.Result r = confirm(lena, tcrNumber);
    Test.stopTest();

    System.assertEquals(
      false,
      r.applied,
      'the FIRST confirmation must never apply the change'
    );
    System.assertEquals(
      true,
      r.awaitingFinalConfirmation,
      'it must ask for an explicit, binding confirmation instead'
    );
    System.assertNotEquals(
      null,
      r.bindingTerms,
      'and hand the agent the binding terms'
    );
    System.assert(
      r.bindingTerms.contains('BINDING'),
      'which say the change is binding'
    );
    System.assert(
      r.bindingTerms.contains('next billing period'),
      'and when it takes effect'
    );
    System.assert(
      r.bindingTerms.contains(tcrNumber),
      'and which proposal they belong to'
    );
    System.assert(
      r.message.contains('NOTHING HAS BEEN CHANGED YET'),
      'the agent is told plainly not to claim the tariff was changed'
    );

    System.assertEquals(
      'Test Basis',
      tariffOf(lena),
      'THE CONTRACT MUST BE UNCHANGED'
    );
    System.assertEquals(
      'Terms_Presented',
      statusOf(tcrNumber),
      'the proposal only advanced a state'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Case WHERE AccountId = :lena],
      'and no case was opened'
    );
  }

  @isTest
  static void secondConfirmationAppliesAndOpensACase() {
    Id lena = acc('Test Lena');
    String tcrNumber = propose(lena);
    confirm(lena, tcrNumber); // #1 — terms presented, nothing applied
    System.assertEquals(
      'Test Basis',
      tariffOf(lena),
      'still unchanged after the first Ja'
    );

    Test.startTest();
    HWConfirmTariffChangeAction.Result r = confirm(lena, tcrNumber); // #2 — the binding one
    Test.stopTest();

    System.assertEquals(true, r.applied, 'the SECOND confirmation applies it');
    System.assertEquals(
      'Test EV',
      r.newTariff,
      'switched to the recommended tariff'
    );
    System.assertNotEquals(
      null,
      r.annualSaving,
      'the quoted saving is carried through'
    );
    System.assertNotEquals(
      null,
      r.caseNumber,
      'a human owns the follow-through'
    );

    System.assertEquals(
      'Test EV',
      tariffOf(lena),
      'the contract really changed'
    );
    System.assertEquals(
      'Applied',
      statusOf(tcrNumber),
      'the proposal is spent'
    );

    Case c = [
      SELECT Subject, HW_Topic__c, Description
      FROM Case
      WHERE AccountId = :lena
      LIMIT 1
    ];
    System.assertEquals(
      'TariffChange',
      c.HW_Topic__c,
      'the case is categorized'
    );
    System.assert(
      c.Description.contains(tcrNumber),
      'the case cites the proposal it acted on'
    );
    System.assert(
      c.Description.contains('binding terms were presented'),
      'and records that the customer saw and accepted the binding terms'
    );
  }

  // ============ THE REFUSALS: every one of these must change NOTHING ============

  @isTest
  static void refusesWithoutARequestNumber() {
    Id lena = acc('Test Lena');
    Test.startTest();
    HWConfirmTariffChangeAction.Result r = confirm(lena, null);
    Test.stopTest();

    System.assertEquals(false, r.applied, 'no proposal -> no change');
    System.assertEquals('NO_REQUEST_NUMBER', r.refusalReason);
    System.assertEquals(
      'Test Basis',
      tariffOf(lena),
      'the contract must be UNCHANGED'
    );
  }

  @isTest
  static void refusesAnInventedRequestNumber() {
    // The model hallucinates consent and invents a plausible-looking number.
    Id lena = acc('Test Lena');
    Test.startTest();
    HWConfirmTariffChangeAction.Result r = confirm(lena, 'TCR-99999');
    Test.stopTest();

    System.assertEquals(
      false,
      r.applied,
      'a fabricated number must never work'
    );
    System.assertEquals('UNKNOWN_OR_FOREIGN_REQUEST', r.refusalReason);
    System.assertEquals(
      'Test Basis',
      tariffOf(lena),
      'the contract must be UNCHANGED'
    );
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Tariff_Change_Request__c
        WHERE Status__c = 'Applied'
      ],
      'nothing was applied'
    );
  }

  @isTest
  static void refusesAnotherCustomersRequestNumber() {
    // THE cross-customer test: Huber's valid proposal, presented on Lena's session.
    Id lena = acc('Test Lena');
    Id huber = acc('Test Huber');
    String hubersNumber = propose(huber);
    System.assertNotEquals(
      null,
      hubersNumber,
      'Huber really does have a valid proposal'
    );

    Test.startTest();
    HWConfirmTariffChangeAction.Result r = confirm(lena, hubersNumber);
    Test.stopTest();

    System.assertEquals(
      false,
      r.applied,
      'a proposal minted for one customer can NEVER be applied to another'
    );
    System.assertEquals('UNKNOWN_OR_FOREIGN_REQUEST', r.refusalReason);
    System.assertEquals('Test Basis', tariffOf(lena), 'Lena unchanged');
    System.assertEquals(
      'Test Basis',
      tariffOf(huber),
      'and Huber unchanged too'
    );
    System.assertEquals(
      'Proposed',
      statusOf(hubersNumber),
      'and Huber\'s proposal was not even advanced a state'
    );
  }

  @isTest
  static void refusesAnExpiredProposal() {
    Id lena = acc('Test Lena');
    String tcrNumber = propose(lena);
    // Consent is perishable: age the proposal past its window.
    Tariff_Change_Request__c tcr = [
      SELECT Id, Expires_At__c
      FROM Tariff_Change_Request__c
      WHERE Name = :tcrNumber
      LIMIT 1
    ];
    tcr.Expires_At__c = System.now().addMinutes(-1);
    update tcr;

    Test.startTest();
    HWConfirmTariffChangeAction.Result r = confirm(lena, tcrNumber);
    Test.stopTest();

    System.assertEquals(
      false,
      r.applied,
      'a stale proposal must not be applied'
    );
    System.assertEquals('EXPIRED', r.refusalReason);
    System.assertEquals(
      'Test Basis',
      tariffOf(lena),
      'the contract must be UNCHANGED'
    );
    System.assertEquals(
      'Expired',
      statusOf(tcrNumber),
      'and the proposal is marked expired so it can never be replayed'
    );
  }

  @isTest
  static void refusesWithoutIdentity() {
    HWConfirmTariffChangeAction.Result r = confirm(null, 'TCR-00001');
    System.assertEquals(false, r.applied);
    System.assertEquals('NO_IDENTITY', r.refusalReason);
  }

  @isTest
  static void furtherConfirmationsAreIdempotent() {
    Id lena = acc('Test Lena');
    String tcrNumber = propose(lena);
    confirm(lena, tcrNumber); // #1 terms presented
    confirm(lena, tcrNumber); // #2 applies

    Test.startTest();
    HWConfirmTariffChangeAction.Result again = confirm(lena, tcrNumber); // #3
    Test.stopTest();

    System.assertEquals(true, again.applied, 'reports the original outcome');
    System.assert(again.message.contains('already'), 'and says so plainly');
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Case WHERE AccountId = :lena],
      'confirming again must NOT open a second case or re-apply the change'
    );
  }

  @isTest
  static void bulkStaysGovernorSafe() {
    Id lena = acc('Test Lena');
    String tcrNumber = propose(lena);
    confirm(lena, tcrNumber); // advance it to Terms_Presented so the bulk run can apply it once

    List<HWConfirmTariffChangeAction.Request> reqs = new List<HWConfirmTariffChangeAction.Request>();
    for (Integer i = 0; i < 200; i++) {
      HWConfirmTariffChangeAction.Request c = new HWConfirmTariffChangeAction.Request();
      c.accountId = lena;
      c.requestNumber = (i == 0) ? tcrNumber : 'TCR-8' + i; // one real, 199 invented
      reqs.add(c);
    }

    Test.startTest();
    List<HWConfirmTariffChangeAction.Result> res = HWConfirmTariffChangeAction.run(
      reqs
    );
    Test.stopTest();

    System.assertEquals(200, res.size());
    System.assertEquals(
      true,
      res[0].applied,
      'the one real, terms-accepted proposal applied'
    );
    System.assertEquals(false, res[1].applied, 'the invented ones did not');
    // The point is not the absolute number — it is that it is CONSTANT. 200 requests cost
    // the same handful of statements as one: one update per object, one publish.
    System.assert(
      Limits.getDmlStatements() <= 10,
      'bulk-safe: DML must not scale with input, used ' +
      Limits.getDmlStatements()
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Case WHERE AccountId = :lena],
      'exactly one case, from the one legitimate confirmation'
    );
  }
}
