/**
 * Tests for HWCaseService + HWCreateCaseAction — logging a support case for a customer.
 * Free — no callouts, no credits.
 */
@isTest
private class HWCaseServiceTest {

    @TestSetup
    static void seed() {
        insert new Account(Name = 'Test Case Account');
    }

    @isTest
    static void createsCategorizedCase() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Case Account' LIMIT 1];
        HWCreateCaseAction.Request req = new HWCreateCaseAction.Request();
        req.accountId = a.Id;
        req.topic = 'Billing';
        req.subject = 'Bill too high';
        req.description = 'Customer disputes the May bill.';
        Test.startTest();
        List<HWCreateCaseAction.Result> res =
            HWCreateCaseAction.run(new List<HWCreateCaseAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(true, res[0].created, 'case created');
        System.assertNotEquals(null, res[0].caseNumber, 'case number returned');

        Case c = [SELECT AccountId, Subject, HW_Topic__c FROM Case WHERE AccountId = :a.Id LIMIT 1];
        System.assertEquals('Billing', c.HW_Topic__c, 'topic categorized');
        System.assertEquals('Bill too high', c.Subject, 'subject set');
    }

    @isTest
    static void unknownTopicBecomesOther() {
        Account a = [SELECT Id FROM Account WHERE Name='Test Case Account' LIMIT 1];
        HWCaseService.NewCase nc = new HWCaseService.NewCase();
        nc.accountId = a.Id;
        nc.topic = 'Nonsense';
        nc.subject = 'Something';
        Test.startTest();
        List<HWCaseService.Created> made =
            HWCaseService.createCases(new List<HWCaseService.NewCase>{ nc });
        Test.stopTest();

        System.assertEquals(1, made.size());
        Case c = [SELECT HW_Topic__c FROM Case WHERE Id = :made[0].caseId];
        System.assertEquals('Other', c.HW_Topic__c, 'unknown topic falls back to Other');
    }

    @isTest
    static void nullAccountAsksToIdentify() {
        HWCreateCaseAction.Request req = new HWCreateCaseAction.Request();
        req.accountId = null;
        req.topic = 'Billing';
        List<HWCreateCaseAction.Result> res =
            HWCreateCaseAction.run(new List<HWCreateCaseAction.Request>{ req });
        System.assertEquals(1, res.size());
        System.assertEquals(false, res[0].created, 'no case without an account');
        System.assert(res[0].message.contains('identify'), 'asks to identify first');
    }
}
