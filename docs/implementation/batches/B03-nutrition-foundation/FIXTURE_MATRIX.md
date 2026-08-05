# B03-01 — Nutrition Contract and Fixture Matrix

Status: B03-01 implementation artifact. This document freezes the deterministic
fixture contract and records the read-only audit of the current food assets. It
does not add a production nutrition schema, resolver, repository, calculator,
backup format, seed identity, or UI behavior.

## Versions and ownership

| Artifact | Version | Owner/reviewer | Purpose |
|---|---:|---|---|
| B03 contract fixture vocabulary | `1` | GPT Luna implementation / Sol High review | Stable semantic cases for downstream B03 tasks |
| B03 manifest-audit shape | `1` | GPT Luna implementation / Sol High review | Read-only source coverage and unresolved-row report |
| Reviewed food identity manifest | `1` | B03-03 catalogue owner / Sol High identity review | Explicit portable food IDs, aliases, variants, and source revisions |

The planned manifest path is
`assets/data/nutrition_food_identity_manifest.json`. B03-01 intentionally did
not create it; B03-03 now owns the reviewed manifest. Stable IDs in the
fixture matrix and manifest are explicit and are never derived at runtime
from display names or insertion order.

Implementation: `lib/core/fixtures/b03_nutrition_fixture_matrix.dart`.
Required tests: `test/b03_contract_fixture_test.dart` and
`test/b03_food_manifest_fixture_test.dart`.

## Fixture contract coverage

`B03ContractFixtureDocument.current` contains exactly three cases for every
accepted decision and automatically accepted product default:

- `valid`: accepted contract shape;
- `invalid`: reject before mutation;
- `unknown`: preserve unknown, unresolved, partial, or legacy state.

The complete traceability set is 29 references × 3 cases = 87 deterministic
fixtures. Reordering entries preserves the fixture ID and reference
relationship. Duplicate IDs, unknown references, unsupported versions, missing
case fields, and incomplete valid/invalid/unknown coverage fail before the
document is returned.

| Reference | Contract focus | Downstream consumers |
|---|---|---|
| B03-D01 | Portable food/preparation identity separate from recipes and logs | B03-03, B03-06A/B, B03-11A |
| B03-D02 | Exact narrow normalization and explicit ambiguity | B03-03 |
| B03-D03 | Legacy preservation and no speculative mapping | B03-02, B03-06A, B03-11B |
| B03-D04 | Mass, volume, count, serving, and household dimensions | B03-04, B03-05, B03-08 |
| B03-D05 | Scoped, bounded, provenance-bearing conversions | B03-04, B03-05 |
| B03-D06 | Direct-food immutable recipes; nested recipes deferred | B03-07, B03-08 |
| B03-D07 | Immutable source/result history snapshots | B03-11A/B |
| B03-D08 | Directional reviewed raw/cooked transformations | B03-09 |
| B03-D09 | Contextual household labels and volume-only vessels | B03-10 |
| B03-D10 | Typed nutrient status, basis, source, and bounds | B03-05, B03-08 |
| B03-D11 | Estimate uncertainty and correction lineage | B03-14 |
| B03-D12 | Ordered thali composition through the shared calculator | B03-13 |
| B03-D13 | Descriptive protein distribution and source-aware leucine | B03-15 |
| B03-D14 | Typed constraint evidence and four cautious states | B03-16 |
| B03-D15 | Transactional v17/v8 migration and restore boundary | B03-02, B03-06A/B |
| B03-D16 | One owner and one calculation path per bounded context | B03-08, B03-13 |
| B03-D17 | Unknown, approximate, offline, correction, and error states | B03-14, B03-17 |
| B03-D18 | Reviewed versioned food-identity manifest | B03-03 |
| B03-D19 | Minimized AI/photo privacy and manual/unknown offline fallback | B03-14 |
| B03-PD01 | Current and regional rows remain distinct until review | B03-03 |
| B03-PD02 | Typed Indian portion vocabulary with unavailable fallback | B03-04 |
| B03-PD03 | Legacy meal templates remain separate from recipes | B03-02, B03-07, B03-11B |
| B03-PD04 | Append-only corrections and archive/delete boundary | B03-06B, B03-11A, B03-14 |
| B03-PD05 | Explicit meal groups and frozen local time | B03-11A, B03-15 |
| B03-PD06 | Free-form ordered thali | B03-13 |
| B03-PD07 | Volume-only vessel calibration | B03-10 |
| B03-PD08 | Offline manual/unknown estimate path | B03-14 |
| B03-PD09 | Descriptive protein/leucine MVP | B03-15 |
| B03-PD10 | Identity-only user aliases and no unrestricted safety rules | B03-03, B03-16 |

