/**
 * Tests for HWTariffService — the money leg of the grounding story (ADR-020).
 *
 * The two things worth proving for free, before a single Flex Credit is spent:
 *   1. The Grundgebühr trap is real: a lower price-per-kWh tariff with a higher base fee
 *      is genuinely more expensive below the break-even (375 kWh/month here).
 *   2. Because of that, the recommendation is CONDITIONAL for a customer whose usage
 *      straddles the break-even (Lena: 316 baseline vs 520 latest) and UNCONDITIONAL for
 *      one who does not (Alpina: 165) — the same question, two customers, opposite answers.
 */
@isTest
private class HWTariffServiceTest {
  @TestSetup
  static void seed() {
    // The real HanseWatt tariff shape: Basis is cheap to be on, EV is cheap to use.
    // Break-even = (24.90 - 9.90) * 12 / ((0.32 - 0.28) * 12) = 375 kWh/month.
    List<Tariff__c> tariffs = new List<Tariff__c>{
      new Tariff__c(
        Name = 'Test Basis',
        Type__c = 'Strom',
        Price_per_kWh__c = 0.32,
        Base_Fee__c = 9.90
      ),
      new Tariff__c(
        Name = 'Test Oeko',
        Type__c = 'Strom',
        Price_per_kWh__c = 0.36,
        Base_Fee__c = 11.90,
        Green__c = true
      ),
      new Tariff__c(
        Name = 'Test EV',
        Type__c = 'Strom',
        Price_per_kWh__c = 0.28,
        Base_Fee__c = 24.90,
        Green__c = true
      ),
      new Tariff__c(
        Name = 'Test Gas',
        Type__c = 'Gas',
        Price_per_kWh__c = 0.11,
        Base_Fee__c = 12.90
      )
    };
    insert tariffs;
    Map<String, Id> tId = new Map<String, Id>();
    for (Tariff__c t : tariffs)
      tId.put(t.Name, t.Id);

    Account spike = new Account(Name = 'Test Spike Account'); // straddles the break-even
    Account low = new Account(Name = 'Test Low Account'); // well below it
    Account noRead = new Account(Name = 'Test No Readings');
    Account noCon = new Account(Name = 'Test No Contract');
    insert new List<Account>{ spike, low, noRead, noCon };

    Meter__c mS = new Meter__c(
      Name = 'M-S',
      Serial__c = 'T-S',
      Type__c = 'Strom',
      Account__c = spike.Id
    );
    Meter__c mL = new Meter__c(
      Name = 'M-L',
      Serial__c = 'T-L',
      Type__c = 'Strom',
      Account__c = low.Id
    );
    insert new List<Meter__c>{ mS, mL };

    List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
    // Spike: trailing average 316, latest 520 -> straddles 375
    Integer[] spikeVals = new List<Integer>{ 310, 325, 300, 330, 315, 520 };
    for (Integer i = 0; i < spikeVals.size(); i++) {
      reads.add(
        new Meter_Reading__c(
          Meter__c = mS.Id,
          kWh__c = spikeVals[i],
          Source__c = 'Smart',
          Read_Date__c = DateTime.now().addMonths(-(spikeVals.size() - 1 - i))
        )
      );
    }
    // Low: flat 165 -> always below the break-even
    for (Integer i = 0; i < 6; i++) {
      reads.add(
        new Meter_Reading__c(
          Meter__c = mL.Id,
          kWh__c = 165,
          Source__c = 'Smart',
          Read_Date__c = DateTime.now().addMonths(-(5 - i))
        )
      );
    }
    insert reads;

    insert new List<Service_Contract__c>{
      new Service_Contract__c(
        Account__c = spike.Id,
        Tariff__c = tId.get('Test Basis'),
        Status__c = 'Active'
      ),
      new Service_Contract__c(
        Account__c = low.Id,
        Tariff__c = tId.get('Test Oeko'),
        Status__c = 'Active'
      ),
      new Service_Contract__c(
        Account__c = noRead.Id,
        Tariff__c = tId.get('Test Basis'),
        Status__c = 'Active'
      )
    };
  }

