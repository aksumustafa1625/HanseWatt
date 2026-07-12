/**
 * seed_tariff_pricing.apex — make the Grundgebühr trap real.
 *
 * German EV / Wallbox tariffs genuinely carry a HIGHER Grundpreis (monthly base fee)
 * in exchange for a lower Arbeitspreis (price per kWh): the utility has to provision
 * a separate registered load. Our seeded EV tariff had a base fee of only €12.90,
 * which made it the cheapest tariff for *every* customer — so the comparison was
 * decorative, not decisive.
 *
 * With a realistic €24.90 base fee the arithmetic becomes genuinely decision-critical:
 *
 *   Break-even = (24.90 - 9.90) * 12 / ((0.32 - 0.28) * 12) = 375 kWh / month
 *
 *   Lena, trailing average 316 kWh  -> Basis is CHEAPER (EV would cost ~€28 MORE)
 *   Lena, if the 520 kWh persists   -> EV-Tarif is cheaper (~€70/year saving)
 *   Studio Alpina, 165 kWh          -> Basis is cheaper (the recommendation FLIPS)
 *   Müller GmbH, 4762 kWh           -> EV-Tarif wins by a wide margin
 *
 * That is what lets the agent give a *conditional* recommendation and name its own
 * assumption ("only if the new load is permanent") instead of confidently guessing.
 *
 * Idempotent — safe to re-run.
 */
List<Tariff__c> toUpdate = new List<Tariff__c>();

for (Tariff__c t : [
        SELECT Id, Name, Type__c, Price_per_kWh__c, Base_Fee__c
        FROM Tariff__c
        WHERE Name LIKE '%EV%'
]) {
    t.Price_per_kWh__c = 0.28;   // low Arbeitspreis (night / EV charging)
    t.Base_Fee__c      = 24.90;  // high Grundpreis (separate registered load)
    toUpdate.add(t);
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
}

System.debug('=== HanseWatt Strom tariffs after seeding ===');
for (Tariff__c t : [
        SELECT Name, Type__c, Price_per_kWh__c, Base_Fee__c
        FROM Tariff__c
        WHERE Type__c = 'Strom'
        ORDER BY Name
]) {
    System.debug(t.Name + ' | ' + t.Price_per_kWh__c + ' EUR/kWh | Grundgebühr ' + t.Base_Fee__c + ' EUR/Monat');
}

// Prove the break-even so the demo story is arithmetic, not assertion.
Decimal basisPrice = 0.32, basisFee = 9.90;
Decimal evPrice    = 0.28, evFee    = 24.90;
Decimal breakEven  = ((evFee - basisFee) * 12) / ((basisPrice - evPrice) * 12);
System.debug('=== Break-even: ' + breakEven.setScale(0) + ' kWh/month ===');
for (Integer kwh : new List<Integer>{ 165, 316, 520 }) {
    Decimal basisAnnual = (basisPrice * kwh * 12) + (basisFee * 12);
    Decimal evAnnual    = (evPrice    * kwh * 12) + (evFee    * 12);
    System.debug(kwh + ' kWh/month -> Basis ' + basisAnnual.setScale(2)
        + ' EUR | EV ' + evAnnual.setScale(2) + ' EUR | cheaper: '
        + (basisAnnual < evAnnual ? 'Basis' : 'EV-Tarif'));
}
