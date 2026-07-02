/**
 * HWCreateCaseAction — the Agentforce-callable action that logs a support Case for a customer
 * (billing dispute, move, complaint, ...). Pair it with HW Identify Customer to get the Account
 * Id first. The new Case flows into the Faz 1 SLA + Omni-Channel routing for human follow-up.
 *
 * Bulk-safe @InvocableMethod delegating to HWCaseService (ADR-006).
 */
public with sharing class HWCreateCaseAction {

    public class Request {
        @InvocableVariable(label='Account Id' description='The customer Account, from HW Identify Customer. If unknown, identify the customer first.')
        public Id accountId;
        @InvocableVariable(label='Topic' description='Category: Billing, Consumption, TariffChange, Move, Outage, Complaint, or Other.')
        public String topic;
        @InvocableVariable(label='Subject' description='A short subject line for the case.')
        public String subject;
        @InvocableVariable(label='Description' description='The details of the customer request.')
        public String description;
    }

    public class Result {
        @InvocableVariable(label='Created') public Boolean created;
        @InvocableVariable(label='Case Number') public String caseNumber;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='HW Create Case'
        description='Logs a support case for the customer (billing dispute, move, complaint, etc.) and hands it to the service queue.')
    public static List<Result> run(List<Request> requests) {
        List<HWCaseService.NewCase> toCreate = new List<HWCaseService.NewCase>();
        List<Request> creatable = new List<Request>();
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            if (req.accountId == null) {
                Result res = new Result();
                res.created = false;
                res.message = 'I need to identify your account before I can open a case. '
                    + 'Could you share the email address on your account?';
                results.add(res);
                continue;
            }
            HWCaseService.NewCase nc = new HWCaseService.NewCase();
            nc.accountId = req.accountId;
            nc.topic = req.topic;
            nc.subject = req.subject;
            nc.description = req.description;
            toCreate.add(nc);
            creatable.add(req);
        }

        List<HWCaseService.Created> made = HWCaseService.createCases(toCreate);
        for (Integer i = 0; i < made.size(); i++) {
            Result res = new Result();
            res.created = true;
            res.caseNumber = made[i].caseNumber;
            res.message = 'I have opened case ' + made[i].caseNumber
                + ' for you. A HanseWatt specialist will follow up shortly.';
            results.add(res);
        }
        return results;
    }
}
