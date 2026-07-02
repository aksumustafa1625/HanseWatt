/**
 * HWIdentifyCustomerAction — the Agentforce-callable action that resolves a customer's Account
 * from the email they give in conversation. The agent calls this first ("what's the email on
 * your account?"), then passes the returned Account Id to the data actions (explain
 * consumption, latest bill, create case) so every answer is grounded to the right customer.
 *
 * Bulk-safe @InvocableMethod delegating to HWCustomerService (ADR-006).
 */
public with sharing class HWIdentifyCustomerAction {

    public class Request {
        @InvocableVariable(label='Email' description='The email address the customer gives to identify their account' required=true)
        public String email;
    }

    public class Result {
        @InvocableVariable(label='Found') public Boolean found;
        @InvocableVariable(label='Account Id') public String accountId;
        @InvocableVariable(label='Account Name') public String accountName;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='HW Identify Customer'
        description='Resolves a customer Account from an email address so later actions can ground on that customer. Call this before explaining consumption or bills when the customer is not yet identified.')
    public static List<Result> run(List<Request> requests) {
        Set<String> emails = new Set<String>();
        for (Request req : requests) {
            if (String.isNotBlank(req.email)) emails.add(req.email.trim().toLowerCase());
        }
        Map<String, HWCustomerService.Customer> byEmail = HWCustomerService.byEmail(emails);

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            String key = String.isNotBlank(req.email) ? req.email.trim().toLowerCase() : null;
            HWCustomerService.Customer c = (key != null) ? byEmail.get(key) : null;
            if (c != null) {
                res.found = true;
                res.accountId = c.accountId;
                res.accountName = c.accountName;
                res.message = 'Identified customer: ' + c.accountName + '.';
            } else {
                res.found = false;
                res.message = 'No customer was found for that email address. Please double-check it.';
            }
            results.add(res);
        }
        return results;
    }
}
