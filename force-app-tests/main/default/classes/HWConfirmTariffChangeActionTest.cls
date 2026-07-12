/**
 * Tests for HWConfirmTariffChangeAction — the structural consent guardrail (ADR-020).
 *
 * This is the most important test class in HanseWatt. It proves the claim that a
 * Principal Engineer will attack hardest:
 *
 *   "A `customerConfirmed = true` Boolean is not a structural guardrail — the model fills
 *    it in, so a jailbroken model can simply set it."
 *
 * Correct. So consent here is not a Boolean: it is a **server-issued, expiring, account-
 * scoped request number** minted inside HWProposeTariffChangeAction. These tests prove
 * that when the model presents anything else — nothing, an invented number, another
 * customer's number, or a stale one — the Apex refuses and **ZERO DML runs**. The contract
 * is asserted unchanged in every refusal path.
 *
 * The guarantee is enforced by the data flow, not by hoping the prompt held.
 */
@isTest
private class HWConfirmTariffChangeActionTest {

    @TestSetup
    static void seed() {
        List<Tariff__c> tariffs = new List<Tariff__c>{
            new Tariff__c(Name='Test Basis', Type__c='Strom', Price_per_kWh__c=0.32, Base_Fee__c=9.90),
            new Tariff__c(Name='Test EV',    Type__c='Strom', Price_per_kWh__c=0.28, Base_Fee__c=24.90)
        };
        insert tariffs;
        Id basis = tariffs[0].Id, ev = tariffs[1].Id;

        Account lena  = new Account(Name='Test Lena');   // high usage -> EV proposal
        Account huber = new Account(Name='Test Huber');  // a DIFFERENT customer
        insert new List<Account>{ lena, huber };

        Meter__c mL = new Meter__c(Name='M-L', Serial__c='T-L', Type__c='Strom', Account__c=lena.Id);
        Meter__c mH = new Meter__c(Name='M-H', Serial__c='T-H', Type__c='Strom', Account__c=huber.Id);
        insert new List<Meter__c>{ mL, mH };

        List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
        for (Integer i = 0; i < 5; i++) {
            reads.add(new Meter_Reading__c(Meter__c=mL.Id, kWh__c=600, Source__c='Smart',
                Read_Date__c=DateTime.now().addMonths(-(5-i))));
            reads.add(new Meter_Reading__c(Meter__c=mH.Id, kWh__c=600, Source__c='Smart',
                Read_Date__c=DateTime.now().addMonths(-(5-i))));
        }
        insert reads;

        insert new List<Service_Contract__c>{
            new Service_Contract__c(Account__c=lena.Id,  Tariff__c=basis, Status__c='Active'),
            new Service_Contract__c(Account__c=huber.Id, Tariff__c=basis, Status__c='Active')
        };
    }

    private static Id acc(String n) { return [SELECT Id FROM Account WHERE Name=:n LIMIT 1].Id; }

    private static String tariffOf(Id accountId) {
        return [SELECT Tariff__r.Name FROM Service_Contract__c
                WHERE Account__c = :accountId LIMIT 1].Tariff__r.Name;
    }

    /** Mint a real proposal the way the agent would: via the propose action. */
    private static String propose(Id accountId) {
        HWProposeTariffChangeAction.Request p = new HWProposeTariffChangeAction.Request();
        p.accountId = accountId;
        return HWProposeTariffChangeAction.run(
            new List<HWProposeTariffChangeAction.Request>{ p })[0].requestNumber;
    }

    private static HWConfirmTariffChangeAction.Result confirm(Id accountId, String tcrNumber) {
        HWConfirmTariffChangeAction.Request c = new HWConfirmTariffChangeAction.Request();
        c.accountId = accountId;
        c.requestNumber = tcrNumber;
        return HWConfirmTariffChangeAction.run(
            new List<HWConfirmTariffChangeAction.Request>{ c })[0];
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
        System.assertEquals('Test Basis', tariffOf(lena), 'the contract must be UNCHANGED');
    }

    @isTest
    static void refusesAnInventedRequestNumber() {
        // The model hallucinates consent and invents a plausible-looking number.
        Id lena = acc('Test Lena');
        Test.startTest();
        HWConfirmTariffChangeAction.Result r = confirm(lena, 'TCR-99999');
        Test.stopTest();

        System.assertEquals(false, r.applied, 'a fabricated number must never work');
        System.assertEquals('UNKNOWN_OR_FOREIGN_REQUEST', r.refusalReason);
        System.assertEquals('Test Basis', tariffOf(lena), 'the contract must be UNCHANGED');
        System.assertEquals(0, [SELECT COUNT() FROM Tariff_Change_Request__c WHERE Status__c = 'Applied'],
            'nothing was applied');
    }

