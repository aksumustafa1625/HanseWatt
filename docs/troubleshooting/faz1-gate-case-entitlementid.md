# Troubleshooting — `Case.EntitlementId` missing despite Entitlement Management ON

> **Purpose:** a self-contained writeup so another engineer or AI can help diagnose why the
> standard **`Case.EntitlementId`** lookup is absent from the Case object in this org even
> though Entitlement Management is enabled. Everything needed to reason about the problem is
> below — no prior context required.
>
> **Status:** RESOLVED (confirmed edition limitation) · **Last updated:** 2026-06-29

---

## 1. Goal (what we're trying to do)

Close the **Faz 1 gate** of the HanseWatt project: prove that a **Case linked to an
Entitlement** automatically generates **`CaseMilestone`** rows (the SLA clock starts). This
is the standard Salesforce Service Cloud Entitlements + Milestones flow:

```
Entitlement (linked to an SLA/Entitlement Process)
        │
        ▼
Case.EntitlementId = <entitlement>   ──►  Salesforce auto-creates CaseMilestone rows
                                          (First Response, Resolution) with target dates
```

To do this we set `Case.EntitlementId`. **That field does not exist on Case in this org**,
which blocks the whole flow.

## 2. Environment

| | |
|---|---|
| Org alias | `hansewatt` |
| Edition | **Developer Edition with Agentforce + Data 360** |
| Instance | `your-org.develop.my.salesforce.com` |
| API version | **67.0** |
| Org ID | `00Dxx0000000000XXX` (instance CAN96) |

## 3. What is already built & verified (works fine)

All deployed as source metadata, confirmed present via `sf org list metadata` / SOQL:

- **EntitlementProcess** `HW_Standard_SLA` — active, `exitCriteriaFormula = IsClosed`,
  `SObjectType = Case`, `entryStartDateField = CreatedDate`.
- **MilestoneType** `HW_First_Response`, `HW_Resolution` (process binds them with
  `minutesToComplete` 240 / 2880 against `Default` business hours).
- **SlaProcess** row exists: `SELECT Name FROM SlaProcess` → `HW_Standard_SLA`, `IsActive=true`.
  (Note: `SlaProcess.Name` is the **developer name** `HW_Standard_SLA`, not the friendly
  label "HW Standard SLA".)
- **Entitlement** object is queryable; `SELECT COUNT() FROM Entitlement` → 1 record exists.
- **Omni-Channel** (service channel, escalation queue, routing config, presence statuses,
  skills) — all deployed.

So entitlements/milestones are clearly **functional at the metadata layer**.

## 4. The symptom — `Case.EntitlementId` is not in the Case schema

Every access path agrees the field is absent from the **active** Case schema:

| Probe | Result |
|---|---|
| Apex constructor `new Case(EntitlementId = x)` | **compile error**: `Field does not exist: EntitlementId on Case` |
| Apex dynamic `c.put('EntitlementId', x)` | **runtime**: `System.SObjectException: Invalid field EntitlementId for Case` |
| SOQL `SELECT EntitlementId FROM Case LIMIT 1` | `No such column 'EntitlementId' on entity 'Case'` |
| Apex `Case.SObjectType.getDescribe().fields.getMap()` | does **not** contain `entitlementid` (only custom `slaviolation__c`) |
| `sf sobject describe --sobject Case` | only `SLAViolation__c` matches `Entitlement\|Sla\|Milestone` |

**The contradiction:** Tooling API **does** report the field as existing:

```sql
-- Tooling API
SELECT QualifiedApiName, DataType
FROM FieldDefinition
WHERE EntityDefinition.QualifiedApiName='Case' AND QualifiedApiName='EntitlementId'
-- → returns: EntitlementId | Lookup(Entitlement)
```

So `FieldDefinition` lists `Case.EntitlementId` as a `Lookup(Entitlement)`, but the field is
**not materialized** in the runtime/Apex/SOQL schema.

## 5. The other contradiction — the setting is already ON

Retrieved the live `EntitlementSettings` metadata:

