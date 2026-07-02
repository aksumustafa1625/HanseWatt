/**
 * HWCaseService — creates a support Case on behalf of a customer so the agent can take action
 * (log a billing dispute, a move request, a complaint) and hand off to a human under the Faz 1
 * SLA + Omni-Channel routing. This is the agent's "do something", not just "explain something".
 *
 * The Case is categorized with HW_Topic__c (the same taxonomy the record types use); the record
 * type itself is left to the org default / assignment rules so the agent user does not need
 * record-type assignment.
 *
 * Standard (ADR-006): with sharing, DML "as user", bulk-safe.
 */
public with sharing class HWCaseService {

    private static final Set<String> VALID_TOPICS = new Set<String>{
        'Billing', 'Consumption', 'TariffChange', 'Move', 'Outage', 'Complaint', 'Other'
    };

    /** A requested case. */
    public class NewCase {
        public Id     accountId;
        public String topic;       // maps to HW_Topic__c; anything unknown becomes 'Other'
        public String subject;
        public String description;
    }

    /** The created case. */
    public class Created {
        public Id     caseId;
        public String caseNumber;
    }

    /**
     * Bulk-safe: insert one Case per request as the running user.
     * @param inputs the requested cases (accountId required)
     * @return the created cases (id + number), in request order (skips inputs with no account)
     */
    public static List<Created> createCases(List<NewCase> inputs) {
        List<Case> toInsert = new List<Case>();
        for (NewCase nc : inputs) {
            if (nc.accountId == null) continue;
            String topic = (String.isNotBlank(nc.topic) && VALID_TOPICS.contains(nc.topic))
                ? nc.topic : 'Other';
            toInsert.add(new Case(
                AccountId   = nc.accountId,
                Subject     = String.isNotBlank(nc.subject) ? nc.subject : 'Customer request via agent',
                Description = nc.description,
                HW_Topic__c = topic
            ));
        }
        List<Created> out = new List<Created>();
        if (toInsert.isEmpty()) {
            return out;
        }
        insert as user toInsert;

        Map<Id, Case> byId = new Map<Id, Case>(
            [SELECT Id, CaseNumber FROM Case WHERE Id IN :toInsert WITH USER_MODE]);
        for (Case c : toInsert) {
            Created cr = new Created();
            cr.caseId = c.Id;
            cr.caseNumber = byId.containsKey(c.Id) ? byId.get(c.Id).CaseNumber : null;
            out.add(cr);
        }
        return out;
    }
}
