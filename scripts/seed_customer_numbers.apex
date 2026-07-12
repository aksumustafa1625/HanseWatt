// Seed the Kundennummer (customer number) — the second authentication factor.
// HanseWatt releases NO account data on an email alone: the customer must also present the
// number printed on their bill. See ADR-021.
Map<String, String> numberByAccount = new Map<String, String>{
    'Lena Bergmann'            => 'HW-100001',
    'Familie Huber'            => 'HW-100002',
    'Müller Maschinenbau GmbH' => 'HW-100003',
    'Studio Alpina'            => 'HW-100004'
};

List<Account> toUpdate = new List<Account>();
for (Account a : [SELECT Id, Name, Customer_Number__c FROM Account WHERE Name IN :numberByAccount.keySet()]) {
    a.Customer_Number__c = numberByAccount.get(a.Name);
    toUpdate.add(a);
}
update toUpdate;

for (Account a : [SELECT Name, Customer_Number__c FROM Account WHERE Customer_Number__c != null ORDER BY Customer_Number__c]) {
    System.debug('KUNDENNUMMER: ' + a.Customer_Number__c + '  ->  ' + a.Name);
}
System.debug('Seeded ' + toUpdate.size() + ' customer numbers.');
