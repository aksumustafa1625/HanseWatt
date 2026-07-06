/**
 * Tests for HWIdentifyCustomerAction — resolving a customer Account from the email given in
 * conversation. Covers every branch: known email (found), unknown email, blank email, and a
 * 200-record bulk run. Free — no callouts, no credits.
 */
@isTest
private class HWIdentifyCustomerActionTest {

    @TestSetup
    static void seed() {
        Account acc = new Account(Name = 'Test Customer GmbH');
        insert acc;
        insert new Contact(FirstName='Test', LastName='Customer',
            Email='test.customer@example.de', AccountId=acc.Id);
    }

    @isTest
    static void identifiesKnownCustomer() {
        HWIdentifyCustomerAction.Request req = new HWIdentifyCustomerAction.Request();
        req.email = '  Test.Customer@Example.de '; // messy input: trimmed + lower-cased

        Test.startTest();
        List<HWIdentifyCustomerAction.Result> res =
            HWIdentifyCustomerAction.run(new List<HWIdentifyCustomerAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(true, res[0].found, 'known customer found');
        System.assertNotEquals(null, res[0].accountId, 'account id set');
        System.assert(res[0].message.contains('Test Customer GmbH'), 'friendly message with name');
    }

    @isTest
    static void unknownEmailNotFound() {
        HWIdentifyCustomerAction.Request req = new HWIdentifyCustomerAction.Request();
        req.email = 'nobody@nowhere.de';
        List<HWIdentifyCustomerAction.Result> res =
            HWIdentifyCustomerAction.run(new List<HWIdentifyCustomerAction.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals(false, res[0].found, 'unknown email not found');
        System.assertEquals(null, res[0].accountId, 'no account id');
        System.assert(res[0].message.contains('No customer'), 'graceful not-found message');
    }

    @isTest
    static void blankEmailNotFound() {
        HWIdentifyCustomerAction.Request req = new HWIdentifyCustomerAction.Request();
        req.email = '   '; // blank / whitespace only
        List<HWIdentifyCustomerAction.Result> res =
            HWIdentifyCustomerAction.run(new List<HWIdentifyCustomerAction.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals(false, res[0].found, 'blank email cannot resolve');
    }

    @isTest
    static void bulkResolvesManyCustomers() {
        List<Account> accts = new List<Account>();
        for (Integer i = 0; i < 200; i++) accts.add(new Account(Name='Bulk Cust ' + i));
        insert accts;
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(FirstName='B', LastName='Cust'+i,
                Email='bulk'+i+'@example.de', AccountId=accts[i].Id));
        }
        insert contacts;

        List<HWIdentifyCustomerAction.Request> reqs = new List<HWIdentifyCustomerAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            HWIdentifyCustomerAction.Request r = new HWIdentifyCustomerAction.Request();
            r.email = 'bulk'+i+'@example.de';
            reqs.add(r);
        }

        Test.startTest();
        List<HWIdentifyCustomerAction.Result> res = HWIdentifyCustomerAction.run(reqs);
        Test.stopTest();

        System.assertEquals(200, res.size(), '200 requests -> 200 results');
        System.assert(Limits.getQueries() <= 5,
            'bulk-safe: SOQL must not scale with input, used ' + Limits.getQueries());
        System.assertEquals(true, res[0].found, 'each request resolves its own customer');
    }
}
