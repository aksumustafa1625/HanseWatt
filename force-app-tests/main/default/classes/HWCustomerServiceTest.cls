/**
 * Tests for HWCustomerService + HWIdentifyCustomerAction — resolving a customer Account from
 * the email given in conversation. Free — no callouts, no credits.
 */
@isTest
private class HWCustomerServiceTest {

    @TestSetup
    static void seed() {
        Account acc = new Account(Name = 'Test Customer GmbH');
        insert acc;
        insert new Contact(FirstName='Test', LastName='Customer',
            Email='test.customer@example.de', AccountId=acc.Id);
    }

    @isTest
    static void resolvesByEmailCaseInsensitive() {
        Test.startTest();
        Map<String, HWCustomerService.Customer> m =
            HWCustomerService.byEmail(new Set<String>{ '  Test.Customer@Example.de ' });
        Test.stopTest();

        HWCustomerService.Customer c = m.get('test.customer@example.de');
        System.assertNotEquals(null, c, 'email should resolve (trimmed + lower-cased)');
        System.assertEquals('Test Customer GmbH', c.accountName, 'account name returned');
        System.assertNotEquals(null, c.accountId, 'account id returned');
    }

    @isTest
    static void actionIdentifiesKnownCustomer() {
        HWIdentifyCustomerAction.Request req = new HWIdentifyCustomerAction.Request();
        req.email = 'test.customer@example.de';
        Test.startTest();
        List<HWIdentifyCustomerAction.Result> res =
            HWIdentifyCustomerAction.run(new List<HWIdentifyCustomerAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(true, res[0].found, 'known customer found');
        System.assertNotEquals(null, res[0].accountId, 'account id set');
        System.assert(res[0].message.contains('Test Customer GmbH'), 'friendly message');
    }

    @isTest
    static void actionHandlesUnknownEmail() {
        HWIdentifyCustomerAction.Request req = new HWIdentifyCustomerAction.Request();
        req.email = 'nobody@nowhere.de';
        List<HWIdentifyCustomerAction.Result> res =
            HWIdentifyCustomerAction.run(new List<HWIdentifyCustomerAction.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals(false, res[0].found, 'unknown email not found');
        System.assertEquals(null, res[0].accountId, 'no account id');
        System.assert(res[0].message.contains('No customer'), 'graceful not-found message');
    }
}
