# PV1-CONTENT-01A: Signed Content-Pack Envelope (Specification)

- Status: Specified; contracts frozen in `test/pv1_content01a_pack_contract_test.dart`
- Effective date: 2026-09-06
- Scope: envelope format, validation pipeline, activation/rollback policy.
  Out of scope: acquisition/download transport (a later `ContentDownloadCapability`
  package), durable pack pinning (later storage package), key distribution PKI.

## 1. Why

Food, exercise, and starter-plan content currently ships only inside app
releases (`assets/data/regional/*.json`, `meal_plans/*.json`,
`split_templates.json`, `exercises.json`). Fixing a wrong macro or adding a
regional pack should not require a store release. Content packs make that
extensible while keeping every trust property the offline core demands.

## 2. Envelope format

```json
{
  "pack_id": "regional-punjabi-v3",
  "kind": "regionalFoods",
  "version": 3,
  "min_app_version": "1.0.0",
  "issued_at_utc": "2026-09-06T00:00:00.000Z",
  "files": [
    {"path": "punjabi.json", "sha256": "<hex>", "size_bytes": 1234}
  ],
  "signature": "<hmac-sha256-hex>"
}
```

- `version` is a monotonically increasing integer per `pack_id`.
- `min_app_version` is `major.minor.patch`, compared numerically.
- `signature` is HMAC-SHA256 over the canonical payload (sorted keys;
  `lib/core/content/content_pack_validator.dart`) with the pack-signing key.
- Unknown kinds, missing fields, empty file lists, and non-positive versions
  fail closed at parse time.

## 3. Validation pipeline (strict order)

1. **Structure** — strict `fromJson`; unknown enum values throw.
2. **Compatibility** — reject when `min_app_version` exceeds the running app.
3. **Authenticity** — constant-time HMAC comparison. No default or embedded
   key: the validator takes the key as a parameter and rejects empty keys.
4. **Integrity** — per-file SHA-256 recomputed over the exact transfer bytes
   (never re-serialized approximations) plus byte-size match.
5. **Schema pre-check** — per kind, on verified bytes only:
   - `regionalFoods`: JSON array; every item needs a non-empty name and
     non-negative calorie/macro numbers; Atwater rule identical to the food
     catalog (`|kcal − (4P+4C+9F)| ≤ max(15, 20%)`, unit-independent).
   - `exerciseMetadata` / `starterPlan`: JSON array of objects with names
     (detailed per-field validators arrive with their domain packages).

A valid signature on corrupt data therefore cannot poison local storage:
steps 4–5 run after authentication, on the bytes themselves.

## 4. Activation and rollback

- Only validated envelopes may stage; only the staged instance may activate
  (`ContentPackRegistry` throws otherwise — a caller bug cannot promote
  unverified content, and last-good stays live on any failure).
- `rollbackToBundled()` returns to compiled-in canonical assets (`assets/`
  as shipped). Rollback never deletes history, downloads, or user data.
- **App-upgrade fallback:** if an upgrade makes the active pack incompatible
  (`min_app_version` above the new app — impossible in the normal direction,
  but enforced on every load path that consults the registry), the reader
  treats the pack as absent and serves bundled assets. Bundled assets are
  always the safe default, never a degraded error state.

## 5. First application: regional food deltas

Regional packs (`regionalFoods` kind over `assets/data/regional/*.json`
shapes) are the first consumer: small, high-value, and covered by the
existing identity manifest. Exercise metadata and starter plans reuse the
same envelope with their own schema pre-checks.

## 6. Deferred decisions (explicitly not this package)

- Key distribution, rotation, and revocation (account-gate track).
- Download transport, resume, bandwidth budgets, storage quotas.
- Durable pack pinning across restarts (storage package; no schema changes
  were made here by hotspot rule).
- Server-side catalogue/plan discovery UX and version-update prompts
  (presented as diffs, never silent mutations — roadmap requirement).

## 7. Verification

- `flutter test test/pv1_content01a_pack_contract_test.dart` — valid,
  tampered-signature, tampered-byte, oversized/missing-file, incompatible,
  malformed, Atwater-violating, and rollback/retention cases.
- `flutter analyze` — no issues.
