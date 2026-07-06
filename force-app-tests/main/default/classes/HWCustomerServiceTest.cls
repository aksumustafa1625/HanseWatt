/**
 * Tests for HWCustomerService — resolving a customer Account from an email (Contact → Account),
 * trimmed + case-insensitive. Free — no callouts, no credits. The Agentforce action is covered
 * in HWIdentifyCustomerActionTest.
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
    static void unknownAndEmptyInputReturnEmpty() {
        // Unknown email resolves to nothing...
        Map<String, HWCustomerService.Customer> m =
            HWCustomerService.byEmail(new Set<String>{ 'nobody@nowhere.de' });
        System.assert(!m.containsKey('nobody@nowhere.de'), 'unknown email not resolved');
        // ...and an empty input short-circuits to an empty map (guard branch).
        System.assertEquals(0, HWCustomerService.byEmail(new Set<String>()).size(),
            'empty input -> empty map');
    }
}
