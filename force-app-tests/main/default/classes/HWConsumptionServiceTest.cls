/**
 * Tests for HWConsumptionService — the anomaly math (latest period vs trailing average) over
 * unified meter-reading data. Mirrors the seeded demo (Lena: 520 vs 316 kWh = +64.6%). Free —
 * no callouts, no credits. The Agentforce bridge is covered in HWExplainConsumptionActionTest.
 */
@isTest
private class HWConsumptionServiceTest {

    @TestSetup
    static void seed() {
        Account spike  = new Account(Name = 'Test Spike Account');
        Account flat   = new Account(Name = 'Test Flat Account');
        Account none   = new Account(Name = 'Test No Data');   // no meter/readings
        Account single = new Account(Name = 'Test Single');    // exactly one reading
        Account drop   = new Account(Name = 'Test Drop');      // usage dropped sharply
        insert new List<Account>{ spike, flat, none, single, drop };

        Meter__c mSpike  = new Meter__c(Name='M-Spike',  Serial__c='T-SPK', Type__c='Strom', Account__c=spike.Id);
        Meter__c mFlat   = new Meter__c(Name='M-Flat',   Serial__c='T-FLT', Type__c='Strom', Account__c=flat.Id);
        Meter__c mSingle = new Meter__c(Name='M-Single', Serial__c='T-SGL', Type__c='Strom', Account__c=single.Id);
        Meter__c mDrop   = new Meter__c(Name='M-Drop',   Serial__c='T-DRP', Type__c='Strom', Account__c=drop.Id);
        insert new List<Meter__c>{ mSpike, mFlat, mSingle, mDrop };

        List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
        // Single: just one reading -> not enough history to detect a trend
        reads.add(new Meter_Reading__c(Meter__c=mSingle.Id, kWh__c=280, Source__c='Smart',
            Read_Date__c=DateTime.now()));
        // Drop: prior ~400 average, latest 190 -> well below (-50%+)
        Integer[] dropVals = new Integer[]{400, 410, 395, 405, 190};
        for (Integer i = 0; i < dropVals.size(); i++) {
            reads.add(new Meter_Reading__c(Meter__c=mDrop.Id, kWh__c=dropVals[i], Source__c='Smart',
                Read_Date__c=DateTime.now().addMonths(-(dropVals.size()-1-i))));
        }
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
    static void noReadingsAndEmptyInputHandled() {
        // Account with no readings is simply absent from the result map...
        Account none = [SELECT Id FROM Account WHERE Name = 'Test No Data' LIMIT 1];
        Map<Id, HWConsumptionService.Anomaly> m =
            HWConsumptionService.anomaliesByAccount(new Set<Id>{ none.Id });
        System.assert(!m.containsKey(none.Id), 'account with no readings is absent from the map');
        // ...and an empty/null input set short-circuits to an empty map (guard branch).
        System.assertEquals(0, HWConsumptionService.anomaliesByAccount(new Set<Id>()).size(),
            'empty input -> empty map');
        System.assertEquals(0, HWConsumptionService.anomaliesByAccount(null).size(),
            'null input -> empty map');
    }

    @isTest
    static void singleReadingNotEnoughHistory() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Single' LIMIT 1];
        HWConsumptionService.Anomaly an =
            HWConsumptionService.anomaliesByAccount(new Set<Id>{ a.Id }).get(a.Id);
        System.assertNotEquals(null, an, 'one reading still returns a result');
        System.assertEquals(280, an.latestKwh, 'latest = the only reading');
        System.assertEquals(0, an.anomalyPercent, 'no trend with a single reading');
        System.assert(an.explanation.contains('one reading'), 'explains the lack of history');
    }

    @isTest
    static void droppedUsageIsBelowAverage() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Drop' LIMIT 1];
        HWConsumptionService.Anomaly an =
            HWConsumptionService.anomaliesByAccount(new Set<Id>{ a.Id }).get(a.Id);
        System.assert(an.anomalyPercent <= -30, 'latest is well below average, got ' + an.anomalyPercent);
        System.assert(an.explanation.contains('below'), 'explanation flags the decrease');
    }

    @isTest
    static void emptyReadingListHandledDirectly() {
        // fromReadings is @TestVisible; the empty-list guard is otherwise unreachable because
        // anomaliesByAccount only computes for accounts that have readings.
        HWConsumptionService.Anomaly an = HWConsumptionService.fromReadings(new List<Decimal>());
        System.assertEquals(0, an.readingCount, 'no readings counted');
        System.assertEquals(null, an.latestKwh, 'no latest figure');
        System.assert(an.explanation.contains('No consumption data'), 'graceful empty message');
    }
}
