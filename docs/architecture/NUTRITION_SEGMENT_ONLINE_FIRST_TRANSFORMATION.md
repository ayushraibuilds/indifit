# IndiFit — Nutrition Segment Transformation: Online-First, Offline-Fallback Architectural Blueprint & Execution Spec

> **Authoritative Engineering Specification & Production Blueprint**  
> **Target Release:** IndiFit 1.1.0+ (Nutrition Modernization Milestone)  
> **Status:** Finalized Architectural Specification (Post-Review Reconciled)  
> **Core Principle:** *Workouts = 100% Offline (Basement-Proof) | Nutrition = Online-First, Offline-Fallback (Quality, Speed & Scale)*  
> **Cross-Referenced Ground Truth:** Reconciled against `food_search_screen.dart`, `nutrition_food_catalog_repository.dart`, `lib/core/outbox/`, and FastAPI `backend/routers/ai.py`.

---

## Table of Contents

1. [Executive Summary & The Hybrid Contract](#1-executive-summary--the-hybrid-contract)
2. [Forensic Codebase Audit: The Line-Level "Offline Tax"](#2-forensic-codebase-audit-the-line-level-offline-tax)
3. [The New Privacy & Architectural Contract](#3-the-new-privacy--architectural-contract)
4. [Detailed Engineering Blueprints](#4-detailed-engineering-blueprints)
   - [Blueprint A: The Backend Food Search & Barcode Proxy](#blueprint-a-the-backend-food-search--barcode-proxy)
   - [Blueprint B: Category Taxonomy & Server-Driven Serving Intelligence](#blueprint-b-category-taxonomy--server-driven-serving-intelligence)
   - [Blueprint C: Multimodal Logging Engine (Voice, Photo, Outbox Queue)](#blueprint-c-multimodal-logging-engine-voice-photo-outbox-queue)
   - [Blueprint D: Micronutrients, Provenance Badges & Batch Handi Cooking](#blueprint-d-micronutrients-provenance-badges--batch-handi-cooking)
5. [Telemetry, Flywheel & Evaluation Metrics](#5-telemetry-flywheel--evaluation-metrics)
6. [What NOT To Do: Scope Traps & Anti-Patterns](#6-what-not-to-do-scope-traps--anti-patterns)
7. [Calibrated Phasing & Execution Timeline](#7-calibrated-phasing--execution-timeline)

---

## 1. Executive Summary & The Hybrid Contract

### 1.1 The Operational Disconnect
IndiFit’s initial philosophy enforced strict offline-first operation across the entire app. While this remains vital for strength training (where signal dead zones in basement gyms cause network spinners to drop sets and ruin rest timers), **it imposed a heavy "offline tax" on nutrition tracking without any user benefit**:
* **Lifting happens in basements**: Heavy barbell sets, RPE logging, rest timers, and plate calculations happen in iron-clad facilities where mobile signal drops. **The 100% offline-first requirement is non-negotiable for the Workout Player.**
* **Eating happens in connected spaces**: Meals are logged in kitchens, at dining tables, at work desks, in restaurants, or at grocery aisles. 99% of logging moments have accessible 4G/5G or home Wi-Fi.

By forcing food logging to be strictly offline-only:
* The food catalog was artificially capped at **573 bundled SQLite rows**.
* Search was limited to naive `LIKE %query%` matching, with zero tolerance for typos, Hinglish transliterations, or regional dish names.
* Packaged food barcode lookups were slow and lacked Indian fitness SKU coverage.
* Fiber, sodium, and micronutrients were discarded to keep local row schemas narrow.

### 1.2 The Dual-Engine Operational Contract

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        INDIFIT DUAL-ENGINE OPERATIONAL CONTRACT                        │
├────────────────────────────────────────┬───────────────────────────────────────────────┤
│ TRAINING ENGINE (STRENGTH & WORKOUTS)  │ NUTRITION ENGINE (DIARY, SEARCH, FOOD LOG)    │
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ • 100% Offline-First (Non-negotiable)  │ • Online-First, Offline-Fallback              │
│ • Local Drift SQLite (0ms latency)     │ • Fast Backend Search Proxy (/api/food/search)│
│ • Live Activities & Screen Wakelock    │ • AI Voice-to-Thali & Photo Meal Recognition  │
│ • Zero network checks during lifting   │ • Drift SQLite disk cache (food_search_cache) │
│ • Completely basement-proof            │ • Durable outbox queue (never block logging)  │
└────────────────────────────────────────┴───────────────────────────────────────────────┘
```

---

## 2. Forensic Codebase Audit: The Line-Level "Offline Tax"

A forensic inspection of the current nutrition stack confirms the exact code bottlenecks:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               CURRENT NUTRITION STACK STATUS                           │
├────────────────────────────────────────┬───────────────────────────────────────────────┤
│ Components That Work Well (Keep)       │ Crippled by the "Offline Tax" (Refactor)      │
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ • 300ms debounce + CancelToken in      │ • Local DB has only 573 items; search is naive│
│   food_search_screen.dart              │   LIKE %query% without FTS5 or typo tolerance │
│ • Multi-select batch logging + undo via│ • Hardcoded katori heuristic at lines 632-648 │
│   nutritionFoodLoggingCoordinator      │   in food_search_screen.dart won't scale      │
│ • hasCompleteMacros guard stops zeros  │ • ensureProviderFood() drops fiber, sugar,    │
│ • Natural language decomposition in    │   sodium, and sat-fat (lines 139-145)         │
│   natural_language_meal_service.dart   │ • Direct client-to-OFF calls (slow, un-cached)│
│ • Ephemeral cleanup in OCR service     │ • Dual legacy/canonical recent timeout (2s)   │
└────────────────────────────────────────┴───────────────────────────────────────────────┘
```

### Verified Code Hotspots

#### 1. Hardcoded Substring Katori Heuristics
In [`lib/features/food_log/food_search_screen.dart:632-648`](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/food_search_screen.dart#L632-L648), serving options are inferred via brittle substring containment:
```dart
if (lowerName.contains('dal') || lowerName.contains('curry') || lowerName.contains('sabzi') || lowerName.contains('sambar') ...)
  const ServingOption(unitName: 'katori', gramWeight: 150.0),
if (lowerName.contains('biryani') || lowerName.contains('pulao') || lowerName.contains('rice'))
  const ServingOption(unitName: 'medium_katori', gramWeight: 200.0),
if (lowerName.contains('roti') || lowerName.contains('chapati') || lowerName.contains('phulka'))
  const ServingOption(unitName: 'roti_piece', gramWeight: 35.0),
```
* **Failure Mode**: Items named without these specific substrings (e.g., *"Arhar Tadka"*, *"Chana Masala"*, *"Kootu"*, *"Undhiyu"*) fail matching and fall back to raw 100g, forcing mental arithmetic on the user.

#### 2. Discarding Micronutrients & Fiber
In [`lib/data/repositories/nutrition_food_catalog_repository.dart:139-145`](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/nutrition_food_catalog_repository.dart#L139-L145):
```dart
facts = <String, NutrientFact>{
  for (final definition in _registry.definitions)
    definition.id: _providerFact(
      nutrientId: definition.id,
      value: switch (definition.id) {
        'energy' => energyKcal,
        'protein' => proteinG,
        'carbohydrate' => carbohydrateG,
        'fat' => fatG,
        _ => null, // <--- DISCARDED: Fiber, Sugar, Sodium, Saturated Fat
      },
      ...
    ),
};
```
* **Failure Mode**: Open Food Facts returns fiber, sodium, added sugar, and saturated fat, and `NutrientRegistry` has definitions for them, but `ensureProviderFood` drops them. For Indian lifters, tracking dietary fiber and sodium is critical for gut health and fluid balance.

#### 3. Naive Local Search & N+1 Hydration
* In `searchFoodLocal()`, SQLite queries use raw `LIKE '%query%'`. An empty query returns `[]` instead of frequently logged or favorite items.
* In `nutrition_food_catalog_repository.dart:310`, hydrating options executes an individual `getOption()` database query for each matching row (N+1 query pattern).
* In `food_search_screen.dart:287`, `_canonicalRecentWithTimeout()` enforces an artificial 2-second timeout to bridge legacy and canonical recents.

---

## 3. The New Privacy & Architectural Contract

### 3.1 Splitting the Privacy Policy Toggle
Instead of an all-or-nothing "Strict Offline Mode" toggle that blocks outbound traffic indiscriminately, the policy is split into distinct domain capabilities:

```dart
// lib/core/privacy/privacy_policy.dart

class PrivacyPolicy {
  final bool isOfflineOnly; // Master kill-switch
  final bool allowOnlineNutrition;
  final bool allowAiFeatures;

  const PrivacyPolicy({
    this.isOfflineOnly = false,
    this.allowOnlineNutrition = true,
    this.allowAiFeatures = true,
  });

  /// Workouts are 100% offline regardless of any policy flag.
  bool get isWorkoutOfflineCapable => true;

  /// Nutrition search hits the cloud proxy by default, falling back to local SQLite.
  bool get isNutritionOnlineAllowed => !isOfflineOnly && allowOnlineNutrition;

  /// Multimodal voice and vision features require explicit DPDP consent.
  bool get isAiAllowed => !isOfflineOnly && allowAiFeatures;

  /// Open Food Facts queries route through the backend proxy.
  bool get isOpenFoodFactsProxyAllowed => isNutritionOnlineAllowed;
}
```

### 3.2 Settings UI & App Store Data Safety
1. **Settings Screen Reorganization**:
   * Permanent Badge: **"Workouts: Always 100% Offline"** (Non-toggleable indicator).
   * Toggle: **"Online Food Catalog & Smart Search"** (Default: **ON**).
   * Toggle: **"AI Multimodal Logging (Voice & Camera)"** (Default: **ON**, with DPDP consent modal on first activation).
2. **Regulatory Disclosures (DPDP / App Store Review Guideline 5.1.1)**:
   * Prior to first camera or voice capture, display an explicit consent modal:
     > *"IndiFit uses secure cloud AI (Google Gemini) to analyze meal photos and voice descriptions. Media is processed ephemerally, never used to train public models, and never sold to third parties."*

---

## 4. Detailed Engineering Blueprints

---

### Blueprint A: The Backend Food Search & Barcode Proxy

```
  MOBILE CLIENT                                         FASTAPI BACKEND
┌──────────────────────────────┐                     ┌────────────────────────────────────────┐
│ User types: "arhar dal"      │                     │ POST /api/food/search                  │
└──────────────┬───────────────┘                     └───────────────────┬────────────────────┘
               │                                                         │
               │ 1. Render Local SQLite Cache (0ms)                      ▼
               │ 2. Debounce 300ms ────────────────► ┌───────────────────────────────────────┐
               │                                     │ 1. Transliteration & Normalization    │
               │                                     │    "arhar" -> ["toor", "pigeon pea"]  │
               │                                     │ 2. Check In-Memory TTL Cache (hash)   │
               │                                     │ 3. Match Curated Indian Database      │
               │                                     │ 4. Fallback to Open Food Facts Proxy  │
               │                                     │ 5. Attach Category Taxonomy Units     │
               │                                     │ 6. Log zero-result queries            │
               │                                     └───────────────────┬───────────────────┘
               │                                                         │
               │◄──────────────── Return Ranked JSON ────────────────────┘
               ▼
┌──────────────────────────────┐
│ • Render ranked cloud items  │
│ • Write to food_search_cache │
└──────────────────────────────┘
```

#### 1. Zero-Ops Caching Architecture (Dropping Redis for V1)
* **Design Decision**: External Redis is explicitly **dropped** for V1 Beta. Redis introduces connection pool overhead, deployment dependencies, and monthly cloud costs for no gain at this scale.
* **Dual-Tier Cache Strategy**:
  1. **Backend Cache**: In-memory `cachetools.TTLCache(maxsize=2000, ttl=3600)` keyed by SHA-256 hash of `query + language`. Single-worker deployment (`WEB_CONCURRENCY=1`) guarantees 100% cache hit sharing.
  2. **Mobile Disk Cache**: New Drift SQLite table `food_search_cache(query_hash TEXT PRIMARY KEY, query_text TEXT, response_json TEXT, cached_at INTEGER, ttl_seconds INTEGER DEFAULT 604800)`. Enables instant offline replay of previously searched terms for 7 days.

#### 2. Search Endpoint Contract
* **Path**: `POST /api/food/search`
* **Request Payload**:
  ```json
  {
    "query": "arhar dal",
    "language": "hinglish",
    "page": 1,
    "limit": 20
  }
  ```
* **Response Payload**:
  ```json
  {
    "query": "arhar dal",
    "total_hits": 14,
    "has_more": false,
    "results": [
      {
        "id": "ind_toor_dal_cooked",
        "name": "Toor Dal / Arhar Dal (Cooked)",
        "brand": null,
        "category_id": "dal_lentil",
        "energy_kcal": 120,
        "protein_g": 8.0,
        "carbs_g": 18.0,
        "fat_g": 2.5,
        "fiber_g": 4.5,
        "sodium_mg": 280.0,
        "serving_options": [
          {"unit": "katori (standard)", "gram_weight": 150.0, "is_default": true},
          {"unit": "small_katori", "gram_weight": 100.0, "is_default": false},
          {"unit": "large_katori", "gram_weight": 250.0, "is_default": false},
          {"unit": "100g", "gram_weight": 100.0, "is_default": false}
        ],
        "provenance": "curated_catalog",
        "confidence": "high"
      }
    ]
  }
  ```

#### 3. Explicit Multi-Factor Ranking Formula
Search results are deterministically scored and ranked on the backend:
$$\text{Score} = S_{\text{match}} + S_{\text{provenance}} + S_{\text{quality}}$$

Where:
* **Match Score ($S_{\text{match}}$)**:
  * Exact Name Match = `100 points`
  * Prefix / Starts-With Match = `70 points`
  * Word Boundary / Synonyms Match = `50 points`
  * Fuzzy Substring Match = `20 points`
* **Provenance Score ($S_{\text{provenance}}$)**:
  * Curated Indian Master DB = `80 points`
  * Verified Indian FMCG Barcode = `70 points`
  * Open Food Facts Provider = `40 points`
* **Data Quality Score ($S_{\text{quality}}$)**:
  * Complete Macros + Fiber Verified = `15 points`
  * Missing Fiber / Partial Macros = `0 points`

#### 4. Transliteration & Dialect Dictionary
Loaded from `backend/data/indian_synonyms.json`:
* `arhar dal` $\leftrightarrow$ `toor dal` $\leftrightarrow$ `tuvar dal` $\leftrightarrow$ `yellow pigeon peas`
* `roti` $\leftrightarrow$ `chapati` $\leftrightarrow$ `phulka` $\leftrightarrow$ `poli`
* `dahi` $\leftrightarrow$ `curd` $\leftrightarrow$ `thayir` $\leftrightarrow$ `mosaru` $\leftrightarrow$ `yogurt`
* `chana` $\leftrightarrow$ `chole` $\leftrightarrow$ `chickpeas` $\leftrightarrow$ `kabuli chana`
* `paneer bhurji` $\leftrightarrow$ `paneer burji` $\leftrightarrow$ `scrambled cottage cheese`
* `khichdi` $\leftrightarrow$ `khichuri` $\leftrightarrow$ `pongal`

#### 5. Top Indian Fitness FMCG Starter Seed (~35 Core SKUs)
Rather than promising 200 unverified SKUs upfront, launch with an initial dietitian-verified starter set of ~35 essential staples, expanding the remainder asynchronously:
* **Amul**: High Protein Lassi (15g), High Protein Buttermilk (15g), Malai Paneer (200g), Whey Protein Sachet, High Protein Milkshake (Chocolate).
* **Epigamia**: Greek Yogurt (Natural, Blueberry, Strawberry), Protein Milkshake (Vanilla, Chocolate).
* **Pintola**: All-Natural Peanut Butter (Crunchy/Smooth), High Protein Peanut Butter (Dark Chocolate).
* **The Whole Truth**: Whey Protein Isolate (Unflavored, Cocoa), Protein Bars (Dark Chocolate, Coffee Cocoa).
* **Tata Sampann**: Unpolished Toor Dal, Unpolished Moong Dal, Fine Besan, Thick Poha.
* **Mother Dairy & Nandini**: Low-fat Cow Milk, Classic Toned Dahi, Paneer.

---

### Blueprint B: Category Taxonomy & Server-Driven Serving Intelligence

Eliminate client substring matching (`food_search_screen.dart:632-648`) by replacing it with an explicit **Category Taxonomy** defined on the food entity:

```json
{
  "taxonomies": [
    {
      "category_id": "dal_lentil",
      "display_name": "Dal & Lentil Curries",
      "serving_options": [
        {"unit": "katori (standard)", "gram_weight": 150.0, "is_default": true},
        {"unit": "small_katori", "gram_weight": 100.0},
        {"unit": "large_katori", "gram_weight": 250.0},
        {"unit": "100g", "gram_weight": 100.0}
      ]
    },
    {
      "category_id": "gravy_curry",
      "display_name": "Gravy Dishes & Non-Veg Curries",
      "serving_options": [
        {"unit": "katori (standard)", "gram_weight": 150.0, "is_default": true},
        {"unit": "medium_katori", "gram_weight": 200.0},
        {"unit": "100g", "gram_weight": 100.0}
      ]
    },
    {
      "category_id": "dry_sabzi",
      "display_name": "Dry Vegetables & Stir-Fries",
      "serving_options": [
        {"unit": "katori (standard)", "gram_weight": 120.0, "is_default": true},
        {"unit": "small_katori", "gram_weight": 80.0},
        {"unit": "100g", "gram_weight": 100.0}
      ]
    },
    {
      "category_id": "staple_bread",
      "display_name": "Indian Breads",
      "serving_options": [
        {"unit": "piece (standard roti)", "gram_weight": 35.0, "is_default": true},
        {"unit": "piece with ghee", "gram_weight": 40.0},
        {"unit": "stuffed paratha", "gram_weight": 110.0}
      ]
    },
    {
      "category_id": "staple_rice",
      "display_name": "Rice, Pulao & Grains",
      "serving_options": [
        {"unit": "medium_katori", "gram_weight": 200.0, "is_default": true},
        {"unit": "plate", "gram_weight": 350.0},
        {"unit": "100g", "gram_weight": 100.0}
      ]
    },
    {
      "category_id": "dairy_liquid",
      "display_name": "Milk, Chaas & Lassi",
      "serving_options": [
        {"unit": "glass (standard)", "gram_weight": 206.0, "is_default": true},
        {"unit": "small_glass", "gram_weight": 150.0},
        {"unit": "100ml", "gram_weight": 100.0}
      ]
    },
    {
      "category_id": "packaged_fmcg",
      "display_name": "Packaged Fitness Food",
      "serving_options": [
        {"unit": "pack / serving", "gram_weight": 0.0, "is_default": true},
        {"unit": "100g", "gram_weight": 100.0}
      ]
    }
  ]
}
```

* **Client Impact**: `FoodPortionBottomSheet` receives `serving_options` directly from the backend JSON. All client string containment checks are deleted.
* **Household Katori Calibration Override**: An optional setting allows users to override standard katori volume (e.g. set home bowl to `180ml` instead of `150ml`). The client dynamically scales all `gram_weight` values by the user's ratio ($\times 1.2$).

---

### Blueprint C: Multimodal Logging Engine (Voice, Photo, Outbox Queue)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                         MULTIMODAL LOGGING INTEGRATION                                 │
└────────────────────────────────────────────────────────────────────────────────────────┘

    [Describe Meal (Text/Voice)]            [Snap Plate (Photo)]
                 │                                    │
                 ▼                                    ▼
       Local Regex Fallback                  Client Downscale (1024x1024)
     (extracts "2 roti, 1 katori")                    │
                 │                           Gemini 1.5 Flash Vision
                 │                           (Quota: max 10/day/device)
                 │                                    │
                 └──────────────────┬─────────────────┘
                                    ▼
                     POST /api/ai/meal-decompose
                                    │
                                    ▼
                     ┌───────────────────────────────┐
                     │     CIRCULAR THALI PLATE      │
                     │  Center: 2 Rotis (70g)        │
                     │  Perimeter: 1 Dal (150g)      │
                     │  Perimeter: 100g Paneer       │
                     └──────────────┬────────────────┘
                                    │
                        [Tap HUD to adjust portions]
                                    │
                                    ▼
                     ┌───────────────────────────────┐
                     │   COMMIT TO LOCAL SQLITE      │
                     │   (Instant diary update)      │
                     └───────────────────────────────┘
```

#### 1. Voice-to-Thali Workflow
* Client records audio via `speech_to_text` and passes transcribed text into `/api/ai/meal-decompose`.
* The returned items populate directly into [`ThaliBuilderScreen`](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/thali/thali_builder_screen.dart).
* Rotis and rice land in the center staple zone; dals, sabzis, and curd land in the perimeter katoris.
* The user adjusts quantities via the Thali Quick-Adjust HUD and taps "Log Thali" with 1 confirmation.

#### 2. Photo Meal Recognition (Strictly Review-Only)
* **Portion Variance Truth**: Computer vision volume estimation carries an inherent $\pm 30\%$ error margin. Photo meal logging is strictly **review-only**; it never logs directly without user confirmation.
* **Client-Side Image Downscaling**: Images are resized on-device to a maximum of $1024 \times 1024$ pixels and compressed to JPEG 80% (under 300KB) prior to upload.
* **Per-Day Vision Budget**: Backend enforces a maximum of **10 photo meal scans per device per day** to control Gemini API costs.

#### 3. Durable Offline Outbox Queue (Never Block Logging)
* Verified in [`lib/core/outbox/`](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/outbox/): `OutboxOperation` already supports `OutboxDomain.food` with idempotency keys and state machines.
* **Offline Fallback Flow**:
  1. User attempts AI voice or photo logging while disconnected.
  2. The raw text and estimated calorie baseline are saved locally to SQLite as an unverified food log entry with badge: `AI Enrichment Pending`.
  3. An `OutboxOperation` is queued with `OutboxDomain.food`.
  4. When connectivity restores, the outbox worker sends the payload to `/api/ai/meal-decompose` and silently updates macros in SQLite.
  5. The user is never blocked from logging.

---

### Blueprint D: Micronutrients, Provenance Badges & Batch Handi Cooking

#### 1. Complete Micronutrient Persistence
Refactor `ensureProviderFood` in [`nutrition_food_catalog_repository.dart:139-145`](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/nutrition_food_catalog_repository.dart#L139-L145) to map all provided facts:
```dart
value: switch (definition.id) {
  'energy' => energyKcal,
  'protein' => proteinG,
  'carbohydrate' => carbohydrateG,
  'fat' => fatG,
  'dietary_fiber' => dietaryFiberG,
  'sodium' => sodiumMg,
  'added_sugars' => addedSugarsG,
  'saturated_fat' => saturatedFatG,
  _ => null,
}
```

#### 2. Visual Provenance & Confidence Badges
In search results and diary lists, attach transparent badges:
* 🟢 **Verified**: Curated Indian catalog item with full macro/micro integrity.
* 🔵 **Brand**: Verified Open Food Facts barcode item.
* 🟣 **AI Estimate**: Decomposed via Gemini (displays confidence: *High / Medium / Low*).
* 🟡 **Custom**: User-created quick-add or custom recipe.

#### 3. The "Batch Handi" Leftover Specification
* **Problem**: Indian households prepare a large pot of curry (*handi*) consumed over 2–3 days.
* **Data Model**:
  ```dart
  class HandiRecipe {
    final String id;
    final String name; // e.g., "Mom's Chicken Handi"
    final List<IngredientItem> rawIngredients; // Total raw ingredients in pot
    final double rawWeightG; // Sum of raw ingredients
    final double cookedWeightG; // Net cooked weight after water loss/gain
    final int totalYieldKatoris; // User defines: "Makes 4 medium katoris"
    final DateTime cookedOn;
  }
  ```
* **Cooking Physics**:
  * For lentils/rice: Cooked weight expands by $2.5\times - 3.0\times$ due to water absorption (calories remain constant).
  * For meat curries: Meat shrinks by $20-25\%$, while gravy adds water volume.
  * Formula per Katori:
    $$\text{Macro}_{\text{serving}} = \frac{\sum \text{Raw Macros}}{\text{Total Yield Katoris}}$$
* **1-Tap Consumption**:
  * Diary UI surfaces: **"Active Handis in Fridge"**.
  * User taps **"+1 Katori"** $\to$ logs exact proportion of total pot macros instantly.

---

## 5. Telemetry, Flywheel & Evaluation Metrics

### 5.1 The Zero-Results Telemetry Flywheel
* In [`backend/routers/food.py`](file:///Users/dankmagician/Documents/New%20project/indifit/backend/routers/food.py), when a search returns `total_hits == 0`:
  * Record `{ "query": str, "timestamp": int, "language": str }` to an in-memory ring buffer.
  * Flush hourly to an anonymous `missed_searches.jsonl` log file.
  * **Weekly Review Loop**: Engineering uses this log to add missing regional dishes and typos into `indian_synonyms.json`, growing catalog coverage organically.

### 5.2 Objective Quality Metrics (No Premature Parity Claims)
Do not claim parity with Healthify or MyFitnessPal until measured against concrete benchmarks:
1. **Search Success Rate (SSR)**:
   $$\text{SSR} = \frac{\text{Searches Resulting in a Logged Food}}{\text{Total Search Queries}} \times 100\% \quad (\text{Target: } \ge 85\%)$$
2. **Mean Time to Log (MTTL)**:
   $$\text{MTTL} = \text{Time from Search Tap to Log Confirmation} \quad (\text{Target: } \le 12 \text{ seconds})$$
3. **AI Fallback Frequency**: Percentage of queries triggering offline/fallback mode (Target: $< 5\%$).

---

## 6. What NOT To Do: Scope Traps & Anti-Patterns

1. **Do NOT build a proprietary 100,000-item food database from scratch**:
   * Curate the **top 2,000 Indian staple dishes and packaged fitness foods**. Proxy everything else through Open Food Facts Search-a-licious.
2. **Do NOT re-introduce cloud user accounts or authentication gates**:
   * Keep search and logging anonymous (using device UUID for rate-limiting). User authentication should remain deferred to Stream B multi-device sync.
3. **Do NOT rename the 81 `b04_*` files in the same branch**:
   * Refactoring the nutrition architecture while renaming 81 files creates massive merge conflicts and breaks active tests. Keep file names stable; execute the domain rename post-beta.
4. **Do NOT use Redis for V1 Beta**:
   * In-memory TTL cache + Drift SQLite disk cache provides 100% of the speed with zero operational hosting complexity.

---

## 7. Calibrated Phasing & Execution Timeline

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        CALIBRATED IMPLEMENTATION PHASING                               │
├──────────────────────────────┬──────────────────┬──────────────────────────────────────┤
│ Phase                        │ Timeline         │ Key Deliverables                     │
├──────────────────────────────┼──────────────────┼──────────────────────────────────────┤
│ Phase 1A: Backend Proxy &    │ 2–3 Days         │ • backend/routers/food.py search API │
│           Synonyms Engine    │                  │ • indian_synonyms.json transliterate │
│                              │                  │ • In-memory TTLCache (no Redis)      │
│                              │                  │ • Fix P0 schema validators & defaults│
├──────────────────────────────┼──────────────────┼──────────────────────────────────────┤
│ Phase 1B: Client Hybrid Wire │ 2–3 Days         │ • food_search_screen.dart proxy wire │
│           & Category Taxonomy│                  │ • Drift food_search_cache table      │
│                              │                  │ • Replace contains('dal') with cats  │
│                              │                  │ • Persist fiber, sodium, sat-fat     │
├──────────────────────────────┼──────────────────┼──────────────────────────────────────┤
│ Phase 1C: Starter FMCG Seed  │ Async (1 Week)   │ • Curate top 35 fitness SKUs         │
│                              │                  │ • Dietitian-verified macro baseline  │
├──────────────────────────────┼──────────────────┼──────────────────────────────────────┤
│ Phase 2:  Multimodal Logging │ 3–5 Days         │ • Voice-to-Thali integration         │
│           & Outbox Fallback  │                  │ • Client image downscale & vision cap│
│                              │                  │ • DPDP consent modal                 │
│                              │                  │ • lib/core/outbox/ deferred enrich   │
├──────────────────────────────┼──────────────────┼──────────────────────────────────────┤
│ Phase 3:  Batch Handi &      │ 1 Week           │ • "Mom's Handi" leftover data model  │
│           Telemetry Flywheel │                  │ • Quick-Add Macros bottom sheet      │
│                              │                  │ • Missed search logging flywheel     │
└──────────────────────────────┴──────────────────┴──────────────────────────────────────┘
```

---

## 8. Conclusion

This blueprint eliminates the "offline tax" on nutrition tracking while preserving a 100% offline-first strength training core. 

By replacing substring pattern matching with an **explicit category taxonomy**, introducing a **backend search proxy with Hinglish transliteration**, and adding **Voice-to-Thali logging**, IndiFit transforms its food tracking from a constrained utility into a high-speed, culturally authentic competitive moat.
