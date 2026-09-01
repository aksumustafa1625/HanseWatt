/**
 * Tests for HWKnowledgeService — the deterministic procedure-side retriever (ADR-007).
 * Covers: English question, German question (DE→EN alias map), no-match honesty, blank/empty
 * input, and bulk-safety (ONE query for many questions). Free — no callouts, no credits.
 */
@isTest
private class HWKnowledgeServiceTest {
  @TestSetup
  static void seed() {
    // Two competing articles so scoring has to actually pick the right one.
    List<Knowledge__kav> drafts = new List<Knowledge__kav>{
      new Knowledge__kav(
        Title = 'Moving House: Start or Stop Service (Umzug)',
        UrlName = 'test-hw-moving-house-umzug',
        Summary = 'Tell us your move-out date and final meter reading so we can issue a ' +
          'final bill. To continue as a customer, give us the new address and ' +
          'move-in date and we will start service there.'
      ),
      new Knowledge__kav(
        Title = 'What to Do During a Power Outage (Stoerung)',
        UrlName = 'test-hw-power-outage',
        Summary = 'Check your fuse box first. If the whole street is dark, report the ' +
          'outage to the grid operator. We will credit you if service is ' +
          'interrupted for longer than the guaranteed period.'
      )
    };
    insert drafts;

    for (Knowledge__kav k : [
      SELECT KnowledgeArticleId
      FROM Knowledge__kav
      WHERE Id IN :drafts
    ]) {
      KbManagement.PublishingService.publishArticle(k.KnowledgeArticleId, true);
    }
  }

  @isTest
  static void findsArticleFromEnglishQuestion() {
    String q = 'I am moving house next month, what do I need to do?';
    Test.startTest();
    Map<String, HWKnowledgeService.Article> m = HWKnowledgeService.bestArticleByQuestion(
      new List<String>{ q }
    );
    Test.stopTest();

    HWKnowledgeService.Article a = m.get(q);
    System.assertNotEquals(
      null,
      a,
      'the moving-house article should be retrieved'
    );
    System.assert(
      a.title.contains('Moving House'),
      'picked the right article, got ' + a.title
    );
    System.assertNotEquals(
      null,
      a.articleNumber,
      'article number returned for the citation'
    );
    System.assert(
      a.citation.contains(a.articleNumber),
      'citation carries the article number'
    );
    System.assert(
      a.summary.contains('move-out date'),
      'the procedural answer text is returned'
    );
  }

  @isTest
  static void findsArticleFromGermanQuestion() {
    // The DE→EN alias map must land a German question on the English corpus.
    String q = 'Ich ziehe um, was muss ich tun?';
    Map<String, HWKnowledgeService.Article> m = HWKnowledgeService.bestArticleByQuestion(
      new List<String>{ q }
    );

    HWKnowledgeService.Article a = m.get(q);
    System.assertNotEquals(
      null,
      a,
      'German "ziehe um" should resolve to the Umzug article'
    );
    System.assert(
      a.title.contains('Umzug'),
      'picked the Umzug article, got ' + a.title
    );
  }

  @isTest
  static void picksOutageArticleNotMovingArticle() {
    String q = 'Stromausfall - was tun bei einer Stoerung?';
    Map<String, HWKnowledgeService.Article> m = HWKnowledgeService.bestArticleByQuestion(
      new List<String>{ q }
    );

    HWKnowledgeService.Article a = m.get(q);
    System.assertNotEquals(null, a, 'the outage article should be retrieved');
    System.assert(
      a.title.contains('Outage'),
      'scoring picked the outage article, got ' + a.title
    );
  }

  @isTest
  static void unrelatedQuestionMatchesNothing() {
    String q = 'What is the capital of France?';
    Map<String, HWKnowledgeService.Article> m = HWKnowledgeService.bestArticleByQuestion(
      new List<String>{ q }
    );
    System.assert(
      !m.containsKey(q),
      'an off-topic question must return nothing rather than a bad article'
    );
  }

  @isTest
  static void blankAndEmptyInputHandled() {
    System.assertEquals(
      0,
      HWKnowledgeService.bestArticleByQuestion(new List<String>()).size(),
      'empty list -> empty map'
    );
    System.assertEquals(
      0,
      HWKnowledgeService.bestArticleByQuestion(null).size(),
      'null -> empty map'
    );
    System.assertEquals(
      0,
      HWKnowledgeService.bestArticleByQuestion(new List<String>{ '  ' }).size(),
      'blank question -> no match'
    );
  }

  @isTest
  static void bulkUsesOneQueryForManyQuestions() {
    List<String> questions = new List<String>();
    for (Integer i = 0; i < 200; i++) {
      questions.add('I am moving house, question number ' + i);
    }
    Test.startTest();
    Map<String, HWKnowledgeService.Article> m = HWKnowledgeService.bestArticleByQuestion(
      questions
    );
    Test.stopTest();

    System.assertEquals(200, m.size(), 'every question resolved');
    System.assert(
      Limits.getQueries() <= 2,
      'bulk-safe: one corpus query regardless of question count, used ' +
      Limits.getQueries()
    );
  }
}
