# Food catalogue pipeline (CAT-5, CAT-6)

Builds the versioned catalogue packs the app imports
([NUTRITION_CATALOGUE_PACKS_PLAN.md](../../docs/implementation/NUTRITION_CATALOGUE_PACKS_PLAN.md) § 4–5).

```
sources/      inputs; each has a SOURCE.md (licence, URL, date)
overlays/     curated corrections in YAML, applied in file order to every
              pack version at or above their `version`
build.py      sources + overlays -> packs/ and assets/catalog/
validate.py   the invariants; exits 1 on any violation (CI, static job)
packs/        build output, committed: deploy this directory as /catalog/v1/
spotcheck_50.csv  50 random active foods to check against a reference
tests/        python3 -m unittest discover -s tool/catalog/tests
```

Needs Python 3.10+ and PyYAML (`pip install pyyaml`).

## Change the catalogue

1. Edit or add an overlay. Never change or reuse an id; retire instead.
2. If the change is a new pack version, bump `LATEST` in `build.py` and give
   the overlay that `version`.
3. `python3 tool/catalog/build.py`, then `python3 tool/catalog/validate.py`.
4. If the bundled pack changed, bump `kBundledCatalogPackVersion` in
   `lib/data/catalog/catalog_pack.dart`, and keep `kRetiredCatalogueFoods`,
   the identity manifest and `backend/routers/food.py` in line with the
   pack's `retire` list (tests check all three).

Pack 1 is frozen: `build.py` rebuilds it byte for byte, so its published
sha256 never changes.

## Outputs

| File | What |
|---|---|
| `packs/manifest.json` | Hosted manifest: latest version, full packs and deltas with sha256 |
| `packs/v{N}/{N}.json.gz` | Full pack N |
| `packs/v{N}/{N}-from-{N-1}.json.gz` | Delta from N-1 |
| `assets/catalog/pack-{N}.json.gz`, `manifest.json` | The pack bundled with the app |

Hosting (CAT-8) is owner work: publish `packs/` with `manifest.json` served
`Cache-Control: no-cache` and the packs `immutable`.

## See what the invariants catch on today's data

`python3 tool/catalog/validate.py --baseline` describes the catalogue as it
was before the overlay fixes and reports its violations. Today that is 101:
the 6 gram-as-katori rows and the 29 "Double serving/healthy bowl" and
"Small side bowl" rows of audit C-04, the 28 bare "(Double)" rows with the
same defect, the 37 templated variants the overlays retire, and the 25 g
roasted chana row a second time (its ratio is off as well as its amount).
