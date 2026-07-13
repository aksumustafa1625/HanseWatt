// Reset the demo to its starting state before a recording:
//   - Lena back on Strom Basis (so the tariff advisory has something to recommend)
//   - Studio Alpina back on Ökostrom (so the persona flip still flips)
//   - every proposal and every agent-opened case cleared
Id basis    = [SELECT Id FROM Tariff__c WHERE Name = 'HanseWatt Strom Basis' LIMIT 1].Id;
Id oekostrom = [SELECT Id FROM Tariff__c WHERE Name = 'HanseWatt Ökostrom' LIMIT 1].Id;

List<Service_Contract__c> contracts = [
    SELECT Id, Account__r.Name, Tariff__c
    FROM Service_Contract__c
    WHERE Account__r.Name IN ('Lena Bergmann', 'Studio Alpina')];
for (Service_Contract__c sc : contracts) {
    sc.Tariff__c = (sc.Account__r.Name == 'Lena Bergmann') ? basis : oekostrom;
}
update contracts;

delete [SELECT Id FROM Tariff_Change_Request__c];
delete [SELECT Id FROM Case WHERE HW_Topic__c IN ('TariffChange', 'Move')];

for (Service_Contract__c sc : [SELECT Account__r.Name, Tariff__r.Name FROM Service_Contract__c
                               WHERE Id IN :contracts]) {
    System.debug('RESET: ' + sc.Account__r.Name + '  ->  ' + sc.Tariff__r.Name);
}
System.debug('RESET: proposals and agent-opened cases cleared. Ready to record.');
