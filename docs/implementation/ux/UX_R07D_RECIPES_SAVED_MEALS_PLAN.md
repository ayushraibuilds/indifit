# UX R07D-3 — Recipes & Reusable Meals Plan

**Repository:** `/Users/dankmagician/Documents/New project/indifit`  
**Branch:** `ux/r07d-recipes-saved-meals`  
**Baseline Commit:** `68735a4` (Merge R07D-2 food search discovery)  

---

## 1. Domain Semantics & Canonical Architecture

### A. Current Recipe Architecture
- **Entities:** `NutritionRecipes` (head entity with `id`, `name`, `lifecycle`: active/archived/deleted), `NutritionRecipeVersions` (immutable version graph with `versionNumber`, `yieldQuantity`, `yieldUnit`, `servingQuantity`, `source` provenance JSON), `NutritionRecipeIngredients` (ordered ingredient references with `foodId`, `quantityValue`, `quantityDimension`, `quantityUnit`, `measureId`).
- **Identity & Provenance:** Portable UUID strings (`recipe-...`, `recipe-version-...`). Ancestry tracked via `parentVersionId` and `copiedFromVersionId`.
- **Derivation & Yield:** Nutrition is derived automatically from canonical ingredient facts via `NutritionCalculationService` and `NutrientAggregationService`. Yield is represented via `yieldQuantity` and `servingQuantity`.
- **Editing & History:** Immutable versioning. Updating a recipe creates a new version (`versionNumber + 1`). Previously logged diary entries reference historical `recipeVersionId` snapshots and remain frozen.
- **Logging:** Coordinated via `NutritionRecipeLogCoordinator` writing to `NutritionConsumptionSnapshots` with amount choices (`wholeRecipe`, `fraction`, `declaredServing`, `scalar`).
- **Deletion:** Soft delete via `archiveRecipe` / `deleteRecipe` (setting `lifecycle: 'archived'` or `'deleted'`), preserving all past versions and historical consumption snapshots.

### B. Current Saved Semantics
- **Add Food / Search (`FoodSearchScreen`):** "Saved" section previously routed to "Saved recipes" (`SavedRecipeLogScreen`).
- **Legacy Food Repository:** Contained legacy `MealTemplates` and `MealTemplateItems` for saving simple multi-food combinations.
- **Canonical Multi-Item Domain:** `NutritionThalis` and `NutritionThaliItems` provide full canonical support for ordered multi-component combinations (referencing either foods or recipes) with full B03 calculation, household measure resolution, and atomic snapshot logging via `NutritionThaliRepository`.

### C. Domain Decision: Food vs. Recipe vs. Saved Meal
- **Food:** Single catalog or user-created custom food item (e.g. *Banana*, *Paneer 100g*, *Rice 1 katori*).
- **Recipe:** A prepared food composed of raw/cooked ingredients with explicit yield and serving definition (e.g. *Paneer Bhurji*, *Overnight Oats*, *Chicken Curry*). Nutrition is derived per whole recipe or per serving.
- **Saved Meal:** A reusable group of foods and/or recipes commonly logged together for a specific meal context (e.g. *My Usual Lunch*: 1 katori Rice + 1 katori Dal + 100g Paneer + 1 bowl Curd).
  - *Persistence:* Reuses and elevates the canonical `NutritionThalis` / `NutritionThaliDraft` domain and provides seamless legacy `MealTemplates` synchronization so templates are never lost.
  - *Nutrients:* Derived dynamically from constituent components; never stored as a fake homogeneous food or hardcoded flattened macros.

---

## 2. Key User Flows & Interactions

### 1. Recipe Discovery & Management
- **Entry Points:** 
  - Add Food screen (`FoodSearchScreen`) under "Saved & recipes".
  - Food root / Dashboard meal actions sheet.
  - Active search queries (with distinct `Recipe · 420 kcal/serving` badge, deterministic non-intrusive ranking).
- **Recipe Detail Surface:**
  - Clear header with recipe name, total yield/servings, and nutrition per serving (Calories, Protein, Carbs, Fat, Fibre).
  - Ingredient list showing food name, quantity, unit, and item energy.
  - Primary CTA: `ADD TO [MEAL]` (e.g. `ADD TO LUNCH`).
  - Secondary Actions: `Edit recipe`, `Delete recipe`.

### 2. Recipe Creation & Editing
- **Recipe Builder Ergonomics:**
  - Name and optional description.
  - Ingredients list with `+ Add ingredient` reusing full R07D search/selection modal.
  - Yield & Servings input (e.g. 4 servings).
  - Real-time aggregated nutrition breakdown per serving.
  - `Save recipe` creates/publishes immutable version.
  - Editing an existing recipe creates a new version, leaving historical consumption snapshots frozen.

### 3. Saved Meal Creation
- **Primary High-Value Path — Save From Existing Logged Meal:**
  - In Today / Dashboard meal card (e.g. Lunch with Rice, Dal, Paneer, Curd), user taps overflow / "Save as reusable meal".
  - Dialog prompts for meal template name (defaults to "My Lunch" or custom name).
  - Clones current meal components into a reusable `NutritionThaliDraft` / saved meal template.
- **Secondary Path — Create From Saved Meals Screen:**
  - User can tap `+ Create saved meal`, name it, and add foods or recipes.

### 4. Fast Re-Log & Edit-Before-Log
- **One-Tap Quick Log:**
  - Lunch + -> Saved Meals -> "My usual lunch" -> `LOG TO LUNCH` (atomic batch commit to target meal/date).
- **Edit-Before-Log Sheet:**
  - "Review / Edit before logging" opens a transient sheet.
  - User can modify today's portion sizes (e.g. Rice 1.5 katori, Paneer 150g) or remove an item for today's log without mutating the saved meal template.
  - Tapping `ADD TO [MEAL]` logs the modified draft today while keeping the original template untouched.

---

## 3. Correctness & Integrity Boundaries

- **Snapshot Invariance:** Historical `NutritionConsumptionSnapshots` remain 100% frozen. Modifying a recipe or saved meal template never alters past diary logs.
- **Nutrient Missingness:** Unknown nutrients remain truthfully missing/partial in calculations; never coerced to zero.
- **Atomic Batch Logging:** Multi-item saved meals are committed as an atomic batch with idempotency tokens and full undo support.
- **Soft Deletions:** Deleting a recipe or saved meal archives the template for future logging while preserving historical references and diary records.

---

## 4. Verification & Testing Strategy

- **Unit & Integration Tests:**
  - Recipe creation with multiple ingredients, fractions, and household measures.
  - Recipe yield, serving calculation, and nutrient aggregation.
  - Recipe version editing without mutating past consumption snapshots.
  - Recipe deletion preserving historical log snapshots.
  - Saved Meal creation from logged meal, custom creation, editing, and deletion.
  - Saved Meal 1-tap logging and edit-before-log temporary variation.
  - Object identity separation: Food ≠ Recipe ≠ Saved Meal with identical names.
- **UI & Widget Tests:**
  - Responsive layouts (320px, 390px, 430px) and 1.0x/1.5x/2.0x text scaling.
  - Light and dark theme styling with semantic color tokens.
  - Golden tests for Recipe List, Recipe Detail, Recipe Builder, Saved Meals List, Saved Meal Detail, and Edit-Before-Log Sheet.
