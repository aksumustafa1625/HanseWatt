/**
 * HWConfirmTariffChangeAction — step 2 of the consent handshake (ADR-020).
 *
 * This is the only action in HanseWatt that changes a customer's contract, and it is
 * deliberately the hardest one to reach.
 *
 * It applies a tariff change ONLY IF the caller presents a request number that:
 *   1. exists,
 *   2. belongs to THIS account (a proposal minted for Lena can never be applied to Huber),
 *   3. is still in 'Proposed' status,
 *   4. has not expired.
 *
 * The request number is minted by the platform inside HWProposeTariffChangeAction and
 * exists nowhere else. So the model cannot skip the proposal step, cannot fabricate
 * consent, and cannot re-use another customer's consent — **not because the prompt asks
 * it not to, but because the code has nothing to act on.** If the model hallucinates a
 * "Ja" and calls this action with an invented number, the Apex refuses and ZERO DML runs.
 * That is the difference between a prompt guardrail and a structural one.
 *
 * Idempotent: confirming the same request twice reports the original outcome instead of
 * changing the contract again.
 *
 * On success it (a) switches the contract's tariff, (b) marks the proposal Applied,
 * (c) opens a Case so a human owns the follow-through, and (d) publishes
 * `Tariff_Change_Requested__e` — the integration seam that a MuleSoft subscriber would
 * forward to SAP IS-U in production. The far side of that seam is simulated here; the
 * seam itself is real (see STATUS.md).
 *
 * Bulk-safe @InvocableMethod (ADR-006): one query, one update per object, one publish.
 */
