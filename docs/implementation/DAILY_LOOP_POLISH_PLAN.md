# Daily-loop polish plan (2026-10-05)

These are three items from audit §6 that Ayush picked after the pre-launch fixes. Each section gives the facts checked in the code, the change, its tests, and the risks.

| PR | Branch | Item |
|---|---|---|
| D | `feat/repeat-thali-recipe` | Thali and recipe logs in "Repeat yesterday" |
| E | `feat/portion-katori-visual` | Show the katori or bowl in the portion sheet |
| F | `feat/onboarding-goal-first` | Ask the goal first in onboarding |

Verification for each PR:
- `dart format`, `flutter analyze`, the full non-golden suite, and a code-graph regeneration.
- Every new test is shown to fail on the old `lib/`.
- E and F change screens covered by goldens. Their refreshes go through `update-goldens.yml`, and every changed image is reviewed before it lands.

---

## D. Thali and recipe logs in "Repeat yesterday"

**Facts.**
- `repeatableMealItems` (`lib/features/food_log/repeat_meal.dart`) keeps only items whose origin is `direct_food`. A meal logged as a thali (snapshot `sourceType: 'thali'`, items `food`/`recipe`) or as a recipe (`sourceType: 'recipe'`) is skipped. If that's all there was, the card doesn't appear at all.
- A thali snapshot records which thali was logged (`thaliId`) and which version of it (`request_evidence.thali_version`).
- A recipe snapshot records `recipe_id`, `recipe_version_id` and the amount (`request_evidence.amount`, `{kind, value}`).
- Both have coordinators that preview and finalize a fresh log:
  - `NutritionThaliRepository.preview/finalize`;
  - `NutritionRecipeLogCoordinator.preview/finalize`.

**Change.**
- `repeatMealRecords` handles three kinds of record:
  - **Direct foods:** unchanged.
  - **Thali:** load the thali by `thaliId`. If it's still active and still at the logged version, preview and finalize it again with a fresh command id. The meal is logged as the same thali, so it shows as one thali in the diary.
  - **Recipe:** preview the same recipe version with the same amount, then finalize.
- A record that can't be repeated faithfully is **skipped, never approximated**. That covers a thali edited or deleted since yesterday, an archived recipe, and an estimate. The card counts it: "Repeats 2 of 3 · 1 changed since yesterday".
- The card appears whenever at least one record is repeatable. Its subtitle names thalis and recipes by their labels.
- Planning what to repeat (`planRepeat`) becomes a pure function over the records and is tested directly. The async part takes the thali and recipe lookups as parameters, so tests can use a real in-memory database.

**Tests.**
1. Plan: a thali record and a recipe record are repeatable; an estimate isn't; direct foods still are.
2. With a real in-memory DB, log a thali yesterday and repeat it. Today has one thali snapshot with the same `thaliId` and the same totals.
3. Same for a recipe, with the same amount and the same kcal.
4. Edit the thali after yesterday's log. The repeat skips it and reports one skipped.
5. Archive the recipe. It is skipped.
6. Food landing: when yesterday had only a thali, the repeat card appears and names it.

**Risk.** Medium. This writes through existing coordinators only, with no new persistence. A partial failure leaves already-logged records logged, which is today's behaviour and is reported to the user the same way.

## E. Show the katori or bowl in the portion sheet

**Facts.**
- `FoodPortionBottomSheet` offers household chips as text: "1 Katori (150g)", "Med Katori (200g)", "Bowl (300g)", "1 Glass (206ml)" and so on. It also has an amount field with a unit.
- Nothing visual shows how big a katori is, or how many the user has chosen. The audit asks for the bowl to be shown so household measures feel concrete.

**Change.**
- A new `HouseholdPortionVisual` widget draws, in a small `CustomPaint`:
  - the vessel for the current measure: katori (small, standard or medium), bowl, glass, spoon or piece;
  - one vessel per whole unit, plus a partly filled one for a fraction, up to 4 drawn, then "×N";
  - a caption: "1½ katori ≈ 225 g".
- It shows when the selection is a household measure:
  - a household quantity;
  - a serving whose label is a katori, bowl or glass;
  - or a gram amount that matches one of the household chips.
- It is hidden for plain grams.
- It uses theme colours and has a semantics label ("1.5 katori, about 225 grams"). It stays decorative for screen readers that already read the amount.
- Each household chip gets the same small vessel icon, so the chip and the drawing match.

**Tests.**
- Measure detection: a household quantity, a katori serving label, a gram value equal to a chip, and plain grams (hidden).
- Count rendering: 1, 1.5, 3, and 6 (shown as "×6").
- Semantics label text.
- Golden: one new golden of the sheet with "1½ katori", plus refreshed goldens of any existing sheet that changes.

**Risk.** Low. This is presentation only, with no change to what is logged.

## F. Ask the goal first in onboarding

**Facts.**
- `OnboardingScreen` has four pages: About (sex, age, height, weight), Goal, Activity and Diet, followed by a payoff summary.
- Validation and keyboard handling assume About is page 0.
- Drafts store `currentPage` with `flowVersion: 2`.
- The Goal page doesn't depend on any About field. The targets are computed only at the end, so the order can change without changing any result.

**Change.**
- The order becomes Goal, About, Activity, Diet.
- Pages get named indices, so the About checks (sex required, field errors, keeping the focused field visible) follow the About page rather than index 0.
- Drafts move to `flowVersion: 3`. A v2 draft saved on About (0) resumes on About (now 1), and one saved on Goal (1) resumes on Goal (now 0). Activity and Diet keep their places, and v1 mapping is unchanged.
- The Goal page's copy works as the opening question. Its title "What is your main goal?" stays, and the subtitle adds one line on why IndiFit asks.

**Tests.**
- The first page is the goal question.
- Next on Goal goes to About.
- The About checks still block Next on About.
- A v2 draft on About resumes on About, and a v2 draft on Goal resumes on Goal.
- The completed profile is the same as before for the same answers.
- Update the existing onboarding tests that walk the pages in the old order.
- Goldens of the first onboarding screen change and are reviewed.

**Risk.** Low to medium. Many onboarding tests walk the flow, and those will be updated. The computed profile is unchanged.
