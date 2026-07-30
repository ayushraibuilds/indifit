# B01 — Exercise Identity & Equipment Fixtures Audit

## Executive Summary

This audit documents the deterministic exercise identity, alias resolution, ambiguous legacy name handling, and equipment normalization fixtures established in **B01-01** ahead of database schema v15 migration.

---

## 1. Manifest Version & Structure

* **Manifest Version**: `1` (`kExerciseManifestVersion = 1`)
* **Total Canonical Exercises**: 140 bundled catalog exercises parsed from `assets/data/exercises.json`.
* **UUID Assignment Approach**: Explicit, immutable portable UUIDs stored per catalog entry in static golden manifest table (`goldenCatalogUuids`). Catalog UUIDs are fixed and decoupled from dynamic runtime string evaluation—cosmetic display-name changes and manifest reordering maintain 100% UUID stability.

---

## 2. Approved 1-to-1 Aliases

The manifest defines 21 explicitly approved 1-to-1 alias mappings to exact canonical catalog names:

| Normalized Alias Input | Resolved Canonical Catalog Name |
|---|---|
| `push-ups`, `push ups`, `pushup`, `pushups` | `Push-Ups` |
| `barbell squats` | `Barbell Squat` |
| `seated dumbbell press`, `dumbbell shoulder press` | `Seated Dumbbell Shoulder Press` |
| `incline dumbbell press` | `Incline Dumbbell Bench Press` |
| `single-arm dumbbell row`, `single arm dumbbell row` | `One-Arm Dumbbell Row` |
| `barbell row` | `Bent Over Barbell Row` |
| `leg extension machine`, `leg extension` | `Leg Extensions` |
| `rdl`, `romanian deadlift` | `Romanian Deadlift (RDL)` |
| `flat bench press` | `Flat Barbell Bench Press` |
| `lat pulldown machine` | `Lat Pulldown` |
| `cable row` | `Seated Cable Row` |
| `cable face pulls` | `Face Pulls` |
| `ez bar skull crushers`, `skullcrushers` | `Skull Crushers (EZ Bar)` |

---

## 3. Alias Audit & Ambiguous Classifications

### Aliases Removed & Reclassified
* **`dumbbell curls` & `dumbbell curl`**: Removed from automatic 1-to-1 alias resolution. The catalog contains multiple distinct dumbbell curl exercises (`Dumbbell Hammer Curl`, `Incline Dumbbell Curl`, `Dumbbell Bicep Curl (Standard)`). Auto-mapping generic `"dumbbell curls"` creates false precision and corrupts exercise history tracking.

### Complete Ambiguous Legacy Names Registry (15 Entries)
The following generic or multi-candidate legacy exercise names return `ExerciseLookupStatus.ambiguous` and require user resolution or explicit template selection during migration:
1. `dumbbell curls`
2. `dumbbell curl`
3. `leg curl machine`
4. `leg curl`
5. `dumbbell bench press`
6. `squats`
7. `squat`
8. `dips`
9. `tricep dips`
10. `row`
11. `dumbbell bicep curl`
12. `bicep dumbbell curl`
13. `curl`
14. `lunges`
15. `extension`
16. `press`

---

## 4. Movement Technique & Equipment Variant Isolation

* **Technique Variants Kept Separate**: Base movements, `(Standard)`, `Pause`, and `Slow Eccentric` entries are distinct catalog items with separate immutable UUIDs. They are never automatically collapsed into base movements.
  * Example: `Flat Barbell Bench Press (Standard)`, `Pause Flat Barbell Bench Press`, `Slow Eccentric Flat Barbell Bench Press`, and `Flat Barbell Bench Press` maintain 4 distinct UUIDs.
* **Equipment Variants Kept Separate**: `Overhead Barbell Press` (Barbell) and `Seated Dumbbell Shoulder Press` (Dumbbell) remain separate canonical exercises with distinct UUIDs.

---

## 5. Equipment Normalization & Coverage

* **10 Canonical Equipment Items**: `barbell`, `dumbbell`, `cable`, `machine`, `bodyweight`, `bands`, `kettlebell`, `bench`, `rack`, `cardio_equipment`.
* **Catalog Coverage**: 100% resolution for all 5 catalog equipment values (`Barbell`, `Dumbbells`, `Machine`, `Cables`, `Bodyweight`).
* **Combined Equipment Strings**: Parsed via delimiter splitting (e.g. `"Barbell, Bench"`, `"Dumbbells / Cable"`).
* **Legacy Category Mappings**: Maps legacy `UserProfiles.equipmentAccess` strings (`full_gym`, `dumbbells`, `bodyweight`).
* **Unresolved Equipment Labels**: Unrecognized equipment strings (e.g. `"Anti-gravity Chamber"`) are preserved as `unresolved` without silent fallback or coercion.

---

## 6. Unresolved Records & User-Created Exercises

* **User-Created Exercises**: Preserves user-created exercises with their existing portable UUID and display name.
* **Uncatalogued Legacy Code Strings**: Codebase references to non-catalog names (`Pike Push-ups`, `Decline Push-ups`, `Superman Lat Pulls`, `Doorway Bicep Curls`) resolve to `ExerciseLookupStatus.unresolved` with `canonicalUuid: null` while preserving original display strings.

---

## 7. Remediation & Sol Review Conformance

* **B01-F01**: Replaced dynamic name-derived identity with versioned static golden UUID manifest table.
* **B01-F02**: Removed generic `dumbbell curls` alias and added explicit multi-candidate ambiguity handling.
* **B01-I03**: Authored this comprehensive identity and equipment review audit artifact.