## Typed semantic fixtures

### Identity and provenance

The matrix includes canonical, approved-alias, ambiguous, unresolved/custom,
imported-provider, and legacy text-only cases. Canonical and alias fixtures use
portable IDs; aliases may point to a reviewed canonical fixture ID. Ambiguous,
unresolved, and legacy entries retain original display text and have no
canonical ID. Imported fixtures carry provider namespace and external ID
separately from the food identity.

Fixture examples:

- `identity-canonical-roti` / `food-seed-0001`
- `identity-approved-alias-fixture`
- `identity-regional-overlap-ambiguous`
- `identity-custom-unresolved`
- `identity-imported-provider`
- `identity-legacy-text-only`

No fuzzy, substring, punctuation-stripping, preparation-stripping, or
name-derived resolution is present.

### Quantity and missingness

The matrix covers half-roti count `0.5`, banana count with an approximate
conversion, milk glass volume `240 ml`, katori rice without density, a
manufacturer serving, an unknown household measure, and a negative invalid
quantity. Quantity values are contract sentinels, not catalogue nutrition
facts. Negative values fail; unavailable conversions remain unavailable.

Nutrient fixtures distinguish:

- `known` with a typed basis;
- `known_zero` with point/lower/upper all zero;
- `missing` with no numeric value;
- `not_applicable` with no numeric value;
- `estimated` with explicit bounds and AI source; and
- `legacy` copied-value provenance.

### Preparation, estimates, and constraints

- Raw-to-cooked is directional and reviewed-approximate; reverse conversion
  without an approved rule is unavailable.
- AI estimates carry uncertainty, correction lineage, and no retained image.
  Offline status is manual/unknown; unsupported model metadata is opaque and
  not executed.
- All eight constraint types are represented. Unknown composition yields
  `insufficient_information`; user override does not downgrade evidence.

### Legacy and backup compatibility

Fixtures preserve copied legacy food-log values, name-only meal templates,
custom-food provenance, and unknown legacy backup values. v5/v6/v7 inputs are
accepted as legacy-compatible examples with B03 sections absent; a future v8
fixture rejects before mutation. These are expected outcomes only—B03-01 does
not implement migration or backup code.

## Read-only food asset audit

Audit input paths:

- `assets/data/indian_foods.json`
- `assets/data/regional/bengali.json`
- `assets/data/regional/gujarati.json`
- `assets/data/regional/maharashtrian.json`
- `assets/data/regional/punjabi.json`
- `assets/data/regional/south_indian.json`

| Source | Rows | Unique normalized names | Stable IDs | Manifest gaps | Preparation/alias/source revision metadata |
|---|---:|---:|---:|---:|---|
| Base catalogue | 573 | 573 | 0 | 573 | absent |
| Bengali | 5 | 5 | 0 | 5 | absent |
| Gujarati | 5 | 5 | 0 | 5 | absent |
| Maharashtrian | 5 | 5 | 0 | 5 | absent |
| Punjabi | 5 | 5 | 0 | 5 | absent |
| South Indian | 5 | 5 | 0 | 5 | absent |
| **Total** | **598** | — | **0** | **598** | — |

