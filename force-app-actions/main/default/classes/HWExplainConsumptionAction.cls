/**
 * HWExplainConsumptionAction — the Agentforce-callable bridge that returns a customer's
 * consumption anomaly (latest vs trailing average) and a grounded explanation. The agent
 * calls this for the "why is my bill so high?" topic; it never invents the figure.
 *
 * Bulk-safe @InvocableMethod delegating to HWConsumptionService (ADR-006).
 */
public with sharing class HWExplainConsumptionAction {

    public class Request {
        @InvocableVariable(label='Account Id' description='The customer Account to explain, from HW Identify Customer. If unknown, identify the customer first.')
        public Id accountId;
    }

    public class Result {
        @InvocableVariable(label='Latest kWh') public Decimal latestKwh;
        @InvocableVariable(label='Average kWh') public Decimal averageKwh;
        @InvocableVariable(label='Anomaly Percent') public Decimal anomalyPercent;
        @InvocableVariable(label='Explanation') public String explanation;
        @InvocableVariable(label='Citation') public String citation;
    }

    @InvocableMethod(
        label='HW Explain Consumption Anomaly'
        description='Returns the latest usage vs trailing average for a customer and a grounded, citable explanation.')
    public static List<Result> run(List<Request> requests) {
        Set<Id> accountIds = new Set<Id>();
        for (Request req : requests) {
            if (req.accountId != null) accountIds.add(req.accountId);
        }
        Map<Id, HWConsumptionService.Anomaly> byAccount =
            HWConsumptionService.anomaliesByAccount(accountIds);

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            if (req.accountId == null) {
                // No account context yet — drive the agent to identify the customer first
                // instead of guessing. Honest grounding: no account, no figure.
                res.explanation = 'I need to identify your account before I can look up your '
                    + 'usage. Could you share the email address on your account?';
                res.citation = '';
                results.add(res);
                continue;
            }
            HWConsumptionService.Anomaly a = byAccount.get(req.accountId);
            if (a != null && a.latestKwh != null) {
                res.latestKwh = a.latestKwh;
                res.averageKwh = a.averageKwh;
                res.anomalyPercent = a.anomalyPercent;
                res.explanation = a.explanation;
                res.citation = 'Data 360 — Meter Reading (unified consumption)';
            } else {
                res.explanation = 'No consumption data found for this customer.';
                res.citation = '';
            }
            results.add(res);
        }
        return results;
    }
}
