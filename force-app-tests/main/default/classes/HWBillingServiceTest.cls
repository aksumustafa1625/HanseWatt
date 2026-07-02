/**
 * Tests for HWBillingService + HWGetLatestBillAction — returning a customer's latest energy
 * bill. Free — no callouts, no credits.
 */
@isTest
private class HWBillingServiceTest {

    @TestSetup
    static void seed() {
        Account acc = new Account(Name = 'Test Bill Account');
        insert acc;
        // Two bills; the April one is older, the May one is the latest.
        insert new List<Energy_Bill__c>{
            new Energy_Bill__c(Account__c=acc.Id, Period_Start__c=Date.newInstance(2026,4,1),
                Period_End__c=Date.newInstance(2026,4,30), Amount__c=120.00,
                Consumption_kWh__c=316, Status__c='Paid'),
            new Energy_Bill__c(Account__c=acc.Id, Period_Start__c=Date.newInstance(2026,5,1),
                Period_End__c=Date.newInstance(2026,5,31), Amount__c=176.30,
                Consumption_kWh__c=520, Status__c='Open')
        };
    }

    @isTest
    static void returnsLatestBill() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Bill Account' LIMIT 1];
        Test.startTest();
        Map<Id, HWBillingService.Bill> m =
            HWBillingService.latestByAccount(new Set<Id>{ a.Id });
        Test.stopTest();

        HWBillingService.Bill b = m.get(a.Id);
        System.assertNotEquals(null, b, 'expected a bill');
        System.assertEquals(176.30, b.amount, 'latest (May) amount, not the April one');
        System.assertEquals(520, b.consumptionKwh, 'latest usage');
        System.assertEquals('Open', b.status, 'latest status');
    }

    @isTest
    static void actionSummarisesBill() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Bill Account' LIMIT 1];
        HWGetLatestBillAction.Request req = new HWGetLatestBillAction.Request();
        req.accountId = a.Id;
        Test.startTest();
        List<HWGetLatestBillAction.Result> res =
            HWGetLatestBillAction.run(new List<HWGetLatestBillAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(176.30, res[0].amount, 'amount passed through');
        System.assertEquals('Open', res[0].status, 'status passed through');
        System.assert(res[0].summary.contains('176.3'), 'summary quotes the amount');
        System.assert(res[0].citation.contains('billing'), 'citation present');
    }

    @isTest
    static void nullAccountAsksToIdentify() {
        HWGetLatestBillAction.Request req = new HWGetLatestBillAction.Request();
        req.accountId = null;
        List<HWGetLatestBillAction.Result> res =
            HWGetLatestBillAction.run(new List<HWGetLatestBillAction.Request>{ req });
        System.assertEquals(1, res.size());
        System.assertEquals(null, res[0].amount, 'no amount without an account');
        System.assert(res[0].summary.contains('identify'), 'should ask to identify first');
    }
}
