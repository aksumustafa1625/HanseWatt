// HanseWatt — Faz 1 Knowledge seed: 10 English articles, categorized + published.
// Run: sf apex run --file scripts/seed_knowledge.apex --target-org hansewatt
// Idempotent: skips any article whose UrlName already exists. Content is English
// (build language); German is a later localization step. Article body lives in the
// standard Summary field (<=1000 chars) — the custom rich-text Body__c is not yet
// query-exposed on Knowledge__kav in this org. Requires Lightning Knowledge enabled
// and the running user to be a Knowledge User with Manage Articles.

// ---- Article definitions (Title | UrlName | Category | Content) -----------------------
List<Map<String,String>> defs = new List<Map<String,String>>{
    new Map<String,String>{
        'title'=>'Understanding Your Monthly Bill', 'url'=>'hw-understanding-your-bill', 'cat'=>'Billing',
        'text'=>'Each HanseWatt bill has three parts: a fixed base fee (Grundpreis), your consumption charge (kWh used times price per kWh), and statutory taxes and levies. The billing period and the meter readings used are shown at the top of the invoice. If a reading was estimated, the bill is marked accordingly and corrected at the next actual reading.'
    },
    new Map<String,String>{
        'title'=>'Payment Methods and Due Dates', 'url'=>'hw-payment-methods', 'cat'=>'Billing',
        'text'=>'You can pay by SEPA direct debit (recommended) or bank transfer. Direct debit is collected about 10 days after the invoice date. For bank transfer, payment is due within 14 days. You can update your payment method at any time in your customer account.'
    },
    new Map<String,String>{
        'title'=>'Why Is My Bill Higher Than Usual?', 'url'=>'hw-why-bill-higher', 'cat'=>'Consumption',
        'text'=>'The most common reason is simply higher consumption. Compare this period\'s kWh to your trailing average on the consumption chart. Typical drivers: a new high-draw appliance (EV charger, heat pump), colder months, more people at home, or a tariff price change. If usage rose mostly in the evenings, that often points to EV charging. Our agent can explain the anomaly against your meter data and suggest a better-fit tariff.'
    },
    new Map<String,String>{
        'title'=>'Understanding Smart Meter Readings', 'url'=>'hw-smart-meter-readings', 'cat'=>'Consumption',
        'text'=>'Your smart meter reports consumption automatically. Readings marked Smart are measured; readings marked Estimated are projected when a measured value was unavailable and are corrected later. You can always submit a manual reading if needed.'
    },
    new Map<String,String>{
        'title'=>'EV Charging and Your Electricity Usage', 'url'=>'hw-ev-charging-usage', 'cat'=>'Consumption',
        'text'=>'Home charging can add a large, regular evening load. If you charge overnight, our EV tariff offers a lower price per kWh in exchange for a slightly higher base fee, which is usually cheaper overall for EV owners. Review the tariff comparison before switching.'
    },
    new Map<String,String>{
        'title'=>'Comparing HanseWatt Tariffs', 'url'=>'hw-comparing-tariffs', 'cat'=>'Tariff',
        'text'=>'Our tariffs: Strom Basis (standard electricity, lowest base fee); Oekostrom (100% green electricity); Strom EV-Tarif (green, lower price per kWh, best for high or EV usage); and Gas Basis (standard gas). The right tariff depends on how much you use and when. Higher usage favors a lower price-per-kWh tariff even if the base fee is higher.'
    },
    new Map<String,String>{
        'title'=>'Switching to a Green or EV Tariff', 'url'=>'hw-switching-tariff', 'cat'=>'Tariff',
        'text'=>'You can switch tariffs from your customer account or by asking our service agent. The change normally takes effect at the start of the next billing period. Your meter and contract stay the same; only the pricing changes. You receive a written confirmation.'
    },
    new Map<String,String>{
        'title'=>'Moving House: Start or Stop Service (Umzug)', 'url'=>'hw-moving-house-umzug', 'cat'=>'Move',
        'text'=>'Tell us your move-out date and final meter reading so we can issue a final bill. To continue as a customer, give us the new address and move-in date and we will start service there. Provide both readings to avoid estimates.'
    },
    new Map<String,String>{
        'title'=>'What to Do During a Power Outage (Stoerung)', 'url'=>'hw-power-outage-stoerung', 'cat'=>'Outage',
        'text'=>'First check whether the outage affects only your home (a tripped fuse) or the wider area. Our agent can check for a known outage in your region and its expected restoration time. For safety issues or downed lines, contact the emergency number on your invoice.'
    },
    new Map<String,String>{
        'title'=>'Contract Terms, Renewal, and Cancellation', 'url'=>'hw-contract-renewal', 'cat'=>'Contract',
        'text'=>'Contracts run for a fixed term and then renew automatically unless cancelled within the notice period stated in your contract. You can see your contract start and end dates in your account. To cancel, contact us before the notice deadline; we confirm every cancellation in writing.'
    }
};

// ---- Insert drafts (skip existing), categorize, publish --------------------------------
Set<String> wantUrls = new Set<String>();
for (Map<String,String> d : defs) wantUrls.add(d.get('url'));
Set<String> existing = new Set<String>();
for (Knowledge__kav k : [SELECT UrlName FROM Knowledge__kav WHERE UrlName IN :wantUrls]) existing.add(k.UrlName);

List<Knowledge__kav> toInsert = new List<Knowledge__kav>();
List<Map<String,String>> inserting = new List<Map<String,String>>();
for (Map<String,String> d : defs) {
    if (existing.contains(d.get('url'))) continue;
    toInsert.add(new Knowledge__kav(
        Title = d.get('title'), UrlName = d.get('url'),
        Summary = d.get('text'), Language = 'en_US'
    ));
    inserting.add(d);
}

if (toInsert.isEmpty()) {
    System.debug('Knowledge seed: all ' + defs.size() + ' articles already exist. Nothing to do.');
} else {
    insert toInsert;

    // Category selections (must be added while Draft)
    List<Knowledge__DataCategorySelection> cats = new List<Knowledge__DataCategorySelection>();
    for (Integer i = 0; i < toInsert.size(); i++) {
        cats.add(new Knowledge__DataCategorySelection(
            ParentId = toInsert[i].Id,
            DataCategoryGroupName = 'HanseWatt_Topics',
            DataCategoryName = inserting[i].get('cat')
        ));
    }
    insert cats;

    // Publish each (needs the KnowledgeArticleId master id)
    Map<Id,Id> kavToArticle = new Map<Id,Id>();
    for (Knowledge__kav k : [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Id IN :toInsert]) {
        kavToArticle.put(k.Id, k.KnowledgeArticleId);
    }
    Integer published = 0;
    for (Knowledge__kav k : toInsert) {
        KbManagement.PublishingService.publishArticle(kavToArticle.get(k.Id), true);
        published++;
    }
    System.debug('Knowledge seed: inserted ' + toInsert.size() + ', categorized ' + cats.size()
        + ', published ' + published + '. (skipped ' + existing.size() + ' existing)');
}
