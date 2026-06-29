// HanseWatt — Faz 1 demo seed data (idempotent: clears prior HanseWatt demo rows first).
// Run: sf apex run --file scripts/seed_demo_data.apex --target-org hansewatt
// No secrets — safe to commit. Currency values are in the org currency (switch to EUR later).

// ---- 0. Clean prior demo data (child -> parent order) --------------------------------
delete [SELECT Id FROM Meter_Reading__c];
delete [SELECT Id FROM Energy_Bill__c];
delete [SELECT Id FROM Service_Contract__c];
delete [SELECT Id FROM Meter__c];
delete [SELECT Id FROM Consent__c];
delete [SELECT Id FROM Tariff__c];
delete [SELECT Id FROM Outage__c];
delete [SELECT Id FROM Account WHERE Name IN ('Lena Bergmann','Familie Huber','Müller Maschinenbau GmbH','Studio Alpina')];

// ---- 1. Tariffs (reference data) -----------------------------------------------------
List<Tariff__c> tariffs = new List<Tariff__c>{
    new Tariff__c(Name='HanseWatt Strom Basis',   Type__c='Strom', Price_per_kWh__c=0.32, Base_Fee__c=9.90,  Green__c=false),
    new Tariff__c(Name='HanseWatt Ökostrom',      Type__c='Strom', Price_per_kWh__c=0.36, Base_Fee__c=11.90, Green__c=true),
    new Tariff__c(Name='HanseWatt Strom EV-Tarif',Type__c='Strom', Price_per_kWh__c=0.28, Base_Fee__c=12.90, Green__c=true),
    new Tariff__c(Name='HanseWatt Gas Basis',     Type__c='Gas',   Price_per_kWh__c=0.11, Base_Fee__c=12.90, Green__c=false)
};
insert tariffs;
Map<String,Tariff__c> tByName = new Map<String,Tariff__c>();
for (Tariff__c t : tariffs) tByName.put(t.Name, t);

// ---- 2. Accounts (4 DACH customers) + Contacts ---------------------------------------
Account aLena  = new Account(Name='Lena Bergmann',            BillingStreet='Mönckebergstraße 12', BillingPostalCode='20095', BillingCity='Hamburg', BillingCountry='Germany');
Account aHuber = new Account(Name='Familie Huber',            BillingStreet='Mariahilfer Straße 88', BillingPostalCode='1070', BillingCity='Wien',    BillingCountry='Austria');
Account aMuell = new Account(Name='Müller Maschinenbau GmbH', BillingStreet='Deutz-Mülheimer Str. 30', BillingPostalCode='50679', BillingCity='Köln', BillingCountry='Germany');
Account aAlpi  = new Account(Name='Studio Alpina',            BillingStreet='Bahnhofstrasse 21',     BillingPostalCode='8001', BillingCity='Zürich',  BillingCountry='Switzerland');
insert new List<Account>{ aLena, aHuber, aMuell, aAlpi };

insert new List<Contact>{
    new Contact(FirstName='Lena',   LastName='Bergmann', AccountId=aLena.Id,  Email='lena.bergmann@example.de', Phone='+49 40 1234567'),
    new Contact(FirstName='Johann', LastName='Huber',    AccountId=aHuber.Id, Email='j.huber@example.at',       Phone='+43 1 7654321'),
    new Contact(FirstName='Petra',  LastName='Müller',   AccountId=aMuell.Id, Email='p.mueller@mueller-mb.example',  Phone='+49 221 9988776'),
    new Contact(FirstName='Sofia',  LastName='Brunner',  AccountId=aAlpi.Id,  Email='sofia@studio-alpina.example',   Phone='+41 44 5566778')
};

// ---- 3. Meters (one Strom meter per account) -----------------------------------------
Meter__c mLena  = new Meter__c(Name='Meter Bergmann',  Serial__c='DE-HH-0001', Type__c='Strom', Account__c=aLena.Id,  Location__c='Hamburg', Installed_On__c=Date.newInstance(2021,3,15), External_Meter_Id__c='MTR-DE-0001');
Meter__c mHuber = new Meter__c(Name='Meter Huber',     Serial__c='AT-W-0002',  Type__c='Strom', Account__c=aHuber.Id, Location__c='Wien',    Installed_On__c=Date.newInstance(2020,7,1),  External_Meter_Id__c='MTR-AT-0002');
Meter__c mMuell = new Meter__c(Name='Meter Müller',    Serial__c='DE-K-0003',  Type__c='Strom', Account__c=aMuell.Id, Location__c='Köln',    Installed_On__c=Date.newInstance(2019,1,20), External_Meter_Id__c='MTR-DE-0003');
Meter__c mAlpi  = new Meter__c(Name='Meter Alpina',    Serial__c='CH-Z-0004',  Type__c='Strom', Account__c=aAlpi.Id,  Location__c='Zürich',  Installed_On__c=Date.newInstance(2022,9,5),  External_Meter_Id__c='MTR-CH-0004');
insert new List<Meter__c>{ mLena, mHuber, mMuell, mAlpi };

