/**
 * Tests for HWCreateCaseAction — logging a support Case for a customer. Covers every branch:
 * a categorized Case is created, not-yet-identified (null account), and a 200-record bulk run
 * proving the action inserts in one DML. Free — no callouts, no credits.
 */
@isTest
private class HWCreateCaseActionTest {
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
    HWCreateCaseAction.Request req = new HWCreateCaseAction.Request();
    req.accountId = a.Id;
    req.topic = 'Billing';
    req.subject = 'Bill too high';
    req.description = 'Customer disputes the May bill.';

    Test.startTest();
    List<HWCreateCaseAction.Result> res = HWCreateCaseAction.run(
      new List<HWCreateCaseAction.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, res.size());
    System.assertEquals(true, res[0].created, 'case created');
    System.assertNotEquals(null, res[0].caseNumber, 'case number returned');
    System.assert(
      res[0].message.contains('opened case'),
      'friendly confirmation'
    );

    Case c = [
      SELECT AccountId, Subject, HW_Topic__c
      FROM Case
      WHERE AccountId = :a.Id
      LIMIT 1
    ];
    System.assertEquals('Billing', c.HW_Topic__c, 'topic categorized');
    System.assertEquals('Bill too high', c.Subject, 'subject set');
  }

  @isTest
  static void nullAccountAsksToIdentify() {
    HWCreateCaseAction.Request req = new HWCreateCaseAction.Request();
    req.accountId = null;
    req.topic = 'Billing';
    List<HWCreateCaseAction.Result> res = HWCreateCaseAction.run(
      new List<HWCreateCaseAction.Request>{ req }
    );

    System.assertEquals(1, res.size());
    System.assertEquals(false, res[0].created, 'no case without an account');
    System.assert(
      res[0].message.contains('No verified customer'),
      res[0].message
    );
  }

  @isTest
  static void bulkInsertsInOneDml() {
    Account a = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Case Account'
      LIMIT 1
    ];
    List<HWCreateCaseAction.Request> reqs = new List<HWCreateCaseAction.Request>();
    for (Integer i = 0; i < 200; i++) {
      HWCreateCaseAction.Request r = new HWCreateCaseAction.Request();
      r.accountId = a.Id;
      r.topic = 'Complaint';
      r.subject = 'Bulk case ' + i;
      reqs.add(r);
    }

    Test.startTest();
    List<HWCreateCaseAction.Result> res = HWCreateCaseAction.run(reqs);
    Test.stopTest();

    System.assertEquals(200, res.size(), '200 requests -> 200 results');
    System.assert(
      Limits.getDmlStatements() <= 5,
      'bulk-safe: DML must not scale with input, used ' +
      Limits.getDmlStatements()
    );
    System.assertEquals(
      200,
      [SELECT COUNT() FROM Case WHERE AccountId = :a.Id],
      '200 cases inserted for the customer'
    );
  }

  /** An email in the Account Id slot opens NO case. */
  @isTest
  static void anEmailInTheAccountIdSlotIsRefusedNotThrown() {
    HWCreateCaseAction.Request req = new HWCreateCaseAction.Request();
    req.accountId = 'j.huber@example.at';
    req.topic = 'Billing';
    req.subject = 'should never exist';

    Test.startTest();
    HWCreateCaseAction.Result res = HWCreateCaseAction.run(
      new List<HWCreateCaseAction.Request>{ req }
    )[0];
    Test.stopTest();

    System.assertEquals(false, res.created);
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Case WHERE Subject = 'should never exist']
    );
  }
}
