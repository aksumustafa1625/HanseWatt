/**
 * Tests for HWBillingService — returning a customer's latest energy bill (newest period wins).
 * Free — no callouts, no credits. The Agentforce action is covered in HWGetLatestBillActionTest.
 */
@isTest
private class HWBillingServiceTest {

    @TestSetup
    static void seed() {
        Account withBill = new Account(Name = 'Test Bill Account');
        Account noBill   = new Account(Name = 'Test No Bill');
        insert new List<Account>{ withBill, noBill };
        // Two bills; the April one is older, the May one is the latest.
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
    static void noBillAndEmptyInputHandled() {
        // Account with no bill is absent from the result map...
        Account none = [SELECT Id FROM Account WHERE Name='Test No Bill' LIMIT 1];
        Map<Id, HWBillingService.Bill> m =
            HWBillingService.latestByAccount(new Set<Id>{ none.Id });
        System.assert(!m.containsKey(none.Id), 'account with no bill is absent from the map');
        // ...and an empty input short-circuits to an empty map (guard branch).
        System.assertEquals(0, HWBillingService.latestByAccount(new Set<Id>()).size(),
            'empty input -> empty map');
    }
}
