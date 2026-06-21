# HanseWatt — Fazlar (Adım Adım İnşa Planı)

> Bu dosya, `ROADMAP.md`'deki fazları **adım adım, takip edilebilir** bir checklist'e çevirir.
> Her faz: **Amaç → Adımlar → Çıktı (deliverable) → Bitti kriteri (gate)**.
> Teknik isimler İngilizce (portföy standardı), açıklamalar Türkçe.
>
> **Kural:** Sıra önemli. **P0→P7 + GATE** önce ("Minimum Wow Demo"). Sonra öncelikli kuyruk:
> P8 → P9 → P10 → P11 → P12-14.
> Her `sf` komutu `--target-org hansewatt` taşır. TechnoStore/Configra org'larına dokunulmaz.

---

## ⚠️ KOTA DİSİPLİNİ (consumption discipline) — her faz için geçerli standing kural

Bu projeyi durduracak şey storage veya Apex governor limit'leri DEĞİL; **Data 360 ve
Agentforce'un kredi (consumption) kotalarıdır.** Her agent action, her CI refresh, her
identity-resolution job, her generative call kredi yakar ve bu kodla optimize edilemez —
bittiğinde reset beklersin. Aşağıdaki 7 kural her fazda uygulanır:

1. **Faz 0 sert gate:** Digital Wallet'tan gerçek kota rakamlarını ölçmeden P1'e geçilmez.
2. **Mock-first:** Apex action mantığı (SOQL/DML/JSON) önce Apex testleriyle doğrulanır
   (kredi yakmaz); agent'a bağlama en sona bırakılır. Agent'ı 50 kez deneyip kredi yakma.
3. **Küçük veri setiyle geliştir:** CI/identity mapping'ini 10 kayıtla doğrula, doğruysa
   tüm synthetic feed'e ölçekle. Mapping'i tekrar tekrar full-refresh'leme.
4. **On-demand, schedule etme:** dev sırasında CI / Identity Resolution / Segment'i elle
   tetikle; otomatik nightly schedule'a bağlama (boşa kredi).
5. **Eval/Red-team küçük + bir kez:** 8-10 utterance, bir kez çalıştır, sonucu kaydet
   (`HW_Agent_Eval_Result__c` + screenshot). Sıralama: **önce agent'ı dondur**, judge
   rubric'ini **sahte transcript'lerle** ayarla, sonra gerçek pipeline'ı tek sefer koştur.
6. **Artımlı kayıt:** her faz biter bitmez o parçanın video snippet'ini al; demo'yu
   snippet'lerden montajla. Tek büyük final canlı koşuya bağımlı kalma.
7. **Digital Wallet'ı ritüel yap:** her agent-yoğun seansın başında kalan krediyi kontrol
   et; `docs/manual-setup/burn-budget.md` tablosunu güncelle.

> Tek-org stratejisi: TechnoStore/Configra'dan ayrı **tek bir** HanseWatt build org'u
> kullanıyoruz. İkinci "temiz demo org" fikri reddedildi — Data 360 + Agentforce config
> source-track edilemediği için ikinci org'da elle baştan kurmak ağır bakım yükü. Demo
> güvenliği artımlı kayıtla (kural 6) sağlanır. Duvara çarparsak yeniden değerlendiririz.

---

## 🟢 FAZ 0 — Org + Temel (Foundations)

**Amaç:** Org'a bağlan, repo iskeletini kur, gerçek limitleri doğrula.

**Adımlar:**
1. Kayıt e-postası gelince org'u bağla: `sf org login web --alias hansewatt`
2. `sfdx-project.json` + paket dizinleri oluştur (force-app, -services, -actions, -handlers, -agent, -datacloud, -lwc, -tests)
3. `docs/` alt klasörleri: `adr/`, `architecture/`, `manual-setup/`, `security/`, `eval/`
4. Base permission set'ler: `HW_Admin`, `HW_ServiceAgent`, `HW_ReadOnly` (boş iskelet)
5. **D2 — SERT GATE: kota ölçümü.** Setup → **Digital Wallet** (Agentforce'un real-time
   tüketim ekranı) aç ve şu **4 sayıyı** `docs/manual-setup/limits.md`'ye yaz:
   (a) aylık Agentforce action/credit tavanı, (b) Data 360 credit tavanı,
   (c) reset periyodu (aylık mı/günlük mü), (d) **reset takvim günü** — "aylık" yetmez;
   her ayın 1'i mi yoksa org aktivasyon tarihi mi? (En pahalı fazları P10/P11'i reset'in
   hemen ardına denk getirmek için gerekli.) **Bu 4 sayı bilinmeden P1'e geçilmez.**
   Ayrıca yaz: **"Hiçbir Data 360 objesinde otomatik refresh schedule'ı YOK — CI / Identity
   Resolution / Segment hepsi elle tetiklenir."** (En sinsi kota sızıntısı scheduled refresh.)
