/**
 * HWMoveServiceTest — a move is a billing event, so the facts it rests on must come from the
 * CUSTOMER. These tests are about what the service refuses to do: it will not file a move on an
 * invented date or an estimated meter reading, because either one becomes an invented final bill.
 *
 * Free — no callouts, no credits.
 */
@isTest
private class HWMoveServiceTest {

    private static Id accountId;

    @TestSetup
    static void seed() {
        Account a = new Account(Name = 'Lena Bergmann TEST', Customer_Number__c = 'HW-900001');
        insert a;

        Tariff__c t = new Tariff__c(
            Name = 'Basis TEST', Price_per_kWh__c = 0.32, Base_Fee__c = 9.90, Type__c = 'Electricity');
        insert t;

        Meter__c m = new Meter__c(Name = 'MTR-TEST-1', Account__c = a.Id);
        insert m;

        insert new Service_Contract__c(
            Account__c = a.Id, Tariff__c = t.Id, Meter__c = m.Id, Status__c = 'Active');
    }

    private static Id acc() {
        if (accountId == null) {
            accountId = [SELECT Id FROM Account WHERE Name = 'Lena Bergmann TEST' LIMIT 1].Id;
        }
        return accountId;
    }

    private static HWMoveService.MoveRequest validRequest() {
        HWMoveService.MoveRequest r = new HWMoveService.MoveRequest();
        r.accountId         = acc();
        r.moveOutDate       = Date.today().addDays(45);
        r.finalMeterReading = 41250;
        r.staysCustomer     = true;
        r.newAddress        = 'Alsterufer 12, 20354 Hamburg';
        return r;
    }

    private static HWMoveService.MoveResult run(HWMoveService.MoveRequest r) {
        return HWMoveService.registerMoves(new List<HWMoveService.MoveRequest>{ r })[0];
    }

    @isTest
    static void registersACompleteMoveAndOpensAMoveCase() {
        Test.startTest();
        HWMoveService.MoveResult res = run(validRequest());
        Test.stopTest();

        System.assertEquals(true, res.registered, res.message);
        System.assertNotEquals(null, res.caseNumber, 'the customer gets a reference');

        Case c = [SELECT HW_Topic__c, AccountId, Subject, Description FROM Case WHERE Id = :res.caseId];
        System.assertEquals('Move', c.HW_Topic__c, 'the dormant Move topic is finally used');
        System.assertEquals(acc(), c.AccountId);
        System.assert(c.Description.contains('41250'), 'the customer\'s own reading is on the case');
        System.assert(c.Description.contains('Alsterufer'), 'the new address is on the case');
        System.assert(c.Description.contains('not estimated'), c.Description);
    }

    /** The whole point. "Next month" is not a date, and the agent must not turn it into one. */
    @isTest
    static void refusesToFileAMoveWithNoDateAndOpensNoCase() {
        HWMoveService.MoveRequest r = validRequest();
        r.moveOutDate = null;

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals(false, res.registered);
        System.assertEquals('MISSING_MOVE_DATE', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case], 'ZERO DML — no case may be opened');
        System.assert(res.message.contains('Do NOT guess'), res.message);
    }

    /** An estimated reading is an estimated final bill. Refuse it. */
    @isTest
    static void refusesToFileAMoveWithNoMeterReadingAndOpensNoCase() {
        HWMoveService.MoveRequest r = validRequest();
        r.finalMeterReading = null;

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals(false, res.registered);
        System.assertEquals('MISSING_METER_READING', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
        System.assert(res.message.contains('NEVER estimate'), res.message);
    }

    @isTest
    static void refusesAMoveDateInThePast() {
        HWMoveService.MoveRequest r = validRequest();
        r.moveOutDate = Date.today().addDays(-1);

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals('MOVE_DATE_IN_THE_PAST', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void refusesAMoveDateTooFarAhead() {
        HWMoveService.MoveRequest r = validRequest();
        r.moveOutDate = Date.today().addMonths(HWMoveService.MAX_MONTHS_AHEAD).addDays(1);

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals('MOVE_DATE_TOO_FAR', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void refusesANegativeMeterReading() {
        HWMoveService.MoveRequest r = validRequest();
        r.finalMeterReading = -5;

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals('IMPLAUSIBLE_METER_READING', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    /** Staying a customer without saying where is not a move we can act on. */
    @isTest
    static void refusesToKeepSupplyWithoutANewAddress() {
        HWMoveService.MoveRequest r = validRequest();
        r.newAddress = null;

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals('MISSING_NEW_ADDRESS', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    /** Leaving HanseWatt is a legitimate outcome — and it needs no new address. */
    @isTest
    static void aCustomerWhoLeavesIsRegisteredWithoutANewAddress() {
        HWMoveService.MoveRequest r = validRequest();
        r.staysCustomer = false;
        r.newAddress    = null;

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals(true, res.registered);
        Case c = [SELECT Description FROM Case WHERE Id = :res.caseId];
        System.assert(c.Description.contains('Supply ends'), c.Description);
    }

    @isTest
    static void refusesAnUnverifiedCustomer() {
        HWMoveService.MoveRequest r = validRequest();
        r.accountId = null;

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals('NO_IDENTITY', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void refusesAnAccountWithNoContract() {
        Account other = new Account(Name = 'No Contract TEST');
        insert other;

        HWMoveService.MoveRequest r = validRequest();
        r.accountId = other.Id;

        Test.startTest();
        HWMoveService.MoveResult res = run(r);
        Test.stopTest();

        System.assertEquals('NO_CONTRACT', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void emptyInputIsSafe() {
        System.assertEquals(0, HWMoveService.registerMoves(null).size());
        System.assertEquals(0, HWMoveService.registerMoves(new List<HWMoveService.MoveRequest>()).size());
    }

    @isTest
    static void bulkStaysGovernorSafe() {
        List<HWMoveService.MoveRequest> reqs = new List<HWMoveService.MoveRequest>();
        for (Integer i = 0; i < 200; i++) {
            reqs.add(validRequest());
        }

        Test.startTest();
        List<HWMoveService.MoveResult> out = HWMoveService.registerMoves(reqs);
        Test.stopTest();

        System.assertEquals(200, out.size());
        System.assertEquals(true, out[199].registered);
        System.assertEquals(200, [SELECT COUNT() FROM Case]);
        // The number is a CONSTANT, not a function of the 200 inputs — that is the whole claim.
        System.assert(Limits.getDmlStatements() <= 6,
            'DML must not scale with input, used ' + Limits.getDmlStatements());
    }
}