  private static Id acc(String name) {
    return [SELECT Id FROM Account WHERE Name = :name LIMIT 1].Id;
  }

  // ---------- the pure arithmetic: the Grundgebühr trap itself ----------

  @isTest
  static void grundgebuehrTrapIsReal() {
    // At 316 kWh/month the "cheaper" EV tariff is actually MORE expensive.
    Decimal basisAt316 = HWTariffService.annualCost(0.32, 9.90, 316 * 12);
    Decimal evAt316 = HWTariffService.annualCost(0.28, 24.90, 316 * 12);
    System.assertEquals(1332.24, basisAt316, 'Basis at 316 kWh/month');
    System.assertEquals(1360.56, evAt316, 'EV at 316 kWh/month');
    System.assert(
      evAt316 > basisAt316,
      'the lower price-per-kWh tariff must be MORE expensive below the break-even'
    );

    // At 520 kWh/month it flips.
    Decimal basisAt520 = HWTariffService.annualCost(0.32, 9.90, 520 * 12);
    Decimal evAt520 = HWTariffService.annualCost(0.28, 24.90, 520 * 12);
    System.assertEquals(2115.60, basisAt520, 'Basis at 520 kWh/month');
    System.assertEquals(2046.00, evAt520, 'EV at 520 kWh/month');
    System.assert(evAt520 < basisAt520, 'above the break-even EV wins');
  }

  @isTest
  static void annualCostRejectsBadInput() {
    try {
      HWTariffService.annualCost(null, 9.90, 1000);
      System.assert(false, 'null price must throw');
    } catch (HWTariffService.HWTariffException e) {
      System.assert(e.getMessage().contains('requires'), 'guard message');
    }
    try {
      HWTariffService.annualCost(0.32, 9.90, -1);
      System.assert(false, 'negative consumption must throw');
    } catch (HWTariffService.HWTariffException e) {
      System.assert(e.getMessage().contains('non-negative'), 'guard message');
    }
  }

  // ---------- the conditional recommendation (the reason this is an agent, not a Flow) ----------

  @isTest
  static void recommendationIsConditionalWhenUsageStraddlesBreakEven() {
    Id a = acc('Test Spike Account');
    Test.startTest();
    HWTariffService.Recommendation r = HWTariffService.recommendByAccount(
        new Set<Id>{ a }
      )
      .get(a);
    Test.stopTest();

    System.assertEquals(true, r.found, 'recommendation produced');
    System.assertEquals(
      316.0,
      r.baselineKwhMonth,
      'trailing average, NOT the anomaly month'
    );
    System.assertEquals(520, r.currentKwhMonth, 'latest reading');
    System.assertEquals(
      'Test Basis',
      r.currentTariffName,
      'customer is on Basis today'
    );

    System.assertEquals(
      'Test Basis',
      r.bestAtBaselineName,
      'at the historical average, staying on Basis is cheapest'
    );
    System.assertEquals(
      'Test EV',
      r.bestAtCurrentName,
      'if the higher usage persists, EV becomes cheapest'
    );
    System.assertEquals(
      true,
      r.isConditional,
      'the two scenarios disagree -> the agent must NOT give a confident answer'
    );
    System.assert(
      r.assumptionBasis.contains('permanent'),
      'the assumption the answer depends on must be stated'
    );
    System.assertEquals(
      69.60,
      r.savingAtCurrent,
      'saving only if the load persists'
    );
    System.assert(
      r.comparison.contains('Test EV'),
      'the quotable comparison lists every tariff'
    );
  }