6. **Burn-budget tablosu kur:** `docs/manual-setup/burn-budget.md` — faz / işlem tipi /
   tahmini kredi / kümülatif. "P10'a geldiğimde kaç kredi kalır" sorusunu önceden cevapla.
7. **D4 — Metadata isim kontrolü:** `GenAiPlanner` / `GenAiPromptTemplate` / `Bot` / `GenAiFunction` isimlerini canlı org'da teyit et
8. Boş skeleton'ı commit et + `.gitignore` (secret script'ler, org_info)

**Çıktı:** Bağlı org, deploy olan boş repo, **ölçülmüş kota rakamları + burn-budget tablosu**.
**Bitti kriteri:** `sf project deploy start --target-org hansewatt` temiz geçiyor **VE**
Digital Wallet'tan 3 kota sayısı yazılmış (sert gate — bu olmadan P1 başlamaz).

---

## 🟢 FAZ 1 — Service Cloud Çekirdeği

**Amaç:** Bir Case'in açılıp yönlendirildiği ve SLA'yı karşıladığı çalışan bir servis tabanı.

**Adımlar:**
1. Custom objeler + alanlar: `Meter__c`, `Meter_Reading__c`, `Tariff__c`, `Service_Contract__c`, `Energy_Bill__c`, `Outage__c`, `Consent__c`
2. `Case` record type'ları: Billing / Consumption / Move / Outage / Complaint + Almanca support process
3. German Knowledge: 10 makale (data category'ler agent topic'leriyle eşleşsin)
4. Omni-Channel: routing config, presence statuses, escalation queue, skills (dil + konu)
5. Entitlement + Milestone: SLA (örn. First Response 4h, Resolution 2 iş günü) + Case sayfasında milestone tracker
6. Multi-currency (C7): EUR/CHF; DE/AT/CH adres formatı (TechnoStore street-splitter mantığı)
7. Seed data script: 4 DACH demo hesabı (Lena/Hamburg-DE, Huber/Wien-AT, Müller GmbH/Köln-DE, Studio Alpina/Zürich-CH)

**Çıktı:** Çalışan Service Cloud tabanı + Almanca Knowledge + 4 demo hesabı.
**Bitti kriteri:** Manuel açılan bir Case Omni-Channel'dan yönlenir ve SLA milestone'u işler.

---

## 🟢 FAZ 2 — Data 360 Ingestion (Veri Alımı)

**Amaç:** Harici sayaç + fatura verisini Data 360'a aldır.

**Adımlar:**
1. Synthetic meter feed script'i: 3-6 aylık gerçekçi okuma üret (EV akşam piki, Wärmepumpe, tatil düşük, estimated/gaps)
2. Data Streams: `HW_MeterReadings` (Ingestion API), `HW_Billing` (SAP IS-U simüle CSV/API)
3. Salesforce CRM connector + Engagement (chat/case) stream
4. DLO'lar oluşsun (`HW_Meter_Reading__dll`, `HW_Bill__dll`)
5. **C9 — Ölçek gerekçesi:** "neden Apex trigger değil Data 360" tek paragraf → ADR-004 taslağı
6. **D3:** her manuel Data 360 adımının screenshot + adım listesi → `docs/manual-setup/`

**Çıktı:** Data 360'ta görünen harici veri + synthetic feed.
**Bitti kriteri:** Sayaç + fatura verisi Data 360 DLO'larında görünüyor.

---

## 🟢 FAZ 3 — Identity Resolution (Profil Birleştirme)

