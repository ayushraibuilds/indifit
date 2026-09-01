# C0B Contract Freeze and Characterization Baseline

- Status: Complete
- Date: 2026-09-01
- Parent program: [`../POST_V1_CLEANUP_PROGRAM.md`](../POST_V1_CLEANUP_PROGRAM.md)
- C0A evidence: [`C0A_TEST_HARNESS_BASELINE.md`](C0A_TEST_HARNESS_BASELINE.md)
- Preference contract: [`C0B_PREFERENCE_CONTRACT.md`](C0B_PREFERENCE_CONTRACT.md)
- Schema contract: [`C0B_SCHEMA_V20_CONTRACT.md`](C0B_SCHEMA_V20_CONTRACT.md)
- Backup contract: [`C0B_BACKUP_CONTRACT.md`](C0B_BACKUP_CONTRACT.md)
- Fragile-flow matrix: [`C0B_FRAGILE_FLOW_MATRIX.md`](C0B_FRAGILE_FLOW_MATRIX.md)
- Navigation contract: [`C0B_NAVIGATION_CONTRACT.md`](C0B_NAVIGATION_CONTRACT.md)
- Preference ownership: [`C0B_PREFERENCE_OWNERSHIP.md`](C0B_PREFERENCE_OWNERSHIP.md)
- Visual/state inventory: [`C0B_VISUAL_STATE_INVENTORY.md`](C0B_VISUAL_STATE_INVENTORY.md)

## Purpose

C0B freezes observable contracts before retired-code removal or mechanical
presentation extraction. It records machine-checkable public behavior rather
than private widget structure.

## Route contract slice

`test/c0b_route_contract_test.dart` freezes:

- all 43 root `GoRoute` paths and their declaration order;
- uniqueness of route paths;
- the synchronous onboarding redirect truth table;
- eight compatibility redirects for retired or moved destinations;
- accepted and rejected Food date, Food meal, and manual-activity payloads.

### Compatibility redirects

| Existing entry point | Frozen destination |
|---|---|
| `/routine-wizard` | `/plan-library` |
| `/workout` | `/training` |
| `/workouts` | `/training` |
| `/food/ai` | `/food` |
| `/settings/profile` | `/profile` |
| `/meal-planner` | `/food` |
| `/weekly-report` | `/progress` |
| `/travel-mode` | `/training` |

These paths remain compatibility contracts. Their presence does not restore
the retired product surfaces they redirect away from.

### Verification

- `flutter test test/c0b_route_contract_test.dart --reporter expanded` — 5/5
  passed.
- `flutter test test/c0b_preference_contract_test.dart --reporter expanded` —
  4/4 passed.
- `flutter analyze` — no issues found.

## Persisted preference slice

The production key/default inventory is frozen in
[`C0B_PREFERENCE_CONTRACT.md`](C0B_PREFERENCE_CONTRACT.md). Characterization
now covers public key spellings, consumer defaults, Health category mappings,
the exact 17-key onboarding draft surface, and the Today handoff lifecycle.

The inventory distinguishes current durable preferences, resumable/device-local
metadata, and legacy backup aliases. It also records backup coverage gaps and a
legacy hydration-unit inconsistency for the upcoming backup contract review;
neither was changed during this slice.

## Schema v20 slice

[`C0B_SCHEMA_V20_CONTRACT.md`](C0B_SCHEMA_V20_CONTRACT.md) freezes the complete
normalized SQLite DDL for 88 tables, 85 named indexes, and 73 triggers, with
foreign keys enabled and schema version 20. It also adds direct evidence that a
real v19 file advances to v20 while preserving its singleton settings row and
adding only the four nullable lifecycle end markers.

## Backup v5-v10 slice

[`C0B_BACKUP_CONTRACT.md`](C0B_BACKUP_CONTRACT.md) freezes the six supported
restore generations, their owned graphs, no-fabrication rules, envelope
inspection authority, and transactional restore outcomes. The focused matrix
passes 36/36 tests; no historical decoder or payload was changed.

## Fragile-flow slice

[`C0B_FRAGILE_FLOW_MATRIX.md`](C0B_FRAGILE_FLOW_MATRIX.md) maps the six weak
areas identified by the audit to outcome-based protection. The selected Saved
Meal, Recipe, plan authoring, Data Management, Today/dashboard, and notification
tests pass 73/73.

## Detailed navigation slice

[`C0B_NAVIGATION_CONTRACT.md`](C0B_NAVIGATION_CONTRACT.md) records path and
query parameters, positive database IDs, workout `state.extra` payloads and
fallbacks, notification destinations, all 51 `MaterialPageRoute` constructions,
and current push/go/replacement/reset back behavior. No local route was migrated.

## Preference ownership/reset slice

[`C0B_PREFERENCE_OWNERSHIP.md`](C0B_PREFERENCE_OWNERSHIP.md) maps current key
families to all 20 direct production access sites, distinguishes preference
authority from Drift mirrors and device-local metadata, and freezes export,
restore compensation, draft clearing, onboarding reset, and no-global-clear
behavior.

## Visual/semantics/state slice

[`C0B_VISUAL_STATE_INVENTORY.md`](C0B_VISUAL_STATE_INVENTORY.md) catalogues 111
approved goldens, theme and compact/large-text distribution, reduced-motion and
semantics gates, loading/empty/error/retry/offline behavior coverage, and the
focused selection rule for later mechanical splits. Generated failure images
are explicitly not approved baselines.

## Exit evidence

- Consolidated contract, backup, and fragile-flow suite — 120/120 passed.
- Focused W06 visual/accessibility certification — 37/37 passed, including
  light/dark, compact width, large text, semantics, focus, and reduced motion.
- `flutter analyze` — no issues found.
- `git diff --check` — clean.

C0B is complete. C1A may now classify retired-surface candidates; this record
does not itself authorize deletion.