// ---- 4. Service Contracts -------------------------------------------------------------
insert new List<Service_Contract__c>{
    new Service_Contract__c(Account__c=aLena.Id,  Tariff__c=tByName.get('HanseWatt Strom Basis').Id, Meter__c=mLena.Id,  Start__c=Date.newInstance(2024,1,1), Status__c='Active'),
    new Service_Contract__c(Account__c=aHuber.Id, Tariff__c=tByName.get('HanseWatt Ökostrom').Id,    Meter__c=mHuber.Id, Start__c=Date.newInstance(2023,6,1), Status__c='Active'),
    new Service_Contract__c(Account__c=aMuell.Id, Tariff__c=tByName.get('HanseWatt Strom Basis').Id, Meter__c=mMuell.Id, Start__c=Date.newInstance(2022,4,1), End__c=Date.today().addDays(40), Status__c='Active'),
    new Service_Contract__c(Account__c=aAlpi.Id,  Tariff__c=tByName.get('HanseWatt Ökostrom').Id,    Meter__c=mAlpi.Id,  Start__c=Date.newInstance(2024,3,1), Status__c='Active')
};

// ---- 5. Energy Bills (latest month) — Lena's is high (the demo hook) ------------------
Date pStart = Date.today().toStartOfMonth().addMonths(-1);
Date pEnd   = Date.today().toStartOfMonth().addDays(-1);
insert new List<Energy_Bill__c>{
    new Energy_Bill__c(Account__c=aLena.Id,  Period_Start__c=pStart, Period_End__c=pEnd, Consumption_kWh__c=520, Amount__c=176.30, Status__c='Open'),   // spike!
    new Energy_Bill__c(Account__c=aHuber.Id, Period_Start__c=pStart, Period_End__c=pEnd, Consumption_kWh__c=210, Amount__c=87.50,  Status__c='Open'),
    new Energy_Bill__c(Account__c=aMuell.Id, Period_Start__c=pStart, Period_End__c=pEnd, Consumption_kWh__c=4800,Amount__c=1545.90,Status__c='Open'),
    new Energy_Bill__c(Account__c=aAlpi.Id,  Period_Start__c=pStart, Period_End__c=pEnd, Consumption_kWh__c=180, Amount__c=76.70,  Status__c='Open')
};

// ---- 6. Meter Readings — Lena shows a recent monthly jump (EV charging) ---------------
// Lena: ~320 kWh/month baseline, last month jumps to 520 (62% up).
List<Meter_Reading__c> reads = new List<Meter_Reading__c>();
Integer[] lenaMonthly = new Integer[]{310, 325, 300, 330, 315, 520};
for (Integer i = 0; i < lenaMonthly.size(); i++) {
    reads.add(new Meter_Reading__c(Meter__c=mLena.Id, Read_Date__c=DateTime.now().addMonths(-(lenaMonthly.size()-1-i)),
        kWh__c=lenaMonthly[i], Source__c='Smart', Is_Estimated__c=false));
}
// Müller (SME) steady high
Integer[] muellMonthly = new Integer[]{4600, 4750, 4700, 4820, 4900, 4800};
for (Integer i = 0; i < muellMonthly.size(); i++) {
    reads.add(new Meter_Reading__c(Meter__c=mMuell.Id, Read_Date__c=DateTime.now().addMonths(-(muellMonthly.size()-1-i)),
        kWh__c=muellMonthly[i], Source__c='Smart', Is_Estimated__c=false));
}
// Huber (Wien, residential) — mild winter rise, all smart
Integer[] huberMonthly = new Integer[]{180, 195, 210, 230, 205, 200};
for (Integer i = 0; i < huberMonthly.size(); i++) {
    reads.add(new Meter_Reading__c(Meter__c=mHuber.Id, Read_Date__c=DateTime.now().addMonths(-(huberMonthly.size()-1-i)),
        kWh__c=huberMonthly[i], Source__c='Smart', Is_Estimated__c=false));
}
// Alpina (Zürich, residential) — steady; month 4 is an ESTIMATED reading (realism: gap-filled)
Integer[] alpiMonthly = new Integer[]{150, 160, 175, 168, 170, 165};
for (Integer i = 0; i < alpiMonthly.size(); i++) {
    reads.add(new Meter_Reading__c(Meter__c=mAlpi.Id, Read_Date__c=DateTime.now().addMonths(-(alpiMonthly.size()-1-i)),
        kWh__c=alpiMonthly[i], Source__c='Smart', Is_Estimated__c=(i == 3)));
}
insert reads;

// ---- 7. Consent + a sample Outage -----------------------------------------------------
insert new List<Consent__c>{
    new Consent__c(Account__c=aLena.Id,  Type__c='SmartMeterData', Granted__c=true, Granted_On__c=Date.newInstance(2024,1,1)),
    new Consent__c(Account__c=aLena.Id,  Type__c='Marketing',      Granted__c=false),
    new Consent__c(Account__c=aHuber.Id, Type__c='SmartMeterData', Granted__c=true, Granted_On__c=Date.newInstance(2023,6,1))
};
insert new Outage__c(Region__c='Zürich 8001', Start__c=DateTime.now().addHours(-3), Status__c='Active', Cause__c='Transformer fault');

System.debug('HanseWatt seed complete: 4 accounts, 4 tariffs, 4 meters, 4 contracts, 4 bills, '
    + reads.size() + ' readings, 3 consents, 1 outage.');