**Amaç:** Dağınık kaynaklardan tek birleşik müşteri profili.

**Adımlar:**
1. DLO → DMO mapping: `HW_Energy_Usage__dmo`, `HW_Billing__dmo`, Individual, Engagement
2. Match rules: email + fuzzy name/address + external meter/billing id
3. Reconciliation: contact için most-recent-wins, billing id için source-priority
4. **C5 — Kirli veri test case'i:** Lena Bergmann = "L. Bergmann" (SAP) + lena.b@gmx (web) + Lena Bergmann (CRM) → tek Unified Individual
5. **C8 — SoR tablosu/diyagramı:** her veri tipi nerede yazılır/okunur → ADR-003 + Mermaid

**Çıktı:** Unified Individual profili + SoR diyagramı.
**Bitti kriteri:** 3 farklı kaynaktaki Lena tek profile birleşiyor (canlı gösterilebilir).

---

## 🟢 FAZ 4 — Calculated Insights + Grafik (Görünür Wow)

**Amaç:** Agent'ın "kanıtı" olan metrikler + canlı tüketim grafiği.

**Adımlar:**
1. CI'lar: `Avg_Monthly_kWh`, `Consumption_Anomaly_Score`, `Time_of_Day_Profile`
2. `hwConsumptionChart` LWC (Chart.js): 6 ay ortalama + bu ay + akşam 18-22 spike, anomali/EV annotation
3. Grafiği Account/Contact record sayfasına yerleştir, Data 360 CI'dan besle
4. CI değerlerini Query API ile okunabilir doğrula (agent action'ı bunu kullanacak)

**Çıktı:** `hwConsumptionChart` + 3 çalışan CI.
**Bitti kriteri:** Grafik render oluyor, anomali skoru sorgulanabiliyor.

---

## 🟢 FAZ 5 — Agent v1 (Grounded Cevap)

**Amaç:** "Faturam neden yüksek?" sorusuna grounded, citation'lı cevap.

**Adımlar:**
1. `HW_Service_Agent` oluştur; topic: Billing & Consumption
2. Apex Action'lar: `HWGetLatestBillAction`, `HWExplainConsumptionAction`, `HWCreateCaseAction`
   - Kod standardı: `with sharing`, SOQL `WITH USER_MODE`, DML `as user`, bulk-safe, ≥80% test
3. Grounding: Knowledge retriever (DE) + Data 360 retriever
4. **C4 — Retriever split:** rakam/tüketim → Data 360; prosedür/nasıl → Knowledge
5. **C1 — Citation:** cevabın altında "Quelle: Knowledge DE-014 + CI Avg_Monthly_kWh"
6. Instructions/guardrails: kimlik doğrula, rakam uydurma, "Sie" formu

**Çıktı:** Çalışan müşteri agent'ı + 3 action + grounding.
**Bitti kriteri:** Lena Almanca sorar → agent grafiğe dayalı, citation'lı, doğru rakamlı cevap verir.

> **Bu noktada ~4 dakikalık çekirdek "wow" hazır.**

---

## 🟢 FAZ 6 — Prompt Templates + Trust Layer

**Amaç:** LLM yazımı + güvenlik katmanı görünür.

**Adımlar:**
1. `GenAiPromptTemplate`: `HW_BillExplanation` (Almanca anomali açıklaması), `HW_CaseSummary` (rep özeti)
2. Trust Layer: PII masking + grounding + toxicity'yi test et ve screenshot'la (örn. maskeli IBAN logu)

**Çıktı:** 2 deployable prompt template + Trust Layer kanıtı.
**Bitti kriteri:** Template'ler canlı, Trust Layer altında çalışıyor.

---

## 🟢 FAZ 7 — Escalation + Employee Agent (Jonas)

**Amaç:** Çözemezse insana temiz devir + otomatik özet.

**Adımlar:**
1. Action'lar: `HWProposeTariffAction`, `HWInitiateTariffChangeAction`, `HWEscalateToHumanAction`
2. `HW_Employee_Agent` (Jonas): topic CaseSummary + NextBestAction
3. Escalation → Omni-Channel → Jonas Case açınca otomatik Almanca `HW_CaseSummary`
4. **E5 — Sentiment routing:** öfke/Kündigung tespit → SLA kısalt + yönlendir
5. **C10 — Two-agent kararı** → ADR-011

**Çıktı:** Tam handoff akışı + 2. agent.
**Bitti kriteri:** Memnuniyetsiz müşteri → escalation → Jonas özetiyle Case'i devralır.

---

## 🎬 GATE — Minimum Wow Demo Kaydı

**Amaç:** Çekirdeği kaydet; tek başına portföye değer.

**Adımlar (3 perde, ~5 dk):**
1. Perde 1: Lena'nın fatura şoku + grafik
2. Perde 2: Grounded cevap (citation) + otonom tarife değişikliği
3. Perde 3: Escalation → Jonas özeti
4. Kapanış 30 sn: "dış sistemler simüle, Salesforce kod yolları gerçek" honesty statement

**Bitti kriteri:** Kayıt alındı. → Buradan sonra ikinci dalga.

---

## 🔶 FAZ 8 — Closed Loop (Proaktif Döngü)

**Amaç:** Sistem bir sonraki şikayeti oluşmadan önler.

**Adımlar:**
1. Segment: `High_Consumption_Anomaly_No_TariffChange_30d`
2. Activation Flow: fatura kesilmeden 5 gün önce Almanca email ("62% mehr → EV-Tarif prüfen?")
3. **E7 — Event-driven backbone:** Platform Events (anomaly/outage/escalation)
4. `HWCheckOutageAction`, `HWStartMoveAction` (Flow, Umzug + final bill estimate)

**Çıktı:** Çalışan proaktif segment + event backbone.
**Bitti kriteri:** Segment tetikleniyor, proaktif outreach gönderiliyor.

---

## 🔶 FAZ 9 — DSGVO (Right to be Forgotten)

**Amaç:** Compliance'ı kağıt değil, gerçek otomasyon yap.

**Adımlar:**
1. `Consent__c` + consent capture
2. `hwComplianceActions` LWC butonu: "DSGVO Löschung"
3. Akış: Account/Contact anonymize → Data 360 Delete API → Platform Event audit log
4. **C6 — Agent guardrail:** silme talebi → DSGVO process'e route, asla inline silme → ADR-009

**Çıktı:** Çalışan RtbF aracı + agent guardrail.
**Bitti kriteri:** Bir veri sahibi anonimleşiyor + audit event yazılıyor.

---

## 🔶 FAZ 10 — Agent Eval Framework (Manşet Farklılaştırıcı #1)

**Amaç:** "Ben agent'ın kalitesini ölçen sistem kurdum" diyebilmek.

**Adımlar:**
1. `HW_Agent_Eval_Result__c` objesi (rubric alanları: grounding/hallucination/correct-action/trust/tone/escalation)
2. `HW_AgentJudge` prompt template (ikinci LLM, rubric'e göre puanlar)
3. `HWAgentEvalService`: utterance suite → agent → judge → result rows
4. `hwAgentScorecard` LWC + Notion "Agent Quality Scorecard"
5. Regresyon: agent değişince yeniden çalıştır → ADR-012

> ⚠️ **Kota uyarısı (en pahalı faz) — "bir kez"in gerçekten bir kez kalması için sıralama:**
> - **Önce agent'ı dondur.** Eval'i, agent'ın instruction/guardrail'lerini stabilize
>   ettikten ("artık dokunmuyorum" dedikten) SONRA çalıştır. Aksi halde her agent ayarında
>   "bir kez"i tekrar tekrar harcarsın.
> - **Judge'ı agent'tan ayrı geliştir.** `HW_AgentJudge` rubric'ini ayarlarken canlı agent
>   çıktısına değil, elle yazdığın **1-2 sahte transcript'e** karşı test et (agent
>   çalıştırma → kredi yok). Rubric oturunca gerçek pipeline'ı **tek sefer** koştur.
> - Suite'i **8-10 utterance** ile sınırla. Sergilenecek olan **sonuç** (result rows +
>   screenshot), canlı koşu değil.

