# Nutrition Segment Modernization: Online-First, Offline-Fallback Transformation

Transform IndiFit's nutrition segment from an artificially restricted offline-only tool into an **online-first, offline-fallback hybrid tracking engine**. The strength workout player remains **100% offline-first and basement-proof**, while nutrition tracking leverages cloud search, Hinglish transliteration, server-driven portion taxonomy, and AI multimodal assistance.

---

## User Review Required

> [!IMPORTANT]
> **Operational Scope & Architectural Discipline**:
> 1. **Zero External Redis**: For V1 Beta, we drop external Redis dependencies to eliminate operational overhead and hosting costs. Caching will be handled via an in-memory TTL cache (`cachetools`) in the single-worker backend container (`WEB_CONCURRENCY=1`) paired with a persistent Drift SQLite disk cache table (`food_search_cache`) on the client.
> 2. **Phased Data Verification**: We will not claim 200 manually verified FMCG SKUs in 2–3 days. We will launch with an initial verified starter set of ~35 high-frequency fitness staples (Amul protein lassi/buttermilk, Epigamia yogurts, Pintola peanut butter, Tata Sampann dals) and expand the catalog asynchronously.
> 3. **Category Taxonomy vs. Substring Matching**: We eliminate client-side `contains('dal')` heuristics by introducing an explicit `category_id` taxonomy on food rows that strictly drives standard katori and gram weights.

> [!WARNING]
> **Compliance & Privacy Gate**:
> Transmitting photo/voice data to Google Gemini requires an explicit **DPDP & App Store consent modal** in the mobile app before the first camera or microphone capture.

---

## Proposed Changes

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        PROPOSED SYSTEM ARCHITECTURE & DATA FLOW                        │
└────────────────────────────────────────────────────────────────────────────────────────┘

 [ Mobile Client ]                                              [ FastAPI Backend ]