The current audit finds five exact normalized overlaps between the base and
regional sources. They remain distinct source rows pending manifest review:

| Normalized name | Sources |
|---|---|
| `gujarati kadhi` | base, regional/gujarati |
| `sarson ka saag` | base, regional/punjabi |
| `dal makhani` | base, regional/punjabi |
| `masala dosa` | base, regional/south_indian |
| `tomato rasam` | base, regional/south_indian |

Every current row is exposed by the audit as `source#rowIndex`, original
display text, and narrow-normalized text. The source files themselves remain
unannotated: their inline stable-ID, preparation, alias, and source-revision
fields are absent. B03-03 maps all 598 rows in the external reviewed manifest
by explicit source key; the five cross-source overlaps remain distinct
identities. The audit does not promote names, Hindi labels, row order, or
current integer IDs to identity. Duplicate normalized names within one source
fail validation; cross-source overlaps are reported for manual review.

## B03-03 — Food identity boundary

The checked-in `assets/data/nutrition_food_identity_manifest.json` is the
runtime authority for the 598 bundled and regional catalogue rows. Manifest
version `1` uses the `global-durable-id-v1` namespace and carries 598 explicit
source-to-ID mappings, 598 source fingerprints, and 598 source review records.
Six catalogue rows have explicit evidence references and remain reviewed; 592
rows are visible `manualReview` suggestions until per-record evidence is
added. The current artifact contains 598 catalogue entries, 15 aliases, 600
legacy mappings, 8 fixture-only identities, 165 preparation variants, 25
regional variants, 108 serving-presentation variants, and 3 branded entries.

Maintenance generation requires the reviewed source mapping. Existing IDs are
selected by source key or by a fingerprint that excludes only the mutable
English display name; sorted position and insertion order are never identity
inputs. An unmapped source row fails visibly. A newly mapped row requires an
explicit portable ID and is emitted as `manualReview`/`unknown` unless a
source-review record explicitly supplies its kind, variant relationship,
classification, and evidence reason. Reviewed records additionally require a
non-empty `evidence_ref`; unsubstantiated classifications cannot be exposed as
reviewed production identity.

The validator atomically rejects duplicate IDs across entries, canonical
machine identifiers, aliases, legacy mappings, fixtures, fixture portable IDs,
and family identifiers; duplicate normalized canonical names; alias/variant
orphanage and cycles; unsupported versions/namespaces; and contradictory
source-review evidence. Exact reviewed aliases and explicit ambiguous generic
names remain separate from durable fuzzy/search suggestions. Custom, imported,
provider, AI-estimated, recipe, and unknown identities remain fixture-scoped
and are never attached by name.

The B03-03 maintenance tests cover cross-section collision rejection, atomic
loading, cosmetic rename and source reorder stability, explicit onboarding of
new earlier-sorting rows, missing review metadata, and rejection of heuristic
classification. This section is B03-03-owned; the B03-02 baseline harness has
its own dedicated section and remains independently mergeable.

## Review and change policy

Sol High must review the semantic fixture contract before B03-02, B03-03, or
B03-04 consume it. Any fixture change requires:

1. an explicit contract/reference ID and version decision;
2. deterministic stable IDs independent of entry order;
3. valid, invalid, and unknown coverage where applicable;
4. proof that missing is not zero and unresolved is not resolved;
5. updated focused tests and this audit artifact; and
6. a fresh Sol High focused review.

Deferred from B03-01: production schema/backup, food identity manifest
creation, repository/resolver/calculator behavior, seed rewrite, recipe or
thali implementation, AI integration, UI, migration, and any new catalogue
nutrition values.

## B03-02 immutable migration and backup baseline

B03-02 freezes the accepted B02 starting point without changing production
schema or backup versions. Tests copy these files to temporary paths; they do
not regenerate them from current seed logic:

