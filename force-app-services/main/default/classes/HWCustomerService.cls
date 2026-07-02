/**
 * HWCustomerService — resolves a HanseWatt customer Account from an identifier the customer
 * provides in conversation (their email). This is how the agent stops assuming a hardcoded
 * demo customer and works for whoever it is talking to: identify first, then ground on that
 * account's real data.
 *
 * HanseWatt uses business Accounts with a related Contact (Person Accounts are not enabled),
 * so the email lives on Contact and we return its AccountId.
 *
 * Standard (ADR-006): with sharing, SOQL USER_MODE via Database.queryWithBinds (an inline
 * bind throws "Variable does not exist: tmpVar1" in the Agentforce action runtime), bulk-safe.
 */
public with sharing class HWCustomerService {

    /** The resolved customer. */
    public class Customer {
        public Id     accountId;
        public String accountName;
    }

    /**
     * Bulk-safe: resolve accounts for a set of contact emails.
     * @param emails customer email addresses
     * @return map of lower-cased email -> Customer (only emails that matched a contact with an account)
     */
    public static Map<String, Customer> byEmail(Set<String> emails) {
        Map<String, Customer> out = new Map<String, Customer>();
        if (emails == null || emails.isEmpty()) {
            return out;
        }
        Set<String> normalized = new Set<String>();
        for (String e : emails) {
            if (String.isNotBlank(e)) normalized.add(e.trim().toLowerCase());
        }
        if (normalized.isEmpty()) {
            return out;
        }
        String query =
            'SELECT Email, AccountId, Account.Name ' +
            'FROM Contact ' +
            'WHERE Email IN :emails AND AccountId != null';
        Map<String, Object> binds = new Map<String, Object>{ 'emails' => normalized };
        for (Contact c : (List<Contact>) Database.queryWithBinds(query, binds, AccessLevel.USER_MODE)) {
            Customer cust = new Customer();
            cust.accountId   = c.AccountId;
            cust.accountName = c.Account != null ? c.Account.Name : null;
            out.put(c.Email.toLowerCase(), cust);
        }
        return out;
    }
}
