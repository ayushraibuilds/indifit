# B03 Task Matrix — Nutrition Foundation and Food Context

All tasks are planning items. Create implementation branches only after B02 has
passed final Sol verification and has been merged into the accepted base.

| ID | Task | Depends on | Gate | Risk |
|:--|:--|:--|:--|:--|
| B03-01 | Freeze canonical identity, unit, nutrient and uncertainty fixtures | B02 merge; Sol decisions | Sol High | Critical data semantics |
| B03-02 | Add typed quantity, unit and conversion value objects/calculators | B03-01 | Sol High | Silent unit errors |
| B03-03 | Add canonical foods, preparations, aliases and regional variants | B03-01 | Sol High | Identity/source drift |
| B03-04 | Add nutrient registry, facts, completeness and provenance | B03-01/02 | Sol High | Unknown-to-zero coercion |
| B03-05 | Add recipe headers, immutable versions, ingredients and deterministic scaling | B03-02/03/04 | Sol High | History mutation |
| B03-06 | Add raw/cooked transformations, household measures and vessel calibration | B03-02/03 | Sol High | False precision |
| B03-07 | Add consumption snapshots, thali portions and meal-level aggregation | B03-04/05/06 | Sol High | Competing totals |
| B03-08 | Add estimate provenance, bounds, confidence and quality-aware summaries | B03-04/07 | Sol High | AI overclaiming |
| B03-09 | Add protein distribution, leucine and protein-quality guidance | B03-04/07 | Sol Medium | Heuristic misrepresentation |
| B03-10 | Add typed dietary constraints and uncertainty-aware filtering | B03-03/04 | Sol High | Allergy/restriction confusion |
| B03-11 | Add legacy compatibility adapters and migrate safe food-log reads/writes | B03-05/07 | Sol High | Existing-log regression |
| B03-12 | Add B03 schema migration, backup/restore and real database fixtures | B03-03 through 11 | Sol High | Data loss/restore failure |
| B03-13 | Integrate recipe, measure, thali and constraint UI adapters | B03-05/06/07/10/11 | Sol Medium | Scope/UI drift |
| B03-14 | Run full analysis, tests, Android/iOS release and final Sol verification | B03-12/13 | Sol High | Release regression |

## Task ownership rules

- Each task must name one durable data owner and one read-model consumer before
  implementation.
- No task may add display-name matching as a substitute for canonical identity.
- Any task that adds a user-owned row must add backup, restore and migration
  coverage in the same task or explicitly block on B03-12.
- UI work must consume domain contracts and cannot introduce a second nutrient
  calculation authority.