**Çıktı:** Çalışan eval pipeline + kaydedilmiş scorecard.
**Bitti kriteri:** Küçük (8-10) utterance suite üzerinde scorecard bir kez üretilip kaydedildi.

---

## 🔶 FAZ 11 — Red-Team Showcase (Manşet Farklılaştırıcı #2)

**Amaç:** Enerji + kişisel veri bağlamında güvenlik olgunluğu.

**Adımlar:**
1. `docs/security/red-team-suite.md`: ≥8 saldırı (DE + EN): prompt injection, komşunun faturası, "faturamı sıfırla", veri silme social engineering, toxicity, off-topic, cross-customer lookup, hallucination bait
2. Her saldırı: beklenen red/escalation + gerçek + verdict (eval objesinde `Is_Adversarial__c=true`)
3. Trust Layer PII masking kanıtı (transcript + screenshot) → ADR-013

**Çıktı:** Belgeli red-team süiti + kanıtlar.
**Bitti kriteri:** 8+ saldırının agent direnci belgelenmiş.

---

## 🔶 FAZ 12 — Sustainability + ROI + Dayanıklılık

**Amaç:** DACH ESG + iş değeri + "her havada uçan" sistem.

**Adımlar:**
1. **E3:** `CO2_Estimate_kg` + `Peer_Comparison_Score` CI'ları (postcode-bucket, GDPR-safe)
2. **E6:** `hwRoiDashboard` — deflection % → € tasarruf, churn ↓
3. **E8:** graceful degradation — CI yoksa agent fallback path (VF/karar ağacı)

