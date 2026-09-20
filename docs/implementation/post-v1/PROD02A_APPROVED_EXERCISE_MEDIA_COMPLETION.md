# PROD-02A: Approved Exercise Media Completion Specification

**Package:** `PV1-PROD-02A` / `PV1-PROD-02B`  
**Status:** Approved Specification  
**Authority:** `assets/third_party/asset_manifest.json`  
**Legal Boundary:** `docs/legal/THIRD_PARTY_ASSETS.md`  
**Acquisition Architecture:** `docs/implementation/r08/R08_0_3_REPDB_ASSET_ACQUISITION.md`  

---

## 1. Overview & Problem Statement

IndiFit requires clear, human-reviewed movement technique illustrations for core exercises across the Exercise Library, Exercise Details Sheet, and Workout Player without introducing copyright ambiguity, unbounded bitmap decoding memory pressure, or synthetic animation loops.

Prior to `PV1-PROD-02`:
1. **Unresolved Media Delivery:** Raw RepDB WebPs remained unvendored in public Git to respect licensing boundaries, but production builds lacked an automated, verified acquisition path for local distribution.
2. **Missing Pose Inspection:** In `ExerciseDetailsSheet`, illustrations defaulted statically to `start` pose, leaving users unable to inspect `peak` contraction poses or review movement technique disclosures.
3. **Unconstrained Decoder Memory:** Dense list views (`ExerciseLibraryScreen`) rendered 44×44 thumbnails without explicit `cacheWidth` constraints, causing the image engine to decode full-resolution bitmaps into RAM during fast scrolls.

---

## 2. Legal Distribution & Provenance Contract

### A. Provenance Authority
- Single machine-readable authority: `assets/third_party/asset_manifest.json`
- Source repository: `https://github.com/RepDB/exercise-dataset`
- Pinned immutable commit: `045845b61e4aefd9e684fa84518b84c665ea3cd3`
- License: RepDB Free Tier License v1.0 (`LICENSES/RepDB-LICENSE-DATA-v1.0.md`)

### B. Clean Public Repository Invariant
- **Zero Raw WebPs in Git:** In accordance with `THIRD_PARTY_ASSETS.md:44,47`, public redistribution of raw WebP artwork remains uncommitted.
- **Git Ignore Enforcement:** `.gitignore` line 61 ignores `assets/generated/repdb/**/*.webp`.
- **Validation Guard:** `tool/validate_r08_0_3_public_repo.dart` verifies that no WebP files are tracked in the Git index and that the ignore rule remains effective.

### C. Attribution Contract
In `lib/features/settings/about_credits_screen.dart`, the visible credit must read verbatim:
> Exercise data by RepDB (repdb.co). Approved exercise illustrations, when available, are used under the RepDB Free Tier License.

### D. Technique Disclosure Contract
Whenever an approved illustration is presented in an instructional context (e.g. `ExerciseDetailsSheet` or expanded player context), the official technique disclosure must be visible or accessible:
> This illustration represents the underlying movement and equipment. It is not an exact demonstration of pause duration, tempo, or other IndiFit technique prescriptions. Follow the IndiFit cues and set prescription for technique details.

---

## 3. Approved Asset Inventory & Binding Counts

The provenance manifest establishes the exact boundary:
- **Total Approved Visual Asset Sets:** 30
- **Total Acquired Files:** 59
  - 29 `start` / `peak` pairs (58 files)
  - 1 `main`-only static set (`plank-main.webp`, 1 file)
- **Canonical Exercise UUID Bindings:** 120 (each approved set maps to canonical UUIDs in `assets/data/exercises.json`)
- **Binding Rejections:** 5 candidate families rejected during human movement review (`R08_0_2_HUMAN_APPROVAL_SUMMARY.md` and `R08_0_2_TERRA_VISUAL_REVIEW.md`):
  - FAM-19: Barbell Hip Thrust
  - FAM-22: Dumbbell Lateral Raise (cable variant binding)
  - FAM-28: Standing Overhead Triceps Extension (cable variant binding)
  - FAM-31: Hanging Leg Raise
  - FAM-34: Russian Twist

---

## 4. Performance, Memory, & Decoding Constraints

### A. Pinned DPR-to-CacheWidth Formula
To prevent full-resolution bitmap decodes during scrolling and high-density rendering:
1. **List Item Thumbnail (44×44pt container):**
   $$\text{cacheWidth} = \max(88, \, \lfloor 44.0 \times \text{DPR} \rceil)$$
   On standard $2\times$ displays this decodes to 88px; on $3\times$ displays to 132px.
2. **Detail Sheet Banner (110pt slot):**
   $$\text{cacheWidth} = \max(220, \, \lfloor 110.0 \times 1.5 \times \text{DPR} \rceil)$$
   Constrained to bounded dimensions avoiding GPU texture bloat.
3. **Workout Player Context:**
   Existing formula in `B07ExerciseVisualRegion._cacheWidth`:
   $$\text{logicalWidth} = \text{clamp}(120.0, \, 360.0, \, \text{screenWidth} / 2)$$
   $$\text{cacheWidth} = \lfloor \text{logicalWidth} \times \text{DPR} \rceil$$

### B. No Auto-Loop Invariant
Exercise stills must remain static poses (`start`, `peak`, or `main`). No auto-looping animation or GIF/video playback is permitted under `PV1-PROD-02`. Motion/video is deferred to `PV1-MEDIA-02`.

---

## 5. Fallback Chain & Accessibility Contract

### A. Fallback Chain
If local media is absent (e.g. in un-acquired public clones), checksum mismatch occurs, or an exercise is custom/unapproved:
1. **Tier 1 — Approved Local WebP:** Validated via SHA-256 in `_loadApprovedAsset()`.
2. **Tier 2 — IndiFitMuscleMap:** Render primary and secondary targeted muscle groups via vector geometry.
3. **Tier 3 — Semantic Equipment Icon:** Render `IndiFitIcons.equipment` or `IndiFitIcons.exercise`.
4. **Tier 4 — Neutral Fallback:** Render `Icons.image_not_supported_outlined`.

### B. Accessibility Semantics
- **List Thumbnails:** Must declare `decorative: true` (`ExcludeSemantics`), preventing repetitive screen-reader announcements in dense lists.
- **Detail Views & Player:** Must provide meaningful container semantics (`image: true`, label indicating exercise name and pose, e.g. "Bench Press start position illustration").