  @isTest
  static void recommendationFlipsForALowConsumptionCustomer() {
    // Same question, different customer, OPPOSITE answer — the proof the arithmetic is real.
    Id a = acc('Test Low Account');
    HWTariffService.Recommendation r = HWTariffService.recommendByAccount(
        new Set<Id>{ a }
      )
      .get(a);

    System.assertEquals(true, r.found);
    System.assertEquals(
      'Test Oeko',
      r.currentTariffName,
      'this customer is on Oeko'
    );
    System.assertEquals(
      'Test Basis',
      r.bestAtBaselineName,
      'Basis wins at 165 kWh'
    );
    System.assertEquals(
      'Test Basis',
      r.bestAtCurrentName,
      'and still wins at 165 kWh'
    );
    System.assertEquals(
      false,
      r.isConditional,
      'no anomaly -> both scenarios agree -> the recommendation is unconditional'
    );
    System.assertEquals(
      103.20,
      r.savingAtCurrent,
      'Oeko 855.60 - Basis 752.40'
    );
  }

  @isTest
  static void gasTariffIsNeverComparedAgainstAnElectricityContract() {
    Id a = acc('Test Spike Account');
    HWTariffService.Recommendation r = HWTariffService.recommendByAccount(
        new Set<Id>{ a }
      )
      .get(a);
    System.assert(
      !r.comparison.contains('Test Gas'),
      'an electricity contract must never be costed against a gas tariff'
    );
  }

  // ---------- honest refusals ----------

  @isTest
  static void noContractIsRefusedNotGuessed() {
    Id a = acc('Test No Contract');
    HWTariffService.Recommendation r = HWTariffService.recommendByAccount(
        new Set<Id>{ a }
      )
      .get(a);
    System.assertEquals(false, r.found, 'no contract -> no recommendation');
    System.assert(
      r.message.contains('active contract'),
      'says why, offers a case'
    );
  }

  @isTest
  static void noReadingsIsRefusedNotGuessed() {
    Id a = acc('Test No Readings');
    HWTariffService.Recommendation r = HWTariffService.recommendByAccount(
        new Set<Id>{ a }
      )
      .get(a);
    System.assertEquals(false, r.found, 'no consumption -> no recommendation');
    System.assert(
      r.message.contains('will not guess'),
      'refuses to invent a usage figure'
    );
  }

  @isTest
  static void emptyAndNullInputHandled() {
    System.assertEquals(
      0,
      HWTariffService.recommendByAccount(new Set<Id>()).size()
    );
    System.assertEquals(0, HWTariffService.recommendByAccount(null).size());
  }

  @isTest
  static void bulkStaysGovernorSafe() {
    // 200 customers, one catalogue query.
    List<Account> accts = new List<Account>();
    for (Integer i = 0; i < 200; i++)
      accts.add(new Account(Name = 'Bulk Tariff ' + i));
    insert accts;

    Id basis = [SELECT Id FROM Tariff__c WHERE Name = 'Test Basis' LIMIT 1].Id;
    List<Meter__c> meters = new List<Meter__c>();
    List<Service_Contract__c> contracts = new List<Service_Contract__c>();
    for (Integer i = 0; i < 200; i++) {
      meters.add(
        new Meter__c(
          Name = 'BM' + i,
          Serial__c = 'BT' + i,
          Type__c = 'Strom',
          Account__c = accts[i].Id
        )
      );
      contracts.add(
        new Service_Contract__c(
          Account__c = accts[i].Id,
          Tariff__c = basis,
          Status__c = 'Active'
        )
      );
    }
    insert meters;
    insert contracts;
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
          kWh__c = 600,
          Source__c = 'Smart',
          Read_Date__c = DateTime.now()
        )
      );
    }
    insert reads;

    Set<Id> ids = new Set<Id>();
    for (Account a : accts)
      ids.add(a.Id);

    Test.startTest();
    Map<Id, HWTariffService.Recommendation> m = HWTariffService.recommendByAccount(
      ids
    );
    Test.stopTest();

    System.assertEquals(200, m.size(), 'every customer costed');
    System.assert(
      Limits.getQueries() <= 6,
      'bulk-safe: SOQL must not scale with customer count, used ' +
      Limits.getQueries()
    );
  }
}
