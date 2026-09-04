# Future Concept Recovery Map

- Effective date: 2026-09-05
- Baseline: Post-V1 Wave 2 retired surface inventory (`C1A_RETIRED_SURFACE_INVENTORY.md`)
- Purpose: Record product value, recovery patterns, and Git history pointers for retired concepts without maintaining obsolete source code or premature dependencies.

---

## 1. Principles

1. **Clean Codebase, Retained Optionality:** No important future path was irreversibly lost. The cleanup removed obsolete implementations, while the useful canonical data models, repositories, assets, and route redirects were retained.
2. **Never Wholesale Restore:** Never restore a deleted legacy file wholesale (e.g. monolithic God-screens). Recover the product interaction ideas, data schemas, or questionnaires, but build them into the current, modular architecture.
3. **AI as Reviewable Accelerator Only:** AI code from pre-release prototypes is not a safe shortcut. The Post-V1 Roadmap explicitly requires AI to be a reviewable accelerator, never the authority on nutrition or workout plans.

---

## 2. Concept Recovery Matrix

| Retired Area | Product & Future Value | Correct Future Approach & Program Path | Historical Git Pointer |
|---|---|---|---|
| **Thali Builder & Reusable-Meal Helper** | **Highest potential product idea.** Free-form Indian meal composition fits IndiFit exceptionally well. Canonical `NutritionThalis`, `NutritionThaliItems` tables (`nutrition_thalis`, `nutrition_thali_items`), repositories, and meal templates remain intact. | **First priority for future concept promotion.** Create a new `PV1-NUT` package and build a modular composition flow into current Food architecture. Do not restore the 829-line legacy screen or legacy dashboard subtree. | `git show ace6bf6^:lib/features/food_log/thali_builder_screen.dart` |
| **AI Meal Logger, Parser, & Meal Planner** | Interaction patterns remain valuable: editable review before log, manual fallback, temporary-image cleanup, and truthful confirmation. | Rebuild under `PV1-AI-01/02`: typed candidates, uncertainty scoring, user consent, canonical-food matching, and review-before-commit. Text-to-meal must use the reviewed connected-candidate path. | `git show 09687bf^:lib/features/food_log/ai_meal_logger_screen.dart` |
| **Routine Wizard & AI Routine Service** | Questionnaire structure (goal, equipment, frequency, experience level, physical limitations) is valuable user input for future AI plan drafts. | Reuse the product questionnaire design, not the heuristic generator. A future plan draft must select canonical exercise IDs, pass strict schema validation, display a preview diff, and create a local reviewed plan. | `git show b16836b^:lib/features/onboarding/routine_wizard_screen.dart` |
| **Weekly Report, Old Progress, & Protein Screen** | Factual layouts and visual ideas could inspire recap cards, local share cards, achievements, or richer Progress presentation. | Build from canonical read models under `PV1-PROD-01` (recap/share) and `PV1-PROD-03` (achievements). Do not restore AI narrative generators or legacy dashboard widgets. | `git show 182c06c^:lib/features/reports/weekly_report_screen.dart`<br>`git show 9e19f1f^:lib/features/nutrition/protein_distribution_screen.dart` |
| **Streak Freeze & Confetti** | Pre-release delight heuristics. The old card modeled unbacked claimable "freeze" tokens. | Streak protection must follow its own dedicated safety/product rule; achievements need deterministic definitions. | `git show cd507fb^:lib/features/dashboard/widgets/streak_freeze_card.dart`<br>`git show 38a42fa^:lib/core/widgets/confetti_overlay.dart` |
| **Water / Hydration UI** | No reuse as a standalone functional feature. Disconnected to prevent unbacked logging. | `PV1-HYD-01` is explicitly a new canonical-domain program with true device/health sync, "not an unhide water widget." | `git show 4b41237^:lib/features/settings/widgets/water_settings_section.dart` |
| **BMI Card / Generic Health UI** | Visual reference only. | Any health interpretation requires an approved authority and medical/product sign-off; not currently in near-term roadmap. | `git show cd507fb^:lib/features/progress/widgets/progress_bmi_health_card.dart` |
| **Household-Measure Utility** | Superseded. | Replaced by strongly typed `lib/core/nutrition_household_measures.dart`, which is canonical and active. | `git show 9e19f1f^:lib/core/utils/household_measures.dart` |
| **Muscle-Map Showcase & RepDB Pipeline** | Active tooling/fixtures. | Relocated to `test/fixtures/` and `tool/src/`; assets remain available in `assets/generated/repdb/`. | Active in `test/fixtures/` and `tool/src/` |

---

## 3. Implementation Order for Retired Concept Promotions

If product governance approves reviving any retired concept:
1. **Thali Builder (`PV1-NUT`)**: Recompose as a modular multi-item Indian meal logging surface on top of surviving thali tables.
2. **Reviewable Meal Drafts (`PV1-AI-01`)**: Connected meal recognition with human-in-the-loop review.
3. **Plan Draft Questionnaire (`PV1-AI-02`)**: Intake questionnaire generating validated local program drafts.
