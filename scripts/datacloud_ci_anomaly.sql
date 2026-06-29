-- HanseWatt — Consumption Anomaly "Calculated Insight" logic, run against Data 360.
-- Source: the Meter Reading Data Lake Object (Salesforce CRM ingestion, free pipeline).
-- For each meter: latest reading vs the trailing average of prior readings, as a %.
-- This is the figures-half grounding (ADR-007) — validated via the Query API
-- (scripts/datacloud_query.ps1) without a UI Calculated Insight.
--
-- DLO column note: a custom Salesforce field `X__c` lands in the DLO as `X_c__c`.
WITH ranked AS (
    SELECT Meter_c__c        AS meter,
           kWh_c__c          AS kwh,
           ROW_NUMBER() OVER (PARTITION BY Meter_c__c ORDER BY Read_Date_c__c DESC) AS rn
    FROM   Meter_Reading_c_Home__dll
)
SELECT meter,
       MAX(CASE WHEN rn = 1 THEN kwh END)                                          AS latest_kwh,
       ROUND(AVG(CASE WHEN rn > 1 THEN kwh END), 1)                                AS avg_prior_kwh,
       ROUND((MAX(CASE WHEN rn = 1 THEN kwh END) - AVG(CASE WHEN rn > 1 THEN kwh END))
             / AVG(CASE WHEN rn > 1 THEN kwh END) * 100, 1)                        AS anomaly_pct
FROM   ranked
GROUP BY meter
-- Verified 2026-06-29: Lena's meter = latest 520 vs avg 316 prior = +64.6% anomaly.
