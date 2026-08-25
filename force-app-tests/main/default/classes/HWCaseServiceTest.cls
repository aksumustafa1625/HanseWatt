/**
 * Tests for HWCaseService — inserting a categorized support Case for a customer (as user, with
 * HW_Topic__c categorization). Free — no callouts, no credits. The Agentforce action is covered
 * in HWCreateCaseActionTest.
 */
@isTest
private class HWCaseServiceTest {
  @TestSetup
  static void seed() {
    insert new Account(Name = 'Test Case Account');
  }

  @isTest
  static void createsCategorizedCase() {
    Account a = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Case Account'
      LIMIT 1
    ];
    HWCaseService.NewCase nc = new HWCaseService.NewCase();
    nc.accountId = a.Id;
    nc.topic = 'Billing';
    nc.subject = 'Bill too high';
    nc.description = 'Customer disputes the May bill.';

    Test.startTest();
    List<HWCaseService.Created> made = HWCaseService.createCases(
      new List<HWCaseService.NewCase>{ nc }
    );
    Test.stopTest();

    System.assertEquals(1, made.size());
    System.assertNotEquals(null, made[0].caseNumber, 'case number returned');
    Case c = [
      SELECT AccountId, Subject, HW_Topic__c
      FROM Case
      WHERE Id = :made[0].caseId
    ];
    System.assertEquals(a.Id, c.AccountId, 'linked to the customer');
    System.assertEquals('Billing', c.HW_Topic__c, 'topic categorized');
    System.assertEquals('Bill too high', c.Subject, 'subject set');
  }

  @isTest
  static void unknownTopicBecomesOther() {
    Account a = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Case Account'
      LIMIT 1
    ];
    HWCaseService.NewCase nc = new HWCaseService.NewCase();
    nc.accountId = a.Id;
    nc.topic = 'Nonsense';
    nc.subject = 'Something';

    Test.startTest();
    List<HWCaseService.Created> made = HWCaseService.createCases(
      new List<HWCaseService.NewCase>{ nc }
    );
    Test.stopTest();

    System.assertEquals(1, made.size());
    Case c = [SELECT HW_Topic__c FROM Case WHERE Id = :made[0].caseId];
    System.assertEquals(
      'Other',
      c.HW_Topic__c,
      'unknown topic falls back to Other'
    );
  }

  @isTest
  static void emptyInputHandled() {
    Test.startTest();
    List<HWCaseService.Created> made = HWCaseService.createCases(
      new List<HWCaseService.NewCase>()
    );
    Test.stopTest();
    System.assertEquals(
      0,
      made.size(),
      'empty input -> nothing created (guard branch)'
    );
  }
}
