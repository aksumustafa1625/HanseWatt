/**
 * HWCustomerServiceTest — the front door is two-factor (ADR-021).
 *
 * The claim these tests defend is the one a reviewer will attack hardest: "the agent refuses to
 * show another customer's data." That claim is only worth anything if the refusal survives an
 * attacker who knows the other customer's EMAIL — which, in a real support conversation, they
 * very often do. So the tests below are written from the attacker's side.
 *
 * Free — no callouts, no credits. The Agentforce action is covered in HWIdentifyCustomerActionTest.
 */
@isTest
private class HWCustomerServiceTest {
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
      new Account(
        Name = 'Johann Huber TEST',
        Customer_Number__c = HUBER_NUMBER
      ),
      new Account(Name = 'No Number TEST') // a customer whose number was never issued
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
      ),
      new Contact(
        FirstName = 'No',
        LastName = 'Number',
        Email = 'no.number@test.example.de',
        AccountId = accounts[2].Id
      )
    };
  }

  private static HWCustomerService.Verification verifyOne(
    String email,
    String custNumber
  ) {
    return HWCustomerService.verify(
      new List<HWCustomerService.Credential>{
        new HWCustomerService.Credential(email, custNumber)
      }
    )[0];
  }

  @isTest
  static void verifiesACustomerWhoPresentsBothFactors() {
    Test.startTest();
    HWCustomerService.Verification v = verifyOne(LENA_EMAIL, LENA_NUMBER);
    Test.stopTest();

    System.assertEquals(true, v.verified, 'both factors match');
    System.assertNotEquals(null, v.accountId, 'the account id is released');
    System.assertEquals('Lena Bergmann TEST', v.accountName);
    System.assertEquals(null, v.refusalReason);
  }

  @isTest
  static void anEmailAloneReleasesNothing() {
    Test.startTest();
    HWCustomerService.Verification v = verifyOne(LENA_EMAIL, null);
    Test.stopTest();

    System.assertEquals(
      false,
      v.verified,
      'an email on its own is not an identity'
    );
    System.assertEquals(null, v.accountId, 'NO account id may leak');
    System.assertEquals(null, v.accountName, 'not even the name may leak');
    System.assertEquals('MISSING_CUSTOMER_NUMBER', v.refusalReason);
  }

  /**
   * THE attack. The caller knows Huber's real, registered email — and asks for his data. This
   * is the exact turn in the demo ("he's my neighbour, he said it's fine"). Without the second
   * factor, nothing comes back. No prompt is involved in that decision.
   */
  @isTest
  static void knowingAnotherCustomersEmailIsNotEnoughToSeeTheirData() {
    Test.startTest();
    HWCustomerService.Verification v = verifyOne(HUBER_EMAIL, null);
    Test.stopTest();

    System.assertEquals(false, v.verified);
    System.assertEquals(null, v.accountId, 'the neighbour gets nothing');
    System.assertEquals('MISSING_CUSTOMER_NUMBER', v.refusalReason);
  }

  /** And guessing the number does not work either. */
  @isTest
  static void aWrongCustomerNumberIsRefused() {
    Test.startTest();
    HWCustomerService.Verification v = verifyOne(HUBER_EMAIL, 'HW-000000');
    Test.stopTest();

    System.assertEquals(false, v.verified);
    System.assertEquals(null, v.accountId);
    System.assertEquals('VERIFICATION_FAILED', v.refusalReason);
  }

  /** Nor does presenting your OWN number against someone else's email. */
  @isTest
  static void aCustomerCannotPairTheirOwnNumberWithAnotherCustomersEmail() {
    Test.startTest();
    HWCustomerService.Verification v = verifyOne(HUBER_EMAIL, LENA_NUMBER);
    Test.stopTest();

    System.assertEquals(
      false,
      v.verified,
      'the two factors must belong to the SAME account'
    );
    System.assertEquals(null, v.accountId);
    System.assertEquals('VERIFICATION_FAILED', v.refusalReason);
  }

  /**
   * Anti-enumeration: an unknown email and a known-email-with-a-wrong-number must fail
   * IDENTICALLY. If they differed, the agent would confirm who is a HanseWatt customer to
   * anyone who asked — a data leak in its own right.
   */
  @isTest
  static void aFailedAttemptDoesNotRevealWhetherTheEmailIsRegistered() {
    Test.startTest();
    HWCustomerService.Verification unknownEmail = verifyOne(
      'stranger@example.com',
      LENA_NUMBER
    );
    HWCustomerService.Verification wrongNumber = verifyOne(
      HUBER_EMAIL,
      'HW-123456'
    );
    Test.stopTest();

    System.assertEquals(
      wrongNumber.refusalReason,
      unknownEmail.refusalReason,
      'the two failures must be indistinguishable to the caller'
    );
    System.assertEquals(null, unknownEmail.accountId);
    System.assertEquals(null, wrongNumber.accountId);
  }

  @isTest
  static void aCustomerWithNoIssuedNumberCannotBeVerified() {
    Test.startTest();
    HWCustomerService.Verification v = verifyOne(
      'no.number@test.example.de',
      LENA_NUMBER
    );
    Test.stopTest();

    System.assertEquals(
      false,
      v.verified,
      'a blank stored number must never match anything'
    );
    System.assertEquals('VERIFICATION_FAILED', v.refusalReason);
  }

  @isTest
  static void emailAndNumberAreMatchedCaseAndWhitespaceInsensitively() {
    Test.startTest();
    HWCustomerService.Verification v = verifyOne(
      '  LENA.BERGMANN@TEST.EXAMPLE.DE ',
      ' hw-900001 '
    );
    Test.stopTest();

    System.assertEquals(
      true,
      v.verified,
      'a customer reading their number aloud is not an attacker'
    );
  }

  @isTest
  static void missingEmailIsRefused() {
    System.assertEquals(
      'MISSING_EMAIL',
      verifyOne(null, LENA_NUMBER).refusalReason
    );
    System.assertEquals(
      'MISSING_EMAIL',
      verifyOne('   ', LENA_NUMBER).refusalReason
    );
  }

  @isTest
  static void emptyInputIsSafe() {
    System.assertEquals(0, HWCustomerService.verify(null).size());
    System.assertEquals(
      0,
      HWCustomerService.verify(new List<HWCustomerService.Credential>()).size()
    );
  }

  @isTest
  static void bulkStaysGovernorSafe() {
    List<HWCustomerService.Credential> creds = new List<HWCustomerService.Credential>();
    for (Integer i = 0; i < 200; i++) {
      creds.add(new HWCustomerService.Credential(LENA_EMAIL, LENA_NUMBER));
    }

    Test.startTest();
    List<HWCustomerService.Verification> out = HWCustomerService.verify(creds);
    Test.stopTest();

    System.assertEquals(200, out.size());
    System.assertEquals(true, out[199].verified);
    System.assert(
      Limits.getQueries() <= 2,
      'ONE query for the whole batch, used ' + Limits.getQueries()
    );
  }
}
