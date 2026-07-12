// Reset the tariff demo to its starting state (Lena back on Strom Basis).
Id basis = [SELECT Id FROM Tariff__c WHERE Name = 'HanseWatt Strom Basis' LIMIT 1].Id;
Service_Contract__c sc = [SELECT Id, Tariff__c FROM Service_Contract__c
                          WHERE Account__r.Name = 'Lena Bergmann' LIMIT 1];
sc.Tariff__c = basis;
update sc;
delete [SELECT Id FROM Tariff_Change_Request__c];
delete [SELECT Id FROM Case WHERE HW_Topic__c = 'TariffChange'];
System.debug('RESET: Lena is back on ' + [SELECT Tariff__r.Name FROM Service_Contract__c
    WHERE Id = :sc.Id].Tariff__r.Name);