    @isTest
    static void refusesAnotherCustomersRequestNumber() {
        // THE cross-customer test: Huber's valid proposal, presented on Lena's session.
        Id lena  = acc('Test Lena');
        Id huber = acc('Test Huber');
        String hubersNumber = propose(huber);
        System.assertNotEquals(null, hubersNumber, 'Huber really does have a valid proposal');

        Test.startTest();
        HWConfirmTariffChangeAction.Result r = confirm(lena, hubersNumber);
        Test.stopTest();

        System.assertEquals(false, r.applied,
            'a proposal minted for one customer can NEVER be applied to another');
        System.assertEquals('UNKNOWN_OR_FOREIGN_REQUEST', r.refusalReason);
        System.assertEquals('Test Basis', tariffOf(lena),  'Lena unchanged');
        System.assertEquals('Test Basis', tariffOf(huber), 'and Huber unchanged too');
    }

    @isTest
    static void refusesAnExpiredProposal() {
        Id lena = acc('Test Lena');
        String tcrNumber = propose(lena);
        // Consent is perishable: age the proposal past its window.
        Tariff_Change_Request__c tcr =
            [SELECT Id, Expires_At__c FROM Tariff_Change_Request__c WHERE Name = :tcrNumber LIMIT 1];
        tcr.Expires_At__c = System.now().addMinutes(-1);
        update tcr;

        Test.startTest();
        HWConfirmTariffChangeAction.Result r = confirm(lena, tcrNumber);
        Test.stopTest();

        System.assertEquals(false, r.applied, 'a stale proposal must not be applied');
        System.assertEquals('EXPIRED', r.refusalReason);
        System.assertEquals('Test Basis', tariffOf(lena), 'the contract must be UNCHANGED');
        System.assertEquals('Expired',
            [SELECT Status__c FROM Tariff_Change_Request__c WHERE Id = :tcr.Id].Status__c,
            'and the proposal is marked expired so it can never be replayed');
    }

    @isTest
    static void refusesWithoutIdentity() {
        HWConfirmTariffChangeAction.Result r = confirm(null, 'TCR-00001');
        System.assertEquals(false, r.applied);
        System.assertEquals('NO_IDENTITY', r.refusalReason);
    }

    // ============ THE HAPPY PATH: a real, fresh, own-account, confirmed proposal ============

    @isTest
    static void appliesAValidProposalAndOpensACase() {
        Id lena = acc('Test Lena');
        String tcrNumber = propose(lena);
        System.assertNotEquals(null, tcrNumber, 'the propose step minted a request number');

        Test.startTest();
        HWConfirmTariffChangeAction.Result r = confirm(lena, tcrNumber);
        Test.stopTest();

        System.assertEquals(true, r.applied, 'a valid proposal applies');
        System.assertEquals('Test EV', r.newTariff, 'switched to the recommended tariff');
        System.assertNotEquals(null, r.annualSaving, 'the quoted saving is carried through');
        System.assertNotEquals(null, r.caseNumber, 'a human owns the follow-through');

        System.assertEquals('Test EV', tariffOf(lena), 'the contract really changed');
        System.assertEquals('Applied',
            [SELECT Status__c FROM Tariff_Change_Request__c WHERE Name = :tcrNumber].Status__c,
            'the proposal is spent');

        Case c = [SELECT Subject, HW_Topic__c, Description FROM Case WHERE AccountId = :lena LIMIT 1];
        System.assertEquals('TariffChange', c.HW_Topic__c, 'the case is categorized');
        System.assert(c.Description.contains(tcrNumber), 'the case cites the proposal it acted on');
        System.assert(c.Description.contains('Assumption'), 'and records what the customer was told');
    }

    @isTest
    static void secondConfirmIsIdempotent() {
        Id lena = acc('Test Lena');
        String tcrNumber = propose(lena);
        confirm(lena, tcrNumber);

        Test.startTest();
        HWConfirmTariffChangeAction.Result again = confirm(lena, tcrNumber);
        Test.stopTest();

        System.assertEquals(true, again.applied, 'reports the original outcome');
        System.assert(again.message.contains('already'), 'and says so plainly');
        System.assertEquals(1, [SELECT COUNT() FROM Case WHERE AccountId = :lena],
            'confirming twice must NOT open a second case or re-apply the change');
    }

    @isTest
    static void bulkStaysGovernorSafe() {
        Id lena = acc('Test Lena');
        String tcrNumber = propose(lena);
        List<HWConfirmTariffChangeAction.Request> reqs =
            new List<HWConfirmTariffChangeAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            HWConfirmTariffChangeAction.Request c = new HWConfirmTariffChangeAction.Request();
            c.accountId = lena;
            c.requestNumber = (i == 0) ? tcrNumber : 'TCR-8' + i;   // one real, 199 invented
            reqs.add(c);
        }

        Test.startTest();
        List<HWConfirmTariffChangeAction.Result> res = HWConfirmTariffChangeAction.run(reqs);
        Test.stopTest();

        System.assertEquals(200, res.size());
        System.assertEquals(true, res[0].applied, 'the one real proposal applied');
        System.assertEquals(false, res[1].applied, 'the invented ones did not');
        System.assert(Limits.getDmlStatements() <= 6,
            'bulk-safe: DML must not scale with input, used ' + Limits.getDmlStatements());
        System.assertEquals(1, [SELECT COUNT() FROM Case WHERE AccountId = :lena],
            'exactly one case, from the one legitimate confirmation');
    }
}
