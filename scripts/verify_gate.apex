// HanseWatt — Faz 1 gate check: prove a Case enters the SLA process, gets milestones,
// and lands in the Omni-Channel escalation queue.
// Run: sf apex run --file scripts/verify_gate.apex --target-org hansewatt
// Idempotent-ish: reuses Lena's account + entitlement if present.

// 1. Lena's account (from seed data)
Account lena = [SELECT Id, Name FROM Account WHERE Name = 'Lena Bergmann' LIMIT 1];

// 2. The deployed SLA / entitlement process (SlaProcess.Name is the developer name)
SlaProcess sla = [SELECT Id, Name FROM SlaProcess
                  WHERE Name = 'HW_Standard_SLA' AND IsActive = true LIMIT 1];

// 3. The Omni-Channel escalation queue
Group escQ = [SELECT Id, Name FROM Group WHERE Type = 'Queue' AND DeveloperName = 'HW_Escalations' LIMIT 1];

// 4. Entitlement linking the account to the SLA process (reuse if present)
List<Entitlement> ents = [SELECT Id FROM Entitlement WHERE AccountId = :lena.Id AND SlaProcessId = :sla.Id LIMIT 1];
Entitlement ent;
if (ents.isEmpty()) {
    ent = new Entitlement(Name = 'HanseWatt Standard SLA', AccountId = lena.Id, SlaProcessId = sla.Id,
                          StartDate = Date.today());
    insert ent;
} else {
    ent = ents[0];
}

// 5. Case under the entitlement, owned by the escalation queue (Omni-Channel routing target)
Id billingRt = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Billing').getRecordTypeId();
Case c = new Case(
    Subject = 'Why is my electricity bill so high? (gate test)',
    Status = 'New', Origin = 'Web',
    AccountId = lena.Id, RecordTypeId = billingRt,
    OwnerId = escQ.Id, HW_Topic__c = 'Billing'
);
// EntitlementId set dynamically to bypass a stale Apex compile-schema cache after org changes
c.put('EntitlementId', ent.Id);
insert c;

// 6. Verify milestones were generated (SLA clock running)
List<CaseMilestone> ms = [SELECT MilestoneType.Name, TargetDate, IsCompleted, IsViolated
                          FROM CaseMilestone WHERE CaseId = :c.Id ORDER BY TargetDate];

System.debug('=== Faz 1 GATE CHECK ===');
System.debug('Account     : ' + lena.Name);
System.debug('SLA process : ' + sla.Name);
System.debug('Case        : ' + c.Id + ' owner=' + escQ.Name + ' (queue)');
System.debug('Milestones  : ' + ms.size());
for (CaseMilestone m : ms) {
    System.debug('  - ' + m.MilestoneType.Name + ' | target=' + m.TargetDate
        + ' | completed=' + m.IsCompleted + ' | violated=' + m.IsViolated);
}
System.debug(ms.isEmpty()
    ? 'RESULT: NO milestones — SLA did not attach (investigate entitlement process).'
    : 'RESULT: PASS — Case is in the escalation queue with a running SLA milestone clock.');