| Fixture | Version | SHA-256 | Purpose |
|---|---:|---|---|
| `test/fixtures/data/b03_v16_legacy_baseline.db` | schema `16` | `27516799c7cfa9dba53a408c13a638fdb2be8bae32ee887fee2bf9f7ce147eb5` | Real on-disk legacy/custom/imported food-log and B02 baseline |
| `test/fixtures/data/b03_backup_v7_legacy_baseline.json` | Backup `7`, schema `16` | `16e486faf0abba0f4b075a928eab25f3fe9e651e68687a6f66da14b944daa3ae` | Real v7 compatibility and restore baseline |
| `test/fixtures/data/b03_v16_complete_graph.db` | schema `16` | `cee818f3502273e507d02670e3ecf084a3dd0528828e68e40d15cd88c645e550` | Complete non-empty B01/B02 relationship graph for durable-state comparison |
| `test/fixtures/data/b03_backup_v7_complete_graph.json` | Backup `7`, schema `16` | `02dc06612a6798ceec21efdc3bc9617a58e9e99af87b765ce11992b1aa51890a` | Complete v7 graph restore and local-ID remapping baseline |

The fixture IDs are `b03-v16-legacy-baseline-01` and
`b03-backup-v7-legacy-baseline-01`; the complete graph fixtures are identified
by their file names and checksums. The reusable harness captures durable
logical snapshots, foreign-key violations, file hashes, and typed,
stage-injected failures. No schema-v17 table, Backup-v8 field, B03 nutrition
entity, or historical reinterpretation is present.

### B03-02 remediation: supported failure boundaries and snapshot authority

The stage harness uses typed `B03FailureStage` values and records every stage
reached before injecting exactly one selected failure. The supported matrix is:

| Boundary | Injectable point | Rollback claim |
|---|---|---|
| Migration validation | Before the v15→v16 transaction begins | Zero mutation; original v15 file remains readable |
| Migration DDL/data mutation | After v16 DDL/backfill work inside the transaction | Full SQLite transaction rollback |
| Migration final transaction | Immediately before the migration transaction commits | Full rollback at the last testable pre-commit boundary |
| Backup relationship prevalidation | After v7 relationship validation and before preference/database mutation | Zero mutation |
| Backup database mutation | After restore deletion begins inside the transaction | Full SQLite transaction rollback |
| Preference write | After managed preference writes and before database mutation | Database remains unchanged; preferences compensated |
| Preference restore | After one compensation write while handling a deterministic database fault | Database rollback and documented recoverable partial-compensation state |
| Restore final transaction | Immediately before restore transaction commit | Full rollback at the last testable pre-commit boundary |

SQLite/Drift does not expose a callback after the physical `COMMIT`. The two
final-transaction rows intentionally document pre-commit coverage and do not
claim impossible post-commit injection. Retry tests disable the selected seam
and reuse the same fixture.

`B03LogicalSnapshot.capture` covers all 48 durable schema-v16 tables present in
the fixture, including the B01 program/occurrence graph, B02 session/set,
cardio/mobility, health, draft, muscle, and exercise-muscle mapping tables.
Rows are ordered by portable UUID/stable/source keys, compound relationship
keys, or persistent sequence fields; `rowid` is never used. The reusable
`logicallyEquals`/`assertLogicallyEquals` comparison omits only local integer
primary keys and replaces local foreign keys with semantic parent tokens.
Portable UUIDs, stable IDs, source identities, timestamps, values, unknown
fields, and relationship structure remain asserted. Thus a restored custom
food or session may receive a different local integer ID without producing a
false failure, while a broken relationship does fail.

The complete graph fixture contains non-empty rows for programs, occurrences,
groups, prescriptions, cardio intervals, mobility, performed sets,
legacy-routine relationships, hydration, achievements, preferences, and
exercise-muscle mappings. The original legacy baseline remains byte-for-byte
unchanged and is still used for compatibility-only assertions.
