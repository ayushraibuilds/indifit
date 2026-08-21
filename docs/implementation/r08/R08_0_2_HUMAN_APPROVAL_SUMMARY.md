# IndiFit R08-0.2: RepDB Movement Mapping Human Approval Summary

**Status:** **BINDING HUMAN APPROVAL RECORD COMPLETED**
**Approval Date:** 2026-08-21
**Approved By:** Human Product Owner
**Pinned RepDB Source Commit:** `045845b61e4aefd9e684fa84518b84c665ea3cd3`

---

## 1. Executive Summary & Approval Totals

The human product approval stage for IndiFit R08-0.2 is formally closed. This record establishes the binding human decisions for visual movement illustration reuse from the pinned RepDB free-tier dataset.

- **Total Movement Families Reviewed:** 35 families (covering all 140 canonical catalog exercise UUIDs)
- **Approved Families:** **30 families** (`120` canonical UUID bindings)
- **Rejected / Fallback Families:** **5 families** (`20` canonical UUID bindings)
- **Production Media Vendoring Status:** Zero production assets vendored (`assets/exercises/repdb/` remains empty; production manifest contains 0 assets).

---

## 2. Decision Pipeline & Authority Chain

```
Pinned RepDB Snapshot (045845b61e4aefd9e684fa84518b84c665ea3cd3)
    │
    ▼
Candidate Mapping & Contact Sheet (Flash Candidate R08_0_2_REPDB_MAPPING_REVIEW.csv)
    │
    ▼
Independent Visual & Mechanical Review (Terra Review R08_0_2_TERRA_RECOMMENDATIONS.csv)
    │
    ▼
Binding Human Product Decisions (R08_0_2_REPDB_MAPPING_APPROVALS.csv)
```

1. **Flash Candidate Review (`R08_0_2_REPDB_MAPPING_REVIEW.csv`):** Historical metadata reconciliation and initial candidate pose acquisition.
2. **Terra Independent Visual Review (`R08_0_2_TERRA_VISUAL_REVIEW.md`):** Detailed frame-by-frame biomechanical inspection of 67 actual review WebP images against canonical IndiFit cues, equipment, and movement definitions.
3. **Human Approval Authority (`R08_0_2_REPDB_MAPPING_APPROVALS.csv`):** Final binding governance record. All 30 Terra `APPROVE_RECOMMENDED` families are approved; all 4 Terra `REJECT_RECOMMENDED` families are rejected; the single `NEEDS_HUMAN_REVIEW` family (`FAM-19` Walking Lunges) is rejected to enforce fail-closed product integrity.

---

## 3. Rejected / Fallback Families & Explicit Rationales

The following 5 families fail closed to IndiFit's standard **B05 canonical muscle / neutral text fallback chain**. No synthetic or approximate artwork may be substituted:

| Family ID | Canonical Movement | Candidate RepDB ID | Explicit Rejection Reason |
|---|---|---|---|
| **`FAM-03`** | **Decline Hammer Strength Press** | `NO_MATCH` | No truthful plate-loaded convergent decline Hammer Strength-style candidate exists in RepDB free tier. Generic barbell decline or seated chest machine press is strictly prohibited. |
| **`FAM-17`** | **Seated Leg Curl** | `leg-curl` | Candidate depicts a prone/lying leg curl machine, which materially contradicts the canonical seated body orientation and apparatus geometry. |
| **`FAM-18`** | **Standing Calf Raise** | `standing-calf-raise` | Canonical catalog specifies Bodyweight standing calf raises on a step edge; candidate visibly depicts a loaded standing calf machine with shoulder pads and weight stack. |
| **`FAM-19`** | **Walking Lunges** | `db-lunge` | Candidate communicates a stationary forward lunge step but does not truthfully communicate walking or alternating locomotion. Product authority requires visible locomotion/alternation; fails closed. |
| **`FAM-35`** | **Hanging Leg Raise** | `hanging-leg-raise` | Candidate depicts a bent-knee hanging knee raise rather than the canonical straight-leg raise to approximately 90 degrees. |

---

## 4. Approved Specificity & Caveats (Non-Invalidating)

The following minor specificities were reviewed by Terra and approved by the Human Product Owner as acceptable movement illustrations for unspecialized generic movements:

- **`FAM-12` (Seated Cable Row):** Depicts a wide-grip straight-bar attachment. Approved for generic seated cable row; attachment is noted but not misleading.
- **`FAM-28` (Preacher Curl):** Depicts an EZ-curl bar. Approved for generic preacher curl; arm-supported pad mechanics are exact.
- **`FAM-34` (Plank):** Static hold movement. Approved with single `MAIN` pose (`plank-main.webp`) rather than dynamic start/peak pair.

---

## 5. Mandatory Product & Technique Disclosure

The following disclosure is binding for all approved exercise visual presentations:

> **Mandatory Product Disclosure:**
> Exercise artwork represents the underlying physical movement and equipment. It does not demonstrate exact pause duration, tempo, cadence, or other IndiFit technique prescriptions. IndiFit cues and set prescriptions remain the sole technique authority.

---

## 6. Canonical Identity & Architecture Guardrails

1. **140 Canonical UUIDs Remain Distinct:** Every canonical exercise entry preserves its unique, immutable UUID. No exercises are merged, renamed, or deleted.
2. **Zero Domain Model Changes:** No `baseMovementVisualKey`, `visual_id`, or `family_id` column or property is introduced into the database, domain entities, or backup formats.
3. **Explicit Future Asset Binding:** In R08-0.3+, the 4 canonical variant UUIDs of each approved family will explicitly bind to the approved visual asset-set ID in the visual registry.
4. **Zero Production Media Vendored:** No review images were moved into `assets/exercises/repdb/` or registered in `assets/third_party/asset_manifest.json`.

---

## 7. Approval Ledger Reference

The complete machine-readable ledger is maintained in:
[`docs/implementation/r08/R08_0_2_REPDB_MAPPING_APPROVALS.csv`](file:///Users/dankmagician/Documents/New%20project/indifit/docs/implementation/r08/R08_0_2_REPDB_MAPPING_APPROVALS.csv)
