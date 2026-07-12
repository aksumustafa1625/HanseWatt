/**
 * Tests for HWProposeTariffChangeAction — step 1 of the consent handshake (ADR-020).
 *
 * Proves that the action (a) mints a real, server-issued request number the model cannot
 * invent, (b) surfaces the CONDITIONAL flag when the two consumption scenarios disagree,
 * and (c) refuses to invent a switch for a customer who is already on the cheapest tariff.
 */
@isTest
private class HWProposeTariffChangeActionTest {

    @TestSetup
    static void seed() {
        List<Tariff__c> tariffs = new List<Tariff__c>{
            new Tariff__c(Name='Test Basis', Type__c='Strom', Price_per_kWh__c=0.32, Base_Fee__c=9.90),
            new Tariff__c(Name='Test EV',    Type__c='Strom', Price_per_kWh__c=0.28, Base_Fee__c=24.90)
        };
        insert tariffs;
        Id basis = tariffs[0].Id;

        Account spike   = new Account(Name='Test Spike');    // 316 baseline / 520 latest -> conditional
        Account cheapest= new Account(Name='Test Cheapest'); // low usage, already on Basis
        insert new List<Account>{ spike, cheapest };

        Meter__c mS = new Meter__c(Name='M-S', Serial__c='P-S', Type__c='Strom', Account__c=spike.Id);
        Meter__c mC = new Meter__c(Name='M-C', Serial__c='P-C', Type__c='Strom', Account__c=cheapest.Id);
        insert new List<Meter__c>{ mS, mC };

        List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
        Integer[] spikeVals = new Integer[]{310, 325, 300, 330, 315, 520};
        for (Integer i = 0; i < spikeVals.size(); i++) {
            reads.add(new Meter_Reading__c(Meter__c=mS.Id, kWh__c=spikeVals[i], Source__c='Smart',
                Read_Date__c=DateTime.now().addMonths(-(spikeVals.size()-1-i))));
        }
        for (Integer i = 0; i < 6; i++) {
            reads.add(new Meter_Reading__c(Meter__c=mC.Id, kWh__c=150, Source__c='Smart',
                Read_Date__c=DateTime.now().addMonths(-(5-i))));
        }
        insert reads;

        insert new List<Service_Contract__c>{
            new Service_Contract__c(Account__c=spike.Id,    Tariff__c=basis, Status__c='Active'),
            new Service_Contract__c(Account__c=cheapest.Id, Tariff__c=basis, Status__c='Active')
        };
    }

    private static Id acc(String n) { return [SELECT Id FROM Account WHERE Name=:n LIMIT 1].Id; }

    private static List<HWProposeTariffChangeAction.Result> run(Id accountId) {
        HWProposeTariffChangeAction.Request req = new HWProposeTariffChangeAction.Request();
        req.accountId = accountId;
        return HWProposeTariffChangeAction.run(
            new List<HWProposeTariffChangeAction.Request>{ req });
    }

    @isTest
    static void mintsAServerIssuedRequestNumber() {
        Id a = acc('Test Spike');
        Test.startTest();
        HWProposeTariffChangeAction.Result r = run(a)[0];
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assertEquals('Test Basis', r.currentTariff);
        System.assertEquals('Test EV', r.recommendedTariff, 'EV wins if the higher usage persists');
        System.assertEquals(69.60, r.annualSaving, 'the saving is arithmetic over real tariff rows');
        System.assertNotEquals(null, r.requestNumber, 'a request number was minted');
        System.assert(r.requestNumber.startsWith('TCR-'),
            'and it is issued by the platform, not by the model: ' + r.requestNumber);
        System.assert(r.citation.contains('Tariff'), 'the money is cited to its source');

        // The proposal really exists, is open, and expires.
        Tariff_Change_Request__c tcr = [
            SELECT Status__c, Expires_At__c, Annual_Saving__c, Assumption_Basis__c, Account__c
            FROM Tariff_Change_Request__c WHERE Name = :r.requestNumber];
        System.assertEquals('Proposed', tcr.Status__c);
        System.assertEquals(a, tcr.Account__c, 'scoped to this customer only');
        System.assert(tcr.Expires_At__c > System.now(), 'consent is perishable');
        System.assertNotEquals(null, tcr.Assumption_Basis__c, 'what the customer was told is persisted');
    }

    @isTest
    static void surfacesTheConditionalFlagAndTheAssumption() {
        HWProposeTariffChangeAction.Result r = run(acc('Test Spike'))[0];
        System.assertEquals(true, r.isConditional,
            'at 316 baseline Basis is cheaper; at 520 EV is — the agent must not be confident');
        System.assert(r.assumptionBasis.contains('permanent'),
            'the agent is handed the assumption it must state out loud');
        System.assert(r.message.contains('CONDITIONAL'),
            'and is explicitly told to ask before confirming');
        System.assert(r.comparison.contains('base fee'),
            'the Grundgebuehr is visible in the comparison, not hidden');
    }

    @isTest
    static void doesNotInventASwitchForACustomerAlreadyOnTheCheapestTariff() {
        HWProposeTariffChangeAction.Result r = run(acc('Test Cheapest'))[0];
        System.assertEquals(true, r.found, 'we still costed the tariffs');
        System.assertEquals(null, r.requestNumber, 'but no proposal is minted');
        System.assert(r.message.contains('already on the cheapest'),
            'the agent is told to say so instead of manufacturing a switch');
        System.assertEquals(0, [SELECT COUNT() FROM Tariff_Change_Request__c],
            'nothing was written');
    }

    @isTest
    static void nullAccountAsksToIdentify() {
        HWProposeTariffChangeAction.Result r = run(null)[0];
        System.assertEquals(false, r.found);
        System.assert(r.message.contains('identify'), 'asks to identify first');
    }

    @isTest
    static void bulkStaysGovernorSafe() {
        Id a = acc('Test Spike');
        List<HWProposeTariffChangeAction.Request> reqs =
            new List<HWProposeTariffChangeAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            HWProposeTariffChangeAction.Request req = new HWProposeTariffChangeAction.Request();
            req.accountId = a;
            reqs.add(req);
        }
        Test.startTest();
        List<HWProposeTariffChangeAction.Result> res = HWProposeTariffChangeAction.run(reqs);
        Test.stopTest();

        System.assertEquals(200, res.size(), '200 requests -> 200 results');
        System.assert(Limits.getDmlStatements() <= 5,
            'bulk-safe: DML must not scale with input, used ' + Limits.getDmlStatements());
    }
}
