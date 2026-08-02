# B03 Decisions — Nutrition Foundation and Food Context

Status: Proposed for Sol architecture review. No decision below authorizes
implementation before B02 final Sol approval and merge.

## Decision register

| ID | Decision | Status | Primary risk |
|:--|:--|:--|:--|
| B03-D01 | Stable canonical food/preparation identities and versioned aliases | Proposed | Identity fragmentation and unsafe matching |
| B03-D02 | Typed quantities retain dimension, unit and food context | Proposed | Unit corruption and false precision |
| B03-D03 | Recipes use immutable versions and consumption snapshots | Proposed | Historical meals changing after edits |
| B03-D04 | Raw/cooked conversion is directional and preparation-specific | Proposed | Incorrect portion and nutrient totals |
| B03-D05 | Household measures use reviewed food-specific or user-calibrated rules | Proposed | Global multiplier errors |
| B03-D06 | Nutrients use explicit definitions and unknown completeness | Proposed | Missing values presented as zero |
| B03-D07 | Estimates retain bounds, confidence, provenance and rule/model version | Proposed | AI/heuristic overclaiming |
| B03-D08 | Thali is a canonical portion graph resolved into an immutable snapshot | Proposed | UI multiplier becomes a competing authority |
| B03-D09 | Dietary constraints are typed and uncertainty-aware | Proposed | Dish-name matching mistaken for safety |
| B03-D10 | User corrections are overlays, not silent catalogue rewrites | Proposed | Source provenance and reproducibility loss |
| B03-D11 | B03 adds one reviewed schema/backup transition with legacy compatibility | Proposed | Migration or restore data loss |

## Sol review questions

- Which canonical food identity and seed-data versioning scheme fits the current
  regional packs without requiring an unsafe bulk relabeling?
- Which dimensions and units are supported in B03, and where is a conversion
  prohibited rather than estimated?
- Which nutrition snapshot fields are required for historical reproducibility?
- What is the minimum reviewed nutrient registry and source completeness policy?
- Which household-measure conversions can be catalogue-reviewed, and which must
  be user-calibrated?
- Which dietary constraints can be classified locally, and how is incomplete
  composition disclosed in filtering and logging?
- What is the approved B03 schema version and backup version after B02 merge?

## Accepted invariants once approved

- Existing logs remain readable and are not rewritten by catalogue or recipe
  edits.
- Unknown is distinct from zero in storage, calculations and presentation.
- Every estimate and conversion is reproducible from retained provenance and
  version metadata.
- Every user-owned B03 entity is included in backup/restore fixtures.