**Çıktı:** ESG + ROI dashboard + fallback.
**Bitti kriteri:** Dashboard gerçek demo verisini okuyor.

---

## 🔶 FAZ 13 — Multi-Channel (WhatsApp Continuity)

**Amaç:** Aynı agent web + WhatsApp; context korunur (identity resolution kanıtı).

**Adımlar:**
1. TechnoStore Twilio inbound'ı uyarla
2. Lena web'den başlar, WhatsApp'tan devam eder, agent context'i korur (Messaging Session → Unified Individual)

**Çıktı:** Çok-kanallı tek agent.
**Bitti kriteri:** Web'de başlayan sohbet WhatsApp'ta context'le devam ediyor.

---

## 🔶 FAZ 14 — Dokümantasyon + Kayıtlar (Portföy Cilası)

**Amaç:** TechnoStore dokümantasyon kalitesini yakala.

**Adımlar:**
1. ADR'lar (001-016), 6 Mermaid diagram
2. ~30 STAR Notion entry (bilingual DE/EN)
3. İki demo: 10 dk (tam) + 90 sn (LinkedIn hook), split-screen (müşteri sol / Salesforce sağ)
4. Combined landing page: "TechnoStore (Sell) + HanseWatt (Serve)"
5. arc42 `SOLUTION_BLUEPRINT.md`, professional README + CI

**Çıktı:** Portföy-hazır proje.
**Bitti kriteri:** Tüm dokümanlar + kayıtlar yayınlanmış.

---

## Özet tablo

| Faz | Tema | Grup |
|---|---|---|
| 0 | Org + temel | Çekirdek |
| 1 | Service Cloud çekirdeği | Çekirdek |
| 2 | Data 360 ingestion | Çekirdek |
| 3 | Identity resolution | Çekirdek |
| 4 | CI + grafik | Çekirdek |
| 5 | Agent v1 (grounded) | Çekirdek |
| 6 | Prompt templates + Trust Layer | Çekirdek |
| 7 | Escalation + Jonas agent | Çekirdek |
| 🎬 | **Minimum Wow Demo kaydı** | **GATE** |
| 8 | Closed loop (proaktif) | İkinci dalga |
| 9 | DSGVO RtbF | İkinci dalga |
| 10 | Agent Eval framework | İkinci dalga ⭐ |
| 11 | Red-team showcase | İkinci dalga ⭐ |
| 12 | Sustainability + ROI | İkinci dalga |
| 13 | Multi-channel WhatsApp | İkinci dalga |
| 14 | Docs + kayıtlar | Cila |

⭐ = manşet farklılaştırıcılar (çok az adayda var)

---

*15 faz (P0-P14). İlk 8 (P0-P7) + GATE = Minimum Wow Demo. Org gelince P0 ile başlıyoruz.*
