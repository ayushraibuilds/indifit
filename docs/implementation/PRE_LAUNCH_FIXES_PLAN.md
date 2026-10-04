# Pre-launch fixes plan (2026-10-05)

These are six engineering items from the launch roadmap. Each section gives the facts checked in the code, the change, its tests, and the risks.

## Delivery

There are three PRs, each branched from `main` after #50 and #51 merge:

| PR | Branch | Items |
|---|---|---|
| A | `fix/support-email-version-sentry` | 1. App version in the support email · 6. Remove the dead `tracesSampleRate` |
| B | `feat/meal-photo-entry` | 2. Meal photo button (Beta) · 5. Label and photo eval readiness |
| C | `fix/ai-matcher-pieces-sabji` | 3. "4 eggs" → 2 servings · 4. sabzi/sabji fold and the "Aloo Gobbi" name |

Verification for each PR:
- `dart format`, `flutter analyze`, the full non-golden suite, and a code-graph regeneration.
- Every new test is shown to fail on the old `lib/`.

Merge order: A, then B, then C. Each later PR gets `main` merged in and the graph regenerated before it merges.

---

## 1. App version in the recovery-screen support email

**Facts.** `supportEmailUri(errorType)` in `lib/app/database_recovery_screen.dart` puts the error type and platform in the body. `package_info_plus` is already in `pubspec.lock` as a transitive dependency of `sentry_flutter`, so it adds no new native pod or plugin.

**Change.**
- Add `package_info_plus` to `pubspec.yaml` as a direct dependency, pinned to the locked version.
- `supportEmailUri(errorType, {String? appVersion})` adds `App version: 1.0.0 (1)`. When the version is unknown, the line reads `App version: unknown`.
- `_emailSupport` reads `PackageInfo.fromPlatform()` inside a try/catch. The recovery screen runs when the database is broken, so a failed lookup must never block the email.

**Tests.** `database_recovery_test.dart`:
- the body contains the version;
- the body says "unknown" without one;
- spaces are still encoded as `%20`.

## 2. Meal photo has no button in the app

**Facts.**
- `PhotoMealScreen` is reachable only through `/food/photo`. The route already redirects when AI isn't allowed (`_nutritionAiRouteRedirect`).
- The gateway refuses photo requests when the Remote Config key `ai_photo_enabled` is off, and the screen shows "Photo meal estimates are switched off right now."
- Describe meal and Scan label are offered from the Food landing (`FoodSearchRecentList`) only when `privacyPolicy.isAiAllowed`.
- The iOS camera and photo-library purpose strings mention only barcodes and labels. App Review rejects a purpose string that doesn't cover a feature using it.

**Change.**
- Add an `onPhotoMeal` callback to `FoodSearchRecentList`, gated exactly like Describe meal (`isAiAllowed`). It shows as:
  - a "Meal photo" quick-action chip;
  - a "Meal photo · Beta" card under "More ways", reading "Estimate a plate from a photo. Check every item before logging."
