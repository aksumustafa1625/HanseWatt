/**
 * Tests for HWIdentifyCustomerAction — the two-factor front door (ADR-021).
 *
 * The action is the ONLY thing in HanseWatt that can hand the agent an Account Id, so it is the
 * only place a privacy boundary can be enforced. These tests prove the boundary holds against
 * the case that actually happens in a support conversation: someone who knows the other
 * customer's email and asks nicely — then insists.
 *
 * Free — no callouts, no credits.
 */
@isTest
private class HWIdentifyCustomerActionTest {
  private static final String LENA_EMAIL = 'lena.bergmann@test.example.de';
  private static final String LENA_NUMBER = 'HW-900001';
  private static final String HUBER_EMAIL = 'j.huber@test.example.at';
  private static final String HUBER_NUMBER = 'HW-900002';

  @TestSetup
  static void seed() {
    List<Account> accounts = new List<Account>{
      new Account(
        Name = 'Lena Bergmann TEST',
        Customer_Number__c = LENA_NUMBER
      ),
      new Account(Name = 'Johann Huber TEST', Customer_Number__c = HUBER_NUMBER)
    };
    insert accounts;
    insert new List<Contact>{
      new Contact(
        FirstName = 'Lena',
        LastName = 'Bergmann',
        Email = LENA_EMAIL,
        AccountId = accounts[0].Id
      ),
      new Contact(
        FirstName = 'Johann',
        LastName = 'Huber',
        Email = HUBER_EMAIL,
        AccountId = accounts[1].Id
      )
    };
  }

  private static HWIdentifyCustomerAction.Result call(
    String email,
    String custNumber
  ) {
    HWIdentifyCustomerAction.Request req = new HWIdentifyCustomerAction.Request();
    req.email = email;
    req.customerNumber = custNumber;
    return HWIdentifyCustomerAction.run(
      new List<HWIdentifyCustomerAction.Request>{ req }
    )[0];
  }

  @isTest
  static void verifiesTheCustomerWhoPresentsBothFactors() {
    Test.startTest();
    HWIdentifyCustomerAction.Result res = call(LENA_EMAIL, LENA_NUMBER);
    Test.stopTest();

    System.assertEquals(true, res.verified);
    System.assertNotEquals(
      null,
      res.accountId,
      'the Account Id every later action needs'
    );
    System.assertEquals('Lena Bergmann TEST', res.accountName);
    System.assertEquals(null, res.refusalReason);
    System.assert(res.message.contains('verified'), res.message);
  }

  @isTest
  static void anEmailAloneIsRefusedAndTheAgentIsToldToAskForTheNumber() {
    Test.startTest();
    HWIdentifyCustomerAction.Result res = call(LENA_EMAIL, null);
    Test.stopTest();

    System.assertEquals(false, res.verified);
    System.assertEquals(
      null,
      res.accountId,
      'no Account Id => no downstream action can run'
    );
    System.assertEquals('MISSING_CUSTOMER_NUMBER', res.refusalReason);
    System.assert(res.message.contains('customer number'), res.message);
  }

  /**
   * THE demo turn. The caller has Johann Huber's real, registered email. Without his customer
   * number the action releases nothing — and the message explicitly tells the agent not to
   * yield to pleading or to a claim of permission. The refusal is not the model's good
   * judgement; it is the absence of a code path.
   */
  @isTest
  static void aNeighbourWhoKnowsTheEmailStillGetsNothing() {
    Test.startTest();
    HWIdentifyCustomerAction.Result res = call(HUBER_EMAIL, null);
    Test.stopTest();

    System.assertEquals(false, res.verified);
    System.assertEquals(null, res.accountId, 'no id');
    System.assertEquals(null, res.accountName, 'not even the name');
  }

  @isTest
  static void aGuessedCustomerNumberIsRefusedAndRevealsNothing() {
    Test.startTest();
    HWIdentifyCustomerAction.Result res = call(HUBER_EMAIL, 'HW-000000');
    Test.stopTest();

    System.assertEquals(false, res.verified);
    System.assertEquals(null, res.accountId);
    System.assertEquals('VERIFICATION_FAILED', res.refusalReason);
    System.assert(
      res.message.contains('do not comply'),
      'the agent is told to hold the line'
    );
    System.assert(
      res.message.contains('neighbour'),
      'the exact social-engineering line is pre-empted'
    );
  }

  /** Your own number does not unlock someone else's account. */
  @isTest
  static void yourOwnNumberDoesNotUnlockAnotherCustomer() {
    Test.startTest();
    HWIdentifyCustomerAction.Result res = call(HUBER_EMAIL, LENA_NUMBER);
    Test.stopTest();

    System.assertEquals(false, res.verified);
    System.assertEquals(null, res.accountId);
    System.assertEquals('VERIFICATION_FAILED', res.refusalReason);
  }

  @isTest
  static void anUnknownEmailIsRefusedWithoutConfirmingItIsUnknown() {
    Test.startTest();
    HWIdentifyCustomerAction.Result unknown = call(
      'stranger@example.com',
      LENA_NUMBER
    );
    HWIdentifyCustomerAction.Result wrong = call(HUBER_EMAIL, 'HW-123456');
    Test.stopTest();

    System.assertEquals(
      wrong.refusalReason,
      unknown.refusalReason,
      'an outsider cannot tell "not a customer" from "wrong number"'
    );
    System.assertEquals(null, unknown.accountId);
  }

  @isTest
  static void blankEmailIsRefused() {
    System.assertEquals(
      'MISSING_EMAIL',
      call('   ', LENA_NUMBER).refusalReason
    );
  }

  @isTest
  static void bulkStaysGovernorSafe() {
    List<HWIdentifyCustomerAction.Request> reqs = new List<HWIdentifyCustomerAction.Request>();
    for (Integer i = 0; i < 200; i++) {
      HWIdentifyCustomerAction.Request r = new HWIdentifyCustomerAction.Request();
      r.email = LENA_EMAIL;
      r.customerNumber = LENA_NUMBER;
      reqs.add(r);
    }

    Test.startTest();
    List<HWIdentifyCustomerAction.Result> out = HWIdentifyCustomerAction.run(
      reqs
    );
    Test.stopTest();

    System.assertEquals(200, out.size());
    System.assertEquals(true, out[199].verified);
    System.assert(
      Limits.getQueries() <= 2,
      'ONE query for the whole batch, used ' + Limits.getQueries()
    );
  }
}
