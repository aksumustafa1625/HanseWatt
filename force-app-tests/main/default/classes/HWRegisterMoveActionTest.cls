/**
 * HWRegisterMoveActionTest — the Agentforce surface of the move (Umzug) flow.
 * Free — no callouts, no credits. The service logic is covered in HWMoveServiceTest.
 */
@isTest
private class HWRegisterMoveActionTest {

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

    private static Id cachedAccountId;

    private static Id acc() {
        if (cachedAccountId == null) {
            cachedAccountId = [SELECT Id FROM Account WHERE Name = 'Lena Bergmann TEST' LIMIT 1].Id;
        }
        return cachedAccountId;
    }

    private static HWRegisterMoveAction.Request validRequest() {
        HWRegisterMoveAction.Request r = new HWRegisterMoveAction.Request();
        r.accountId         = acc();
        r.moveOutDate       = Date.today().addDays(45);
        r.finalMeterReading = 41250;
        r.staysCustomer     = true;
        r.newAddress        = 'Alsterufer 12, 20354 Hamburg';
        return r;
    }

    private static HWRegisterMoveAction.Result run(HWRegisterMoveAction.Request r) {
        return HWRegisterMoveAction.run(new List<HWRegisterMoveAction.Request>{ r })[0];
    }

    @isTest
    static void filesTheMoveAndReturnsACaseNumber() {
        Test.startTest();
        HWRegisterMoveAction.Result res = run(validRequest());
        Test.stopTest();

        System.assertEquals(true, res.registered);
        System.assertNotEquals(null, res.caseNumber);
        System.assertEquals(null, res.refusalReason);
        System.assertEquals('Move', [SELECT HW_Topic__c FROM Case LIMIT 1].HW_Topic__c);
    }

    @isTest
    static void refusesWithoutAMoveDateAndOpensNoCase() {
        HWRegisterMoveAction.Request r = validRequest();
        r.moveOutDate = null;

        Test.startTest();
        HWRegisterMoveAction.Result res = run(r);
        Test.stopTest();

        System.assertEquals(false, res.registered);
        System.assertEquals('MISSING_MOVE_DATE', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void refusesWithoutAMeterReadingAndOpensNoCase() {
        HWRegisterMoveAction.Request r = validRequest();
        r.finalMeterReading = null;

        Test.startTest();
        HWRegisterMoveAction.Result res = run(r);
        Test.stopTest();

        System.assertEquals(false, res.registered);
        System.assertEquals('MISSING_METER_READING', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void refusesAnUnverifiedCustomer() {
        HWRegisterMoveAction.Request r = validRequest();
        r.accountId = null;

        Test.startTest();
        HWRegisterMoveAction.Result res = run(r);
        Test.stopTest();

        System.assertEquals('NO_IDENTITY', res.refusalReason);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void bulkStaysGovernorSafe() {
        List<HWRegisterMoveAction.Request> reqs = new List<HWRegisterMoveAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            reqs.add(validRequest());
        }

        Test.startTest();
        List<HWRegisterMoveAction.Result> out = HWRegisterMoveAction.run(reqs);
        Test.stopTest();

        System.assertEquals(200, out.size());
        System.assertEquals(true, out[199].registered);
        // A CONSTANT, not a function of the 200 inputs.
        System.assert(Limits.getDmlStatements() <= 6,
            'DML must not scale with input, used ' + Limits.getDmlStatements());
        System.assert(Limits.getQueries() <= 5,
            'SOQL must not scale with input, used ' + Limits.getQueries());
    }
}