public with sharing class HWConfirmTariffChangeAction {

    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The VERIFIED customer Account, from HW Identify Customer.'
            required=true)
        public Id accountId;

        @InvocableVariable(
            label='Request Number'
            description='The request number returned by HW Propose Tariff Change (e.g. TCR-00001). You cannot invent this: it is issued by the system when the proposal is created. Only send it after the customer has explicitly confirmed the switch.'
            required=true)
        public String requestNumber;
    }

    public class Result {
        @InvocableVariable(label='Applied') public Boolean applied;
        @InvocableVariable(label='Request Number') public String requestNumber;
        @InvocableVariable(label='New Tariff') public String newTariff;
        @InvocableVariable(label='Annual Saving') public Decimal annualSaving;
        @InvocableVariable(label='Case Number') public String caseNumber;
        @InvocableVariable(label='Refusal Reason') public String refusalReason;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='HW Confirm Tariff Change'
        description='Applies a tariff change, but ONLY against a valid, unexpired request number issued by HW Propose Tariff Change for this same customer. Call this only after the customer has explicitly confirmed. If the request number is missing, invalid, expired, or belongs to another customer, the change is refused and nothing is modified.')
    public static List<Result> run(List<Request> requests) {
        // 1) Load only the proposals that were actually minted for the accounts in play.
        //    The account scoping here is the structural cross-customer guarantee.
        Set<String> numbers = new Set<String>();
        Set<Id> accountIds = new Set<Id>();
        for (Request req : requests) {
            if (String.isNotBlank(req.requestNumber)) numbers.add(req.requestNumber.trim().toUpperCase());
            if (req.accountId != null) accountIds.add(req.accountId);
        }

        Map<String, Tariff_Change_Request__c> byNumber = new Map<String, Tariff_Change_Request__c>();
        if (!numbers.isEmpty() && !accountIds.isEmpty()) {
            String q =
                'SELECT Id, Name, Account__c, Status__c, Expires_At__c, Applied_At__c, '
              + '       Annual_Saving__c, Assumption_Basis__c, Proposed_Tariff__c, '
              + '       Proposed_Tariff__r.Name, Service_Contract_Ref__c '
              + 'FROM Tariff_Change_Request__c '
              + 'WHERE Name IN :nums AND Account__c IN :accIds';   // <- scoped to the caller's own accounts
            Map<String, Object> binds = new Map<String, Object>{
                'nums' => numbers, 'accIds' => accountIds
            };
            for (Tariff_Change_Request__c t :
                    (List<Tariff_Change_Request__c>) Database.queryWithBinds(q, binds, AccessLevel.USER_MODE)) {
                byNumber.put(t.Name.toUpperCase(), t);
            }
        }

        List<Service_Contract__c> contractUpdates = new List<Service_Contract__c>();
        List<Tariff_Change_Request__c> requestUpdates = new List<Tariff_Change_Request__c>();
        List<Case> casesToOpen = new List<Case>();
        List<Tariff_Change_Requested__e> events = new List<Tariff_Change_Requested__e>();
        List<Result> results = new List<Result>();
        List<Integer> caseSlotByResult = new List<Integer>();   // result index -> case index

        for (Request req : requests) {
            Result res = new Result();
            res.applied = false;
            res.requestNumber = req.requestNumber;
            caseSlotByResult.add(-1);

            // --- Refusal gates. Any one of these means ZERO DML for this request. ---
            if (req.accountId == null) {
                res.refusalReason = 'NO_IDENTITY';
                res.message = 'I need to identify your account first before I can change anything.';
                results.add(res);
                continue;
            }
            if (String.isBlank(req.requestNumber)) {
                res.refusalReason = 'NO_REQUEST_NUMBER';
                res.message = 'I cannot change a tariff without a proposal. Let me quote the options '
                    + 'first, and I will only switch you after you confirm.';
                results.add(res);
                continue;
            }

            Tariff_Change_Request__c tcr = byNumber.get(req.requestNumber.trim().toUpperCase());
            if (tcr == null) {
                // Either it does not exist, or it belongs to a DIFFERENT customer.
                res.refusalReason = 'UNKNOWN_OR_FOREIGN_REQUEST';
                res.message = 'That proposal number is not valid for this account. I will not change '
                    + 'a contract without a proposal I issued to you. Shall I quote the options again?';
                results.add(res);
                continue;
            }
            if (tcr.Status__c == 'Applied') {
                // Idempotent: say what already happened; do not change anything again.
                res.applied      = true;
                res.newTariff    = tcr.Proposed_Tariff__r.Name;
                res.annualSaving = tcr.Annual_Saving__c;
                res.message      = 'This change was already applied. Your contract is on '
                    + tcr.Proposed_Tariff__r.Name + '. Nothing further is needed.';
                results.add(res);
                continue;
            }
            if (tcr.Status__c != 'Proposed') {
                res.refusalReason = 'NOT_PROPOSED';
                res.message = 'That proposal is no longer open. Let me quote the tariffs again.';
                results.add(res);
                continue;
            }
            if (tcr.Expires_At__c == null || tcr.Expires_At__c < System.now()) {
                tcr.Status__c = 'Expired';
                requestUpdates.add(tcr);
                res.refusalReason = 'EXPIRED';
                res.message = 'That proposal has expired, so I will not apply it. Let me re-quote the '
                    + 'tariffs at your current consumption and you can confirm the fresh figures.';
                results.add(res);
                continue;
            }

            // --- All gates passed: this is a real, fresh, own-account, confirmed proposal. ---
            if (tcr.Service_Contract_Ref__c != null) {
                contractUpdates.add(new Service_Contract__c(
                    Id = tcr.Service_Contract_Ref__c,
                    Tariff__c = tcr.Proposed_Tariff__c));
            }
            tcr.Status__c    = 'Applied';
            tcr.Applied_At__c = System.now();
            requestUpdates.add(tcr);

            casesToOpen.add(new Case(
                AccountId   = tcr.Account__c,
                Subject     = 'Tariff change applied: ' + tcr.Proposed_Tariff__r.Name
                              + ' (' + tcr.Name + ')',
                Description = 'The customer confirmed a tariff change proposed by HW Energy Agent.\n\n'
                    + 'Proposal: ' + tcr.Name + '\n'
                    + 'New tariff: ' + tcr.Proposed_Tariff__r.Name + '\n'
                    + 'Quoted annual saving: ' + tcr.Annual_Saving__c + '\n\n'
                    + 'Assumption the quote depends on:\n' + tcr.Assumption_Basis__c + '\n\n'
                    + 'The Salesforce contract has been switched. A Tariff_Change_Requested__e event '
                    + 'has been published for the billing system (SAP IS-U) to register the change.',
                HW_Topic__c = 'TariffChange'));
            caseSlotByResult[results.size()] = casesToOpen.size() - 1;

            events.add(new Tariff_Change_Requested__e(
                Account_Id__c     = tcr.Account__c,
                Request_Number__c = tcr.Name,
                New_Tariff__c     = tcr.Proposed_Tariff__r.Name,
                Annual_Saving__c  = tcr.Annual_Saving__c));

            res.applied      = true;
            res.newTariff    = tcr.Proposed_Tariff__r.Name;
            res.annualSaving = tcr.Annual_Saving__c;
            results.add(res);
        }

        // --- One DML per object. Nothing above ran DML inside a loop. ---
        if (!contractUpdates.isEmpty()) update as user contractUpdates;
        if (!requestUpdates.isEmpty())  update as user requestUpdates;
        if (!casesToOpen.isEmpty())     insert as user casesToOpen;
        if (!events.isEmpty())          EventBus.publish(events);

        // Fill in the case numbers now that they exist.
        if (!casesToOpen.isEmpty()) {
            Set<Id> caseIds = new Set<Id>();
            for (Case c : casesToOpen) caseIds.add(c.Id);
            Map<Id, Case> byId = new Map<Id, Case>(
                [SELECT Id, CaseNumber FROM Case WHERE Id IN :caseIds WITH USER_MODE]);
            for (Integer i = 0; i < results.size(); i++) {
                Integer slot = caseSlotByResult[i];
                if (slot < 0) continue;
                Case c = byId.get(casesToOpen[slot].Id);
                results[i].caseNumber = (c == null) ? null : c.CaseNumber;
                results[i].message = 'Done. Your contract will run on ' + results[i].newTariff
                    + ' from the next billing period, and you save '
                    + results[i].annualSaving + ' per year. Reference: case ' + results[i].caseNumber
                    + '. A specialist confirms the change with the billing system.';
            }
        }
        return results;
    }
}
