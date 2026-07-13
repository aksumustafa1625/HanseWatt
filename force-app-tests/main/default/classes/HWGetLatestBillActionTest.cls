/**
 * Tests for HWGetLatestBillAction — returning a customer's most recent energy bill. Covers
 * every branch: latest bill summarised, not-yet-identified (null account), no bill on file,
 * and a 200-record bulk run. Free — no callouts, no credits.
 */
@isTest
private class HWGetLatestBillActionTest {

    @TestSetup
    static void seed() {
        Account withBill = new Account(Name = 'Test Bill Account');
        Account noBill   = new Account(Name = 'Test No Bill');
        insert new List<Account>{ withBill, noBill };
        // Two bills; April is older, May is the latest.
        insert new List<Energy_Bill__c>{
            new Energy_Bill__c(Account__c=withBill.Id, Period_Start__c=Date.newInstance(2026,4,1),
                Period_End__c=Date.newInstance(2026,4,30), Amount__c=120.00,
                Consumption_kWh__c=316, Status__c='Paid'),
            new Energy_Bill__c(Account__c=withBill.Id, Period_Start__c=Date.newInstance(2026,5,1),
                Period_End__c=Date.newInstance(2026,5,31), Amount__c=176.30,
                Consumption_kWh__c=520, Status__c='Open')
        };
    }

    @isTest
    static void summarisesLatestBill() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Bill Account' LIMIT 1];
        HWGetLatestBillAction.Request req = new HWGetLatestBillAction.Request();
        req.accountId = a.Id;

        Test.startTest();
        List<HWGetLatestBillAction.Result> res =
            HWGetLatestBillAction.run(new List<HWGetLatestBillAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(176.30, res[0].amount, 'latest (May) amount, not the April one');
        System.assertEquals(520, res[0].consumptionKwh, 'latest usage');
        System.assertEquals('Open', res[0].status, 'latest status');
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
        System.assert(res[0].summary.contains('No verified customer'), res[0].summary);
    }

    @isTest
    static void noBillHandledGracefully() {
        Account a = [SELECT Id FROM Account WHERE Name='Test No Bill' LIMIT 1];
        HWGetLatestBillAction.Request req = new HWGetLatestBillAction.Request();
        req.accountId = a.Id;
        List<HWGetLatestBillAction.Result> res =
            HWGetLatestBillAction.run(new List<HWGetLatestBillAction.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals(null, res[0].amount, 'no bill -> null amount');
        System.assert(res[0].summary.contains('No bill'), 'graceful not-found message');
    }

    @isTest
    static void bulkStaysGovernorSafe() {
        List<Account> accts = new List<Account>();
        for (Integer i = 0; i < 200; i++) accts.add(new Account(Name='Bulk Bill Acct ' + i));
        insert accts;
        List<Energy_Bill__c> bills = new List<Energy_Bill__c>();
        for (Integer i = 0; i < 200; i++) {
            bills.add(new Energy_Bill__c(Account__c=accts[i].Id,
                Period_Start__c=Date.newInstance(2026,5,1), Period_End__c=Date.newInstance(2026,5,31),
                Amount__c=100 + i, Consumption_kWh__c=300, Status__c='Open'));
        }
        insert bills;

        List<HWGetLatestBillAction.Request> reqs = new List<HWGetLatestBillAction.Request>();
        for (Account a : accts) {
            HWGetLatestBillAction.Request r = new HWGetLatestBillAction.Request();
            r.accountId = a.Id;
            reqs.add(r);
        }

        Test.startTest();
        List<HWGetLatestBillAction.Result> res = HWGetLatestBillAction.run(reqs);
        Test.stopTest();

        System.assertEquals(200, res.size(), '200 requests -> 200 results');
        System.assert(Limits.getQueries() <= 5,
            'bulk-safe: SOQL must not scale with input, used ' + Limits.getQueries());
    }

    /**
     * The demo bug: asked for another customer's bill, the planner put an EMAIL in the Account Id
     * slot. That must be a refusal, not an exception — the customer sees a privacy answer, not a
     * stack trace.
     */
    @isTest
    static void anEmailInTheAccountIdSlotIsRefusedNotThrown() {
        HWGetLatestBillAction.Request req = new HWGetLatestBillAction.Request();
        req.accountId = 'j.huber@example.at';

        Test.startTest();
        HWGetLatestBillAction.Result res =
            HWGetLatestBillAction.run(new List<HWGetLatestBillAction.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(null, res.billNumber, 'no bill may leak');
        System.assertEquals(null, res.amount);
        System.assert(res.summary.contains('No verified customer'), res.summary);
    }

}