```xml
<EntitlementSettings xmlns="http://soap.sforce.com/2006/04/metadata">
    <enableEntitlements>true</enableEntitlements>          <!-- ON -->
    <enableEntitlementVersioning>false</enableEntitlementVersioning>
    <enableMilestoneFeedItem>false</enableMilestoneFeedItem>
    <enableMilestoneStoppedTime>false</enableMilestoneStoppedTime>
    <ignoreMilestoneBusinessHours>false</ignoreMilestoneBusinessHours>
    <!-- all asset/entitlement lookup filters = false -->
</EntitlementSettings>
```

In the Setup UI (**Feature Settings → Service → Entitlement Management → Entitlement
Settings**) the **"Entitlement Management"** master checkbox is ✓ checked. So entitlement
management is enabled — yet the Case lookup field that enabling it normally adds is not on
the object.

## 6. Everything we tried (chronological)

1. **Apex constructor** `new Case(EntitlementId = ent.Id)` → compile error (§4).
2. **Dynamic put** `c.put('EntitlementId', ent.Id)` → runtime "Invalid field" (§4). (Used to
   bypass the compile-time check, suspecting a stale compile cache.)
3. **Waited overnight (~12 h)** suspecting a schema-cache propagation lag after a heavy day
   of schema changes (Knowledge enable, multi-currency activate, entitlements, dozens of
   deploys). → No change next morning.
4. **Live Apex global-describe introspection** (`getGlobalDescribe`-style) confirmed the
   field is genuinely absent from the Case field map — not an FLS or cache artifact, because
   `fields.getMap()` returns all fields regardless of FLS. → `has entitlementid: false`.
5. **Retrieved `EntitlementSettings`** → `enableEntitlements` is **already `true`** (§5).
6. **UI re-toggle** (user): unchecked "Entitlement Management" → Save → re-checked → Save.
   After this, re-ran the introspection → **field still absent**; `SlaProcess` +
   `MilestoneType` rows **survived**. (Implies the disable either did nothing to field
   provisioning, or Salesforce silently blocked disabling because an active entitlement
   process exists.)
7. **Metadata disable attempt** — tried to deploy `EntitlementSettings` with
   `enableEntitlements=false` from a temp dir via `sf project deploy start --source-dir` →
   CLI returned **`NothingToDeploy: No local changes to deploy`** (source-tracking would not
   push the settings file from a non-package path). Not yet forced via MDAPI.

## 7. What we have ruled out

- ❌ **Transient schema cache** — 12 h elapsed; live Apex introspection is authoritative.
- ❌ **The `enableEntitlements` setting** — it is already `true`.
- ❌ **Our metadata being wrong** — the EntitlementProcess + MilestoneTypes deploy and exist.
- ❌ **FLS** — `fields.getMap()` ignores FLS and still doesn't list the field.

## 8. Current hypotheses (need confirmation)

- **(H1)** This Developer Edition *flavor* (Agentforce + Data 360) does not **provision the
  standard Case entitlement lookup fields** (`EntitlementId`, `SlaStartDate`, `SlaExitDate`,
  `MilestoneStatus`, `SlaExitDate`) even though the feature toggle reports enabled — a
  platform/edition limitation.
- **(H2)** Disabling Entitlement Management (to force a clean re-provision) is **blocked**
  while an active EntitlementProcess + Entitlement exist, so the re-toggle in step 6 never
  actually toggled, hence no re-provision.
- **(H3)** A hidden prerequisite materializes the field: a specific **permission set /
  license**, a **page-layout** action, a **Service Setup** flow, or **Simplified SLA Setup**.

## 9. Open questions for a second opinion (sister AI / Salesforce expert)

1. In a **Developer Edition with Agentforce + Data 360**, with Entitlement Management
   enabled, why would **`Case.EntitlementId` be absent** from the Case object's runtime/Apex/
   SOQL schema while **appearing in Tooling `FieldDefinition`** as `Lookup(Entitlement)`?
   Is this a known edition limitation?
2. What exactly **materializes** the Case Entitlement lookup field? Is it added only via the
   **UI** "Enable Entitlement Management" action (not via metadata `enableEntitlements`)?
   Is there a **page-layout** or **related-list** step required first?
3. To force a clean **disable → re-enable** re-provision: what is the correct, safe sequence?
   (Delete `Entitlement` records → deactivate/delete the `EntitlementProcess` → uncheck
   Enable Entitlement Management → Save → re-check → Save?) Does that actually re-add
   `Case.EntitlementId`?
