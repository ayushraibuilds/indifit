# Nutrition catalogue packs: online-sourced, locally served

**Status:** approved direction (Ayush, 2026-10-06) · **Owner:** Ayush (data, hosting, licences), Claude (code) · **Last updated:** 2026-10-07

Related:
- [LAUNCH_ROADMAP_FINAL.md](LAUNCH_ROADMAP_FINAL.md): PR order and launch dates. PR-A, E and F are re-scoped by this plan.
- [FINAL_LAUNCH_AUDIT_2026-10-05.md](../audit/FINAL_LAUNCH_AUDIT_2026-10-05.md): findings C-01, C-04, C-06, C-09, A-01, A-02.
- [NUTRITION_SEGMENT_ONLINE_FIRST_TRANSFORMATION.md](../architecture/NUTRITION_SEGMENT_ONLINE_FIRST_TRANSFORMATION.md): the earlier blueprint. Its server search proxy is **replaced** by this plan; its synonyms, taxonomy, cache and "don't build 100k foods" guidance still apply.

---

## 0. Tracker

Update this table in every PR that touches the catalogue. IDs are referenced from commits and the roadmap.

| ID | Work item | Kind | PR | Depends on | Status |
|---|---|---|---|---|---|
| CAT-1 | Pack format v1 spec + schema v24 (`catalog_state`) | Code | A | — | Merged (#61) |
| CAT-2 | Pack importer (validate → one transaction → canonical tables) | Code | A | CAT-1 | Merged (#61). PR-E adds pack aliases to the format and importer. |
| CAT-3 | Bundled pack v1 from today's catalogue; single nutrition-fact read path (fixes C-01) | Code | A | CAT-2 | Merged (#61) |
| CAT-4 | Servings with gram weights + household conversions in packs | Code + data | A (format), E (data) | CAT-1 | Format merged (#61). Data in progress (PR-E): option (a), gram weights only where derivable (stated grams, the app's 150 g katori and 300 g bowl), each with its `basis`: 316 of 498 active foods. The rest get none, and the app declines to convert them to grams. |
| CAT-5 | Pack build pipeline `tool/catalog/` + validator + CI job | Code | E | CAT-1 | In progress (PR-E): `build.py`, `validate.py` (all § 5 invariants), CI step in `static`. `--baseline` reports 101 violations on today's data, including C-04's 6 + 29. |
| CAT-6 | Curated overlay v2: C-04 measure fixes, C-09 retirements, honest count | Data | E | CAT-5 | In progress (PR-E): pack v2 bundled; 63 measures fixed, 37 variants retired (75 in the pack), 392 aliases from `indian_synonyms.json`; store and README say 243 dishes. Spot-check sheet `tool/catalog/spotcheck_50.csv` waits for Ayush. |
| CAT-7 | Update service: manifest check, download, verify, import; Settings → Food database | Code | H | CAT-2 | Merged (#70). Updates stay off until a build sets `INDIFIT_CATALOG_MANIFEST_URL` (after CAT-8). Settings → Food database counts variants from the pack's `variant_of`, which the importer now writes to `variant_of_food_id`, so it agrees with the store copy (498 foods, 255 variants, 243 dishes). |
| CAT-8 | Hosting: publish packs on Firebase Hosting | Owner | — | CAT-5 | Config ready (PR-H #70: `firebase.json` hosting, `.firebaserc`). Files ready (PR-E): `tool/catalog/packs/` (manifest + full and delta packs), copied to `public/catalog/v1/` per runbook § 10.1. **Deploy is owner work.** |
| CAT-9 | Local full-text search (FTS5) over names + aliases; retire the legacy search path | Code | I | CAT-3 | Not started |
| CAT-10 | Licences: INDB permission request; attribution screen | Owner + code | — / B | — | **Waiting on Ayush** (INDB email). Code: About & credits names Open Food Facts (ODbL) and labels catalogue values "IndiFit estimates" (PR-B); CC0/OGL credits join when that data ships (CAT-11). |
| CAT-11 | Import INDB recipes (if CAT-10 = yes) **or** build dishes from CC0/OGL ingredient data | Data | J | CAT-5, CAT-10 | Not started |
| CAT-12 | AI portion conversions use pack gram weights (C-06) | Code | F | CAT-4 | Not started |
| CAT-13 | Opt-in "couldn't find it" feedback (local queue, sent only with consent) | Code | K | CAT-7 | Not started (Next) |

Status values: Not started · In progress (PR #) · Merged (PR #) · Blocked (reason).

There are no dates. Items start as soon as their dependencies are met, in the order of the roadmap's ready queue ([LAUNCH_ROADMAP_FINAL.md](LAUNCH_ROADMAP_FINAL.md) § 2.5). The hard rules in that doc's § 0 apply.

---

## 1. Decision record

**Context**
- Nutrition was built offline-first around 573 bundled rows (261 distinct dishes plus 312 templated variants).
- The plan to move nutrition online proposed a FastAPI search proxy. That proxy isn't deployed, and it serves the same `indian_foods.json`, so going online by itself would add no Indian foods.
- Two problems hold nutrition back today:
  - the catalogue is small, static and partly wrong (audit C-04, C-09);
  - nutrition facts live in two places (legacy `food_items` plus canonical tables written lazily), which made every thali log 0 kcal (C-01).

**Decision (2026-10-06)**
- Nutrition becomes **online-sourced and locally served**.
- The catalogue is published as versioned packs on static hosting. The app downloads them when online and writes them into its canonical tables.
- Search and logging always run on the device.
- The network is used for: catalogue updates, Open Food Facts (packaged foods and barcodes), and the AI tools.
- Training stays fully offline-first.

**Why not search on a server per keystroke**
- Latency: Open Food Facts searches measured 634–733 ms on good Wi-Fi in the audit, against instant local search.
- Privacy: no meal text leaves the device for search.
- Cost and operations: no server, auth or rate limits.
- The proxy had open security items (audit, 1 Oct).

**Consequences**
- One canonical place for nutrition facts.
- Catalogue fixes ship without app releases.
- First launch works offline from the bundled pack.
- New content depends on licensed data (§ 3).

**Rejected alternatives**
- Live search proxy: as above.
- Commercial nutrition APIs: per-call cost, storage and caching restrictions, weak Indian dish coverage, and query text leaves the device.
- Bundling Open Food Facts data into packs: ODbL share-alike obligations. Keep it as live lookup plus cache, as today.

---

## 2. Goals and non-goals

**Goals**
1. Every food any feature reads (search, direct log, thali, recipe, AI) has its facts in one canonical place, with explicit basis and serving gram weights.
2. Catalogue content can be corrected or extended by publishing a pack, with no app release.
3. Search stays instant offline; first launch needs no network.
4. Every value has provenance (source, version, licence) visible in the app.

**Non-goals (for now)**
- A server search API or ranking service.
- User accounts or sync.
- Bundling Open Food Facts data.
- More than about 3,000 foods: curated quality beats raw count (earlier blueprint § 6).

**Success measures**
- 0 bundled foods without current energy facts (CI invariant).
- Thali, recipe, direct and AI paths agree on kcal for the same food and amount (test).
- Pack applies in under 2 s on a mid-range Android (owner device check).
- Search over 3,000 foods returns in under 50 ms locally (test benchmark).

---

## 3. Data sources and licences (checked 2026-10-06)

| Source | What it gives | Licence / terms | Use in packs | Evidence |
|---|---|---|---|---|
| **IndiFit catalogue v1** (`assets/data/indian_foods.json`) | 573 rows, 6 nutrients, household units | Ours; **provenance of values not recorded** | Pack v1 base, flagged "unreviewed" until checked | Repo; no `source` field in any row |
| **INDB** (Indian Nutrient Databank) | 1,014 Indian recipes + 1,095 raw foods, 40+ nutrients, per 100 g and per serving | **Paper: CC BY. Data repo: no licence file.** Built from ICMR-NIN IFCT 2017/2004 (which "must be requested from the original source") and recipes from two published cookbooks plus 148 web recipes | **Only with written permission** from the authors (CAT-10) | [Paper, 2024-06-13](https://pmc.ncbi.nlm.nih.gov/articles/PMC11277795/); [repo](https://github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB-) (`gh api …/license` → 404; README has no licence statement) |
| **ICMR-NIN IFCT 2017** | 528 key Indian foods (raw ingredients) | Published by NIN; not openly licensed | Reference only, unless NIN grants permission | NIN publication |
| **USDA FoodData Central** | Ingredients | **Public domain, CC0 1.0**; citation requested | ✅ Ingredient values for recipe-built dishes | [fdc.nal.usda.gov](https://fdc.nal.usda.gov/) |
| **UK CoFID (2021)** | Ingredients | **Open Government Licence v3.0** (attribution) | ✅ Ingredient values | [gov.uk CoFID](https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid) |
| **Open Food Facts** | Packaged products, barcodes | ODbL (the app already shows "Source: Open Food Facts (ODbL)") | ❌ not in packs; live lookup + local cache only | App shot 87 |

**Plan if INDB permission is refused or slow** (CAT-11, path B):
- Build dishes ourselves: standard home recipes (ingredients in grams) × CC0/OGL ingredient values.
- Apply yield/cooking factors.
- Review the top 300 dishes by hand.
- Slower, but fully ours.

---

## 4. Architecture

```
             tool/catalog (repo, CI)                      Firebase Hosting (static, CDN)
  sources/ + overlays/ ──build.py──► packs/v{N}/ ──deploy──► /catalog/v1/manifest.json
                         validate.py (CI gate)               /catalog/v1/v{N}/{N}.json.gz
                                                                   │
  ┌──────────────────────────── app ─────────────────────────────────┼──────────────┐
  │ assets/catalog/pack-{N0}.json.gz (bundled)          CatalogUpdateService ◄──────┘
  │        │                                            (daily max, Wi-Fi default,  │
  │        ▼                                             Offline Mode blocks, ETag) │
  │  CatalogPackImporter ── validate → one DB transaction → canonical tables:       │
  │    nutrition_foods · nutrition_food_nutrient_facts · nutrition_food_aliases     │
  │    nutrition_quantity_conversions · catalog_state (new) · FTS index (CAT-9)     │
  │        │                                                                        │
  │        ▼  every reader uses the same canonical facts                            │
  │  search · direct log · thali · recipe · AI matcher · repeat · diary             │
  └─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Pack format v1 (CAT-1)

**`manifest.json`** (small; fetched with `If-None-Match`):

```json
{
  "format": 1,
  "latest": 7,
  "min_app_build": 12,
  "packs": [
    {"version": 7, "base": 6, "kind": "delta", "url": "packs/7-from-6.json.gz", "sha256": "…", "bytes": 41234},
    {"version": 7, "kind": "full", "url": "packs/7.json.gz", "sha256": "…", "bytes": 612345}
  ]
}
```

**Pack file** (gzip JSON). All ids are stable forever.

```json
{
  "format": 1, "version": 7, "base": 6, "kind": "delta",
  "registry_version": "<nutrient registry version>",
  "sources": [{"id": "indifit-curated", "licence": "proprietary", "attribution": null}],
  "foods": [{
    "id": "food-seed-0564",
    "display_name": "Whole Wheat Roti / Chapati",
    "kind": "canonical", "region": null, "lifecycle": "active",
    "variant_of": null, "source_id": "indifit-curated", "source_ref": "asset:base:whole wheat roti / chapati",
    "category": "breads",
    "facts": {"basis": "per_100_grams", "values": {"energy": 297, "protein": 10.6, "…": "…"}},
    "servings": [{"id": "piece", "label": "1 roti", "grams": 40, "default": true}],
    "household": [{"measure": "piece", "grams": 40}],
    "aliases": [{"text": "phulka", "locale": "hi-Latn"}, {"text": "chapati", "locale": "en-IN"}]
  }],
  "retire": [{"id": "food-seed-0013", "replaced_by": "food-seed-0010"}]
}
```

**Rules**
- **Identity:** existing `food-seed-NNNN` ids and `asset:base:` refs are kept, so past logs resolve. New ids are namespaced (`indb:ASC001`, `cat:<slug>`). Rename the display name freely; never change an id.
- **Facts:** per 100 g (or per 100 ml) whenever a gram weight is known; `per_serving` only when it isn't. Each pack that changes a food's values writes a new `fact_version` and flips `is_current`. Snapshots already logged keep their stored numbers (immutable).
- **Servings:** every active food has at least one serving with a gram (or ml) weight. This is what lets the thali, the portion sheet and the AI convert katori, piece and bowl.
- **Household measures:** food-specific factors go into `nutrition_quantity_conversions` (`owner_scope = catalogue`). The user's calibrated vessels (tables already exist) override them.
- **Retire, never delete:** `lifecycle = deprecated` plus `replaced_by`; the existing `kRetiredCatalogueFoods` behaviour moves into the pack.
- **Size budget:** a full pack under 1 MB gzipped. Measured today: 573 foods ≈ 17 KB gzipped; ~3,000 foods × 18 nutrients is estimated at 0.4–0.8 MB.

### 4.2 Importer (CAT-2)

`lib/data/catalog/catalog_pack_importer.dart`

1. Parse and validate:
   - format version and `min_app_build`;
   - sha256;
   - registry version matches;
   - CHECK-style rules mirroring the table constraints;
   - every `variant_of` and `replaced_by` exists.
2. In **one Drift transaction** (runs on the DB isolate):
   - upsert `nutrition_foods`;
   - write facts (new `fact_version`);
   - upsert aliases and conversions;
   - apply retirements;
   - write `catalog_state(version, sha256, applied_at, source='bundled'|'download')`.
3. Afterwards: invalidate `food_search_cache` and rebuild the FTS rows for changed foods.
4. **Idempotent:** re-applying the same version is a no-op. A delta whose `base` ≠ the installed version is rejected, and the full pack is fetched instead.
5. **Failure** leaves the previous version intact (transaction rollback). The error is logged, with a breadcrumb if crash reporting is on.

### 4.3 Single read path (CAT-3, fixes C-01)

- **Remove the lazy legacy write path from reads:**
  - `NutritionFoodCatalogRepository.search` no longer calls `ensureLegacyFood` per row (`nutrition_food_catalog_repository.dart:385-396`);
  - the recipe coordinator and the thali read only canonical facts, which now always exist for catalogue foods.
- **Legacy `food_items`:**
  - kept read-only for old snapshots and old custom foods;
  - a one-time migration copies legacy custom foods into canonical rows (`kind = userCreated`);
  - the food screen's separate legacy search (`food_search_screen.dart:391` → `searchFoodLocal`) is removed in CAT-9.
- **CI invariant test:** every active catalogue food has a current energy fact, and at least one serving with a gram weight.

### 4.4 Update service (CAT-7)

`lib/data/catalog/catalog_update_service.dart`

- **Trigger:** app resume, at most once every 24 h, plus a manual "Check for updates".
- **Policy:**
  - Offline Mode on → never.
  - Default: Wi-Fi only.
  - User setting: "Also update on mobile data", showing the pack size.
- **Fetch:** `manifest.json` with `If-None-Match`, then the delta if `base` matches, else the full pack; verify sha256; import.
- **As built (PR-H):**
  - the manifest URL comes from `--dart-define=INDIFIT_CATALOG_MANIFEST_URL`; empty (the default) means updates are off and nothing is requested;
  - the small manifest is checked on any connection, so the mobile-data switch can show the waiting download's size; the pack itself waits for Wi-Fi;
  - an update held for Wi-Fi goes ahead on the next resume on Wi-Fi without re-fetching the manifest; everything else waits for the 24-hour mark;
  - the manifest's `min_app_build` is checked before the download, and each pack's again when it is decoded. Both compare against this build's real number (`versionCode` / `CFBundleVersion`, via `package_info_plus`), so a pack that needs build 7 or later needs no code change; if the platform can't report it, the app assumes build 1, which can only refuse a gated pack.
- **No Firebase SDK and no Remote Config** on this path (Remote Config charges past 100,000 requests a day since 1 Sep 2026). A plain HTTPS GET through the app's existing Dio client, so Offline Mode enforcement applies.
- **Settings → Food database** shows:
  - catalogue version and date;
  - number of foods;
  - last check;
  - "Check for updates";
  - sources and attributions (CC0/OGL credits, INDB credit if used).

### 4.5 Local search (CAT-9)

- An FTS5 virtual table over `display_name`, aliases and regional names (first verify that the bundled SQLite build has FTS5: a test that creates the table).
- Query flow:
  1. normalise (lowercase, `foldFoodSpellings`, the synonyms from `backend/data/indian_synonyms.json` moved into packs as aliases);
  2. FTS prefix match;
  3. rank by exact > prefix > alias > fuzzy, plus a personal-frequency boost (recents and frequents already exist);
  4. hide retired foods and templated variants unless asked.
- Open Food Facts results are appended after local results, exactly as today.

### 4.6 What still uses the network

| Feature | Endpoint | Sends | Offline behaviour |
|---|---|---|---|
| Catalogue updates | Firebase Hosting (static) | Nothing about the user (standard HTTP request) | Uses the installed pack |
| Packaged search and barcode | Open Food Facts | Search text or barcode | Local results only; cached lookups replay |
| AI tools | Firebase AI Logic | Typed text or photo, after consent | Hidden or "needs internet" |

---

## 5. Build pipeline (CAT-5, CAT-6)

```
tool/catalog/
  sources/          # raw inputs; licensed sources only, each with SOURCE.md (licence, URL, date)
  overlays/         # curated corrections: measures, retirements, aliases, gram weights (YAML)
  build.py          # sources + overlays → packs/v{N}/{N}.json.gz, delta from N-1, manifest.json
  validate.py       # invariants (below); exits non-zero on failure; run in CI
  packs/            # build output (committed for small packs; else CI artifact)
```

**Invariants enforced by `validate.py`:**
- unique ids;
- no id disappears without a `retire` entry;
- energy present for every active food;
- 4/4/9 check: kcal within ±25 % of `4P + 4C + 9F` (allowing fibre and alcohol);
- every serving has grams > 0;
- household rows: `servings.grams` consistent with the measure (catches the "60 katori" class, C-04);
- a variant's kcal per gram is within ±25 % of its base unless tagged `size` or `oil` (catches "Double = 1 katori");
- names of retired templated variants never return;
- the size budget is met.

**CI:** a new job (or a step in `static`) runs `python3 tool/catalog/validate.py` and fails the build on any violation.

---

## 6. Migration and rollout

1. **Schema v24 (PR-A):**
   - add the `catalog_state` table (plus the FTS virtual table in CAT-9);
   - `onUpgrade` and `onCreate` apply the bundled pack v1;
   - existing ids are untouched, so old logs and snapshots resolve as before.
2. **Bundled pack v1 = today's catalogue as is** (same values; provenance "unreviewed"), plus serving gram weights where they are already known. Data fixes (C-04/C-09) arrive as pack v2 from the pipeline, either downloaded or bundled in the next release.
3. **First download path ships when CAT-7 and CAT-8 are done.** Target: during the closed test (testers get v2 over the air). If it slips, v2 is bundled in 1.0 and downloads start in 1.0.1.
4. **Rollback:** publish a higher version that restores the old content. Clients never move backwards. The importer keeps the last good state on failure.

---

## 7. Privacy, store and copy changes (fold into PR-B where possible)

- **Privacy policy § 2:** "IndiFit downloads food database updates from its servers. These downloads send no information about you or your meals."
- **Offline Mode copy:** add "and food database updates".
- **Data Safety / App Privacy:** no new data types, because no user data is sent. Re-check Google's and Apple's guidance on request metadata when filling in the forms.
- **Store listing:** "260+ Indian dishes with katori, roti and glass portions, updated regularly", then the real count after v2.
- **Attribution screen** (Settings → Food database → Sources): USDA FoodData Central (CC0, citation), UK CoFID (OGL v3.0), Open Food Facts (ODbL), INDB (if permitted).

---

## 8. Cost (checked 2026-10-06, [Firebase pricing](https://firebase.google.com/pricing))

| Item | Free allowance | Above it | Expected use |
|---|---|---|---|
| Firebase Hosting | 10 GB stored, 360 MB/day transfer | $0.15/GB | Deltas of tens of KB; full packs under 1 MB. **₹0 at launch scale.** |
| Cloud Storage (alternative) | 5 GB stored, 100 GB/month download | Cloud Storage rates | Not needed unless Hosting limits bind |
| Remote Config | 100,000 requests/day free (since 1 Sep 2026), then $0.000006 per request | — | **Not used** for catalogue checks |
| Data | CC0/OGL free; INDB depends on permission | — | — |

No server to run. The only usage-based bill stays Gemini for the AI tools.

---

## 9. Work items: change, tests, risks, verification

Each test listed must fail on `main` before the change (`git stash push -- lib`, run, `git stash pop`).

### CAT-1 Pack format + schema v24  (PR-A)
- **Change:** `lib/data/catalog/catalog_pack.dart` (models plus a JSON parser with strict validation); `catalog_state` table; schema 23 → 24 migration.
- **Tests:**
  - parsing rejects a bad sha, a wrong format and a dangling `replaced_by`;
  - the v23 → v24 migration preserves all rows (extend the existing migration contract tests).
- **Risk:** a migration on every installed device. Mitigate with failure-injection tests like v15–v22.

### CAT-2 Importer  (PR-A)
- **Change:** `CatalogPackImporter.apply(pack)` as in § 4.2.
- **Tests:**
  - applying v1 twice is a no-op;
  - a delta on the wrong base is rejected;
  - an injected failure mid-apply leaves the previous `catalog_state` and facts unchanged;
  - a retirement keeps old snapshots resolvable.
- **Risk:** apply time on low-end phones. Batch inserts; measure (success measure: under 2 s).

### CAT-3 Bundled pack v1 + single read path  (PR-A; fixes C-01)
- **Change:** generate `assets/catalog/pack-1.json.gz` from today's assets (a one-off script in `tool/catalog/`); apply it at create/upgrade; remove the lazy `ensureLegacyFood` writes from search; the thali and recipe coordinator read canonical facts.
- **Tests:**
  - **real-catalogue harness** (`test/support/real_catalogue.dart`): Whole Wheat Roti, 2 rotis, gives 170 kcal through direct log, thali and recipe alike (thali is NULL today);
  - all `ThaliPresets.all` presets have energy (NULL today);
  - invariant: every active catalogue food has current energy (fails today: no facts are seeded).
- **Risk:** legacy custom foods. Migrate them, and keep `food_items` read-only.

### CAT-4 Servings and household conversions  (format in PR-A, data in PR-E)
- **Change:** packs carry `servings[]` and `household[]`; the importer writes `nutrition_quantity_conversions`; `PortionMapping` and the portion sheet read them.
- **Tests:**
  - "1 katori" of dal, where the katori is 150 g, gives the same kcal in the portion sheet and the thali;
  - a calibrated personal katori overrides the catalogue's.

### CAT-5 Pipeline + validator + CI  (PR-E)
- **Change:** `tool/catalog/build.py`, `validate.py`, and a CI step.
- **Tests:** `validate.py` run on today's data reports the known C-04 violations (6 gram-as-katori rows, 29 Double/Small rows), proving the invariants bite. The CI job is green after CAT-6.

### CAT-6 Curated overlay v2  (PR-E)
- **Change:** overlays fix C-04 and retire C-09's nonsense variants; gram weights only where the repo's data gives them (decided 2026-10-07, option (a): stated grams, the app's 150 g katori and 300 g bowl; no invented weights); aliases (Hinglish and regional) moved from `backend/data/indian_synonyms.json`.
- **Verification:** the validator is clean; a spot-check sheet of 50 random foods against reference values (Ayush, optionally a dietitian).

### CAT-7 Update service + Settings screen  (PR-H)
- **Change:** § 4.4.
- **Tests (with a fake HTTP client):**
  - an ETag hit doesn't download;
  - Wi-Fi-only on cellular doesn't download;
  - Offline Mode makes no request (the interceptor throws);
  - a sha mismatch is rejected and the previous version kept;
  - a delta is applied when the base matches, and the full pack is fetched when it doesn't.
- **Risk:** a bad pack reaching every device. Mitigate with the CI validator, sha256, `min_app_build`, a staged rollout (manifest `latest` bumped after a 24 h test on Ayush's devices) and rollback (§ 6).

### CAT-8 Hosting  (owner)
- `firebase init hosting` with a `public/catalog/v1/` directory; cache headers: `manifest.json` `Cache-Control: no-cache`, packs `immutable`.
- Deploy with `firebase deploy --only hosting` (Claude can prepare the config; Ayush runs the deploy).
- Verify with `curl -I https://<project>.web.app/catalog/v1/manifest.json`.

### CAT-9 FTS5 search  (PR-I)
- **Change:** § 4.5. Remove `FoodRepository.searchFoodLocal` from the food screen.
- **Tests:**
  - "arhar dal" finds Toor Dal via an alias;
  - "chapti" (typo) finds Chapati;
  - retired foods are hidden;
  - a search over 3,000 foods takes under 50 ms;
  - FTS5 availability.
- **Risk:** FTS5 missing in a platform build. The availability test runs in CI on Linux; the device check is owner work.

### CAT-10 Licences  (owner, now)
- Email the INDB corresponding author (via the paper's correspondence address) asking for written permission to use INDB-derived values in a free consumer app with attribution, and in a possible future paid tier.
- Record the answer in `tool/catalog/sources/indb/SOURCE.md`.
- Add CC0/OGL attributions to the Sources screen (PR-B or PR-H).

### CAT-11 Content growth  (PR-J)
- **Path A (INDB permitted):** map the 1,014 recipes to our schema (per 100 g, serving grams from `recipes_servingsize.xlsx`, household weights), de-duplicate against our 261 dishes, review the top 300.
- **Path B (not permitted):** recipe-built dishes from CC0/OGL ingredients (§ 3).
- **Verification:** the validator passes; zero-result rate on the top 200 Indian dish names (test list) is below 5 %.

### CAT-12 AI conversions  (PR-F)
- **Change:** `PortionMapping.map` (`meal_item_resolver.dart:363`) converts via CAT-4 conversions (bowl, plate, glass, grams ↔ servings); `genericDefaults` "dal" → Toor Dal; hide templated variants from `choices`.
- **Tests:** the audit § 3.4 probe cases become assertions. Then the paid eval rerun (owner).

### CAT-13 "Couldn't find it" feedback  (PR-K, Next)
- A local queue of zero-result queries; nothing is sent unless the user taps "Send these to improve IndiFit" (text only, no diary data).
- It feeds CAT-11 priorities.

---

## 10. Maintenance runbook

| Task | Steps |
|---|---|
| Correct a value | Edit the `overlays/` entry, run `build.py` (new version N+1 with a delta), `validate.py`, PR, deploy Hosting, bump `latest` after 24 h of testing on your own devices |
| Add foods | Add to `sources/` or `overlays/` with provenance, then as above |
| Retire a duplicate | Add `retire: {id, replaced_by}` in an overlay; never delete or re-use the id |
| Emergency rollback | Publish N+2 restoring the previous content (clients never downgrade); the CI validator must pass |
| New nutrient | Update the nutrient registry (`assets/data/nutrient_registry.json`) in an app release first; packs with an unknown registry version are rejected |
| Check state on a device | Settings → Food database shows the version, date and count |

### 10.1 Hosting runbook (CAT-8, owner)

The hosting config is in `firebase.json` (project `indifit-d5f8d`, set in `.firebaserc`). It serves `public/`; the packs live under `public/catalog/v1/`:

- `manifest.json`: `Cache-Control: no-cache` (clients revalidate with `If-None-Match`, so an unchanged manifest costs a 304);
- every `*.json.gz` under it (`v{N}/{N}.json.gz`, `v{N}/{N}-from-{N-1}.json.gz`): `Cache-Control: public, max-age=31536000, immutable` (a pack file never changes; a fix is a new version).

`public/` is not committed (it is in `.gitignore`). The packs are committed in `tool/catalog/packs/` (PR-E), and the manifest's pack URLs are relative to it, so the directory is copied as it is.

1. Check the committed packs are current and valid, then stage them:
   ```bash
   python3 tool/catalog/build.py --check
   python3 tool/catalog/validate.py
   rm -rf public/catalog/v1 && mkdir -p public/catalog/v1
   cp -R tool/catalog/packs/. public/catalog/v1/
   ```
2. Deploy from the repo root:
   ```bash
   firebase deploy --only hosting --project indifit-d5f8d
   ```
3. Verify the headers:
   ```bash
   curl -I https://indifit-d5f8d.web.app/catalog/v1/manifest.json
   # expect: HTTP/2 200, cache-control: no-cache, an etag

   curl -I -H 'If-None-Match: "<etag from above>"' \
     https://indifit-d5f8d.web.app/catalog/v1/manifest.json
   # expect: HTTP/2 304

   curl -I https://indifit-d5f8d.web.app/catalog/v1/v<N>/<N>.json.gz
   # expect: HTTP/2 200, cache-control: public, max-age=31536000, immutable,
   # and NO content-encoding header (the app checks the sha256 of the .gz bytes)
   ```
4. Check a pack's checksum against the manifest:
   ```bash
   curl -s https://indifit-d5f8d.web.app/catalog/v1/v<N>/<N>.json.gz | shasum -a 256
   ```
5. Turn updates on in a build:
   `--dart-define=INDIFIT_CATALOG_MANIFEST_URL=https://indifit-d5f8d.web.app/catalog/v1/manifest.json`.
   Without it, the app never makes an update request. Test on your own devices for 24 hours (Settings → Food database → Check for updates) before bumping `latest` for everyone (§ 9 CAT-7 risk).

## 11. Open questions for Ayush

1. **INDB:** send the permission email now? *Recommend yes.* It costs nothing, and the answer decides CAT-11 path A or B.
2. **Mobile-data downloads:** off by default? *Recommend Wi-Fi-only by default*; deltas are tiny, so offer "Also on mobile data". **Decided (Ayush): Wi-Fi only by default**, with the "Also update on mobile data" switch (PR-H).
3. **Pack v2 timing:** ship over the air during the closed test (needs CAT-7 merged and CAT-8 deployed while the test is still running) or bundle it in 1.0? *Recommend over the air.* It also exercises the update path with real testers.
4. **Dietitian review** of the top 300 dishes before calling the catalogue "reviewed"? *Recommend yes after launch*; until then, label values "IndiFit estimate".