- `food_search_screen.dart` passes the meal type and date the same way Describe meal does. The duplicated query-string code for the three AI routes becomes one helper.
- Rewrite `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to cover meal photos.

**Tests.**
- With AI allowed, the chip and the card appear, and tapping one pushes `/food/photo?mealType=…&date=…`.
- With AI off, both are absent.

**Not changed.** Photo stays "Beta" until the photo eval exists (item 5). Remote Config `ai_photo_enabled` stays the kill switch.

## 3. "4 eggs" should become 2 servings of "Boiled Eggs (2 pieces)"

**Facts.**
- The catalogue stores "Boiled Eggs (2 pieces)" as `serving_size: 2, serving_unit: piece`. `_LegacyQuantityAuthority` turns that into a per-serving base with **no** `servingUnitLabel`, because the label is only kept when size is 1.
- In `PortionMapping.map`, the AI's "4 egg" is a piece unit against a serving base, and `_sameServing` sees no label. The result is `needsReview`, so the amount resets to 1 serving with "Set the amount".
- The same thing happens to every food whose name gives a piece count per serving: Dhokla (2 pieces), Pani Puri (6 pieces), Paneer Pakora (3 pieces), Paneer Tikka (5 pcs), Chicken Tikka (6 pcs) and their variants. That's 18 foods.

**Change.**
- Add `piecesPerServing(option)` in `meal_item_resolver.dart`. It reads the `(N pieces)` / `(N pcs)` count from the catalogue name, the convention all 18 foods follow.
- `PortionMapping.map`: when the base is a serving, the AI unit is a piece, and the food has N pieces per serving, log `amount / N` servings. For example, 3 eggs logs 1.5 servings.
- A one-piece-per-serving food ("Samosa (1 piece)") already matches through its label and is unchanged.
- `bindToCatalog` uses the mapped amount instead of the AI's raw number, so the review card shows "2 serving" and logs 2 servings.
- `ai_items_thali_handoff.dart` already uses `portion.quantity`, so the thali hand-off gets the fix for free.

**Tests.** `ws7_meal_item_resolver_test.dart` and the binding tests:
- 4 eggs → 2 servings, no review note;
- 3 eggs → 1.5 servings;
- 12 pani puri → 2 servings;
- 2 samosa → 2 servings (unchanged);
- 2 rotis against a per-100 g food still needs review.

## 4. Fold "sabzi"/"sabji"; fix the "Aloo Gobbi" typo

**Facts.**
- The catalogue spells it "Sabji" in 30+ names. `MealItemResolver.normalize` doesn't fold spellings, so the AI or a user writing "sabzi" or "subzi" misses. The workaround today is duplicate default keys (`'bhindi sabzi'`).
- Catalogue search is a plain SQL substring match on the display name.
- "Aloo Gobbi (Dry Sabji)" is `food-seed-0010`, plus variants `-0011` and `-0012`. Their identity key is `asset:base:aloo gobbi (dry sabji)`, which also points at the `food_items` row and the asset JSON row.
- The correctly spelled "Aloo Gobi Dry Sabji" (`-0013`) was already retired into `-0010` on 2026-10-03.

**Change: spelling fold.**
- In `MealItemResolver._tokens`, map `sabzi`, `subzi`, `subji` and `sabjee` to `sabji`, the catalogue spelling. Search then receives the catalogue spelling too.
- Remove the now-redundant `'bhindi sabzi'` default.
- Fold the same spellings in `NutritionFoodCatalogRepository.search`, so manual search for "aloo gobi sabzi" also finds "Sabji" foods.

**Change: display name (revised during implementation).** Renaming is deferred, and the search bug is fixed instead.
- Implementation found three more places that depend on the asset name "Aloo Gobbi (Dry Sabji)":
  - `upsertSeededFoodsFromAsset` matches `food_items` rows by name, so a renamed asset inserts a duplicate row;
  - `_servingUnitLabelFor` finds the row by the `asset:base:` key, so the katori label would be lost;
  - Food search lists `food_items` names directly.
- A safe rename needs its own migration that covers all of these, plus tests.
- What ships instead:
  - Food search maps "gobi" to also try "gobbi", so "aloo gobi" finds the food. Before, it found nothing, because the correctly spelled duplicate was retired.
  - The AI defaults cover "aloo gobi sabji" and "aloo gobi dry sabji".

## 5. Label and photo AI evals

**Facts.**
- The harness (`tool/ai_eval/run_eval_test.dart`) already scores labels and photos. Today it reports "Not evaluated" because `labels/` and `photos/` contain only empty `cases.json` files.
- A run needs real photos and the iOS App Check debug token. Both are Ayush's. Tokens are never stored.

**Change (what code can do now).**
- `test/ws7_ai_eval_test.dart` gains CI checks on both case files:
  - every case names an existing JPEG under 1024 px;
  - the label `basis` is valid;
  - field names are known;
  - photo `kcal` is a positive number.
  - Bad data then fails in CI, not in a paid run.
- Add a "Before a release" checklist to the README: how many cases, how to strip EXIF, the run command.

**Owner step.**
- Add about 20 label photos and about 30 meal photos.
- Run the eval with the token, which is also a good point to re-run meal text after items 3 and 4.
- Decide from the photo calorie error whether photo can drop "Beta".

## 6. Remove the dead Sentry `tracesSampleRate = 0.2`

**Facts.**
- `enableAutoPerformanceTracing = false`.
- No code starts a transaction or span: no `startTransaction`, no `SentryNavigatorObserver`, no Sentry HTTP client.
- The sample rate therefore enables nothing, and it suggests performance tracing that the privacy policy doesn't describe.

**Change.** Delete the line, so tracing stays off (`null`). Expose the options configuration to tests.

**Test.** `crash_reporting_test.dart`: the configured options have a null `tracesSampleRate`, auto performance tracing is off, and `sendDefaultPii` is false.
