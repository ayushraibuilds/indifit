# R07D-1 — Food Diary & Fast Meal Logging

## Baseline

- Branch: `ux/r07d-food-diary-logging`
- Baseline: local integration merge `687150f` (`R07C` already merged; review/remediation commit `71bb9a7` is an ancestor).
- Scope: consumer Food diary, Today meal entry points, fast local-first logging, canonical quantity/edit/delete behavior, and focused validation.
- Exclusions: provider ranking/catalog cleanup, AI/photo/barcode implementation changes beyond placement, recipe-builder redesign, schema/target/onboarding changes, and R07D-2 search ranking/provider work.

## Existing production map

| User path | Current owner | R07D-1 treatment |
| --- | --- | --- |
| Today meal rows | `TodayDailyActionSurface` + `TodayNutritionPresentation` | Keep canonical totals; make every row a meal detail entry point and keep direct `+` scoped to the selected date/meal. |
| Food root | `MainNavigationScaffold` → `_FoodTabRoot` → `FoodSearchScreen(mealType: null)` | Replace the launcher-first root with a daily diary: summary, meal sections, direct add, and secondary tools. |
| Meal add/search | `FoodSearchScreen(mealType: ...)` | Keep the route, focus search, surface real recent/frequent/saved choices before typing, and add multi-select. |
| Local/online search | `FoodRepository.searchFoodLocal`, `FoodApiService.searchOnline` | Preserve local-first ordering, cancellation/stale guards, and friendly offline states. |
| Recent | `canonicalRecentFoodsProvider`, legacy fallback | Canonical history wins; deterministic de-duplication and frequency metadata come from local history. |
| Quantity/logging | `NutritionFoodLoggingCoordinator` → `NutritionConsumptionRepository` | Reuse typed quantities and previews; add one-tap default-serving and atomic multi-item finalization. |
| History/detail/actions | `FoodLogEntriesPanel`, `showCanonicalFoodDelete`, `FoodContextualActions` | Use compact meal detail rows and existing correction/retraction seams; expose only repository-backed undo. |
| Custom food/alternate paths | `CustomFoodEditorScreen`, barcode, AI, recipes | Keep secondary; tighten hierarchy, labels, missing nutrient truthfulness, and responsive layout. |
| Daily aggregation | `NutritionReadModelRepository` / `todaySurfaceSnapshotProvider` | No new calculation authority; invalidate existing revisions after successful commands. |

## Canonical integrity rules

1. New food writes go through `NutritionFoodLoggingCoordinator` and immutable B03 consumption snapshots.
2. A multi-select commit is one canonical snapshot with ordered direct-food items. The repository transaction therefore commits all selected lines together or none of them, while preserving each food identity, quantity, source, and frozen nutrient facts.
3. `NutritionFoodOption.baseQuantity`, reviewed household measures, and dimensional conversion remain the only quantity authority. Unsupported units stay hidden; no household label is converted to grams without an explicit canonical conversion.
4. Missing nutrient facts render as unknown (`—`/unavailable), never as zero. A zero is shown only when the source explicitly supplies a known zero or the day is known to have no consumption.
5. Date and meal are normalized before finalization and remain part of edit/delete/retraction context checks. Repeated command IDs are idempotent.

## Implementation slices

### 1. Food diary and meal detail

- Add a compact diary root with the selected civil date, calorie/macro progress, four meal sections, meal totals/previews, and direct meal-scoped `+` actions.
- Make meal sections open a detail screen with entries, meal total, `+ Add Food`, and existing edit/copy/delete actions.
- Keep Today’s summary and meal rows concise; route row inspection to the same meal detail behavior.

### 2. Fast Add and local history

- Keep the meal-scoped `Add to <Meal>` header and autofocus search.
- Show canonical recent/frequent choices before typing, with deterministic count/last-used ordering and no seeded aliases.
- Add a safe default-serving action with compact Undo feedback; fall back to the quantity sheet when a default is not safe.
- Preserve local results while online search is loading or unavailable.

### 3. Multi-select and quantity editing

- Selecting a row is transient and never writes.
- Selected items expose quantity editing through the same compact typed quantity sheet, with truthful aggregate calories only when every selected item has known energy.
- Commit selected items with one idempotent canonical command, clear selection only after success, and invalidate Today/Food reads immediately.

### 4. Secondary surfaces and quality

- Keep saved foods distinct from saved recipes/meals; keep recipes reachable without redesigning the builder.
- Rework Custom Food field hierarchy and narrow-width nutrient layout without inventing missing facts.
- Add focused unit/widget coverage for command safety, deterministic history, meal/date routing, quantity truthfulness, responsive semantics, and R07D goldens.

## Validation contract

Run focused R07D/B03/R07A/B04/B05 food tests, affected widget/golden tests, formatter/analyzer/diff checks, then the full test suite serially. Inspect representative 320/390/430 layouts, 1×/1.5×/2× text, and light/dark captures. Do not merge or push this branch.
