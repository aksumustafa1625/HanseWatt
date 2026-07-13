/**
 * HWIdsTest — the boundary guard.
 *
 * This class exists because of a real failure, caught in a demo recording: asked for ANOTHER
 * customer's bill, the planner put the *email address* into the Account Id slot. The actions
 * declared that slot as `Id`, so Apex threw on coercion before a single line of our code ran —
 * and the customer saw "an error occurred" where a privacy refusal belonged. A guardrail that
 * crashes is not a guardrail.
 *
 * The rule these tests lock in: an action input is a string a LANGUAGE MODEL chose. Anything
 * that is not a real Account Id becomes null — and null already means "not identified", which is
 * the correct, safe answer.
 *
 * Free — no callouts, no credits.
 */
@isTest
private class HWIdsTest {

    @isTest
    static void acceptsARealAccountId() {
        Account a = new Account(Name = 'Boundary TEST');
        insert a;

        System.assertEquals(a.Id, HWIds.accountId(a.Id),
            'a real Account Id passes through unchanged');
        System.assertEquals(a.Id, HWIds.accountId('  ' + a.Id + ' '),
            'whitespace is not an attack');
    }

    /** THE bug. This exact value crashed the agent mid-demo. */
    @isTest
    static void anEmailAddressIsNotAnIdAndMustNotThrow() {
        System.assertEquals(null, HWIds.accountId('j.huber@example.at'),
            'the planner put an email here — it must become null, not an exception');
    }

    @isTest
    static void garbageAndBlanksBecomeNull() {
        System.assertEquals(null, HWIds.accountId(null));
        System.assertEquals(null, HWIds.accountId(''));
        System.assertEquals(null, HWIds.accountId('   '));
        System.assertEquals(null, HWIds.accountId('unknown'));
        System.assertEquals(null, HWIds.accountId('001XXXXXXXXXXXX'), 'malformed id');
    }

    /** A well-formed id of the WRONG object is still not an account. Reject it before querying. */
    @isTest
    static void anIdOfAnotherObjectIsRejected() {
        Case c = new Case(Subject = 'Boundary TEST');
        insert c;

        System.assertEquals(null, HWIds.accountId(c.Id),
            'a Case id is a valid id — but it is not an ACCOUNT id');
    }
}
