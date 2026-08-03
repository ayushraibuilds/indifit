# B03 Reviewed Food Identity Audit

Status: checked-in B03-03 fixture artifact
Manifest: `assets/data/nutrition_food_identity_manifest.json`
Manifest version: `1`
Normalization contract: `case-and-unicode-whitespace-v1`
Identity namespace: `global-durable-id-v1`

Manifest SHA-256: `f5f727eef95baa84ae6d26dc94ff16e9f54069c6f25f160e138154f9b3a80ef1`

This artifact records the reviewed identity boundary for the existing bundled
nutrition assets. The JSON manifest is authoritative for portable IDs. The
asset order, display label, and current Drift auto-increment ID are not
identity authorities.

## Coverage

| Measure | Count |
|---|---:|
| Bundled base asset rows | 573 |
| Regional asset rows | 25 |
| Reviewed catalogue entries | 598 |
| Total manifest entries, including one deprecated fixture identity | 599 |
| Canonical catalogue entries | 297 |
| Preparation variants | 165 |
| Regional variants | 25 |
| Serving-presentation variants | 108 |
| Branded catalogue entries | 3 |
| Restaurant estimate fixture identities | 1 |
| Homemade estimate fixture identities | 1 |
| Explicit aliases | 15 |
| Approved aliases | 6 |
| Explicit ambiguous aliases | 9 |
| Legacy mappings | 600 |
| Explicit source-to-ID mappings | 598 |
| Source content fingerprints | 598 |
| Explicit source review records | 598 |
| Ambiguous legacy/alias records | 10 |
| Unresolved legacy/unknown records | 2 |
| Deprecated identities | 1 |
| Records requiring manual review at this gate | 0 |

All 598 source rows have exactly one reviewed manifest entry and one explicit
legacy/source mapping. The five exact normalized cross-source overlaps remain
distinct identities:

- `gujarati kadhi`
- `sarson ka saag`
- `dal makhani`
- `masala dosa`
- `tomato rasam`

Where an overlap is materially the same label across packs, the regional entry
may have a reviewed `parent_id` relationship. That relationship is lineage
metadata only; it does not merge nutrient authority or rewrite existing logs.

## Stable identity contract

Each checked-in entry has an explicit portable `id`, `machine_id`, display
metadata, source key, source revision, lifecycle state, and variant metadata.
Catalogue IDs use the reviewed `food-seed-*` and `food-regional-*` values. They
are not generated at runtime, from a display label, from insertion order, or
from a database integer. A cosmetic display-name change retains the explicit
ID and source mapping. The maintenance generator resolves an existing row by
its explicit source key or by its reviewed content fingerprint; it never
assigns an ordinal. Source fingerprints exclude only the mutable English
display name, while retaining source/serving/nutrient evidence. New rows need
an explicit source-to-ID mapping and do not renumber existing rows.

All durable manifest IDs share `global-durable-id-v1`. Entry IDs, canonical
machine IDs, alias IDs, legacy mapping IDs, fixture IDs, fixture portable IDs,
and family IDs are checked as one collision namespace. A collision in any
section rejects the complete manifest before it can be exposed.

Every catalogue row also has an explicit source review record containing its
target ID, kind, classification, variant relationship, review state, source
fingerprint, and evidence reason. Missing review metadata produces an
`unknown`/`manualReview` record in maintenance output; name, directory, brand,
preparation, and regional heuristics cannot create a reviewed classification.
Deprecated identities remain resolvable and retain their IDs.

Fixture-only identities cover user-created, imported/provider, branded,
AI-estimate, restaurant-estimate, homemade-estimate, recipe, and unknown
records. User/provider/import/estimate identities are not auto-attached to a
catalogue entry. Provider namespace and external ID are retained separately
from display labels and local IDs.

## Alias and variant decisions

Durable resolution performs exact normalized lookup only. Normalization is
limited to case and Unicode whitespace. It does not remove punctuation, strip
preparation words, normalize brands or portions, fuzzy-match, or use
substring matching.

Approved aliases are explicit, reviewed, and one-to-one. They cover reviewed
spelling/transliteration cases such as `Masala Dosai` → the bundled `Masala
Dosa` identity. Generic names remain explicit ambiguous aliases and are not
selected automatically:

`Dal`, `Curry`, `Sabzi`, `Roti`, `Chapati`, `Biryani`, `Dosa`, `Chawal`, and
`Paneer Curry`.

Preparation, regional, branded, restaurant, homemade, and serving-presentation
variants remain distinct identities. Raw/cooked wording is not stripped and
does not create an implicit alias. A parent/family relationship is descriptive
lineage and does not imply identical nutrient facts.

## Legacy mapping boundary

The 573 base rows retain their current local insertion integer only as
compatibility evidence; it is never exported as portable identity. Regional
rows use explicit asset source keys without inventing local IDs. Reviewed exact
asset keys resolve to one manifest ID. A generic old display name and an
unknown old local record are represented as explicit ambiguous/unresolved
legacy mappings. No historical food-log row is changed by this artifact.

## Unsafe alias examples and unresolved work

The following are intentionally not automatic aliases: generic dish names,
names that require punctuation stripping, names that hide a preparation or
brand distinction, restaurant/home-made estimates, and equal-name provider
records. There are no catalogue rows marked `manualReview` in this checked-in
v1 fixture because all 598 source classifications have explicit review
records. A newly added source without that evidence is emitted as
`manualReview`/`unknown` and is included in the maintenance failure output.
The explicit ambiguous and unresolved records remain visible for future
Sol/food-catalogue review; they must not be resolved by fuzzy matching or by
current nutrient values.

## Validation and change review

Manifest loading validates the complete document before exposing it. It rejects
duplicate IDs/machine IDs, global cross-section durable-ID collisions,
duplicate canonical normalized names, alias collisions or orphan targets,
variant cycles and unknown parents, unsupported versions/normalization or
namespace contracts, unknown provenance/review values, duplicate legacy keys,
contradictory unresolved mappings, missing source-to-ID/fingerprint/review
evidence, provider identity gaps, and malformed fixture entries. Reordering
entries or source files does not alter source-key/fingerprint to ID
relationships.

Any manifest change requires:

1. An explicit version decision and review of portable IDs.
2. Updated source-key/legacy evidence and this audit count.
3. Runtime validator tests for aliases, variants, ambiguity, and coverage.
4. A migration/backup impact review before any canonical database write.

This B03-03 artifact does not change schema version, backup version, food-log
rows, provider synchronization, nutrient facts, recipes, conversions, or UI.
