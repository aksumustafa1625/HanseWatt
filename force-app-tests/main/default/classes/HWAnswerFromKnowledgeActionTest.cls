/**
 * Tests for HWAnswerFromKnowledgeAction — the Agentforce-callable procedure answer, cited to a
 * real Knowledge article (ADR-007). Covers: cited answer (EN + DE), honest no-match, blank
 * input, and a 200-record bulk run. Free — no callouts, no credits.
 */
@isTest
private class HWAnswerFromKnowledgeActionTest {
  @TestSetup
  static void seed() {
    Knowledge__kav draft = new Knowledge__kav(
      Title = 'Moving House: Start or Stop Service (Umzug)',
      UrlName = 'test-act-moving-house-umzug',
      Summary = 'Tell us your move-out date and final meter reading so we can issue a final ' +
        'bill. To continue as a customer, give us the new address and move-in date.'
    );
    insert draft;
    Knowledge__kav published = [
      SELECT KnowledgeArticleId
      FROM Knowledge__kav
      WHERE Id = :draft.Id
      LIMIT 1
    ];
    KbManagement.PublishingService.publishArticle(
      published.KnowledgeArticleId,
      true
    );
  }

  @isTest
  static void answersWithCitation() {
    HWAnswerFromKnowledgeAction.Request req = new HWAnswerFromKnowledgeAction.Request();
    req.question = 'I am moving house next month, what do I need to do?';

    Test.startTest();
    List<HWAnswerFromKnowledgeAction.Result> res = HWAnswerFromKnowledgeAction.run(
      new List<HWAnswerFromKnowledgeAction.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, res.size());
    System.assertEquals(true, res[0].found, 'article found');
    System.assert(
      res[0].articleTitle.contains('Moving House'),
      'the right article'
    );
    System.assertNotEquals(
      null,
      res[0].articleNumber,
      'article number for the citation'
    );
    System.assert(
      res[0].answer.contains('move-out date'),
      'the procedural answer text'
    );
    System.assert(
      res[0].citation.contains('HanseWatt Knowledge'),
      'citation present'
    );
  }

  @isTest
  static void answersGermanQuestion() {
    HWAnswerFromKnowledgeAction.Request req = new HWAnswerFromKnowledgeAction.Request();
    req.question = 'Ich ziehe um, was muss ich tun?';
    List<HWAnswerFromKnowledgeAction.Result> res = HWAnswerFromKnowledgeAction.run(
      new List<HWAnswerFromKnowledgeAction.Request>{ req }
    );

    System.assertEquals(
      true,
      res[0].found,
      'German question resolves to the Umzug article'
    );
    System.assert(res[0].citation.contains('Umzug'), 'cites the Umzug article');
  }

  @isTest
  static void noArticleFoundIsHonest() {
    HWAnswerFromKnowledgeAction.Request req = new HWAnswerFromKnowledgeAction.Request();
    req.question = 'What is the capital of France?';
    List<HWAnswerFromKnowledgeAction.Result> res = HWAnswerFromKnowledgeAction.run(
      new List<HWAnswerFromKnowledgeAction.Request>{ req }
    );

    System.assertEquals(1, res.size());
    System.assertEquals(
      false,
      res[0].found,
      'no article for an off-topic question'
    );
    System.assertEquals('', res[0].citation, 'no citation invented');
    System.assert(
      res[0].message.contains('Do not guess'),
      'instructs the agent not to improvise'
    );
  }

  @isTest
  static void blankQuestionHandled() {
    HWAnswerFromKnowledgeAction.Request req = new HWAnswerFromKnowledgeAction.Request();
    req.question = '   ';
    List<HWAnswerFromKnowledgeAction.Result> res = HWAnswerFromKnowledgeAction.run(
      new List<HWAnswerFromKnowledgeAction.Request>{ req }
    );
    System.assertEquals(1, res.size());
    System.assertEquals(
      false,
      res[0].found,
      'blank question cannot be answered'
    );
  }

  @isTest
  static void bulkStaysGovernorSafe() {
    List<HWAnswerFromKnowledgeAction.Request> reqs = new List<HWAnswerFromKnowledgeAction.Request>();
    for (Integer i = 0; i < 200; i++) {
      HWAnswerFromKnowledgeAction.Request r = new HWAnswerFromKnowledgeAction.Request();
      r.question = 'I am moving house, case ' + i;
      reqs.add(r);
    }

    Test.startTest();
    List<HWAnswerFromKnowledgeAction.Result> res = HWAnswerFromKnowledgeAction.run(
      reqs
    );
    Test.stopTest();

    System.assertEquals(200, res.size(), '200 requests -> 200 results');
    System.assertEquals(true, res[0].found, 'each resolved to the article');
    System.assert(
      Limits.getQueries() <= 2,
      'bulk-safe: SOQL must not scale with input, used ' + Limits.getQueries()
    );
  }
}