┌──────────────────────────────┐                               ┌────────────────────────────────┐
│ User types: "arhar tadka"    │                               │ POST /api/food/search          │
│ 1. Render Local SQLite Cache │                               │ 1. Transliteration Dictionary  │
│ 2. Debounce 300ms ───────────┼──────────────────────────────►│ 2. In-memory TTL Cache Check   │
│                              │                               │ 3. Curated Indian DB Match     │
│                              │                               │ 4. Open Food Facts Proxy Fallback│
│                              │                               │ 5. Attach Category Taxonomy    │
│                              │                               │ 6. Log zero-result queries     │
│ 3. Merge & Deduplicate ◄─────┼───────────────────────────────┤ 7. Return Ranked JSON          │
│ 4. Write to food_search_cache│                               └────────────────────────────────┘
│ 5. Select portion via HUD    │
│ 6. Commit to local SQLite    │
└──────────────────────────────┘
```

---

### Backend Component (`backend/`)

#### [NEW] [food.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/routers/food.py)
* Create `backend/routers/food.py` and register it in `backend/main.py`.
* Implement `POST /api/food/search`:
  - Request: `{ "query": str, "language": "hinglish|en", "page": int = 1, "limit": int = 20 }`
  - Response: `{ "query": str, "total_hits": int, "has_more": bool, "results": List[FoodSearchResultItem] }`
* Implement ranking algorithm:
  $$\text{Score} = \text{Exact Match (100)} > \text{Catalog Verified (80)} > \text{Frequent (60)} > \text{Provider (40)} > \text{Fuzzy (20)}$$
* Implement `GET /api/food/barcode/{code}`:
  - Checks curated local FMCG catalog first; if missing, proxies to Open Food Facts with in-memory TTL caching.
* Implement anonymous zero-results logging to capture missing Indian dishes and spellings:
  - Appends to an in-process ring buffer / `missed_searches` log file (rate-limited, no user PII).

#### [NEW] [indian_food_taxonomy.json](file:///Users/dankmagician/Documents/New%20project/indifit/backend/data/indian_food_taxonomy.json)
* Define formal `category_id` taxonomy mapping to standard serving units:
  - `dal_lentil`: Standard Katori (150g), Small (100g), Large (250g)
  - `gravy_curry`: Standard Katori (150g), Medium (200g)
  - `dry_sabzi`: Standard Katori (120g), Small (80g)
  - `staple_bread`: Piece (35g standard roti, 40g with ghee, 110g stuffed paratha)
  - `staple_rice`: Medium Katori (200g), Full Plate (350g)
  - `dairy_liquid`: Glass (206g / 200ml), Small Glass (150g)
  - `packaged_fmcg`: Per serving size declared on package

#### [NEW] [indian_synonyms.json](file:///Users/dankmagician/Documents/New%20project/indifit/backend/data/indian_synonyms.json)
* Dictionary for Hinglish and regional transliterations:
  - `toor dal` $\leftrightarrow$ `arhar dal` $\leftrightarrow$ `tuvar` $\leftrightarrow$ `yellow pigeon peas`
  - `roti` $\leftrightarrow$ `chapati` $\leftrightarrow$ `phulka` $\leftrightarrow$ `poli`
  - `dahi` $\leftrightarrow$ `curd` $\leftrightarrow$ `thayir` $\leftrightarrow$ `mosaru`
  - `chana` $\leftrightarrow$ `chole` $\leftrightarrow$ `chickpeas` $\leftrightarrow$ `kabuli chana`
  - `paneer bhurji` $\leftrightarrow$ `paneer burji` $\leftrightarrow$ `cottage cheese scramble`

#### [MODIFY] [schemas/ai.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/schemas/ai.py)
* Add `@field_validator` on `RoutineRequest` for `days_per_week` (1–7) and `experience` (`beginner`, `intermediate`, `advanced`).
* Remove hardcoded defaults from `MealPlanRequest` (`calorie_goal`, `diet_preference`, `days`) and `WeeklyReportRequest` (`total_calories_logged`, `workout_sessions_count`, `total_volume_kg`, `prs_count`, `adherence_score`) to return strict HTTP 422 errors on missing client fields.

#### [MODIFY] [core/security.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/core/security.py) & [gemini_client.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/services/gemini_client.py)
* Add daily aggregate spend ceiling for Gemini calls returning `is_fallback: true` when exceeded.
* Integrate `cachetools.TTLCache` (TTL: 1 hour, maxsize: 1000) for identical prompt hashes.

---

### Mobile Client Component (`lib/`)

#### [MODIFY] [lib/core/privacy/privacy_policy.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/privacy/privacy_policy.dart)
* Split master offline toggle into modular capabilities:
  - `bool get isWorkoutOfflineCapable => true;` (Always true)
  - `bool get isNutritionOnlineAllowed => !isOfflineOnly && allowOnlineNutrition;` (Default true)
  - `bool get isAiAllowed => !isOfflineOnly && allowAiFeatures;` (Default true, gated by consent)

#### [MODIFY] [lib/features/settings/settings_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/settings/settings_screen.dart)
* Relabel "Strict Offline Mode":
  - Add permanent badge: **"Workouts: Always 100% Offline"**
  - Separate toggles: **"Online Food Search & Database"** (ON) and **"AI Meal Logging (Voice & Camera)"** (ON).

#### [MODIFY] [lib/data/database/app_database.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/database/app_database.dart)
* Add `FoodSearchCache` table to SQLite (Drift):
  - Columns: `query_hash` (text primary key), `query_text` (text), `response_json` (text), `cached_at` (dateTime), `ttl_seconds` (int).
  - Enables instant offline replay of previously searched terms without network.

#### [MODIFY] [lib/data/repositories/nutrition_food_catalog_repository.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/nutrition_food_catalog_repository.dart)
* In `ensureProviderFood` (lines 139–145): Stop discarding micronutrients!
* Persist `dietary_fiber`, `sodium_mg`, `added_sugars_g`, and `saturated_fat_g` into `NutrientFact` records.

#### [MODIFY] [lib/features/food_log/food_search_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/food_search_screen.dart)
* Refactor search pipeline:
  1. Instant render of matching local SQLite rows + `food_search_cache`.
  2. 300ms debounced network call to `/api/food/search`.
  3. Seamlessly merge server results, ranking verified Indian items first.
* Remove lines 632–648 hardcoded `contains('dal')` checks; read `serving_options` directly from the payload's `category_id` taxonomy.
* Replace empty query `[]` with user's frequent meals and favorites.

#### [MODIFY] [lib/core/services/crash_reporting_service.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/services/crash_reporting_service.dart)
* Add short-circuit check in `initialize`: skip `SentryFlutter.init` if user opted out or if `SENTRY_DSN` contains `placeholder_key`.

#### [NEW] [lib/features/food_log/widgets/quick_add_macros_sheet.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/widgets/quick_add_macros_sheet.dart)
* 10-second quick-add modal: enter name (optional), Calories, Protein, Carbs, Fat directly into the diary without searching a food item.

---

## Verification Plan

### Automated Backend Tests
1. Run pytest suite with newly added tests:
   ```bash
   PYTHONPATH=. INDIFIT_API_KEY=test_key ./backend/venv/bin/pytest backend/tests
   ```
2. Verify:
   - `test_food_search_endpoint`: Tests exact matches, Hinglish transliterations (`"toor dal"` $\to$ `"arhar dal"`), and pagination.
   - `test_validation_errors`: Asserts HTTP 422 when `RoutineRequest` has invalid `days_per_week` or `WeeklyReportRequest` is missing required fields.
   - `test_gemini_budget`: Asserts `is_fallback: true` when quota is exceeded.

### Automated Flutter Tests
1. Run static analysis:
   ```bash
   flutter analyze
   ```
2. Run database and repository tests:
   ```bash
   flutter test test/nutrition_food_catalog_test.dart test/food_search_ranking_test.dart
   ```
3. Verify that `ensureProviderFood` correctly saves and retrieves fiber and sodium facts.

### Manual / Integration Verification
1. **Search Experience**:
   * Search "arhar" $\to$ displays "Toor Dal (Arhar Dal)" with standard 150g Katori option.
   * Search "amul protein" $\to$ displays Amul High Protein Lassi with verified 15g protein.
   * Disconnect Wi-Fi $\to$ repeat previous search $\to$ results load instantly from SQLite disk cache.
2. **Offline Workout Invariance**:
   * Turn on Airplane Mode $\to$ start workout $\to$ log sets, trigger rest timer, check plate calculator $\to$ verify zero network prompts or errors.
3. **Quick-Add Sheet**:
   * Log 300 kcal / 25g protein / 30g carbs / 8g fat via Quick-Add $\to$ verify dashboard calorie and macro rings update immediately.
