/**
 * HWGetLatestBillAction — the Agentforce-callable action that returns a customer's most recent
 * energy bill so the agent can answer "how much is my latest bill?" with the real amount,
 * period, usage and status. Pair it with HW Identify Customer to get the Account Id first.
 *
 * Bulk-safe @InvocableMethod delegating to HWBillingService (ADR-006).
 */
public with sharing class HWGetLatestBillAction {

    public class Request {
        @InvocableVariable(label='Account Id' description='The customer Account, from HW Identify Customer. If unknown, identify the customer first.')
        public Id accountId;
    }

    public class Result {
        @InvocableVariable(label='Bill Number') public String billNumber;
        @InvocableVariable(label='Period Start') public String periodStart;
        @InvocableVariable(label='Period End') public String periodEnd;
        @InvocableVariable(label='Amount') public Decimal amount;
        @InvocableVariable(label='Currency') public String currencyCode;
        @InvocableVariable(label='Consumption kWh') public Decimal consumptionKwh;
        @InvocableVariable(label='Status') public String status;
        @InvocableVariable(label='Summary') public String summary;
        @InvocableVariable(label='Citation') public String citation;
    }

    @InvocableMethod(
        label='HW Get Latest Bill'
        description='Returns the most recent energy bill for a customer (amount, period, usage, status) from the billing record.')
    public static List<Result> run(List<Request> requests) {
        Set<Id> accountIds = new Set<Id>();
        for (Request req : requests) {
            if (req.accountId != null) accountIds.add(req.accountId);
        }
        Map<Id, HWBillingService.Bill> byAccount = HWBillingService.latestByAccount(accountIds);

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            if (req.accountId == null) {
                res.summary = 'I need to identify your account before I can look up your bill. '
                    + 'Could you share the email address on your account?';
                res.citation = '';
                results.add(res);
                continue;
            }
            HWBillingService.Bill b = byAccount.get(req.accountId);
            if (b != null) {
                res.billNumber     = b.billNumber;
                res.periodStart    = b.periodStart != null ? String.valueOf(b.periodStart) : null;
                res.periodEnd      = b.periodEnd != null ? String.valueOf(b.periodEnd) : null;
                res.amount         = b.amount;
                res.currencyCode   = b.currencyCode;
                res.consumptionKwh = b.consumptionKwh;
                res.status         = b.status;
                res.summary        = 'Latest bill ' + b.billNumber + ' covers ' + b.periodStart
                    + ' to ' + b.periodEnd + ': ' + b.amount + ' ' + b.currencyCode + ' for '
                    + b.consumptionKwh + ' kWh. Status: ' + b.status + '.';
                res.citation       = 'HanseWatt billing (Energy Bill record)';
            } else {
                res.summary  = 'No bill was found for this customer yet.';
                res.citation = '';
            }
            results.add(res);
        }
        return results;
    }
}
