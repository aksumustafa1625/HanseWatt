/**
 * Tests for HWExplainConsumptionAction — the Agentforce-callable consumption-anomaly bridge.
 * Covers every branch: grounded anomaly, not-yet-identified (null account), no-data, and a
 * 200-record bulk run proving the action stays governor-safe (one query for N customers).
 * Free — no callouts, no credits. Mirrors the seeded demo (Lena: 520 vs 316 kWh = +64.6%).
 */
@isTest
private class HWExplainConsumptionActionTest {
  @TestSetup
  static void seed() {
    Account spike = new Account(Name = 'Test Spike Account');
    Account none = new Account(Name = 'Test No Data');
    insert new List<Account>{ spike, none };

    Meter__c m = new Meter__c(
      Name = 'M-Spike',
      Serial__c = 'T-SPK',
      Type__c = 'Strom',
      Account__c = spike.Id
    );
    insert m;

    // Prior 5 average = (310+325+300+330+315)/5 = 316; latest = 520 -> +64.6%
    Integer[] vals = new List<Integer>{ 310, 325, 300, 330, 315, 520 };
    List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
    for (Integer i = 0; i < vals.size(); i++) {
      reads.add(
        new Meter_Reading__c(
          Meter__c = m.Id,
          kWh__c = vals[i],
          Source__c = 'Smart',
          Read_Date__c = DateTime.now().addMonths(-(vals.size() - 1 - i))
        )
      );
    }
    insert reads;
  }

  @isTest
  static void returnsGroundedAnomaly() {
    Account a = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Spike Account'
      LIMIT 1
    ];
    HWExplainConsumptionAction.Request req = new HWExplainConsumptionAction.Request();
    req.accountId = a.Id;

    Test.startTest();
    List<HWExplainConsumptionAction.Result> res = HWExplainConsumptionAction.run(
      new List<HWExplainConsumptionAction.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, res.size(), 'one result per request');
    System.assertEquals(520, res[0].latestKwh, 'latest kWh passed through');
    System.assertEquals(
      316.0,
      res[0].averageKwh,
      'trailing average passed through'
    );
    System.assert(
      res[0].anomalyPercent > 64 && res[0].anomalyPercent < 65,
      'anomaly should be ~64.6%, got ' + res[0].anomalyPercent
    );
    System.assert(
      res[0].citation.contains('Data 360'),
      'grounded citation present'
    );
    System.assert(
      res[0].explanation.contains('above'),
      'explanation flags the increase'
    );
  }

  @isTest
  static void nullAccountAsksToIdentify() {
    HWExplainConsumptionAction.Request req = new HWExplainConsumptionAction.Request();
    req.accountId = null; // customer not identified yet
    List<HWExplainConsumptionAction.Result> res = HWExplainConsumptionAction.run(
      new List<HWExplainConsumptionAction.Request>{ req }
    );

    System.assertEquals(1, res.size());
    System.assertEquals(null, res[0].latestKwh, 'no figure without an account');
    System.assertEquals('', res[0].citation, 'no citation without an account');
    System.assert(
      res[0].explanation.contains('No verified customer'),
      res[0].explanation
    );
  }

  @isTest
  static void noConsumptionDataHandledGracefully() {
    Account a = [SELECT Id FROM Account WHERE Name = 'Test No Data' LIMIT 1];
    HWExplainConsumptionAction.Request req = new HWExplainConsumptionAction.Request();
    req.accountId = a.Id;
    List<HWExplainConsumptionAction.Result> res = HWExplainConsumptionAction.run(
      new List<HWExplainConsumptionAction.Request>{ req }
    );

    System.assertEquals(1, res.size());
    System.assertEquals(null, res[0].latestKwh, 'no reading -> null figure');
    System.assert(
      res[0].explanation.contains('No consumption data'),
      'graceful message'
    );
  }

  @isTest
  static void bulkStaysGovernorSafe() {
    // 200 distinct customers, each with a meter + two readings.
    List<Account> accts = new List<Account>();
    for (Integer i = 0; i < 200; i++)
      accts.add(new Account(Name = 'Bulk Acct ' + i));
    insert accts;

    List<Meter__c> meters = new List<Meter__c>();
    for (Integer i = 0; i < 200; i++) {
      meters.add(
        new Meter__c(
          Name = 'BM' + i,
          Serial__c = 'B' + i,
          Type__c = 'Strom',
          Account__c = accts[i].Id
        )
      );
    }
    insert meters;

    List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
    for (Integer i = 0; i < 200; i++) {
      reads.add(
        new Meter_Reading__c(
          Meter__c = meters[i].Id,
          kWh__c = 300,
          Source__c = 'Smart',
          Read_Date__c = DateTime.now().addMonths(-1)
        )
      );
      reads.add(
        new Meter_Reading__c(
          Meter__c = meters[i].Id,
          kWh__c = 450,
          Source__c = 'Smart',
          Read_Date__c = DateTime.now()
        )
      );
    }
    insert reads;

    List<HWExplainConsumptionAction.Request> reqs = new List<HWExplainConsumptionAction.Request>();
    for (Account a : accts) {
      HWExplainConsumptionAction.Request r = new HWExplainConsumptionAction.Request();
      r.accountId = a.Id;
      reqs.add(r);
    }

    Test.startTest();
    List<HWExplainConsumptionAction.Result> res = HWExplainConsumptionAction.run(
      reqs
    );
    Test.stopTest();

    System.assertEquals(200, res.size(), '200 requests -> 200 results');
    System.assert(
      Limits.getQueries() <= 5,
      'bulk-safe: SOQL must not scale with input, used ' + Limits.getQueries()
    );
    System.assertEquals(
      450,
      res[0].latestKwh,
      'each result grounded on its own customer'
    );
  }

  /** An email in the Account Id slot is a refusal, not an exception. See HWIds. */
  @isTest
  static void anEmailInTheAccountIdSlotIsRefusedNotThrown() {
    HWExplainConsumptionAction.Request req = new HWExplainConsumptionAction.Request();
    req.accountId = 'j.huber@example.at';

    Test.startTest();
    HWExplainConsumptionAction.Result res = HWExplainConsumptionAction.run(
      new List<HWExplainConsumptionAction.Request>{ req }
    )[0];
    Test.stopTest();

    System.assertEquals(null, res.latestKwh, 'no figure may leak');
    System.assert(
      res.explanation.contains('No verified customer'),
      res.explanation
    );
  }
}
