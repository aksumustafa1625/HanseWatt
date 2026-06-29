/**
 * Tests for HWConsumptionService + HWExplainConsumptionAction.
 * Mirrors the seeded demo: Lena's meter spikes to 520 kWh vs a ~316 kWh average (+64.6%).
 * Free — no callouts, no credits.
 */
@isTest
private class HWConsumptionServiceTest {

    @TestSetup
    static void seed() {
        Account spike = new Account(Name = 'Test Spike Account');
        Account flat  = new Account(Name = 'Test Flat Account');
        Account none  = new Account(Name = 'Test No Data');
        insert new List<Account>{ spike, flat, none };

        Meter__c mSpike = new Meter__c(Name='M-Spike', Serial__c='T-SPK', Type__c='Strom', Account__c=spike.Id);
        Meter__c mFlat  = new Meter__c(Name='M-Flat',  Serial__c='T-FLT', Type__c='Strom', Account__c=flat.Id);
        insert new List<Meter__c>{ mSpike, mFlat };

        List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
        // Spike: prior 5 average = (310+325+300+330+315)/5 = 316; latest = 520 -> +64.6%
        Integer[] spikeVals = new Integer[]{310, 325, 300, 330, 315, 520};
        for (Integer i = 0; i < spikeVals.size(); i++) {
            reads.add(new Meter_Reading__c(Meter__c=mSpike.Id, kWh__c=spikeVals[i], Source__c='Smart',
                Read_Date__c=DateTime.now().addMonths(-(spikeVals.size()-1-i))));
        }
        // Flat: steady ~200
        Integer[] flatVals = new Integer[]{198, 202, 200, 205, 199, 201};
        for (Integer i = 0; i < flatVals.size(); i++) {
            reads.add(new Meter_Reading__c(Meter__c=mFlat.Id, kWh__c=flatVals[i], Source__c='Smart',
                Read_Date__c=DateTime.now().addMonths(-(flatVals.size()-1-i))));
        }
        insert reads;
    }

    @isTest
    static void spikeAnomalyComputed() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Spike Account' LIMIT 1];
        Test.startTest();
        Map<Id, HWConsumptionService.Anomaly> m =
            HWConsumptionService.anomaliesByAccount(new Set<Id>{ a.Id });
        Test.stopTest();

        HWConsumptionService.Anomaly an = m.get(a.Id);
        System.assertNotEquals(null, an, 'expected an anomaly result');
        System.assertEquals(520, an.latestKwh, 'latest kWh');
        System.assertEquals(316.0, an.averageKwh, 'trailing average');
        System.assert(an.anomalyPercent > 64 && an.anomalyPercent < 65,
            'anomaly should be ~64.6%, got ' + an.anomalyPercent);
        System.assert(an.explanation.contains('above'), 'explanation should flag the increase');
    }

    @isTest
    static void flatIsNormal() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Flat Account' LIMIT 1];
        Map<Id, HWConsumptionService.Anomaly> m =
            HWConsumptionService.anomaliesByAccount(new Set<Id>{ a.Id });
        HWConsumptionService.Anomaly an = m.get(a.Id);
        System.assert(Math.abs(an.anomalyPercent) < 30, 'flat usage should not be anomalous');
        System.assert(an.explanation.contains('in line'), 'explanation should say in line');
    }

    @isTest
    static void actionReturnsGroundedResult() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Spike Account' LIMIT 1];
        HWExplainConsumptionAction.Request req = new HWExplainConsumptionAction.Request();
        req.accountId = a.Id;
        Test.startTest();
        List<HWExplainConsumptionAction.Result> res =
            HWExplainConsumptionAction.run(new List<HWExplainConsumptionAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(520, res[0].latestKwh, 'latest passed through');
        System.assert(res[0].anomalyPercent > 64, 'anomaly passed through');
        System.assert(res[0].citation.contains('Data 360'), 'citation present');
    }

    @isTest
    static void noDataHandledGracefully() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Test No Data' LIMIT 1];
        HWExplainConsumptionAction.Request req = new HWExplainConsumptionAction.Request();
        req.accountId = a.Id;
        List<HWExplainConsumptionAction.Result> res =
            HWExplainConsumptionAction.run(new List<HWExplainConsumptionAction.Request>{ req });
        System.assertEquals(1, res.size());
        System.assertEquals(null, res[0].latestKwh, 'no reading -> null');
        System.assert(res[0].explanation.contains('No consumption data'), 'graceful message');
    }
}