4. Is the Case Entitlement lookup gated behind a **license or permission** (e.g. an Entitlement
   / Service Cloud feature license) that is not active in this org?
5. Is there a way to **deploy `enableEntitlements=false` reliably** (e.g. MDAPI `deploy
   --metadata-dir`, or `--ignore-conflicts`) when `sf project deploy start --source-dir`
   reports `NothingToDeploy`?
6. **Workaround:** can we demonstrate Milestones/SLA **without** `Case.EntitlementId` in this
   org (e.g. milestones on a different supported object, or asserting the milestone
   definition another way)?

## 10. How to reproduce the key probes

```bash
# 1. Field genuinely absent (live Apex) — expect "has entitlementid: false"
#    (Apex: Case.SObjectType.getDescribe().fields.getMap().containsKey('entitlementid'))

# 2. Field present in Tooling FieldDefinition — expect 1 row
sf data query --use-tooling-api \
  --query "SELECT QualifiedApiName, DataType FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName='Case' AND QualifiedApiName='EntitlementId'" \
  --target-org hansewatt

# 3. Setting already ON — retrieve EntitlementSettings
sf project retrieve start --metadata "Settings:Entitlement" --target-org hansewatt --target-metadata-dir ./_tmp

# 4. SLA process exists
sf data query --query "SELECT Name, IsActive FROM SlaProcess" --target-org hansewatt

# 5. The blocked write (gate) — scripts/verify_gate.apex sets Case.EntitlementId and fails:
sf apex run --file scripts/verify_gate.apex --target-org hansewatt
# → System.SObjectException: Invalid field EntitlementId for Case
```

## 11. Impact / not a blocker

The Faz 1 **SLA infrastructure** (EntitlementProcess + Milestones + Omni-Channel routing) is
fully built, deployed, and committed. Only the **live milestone-clock binding** is blocked
by this field. It does **not** block Faz 2 (Data Cloud) or any later phase — consistent with
the project's honest-framing philosophy (some Dev-Edition features are config-limited). If
unresolved, the gate is recorded as "infrastructure complete; live SLA clock = Dev-Edition
limitation". See [ADR-017](../adr/ADR-017-sla-entitlement-omnichannel-routing.md).

---

## 12. RESOLUTION (2026-06-29) — confirmed edition limitation

A second-opinion pass (multiple AIs) surfaced two real causes; we fixed what was fixable and
confirmed the rest is a platform limit:

1. **The running user was NOT a "Service Cloud User"** (`UserPermissionsSupportUser = false`)
   — abnormal for an admin, and exactly the gate that hides Service-Cloud-licensed standard
   fields even from `fields.getMap()`. **Fixed** (set to `true`).
2. With the license fixed, we ran the **full clean re-provision** the experts prescribed:
   deleted the `Entitlement` record → deleted the `EntitlementProcess` from the org →
   **disabled** Entitlement Management → **re-enabled** it, via *both* metadata deploy *and*
   the **Setup UI toggle** (the UI action normally triggers the async field-provisioning job).

**Outcome:** `Case.EntitlementId` **still did not materialize** — confirmed by the relationship
probe (`SELECT Entitlement.Name FROM Case` → "No such relation 'Entitlement'") after every
step, plus a ~5-minute post-toggle poll.

**Conclusion (H1 confirmed):** this **Developer Edition (Agentforce + Data 360) flavor does
not provision the standard Case entitlement lookup fields** (`EntitlementId`, `SlaStartDate`,
`SlaExitDate`, `MilestoneStatus`), even with the feature enabled, a Service Cloud User
license, and a clean UI disable/re-enable cycle. The fields are catalogued in Tooling
`FieldDefinition` but never instantiated on the Case object. This is **not** a metadata, FLS,
cache, or skill gap.

**Decision:** record the Faz 1 gate as **"SLA infrastructure complete + source-deployable;
live milestone-clock binding deferred — edition limitation"**. `scripts/verify_gate.apex` now
**guards on the field** and reports this gracefully instead of erroring. The binding works
normally in a Service Cloud Enterprise/Unlimited org or a standard Service-Cloud Developer
org — a clean future-verification path if ever needed.

**Org left consistent:** Service Cloud User = true; Entitlement Management = on;
`HW_Standard_SLA` + milestones redeployed; no orphaned Entitlement records.
