#!/usr/bin/env python3
import csv
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS_R08_DIR = os.path.join(PROJECT_ROOT, "docs", "implementation", "r08")

# Human Decisions specification
HUMAN_DECISIONS = [
    {
        "family_id": "FAM-01",
        "indifit_name": "Flat Barbell Bench Press",
        "repdb_id": "bench-press",
        "human_decision": "APPROVED",
        "human_reason": "Visual truthfully communicates conventional flat barbell bench press mechanics, setup, and barbell equipment.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-01",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants as underlying movement illustration."
    },
    {
        "family_id": "FAM-02",
        "indifit_name": "Incline Dumbbell Bench Press",
        "repdb_id": "incline-db-press",
        "human_decision": "APPROVED",
        "human_reason": "Incline angle, bilateral dumbbell loading, and pressing path are visually truthful.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-02",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Neutral-to-semi-pronated dumbbell orientation is harmless."
    },
    {
        "family_id": "FAM-03",
        "indifit_name": "Decline Hammer Strength Press",
        "repdb_id": "NO_MATCH",
        "human_decision": "REJECTED_FALLBACK",
        "human_reason": "No truthful plate-loaded/convergent decline Hammer Strength-style candidate exists in RepDB free tier.",
        "terra_recommendation": "REJECT_RECOMMENDED",
        "approved_variant_reuse": "false",
        "approval_record_id": "REC-R08-02-FAM-03",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Fails closed to B05 canonical muscle / neutral text fallback. Generic decline barbell or machine art prohibited."
    },
    {
        "family_id": "FAM-04",
        "indifit_name": "Chest Dips",
        "repdb_id": "dips",
        "human_decision": "APPROVED",
        "human_reason": "Forward torso lean, shoulder descent, and elbow path are visually sufficient for chest-biased bodyweight dips.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-04",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "RepDB primary-muscle triceps label does not invalidate the visually truthful forward-leaning chest dip pose."
    },
    {
        "family_id": "FAM-05",
        "indifit_name": "Push-Ups",
        "repdb_id": "push-up",
        "human_decision": "APPROVED",
        "human_reason": "Exact prone bodyweight push-up movement match.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-05",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard prone push-up pose pair."
    },
    {
        "family_id": "FAM-06",
        "indifit_name": "Cable Chest Fly",
        "repdb_id": "cable-fly",
        "human_decision": "APPROVED",
        "human_reason": "Standing bilateral cable fly arc is visually clear and distinct from a press.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-06",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants."
    },
    {
        "family_id": "FAM-07",
        "indifit_name": "Barbell Deadlift",
        "repdb_id": "deadlift",
        "human_decision": "APPROVED",
        "human_reason": "Truthfully communicates conventional floor-to-lockout barbell deadlift mechanics and posture.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-07",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "RepDB posterior chain muscle classification does not override visual conventional deadlift correctness."
    },
    {
        "family_id": "FAM-08",
        "indifit_name": "Lat Pulldown",
        "repdb_id": "lat-pulldown",
        "human_decision": "APPROVED",
        "human_reason": "Seated orientation, high cable pulley, and vertical pull range are truthful.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-08",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Wide straight bar grip is consistent with generic canonical pulldown."
    },
    {
        "family_id": "FAM-09",
        "indifit_name": "Bent Over Barbell Row",
        "repdb_id": "barbell-row",
        "human_decision": "APPROVED",
        "human_reason": "Bent-over hip-hinged torso posture and barbell pulling trajectory are unambiguous.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-09",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants."
    },
    {
        "family_id": "FAM-10",
        "indifit_name": "One-Arm Dumbbell Row",
        "repdb_id": "single-arm-db-row",
        "human_decision": "APPROVED",
        "human_reason": "Truthful bench-supported unilateral dumbbell rowing illustration.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-10",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Fixed visual side depiction is harmless for bilateral catalog entry."
    },
    {
        "family_id": "FAM-11",
        "indifit_name": "Pull-Ups",
        "repdb_id": "pull-up",
        "human_decision": "APPROVED",
        "human_reason": "Dead-hang to chin-over-bar vertical bodyweight pulling mechanics match canonical pull-up.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-11",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard overhand bodyweight pull-up."
    },
    {
        "family_id": "FAM-12",
        "indifit_name": "Seated Cable Row",
        "repdb_id": "wide-grip-seated-cable-row",
        "human_decision": "APPROVED",
        "human_reason": "Seated cable horizontal pull mechanics are truthful; wide straight bar attachment is acceptable generic specificity.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-12",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Caveat noted: wide-grip straight bar attachment depicted; does not invalidate unspecialized seated row."
    },
    {
        "family_id": "FAM-13",
        "indifit_name": "Barbell Squat",
        "repdb_id": "squat",
        "human_decision": "APPROVED",
        "human_reason": "Bilateral upper-back barbell placement, stance, and squat depth are visually correct.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-13",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard bilateral barbell back squat."
    },
    {
        "family_id": "FAM-14",
        "indifit_name": "Leg Press",
        "repdb_id": "leg-press",
        "human_decision": "APPROVED",
        "human_reason": "Standard 45-degree sled leg press machine faithfully represents canonical machine movement.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-14",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "45-degree inclined sled apparatus is standard generic presentation."
    },
    {
        "family_id": "FAM-15",
        "indifit_name": "Romanian Deadlift (RDL)",
        "repdb_id": "romanian-deadlift",
        "human_decision": "APPROVED",
        "human_reason": "Standing hip-hinge bar trajectory along legs clearly distinguishes RDL from floor deadlift.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-15",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants."
    },
    {
        "family_id": "FAM-16",
        "indifit_name": "Leg Extensions",
        "repdb_id": "leg-extension",
        "human_decision": "APPROVED",
        "human_reason": "Seated machine knee extension with lower-leg pad is visually truthful.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-16",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard seated quad isolation machine."
    },
    {
        "family_id": "FAM-17",
        "indifit_name": "Seated Leg Curl",
        "repdb_id": "leg-curl",
        "human_decision": "REJECTED_FALLBACK",
        "human_reason": "RepDB candidate depicts a prone/lying leg curl, which materially differs in body orientation and apparatus geometry from canonical Seated Leg Curl.",
        "terra_recommendation": "REJECT_RECOMMENDED",
        "approved_variant_reuse": "false",
        "approval_record_id": "REC-R08-02-FAM-17",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Fails closed to B05 canonical muscle / neutral text fallback. Do not bind lying leg curl art to seated UUIDs."
    },
    {
        "family_id": "FAM-18",
        "indifit_name": "Standing Calf Raise",
        "repdb_id": "standing-calf-raise",
        "human_decision": "REJECTED_FALLBACK",
        "human_reason": "Canonical IndiFit setup is Bodyweight (step edge); candidate visibly depicts a loaded standing calf machine with shoulder pads and weight stack.",
        "terra_recommendation": "REJECT_RECOMMENDED",
        "approved_variant_reuse": "false",
        "approval_record_id": "REC-R08-02-FAM-18",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Fails closed to B05 canonical muscle / neutral text fallback. Canonical equipment is Bodyweight."
    },
    {
        "family_id": "FAM-19",
        "indifit_name": "Walking Lunges",
        "repdb_id": "db-lunge",
        "human_decision": "REJECTED_FALLBACK",
        "human_reason": "Candidate communicates a stationary forward lunge step but does not truthfully communicate walking or alternating locomotion. Fail closed rather than force coverage.",
        "terra_recommendation": "NEEDS_HUMAN_REVIEW",
        "approved_variant_reuse": "false",
        "approval_record_id": "REC-R08-02-FAM-19",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Fails closed to B05 canonical muscle / neutral text fallback. Product authority decision: require visible locomotion/alternation."
    },
    {
        "family_id": "FAM-20",
        "indifit_name": "Overhead Barbell Press",
        "repdb_id": "ohp",
        "human_decision": "APPROVED",
        "human_reason": "Standing vertical barbell press mechanics and chest-to-overhead lockout trajectory are clear.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-20",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard standing barbell overhead press."
    },
    {
        "family_id": "FAM-21",
        "indifit_name": "Seated Dumbbell Shoulder Press",
        "repdb_id": "seated-db-press",
        "human_decision": "APPROVED",
        "human_reason": "Seated vertical pressing mechanics and dumbbell equipment match.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-21",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Seated upright bench support."
    },
    {
        "family_id": "FAM-22",
        "indifit_name": "Dumbbell Lateral Raise",
        "repdb_id": "lateral-raise",
        "human_decision": "APPROVED",
        "human_reason": "Frontal-plane shoulder abduction and standing unsupported stance are unambiguous.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-22",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard standing dumbbell lateral deltoid raise."
    },
    {
        "family_id": "FAM-23",
        "indifit_name": "Dumbbell Front Raise",
        "repdb_id": "dumbbell-front-raise",
        "human_decision": "APPROVED",
        "human_reason": "Sagittal-plane forward arm elevation to shoulder height is visually truthful.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-23",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants."
    },
    {
        "family_id": "FAM-24",
        "indifit_name": "Face Pulls",
        "repdb_id": "face-pull",
        "human_decision": "APPROVED",
        "human_reason": "High pulley rope attachment, high elbows, external rotation, and eye-level finish communicate a face pull.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-24",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard rope cable face pull."
    },
    {
        "family_id": "FAM-25",
        "indifit_name": "Standing Barbell Curl",
        "repdb_id": "barbell-curl",
        "human_decision": "APPROVED",
        "human_reason": "Standing supinated bilateral barbell elbow flexion is exact.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-25",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants."
    },
    {
        "family_id": "FAM-26",
        "indifit_name": "Dumbbell Hammer Curl",
        "repdb_id": "hammer-curl",
        "human_decision": "APPROVED",
        "human_reason": "Neutral hammer grip and standing bilateral curl range are visually truthful.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-26",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard dumbbell neutral grip curl."
    },
    {
        "family_id": "FAM-27",
        "indifit_name": "Incline Dumbbell Curl",
        "repdb_id": "incline-db-curl",
        "human_decision": "APPROVED",
        "human_reason": "Incline bench shoulder extension and curl path are visually clear.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-27",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Side profile view is acceptable for bilateral incline curl."
    },
    {
        "family_id": "FAM-28",
        "indifit_name": "Preacher Curl",
        "repdb_id": "preacher-curl",
        "human_decision": "APPROVED",
        "human_reason": "Arm-supported preacher pad geometry and curl path are exact; EZ-bar depiction is acceptable attachment specificity.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-28",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Caveat noted: EZ-bar attachment depicted; consistent with generic preacher bench curl."
    },
    {
        "family_id": "FAM-29",
        "indifit_name": "Tricep Pushdown",
        "repdb_id": "tricep-pushdown",
        "human_decision": "APPROVED",
        "human_reason": "High-cable pushdown with pinned elbows is visually truthful.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-29",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard cable triceps extension."
    },
    {
        "family_id": "FAM-30",
        "indifit_name": "Skull Crushers (EZ Bar)",
        "repdb_id": "skull-crusher",
        "human_decision": "APPROVED",
        "human_reason": "Supine flat bench position, EZ-bar grip, and forehead-directed elbow flexion are exact.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-30",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Matches canonical lying EZ-bar skull crusher."
    },
    {
        "family_id": "FAM-31",
        "indifit_name": "Overhead Dumbbell Tricep Extension",
        "repdb_id": "overhead-tricep-extension",
        "human_decision": "APPROVED",
        "human_reason": "Two-handed overhead dumbbell extension behind neck is visually clear.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-31",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants."
    },
    {
        "family_id": "FAM-32",
        "indifit_name": "Ab Wheel Rollout",
        "repdb_id": "ab-wheel-rollout",
        "human_decision": "APPROVED",
        "human_reason": "Kneeling anti-extension rollout range and wheel apparatus are exact.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-32",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Approved for 4 canonical variants."
    },
    {
        "family_id": "FAM-33",
        "indifit_name": "Cable Crunch",
        "repdb_id": "cable-crunch",
        "human_decision": "APPROVED",
        "human_reason": "Kneeling spinal flexion against high pulley rope matches canonical cues.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-33",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Standard kneeling cable abdominal crunch."
    },
    {
        "family_id": "FAM-34",
        "indifit_name": "Plank",
        "repdb_id": "plank",
        "human_decision": "APPROVED",
        "human_reason": "Prone forearm plank posture is visually truthful; static hold correctly uses single MAIN image.",
        "terra_recommendation": "APPROVE_RECOMMENDED",
        "approved_variant_reuse": "true",
        "approval_record_id": "REC-R08-02-FAM-34",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "MAIN-only image accepted for static core hold."
    },
    {
        "family_id": "FAM-35",
        "indifit_name": "Hanging Leg Raise",
        "repdb_id": "hanging-leg-raise",
        "human_decision": "REJECTED_FALLBACK",
        "human_reason": "Candidate depicts a bent-knee hanging knee raise rather than the canonical straight-leg raise to approximately 90 degrees.",
        "terra_recommendation": "REJECT_RECOMMENDED",
        "approved_variant_reuse": "false",
        "approval_record_id": "REC-R08-02-FAM-35",
        "approval_date": "2026-08-21",
        "approved_by": "Human Product Owner",
        "notes": "Fails closed to B05 canonical muscle / neutral text fallback. Do not bind bent-knee artwork to straight-leg canonical UUIDs."
    }
]

# Write CSV
csv_path = os.path.join(DOCS_R08_DIR, "R08_0_2_REPDB_MAPPING_APPROVALS.csv")
fieldnames = [
    "family_id",
    "indifit_name",
    "repdb_id",
    "human_decision",
    "human_reason",
    "terra_recommendation",
    "approved_variant_reuse",
    "approval_record_id",
    "approval_date",
    "approved_by",
    "notes"
]

with open(csv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for row in HUMAN_DECISIONS:
        writer.writerow(row)

print(f"Wrote {len(HUMAN_DECISIONS)} approval rows to {csv_path}")

# Write Markdown Summary
summary_path = os.path.join(DOCS_R08_DIR, "R08_0_2_HUMAN_APPROVAL_SUMMARY.md")

approved_rows = [r for r in HUMAN_DECISIONS if r["human_decision"] == "APPROVED"]
rejected_rows = [r for r in HUMAN_DECISIONS if r["human_decision"] == "REJECTED_FALLBACK"]

summary_md = f"""# IndiFit R08-0.2: RepDB Movement Mapping Human Approval Summary

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
"""

with open(summary_path, "w", encoding="utf-8") as f:
    f.write(summary_md)

print(f"Wrote human approval summary to {summary_path}")
