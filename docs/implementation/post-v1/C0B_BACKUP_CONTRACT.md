# C0B Backup v5-v10 Contract

- Status: Frozen baseline
- Date: 2026-09-01
- Current portable format: v10
- Supported restore formats: v5, v6, v7, v8, v9, and v10

## Immutable format ladder

| Format | Owning boundary | Representative evidence |
|---|---|---|
| v5 | legacy schema-v14 records and preferences | `test/fixtures/backup_v5_fixtures.dart`, `test/backup_restore_transaction_test.dart` |
| v6 | B01 plans/calendar/equipment and legacy mapping | `test/b01_backup_v6_test.dart` |
| v7 | B02 typed workout execution and evidence | `test/b02_backup_v7_test.dart` |
| v8 | B03 canonical nutrition graph | `test/b03_backup_v8_codec_test.dart` |
| v9 | B04 targets, consent, coaching, and recovery | `test/b04_backup_v9_test.dart` |
| v10 | B05 dashboard/content/media/playlist state and v20 lifecycle extension | `test/b05_backup_v10_test.dart`, `test/ux_r07f_training_lifecycle_test.dart` |

Each decoder retains the meaning it had when introduced. Older formats import
with later graphs empty; restore must not fabricate nutrition, coaching,
personalization, or lifecycle evidence that the source format could not carry.

## Frozen outcomes

- Raw and encrypted envelopes inspect through the same typed payload authority.
- Envelope labels and table counts never override checksummed payload facts.
- Unknown future versions and unsupported versions below v3 fail before writes.
- v5 integer identities remap without breaking relationships.
- v6 preserves the B01 graph and legacy routine mapping.
- v7 preserves typed modality/execution rows and imports v6 with B02 empty.
- v8 preserves portable user nutrition while excluding catalogue seed rows and
  device-local image state.
- v9 preserves user/goal/recommendation lineage and rejects invalid ownership,
  order, policy, and timestamp contracts.
- v10 preserves typed B05 user-owned rows while excluding local file paths,
  downloaded bytes, physical availability, credentials, and provider payloads.
- Invalid relationships and database failures roll back database rows and
  managed preferences together; a retry remains possible.
- Restored databases pass foreign-key checks.

## Preference boundary

The legacy preference collector is part of the portable format. Current keys,
legacy aliases, intentional device-local metadata, and observed coverage gaps
are classified in [`C0B_PREFERENCE_CONTRACT.md`](C0B_PREFERENCE_CONTRACT.md).
C0B records those gaps but does not alter any historical codec or payload.

## Verification

The focused v5-v10 matrix passed 36/36 tests on 2026-09-01:

```text
flutter test \
  test/backup_restore_transaction_test.dart \
  test/b01_backup_v6_test.dart \
  test/b02_backup_v7_test.dart \
  test/b03_backup_v8_codec_test.dart \
  test/b04_backup_v9_test.dart \
  test/b05_backup_v10_test.dart \
  --reporter compact
```

## Refactor gate

Historical decoders are immutable during cleanup. Consolidating table specs or
validation primitives later must retain representative JSON meaning, inspection
results, restored-state equivalence, failure atomicity, and the no-fabrication
rules above.
