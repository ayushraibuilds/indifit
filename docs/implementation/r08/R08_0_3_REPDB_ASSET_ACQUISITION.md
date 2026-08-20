# R08-0.3 RepDB asset acquisition and exercise visual registry

R08-0.3 keeps the public repository free of raw RepDB WebP artwork. The
source-controlled authority is the single
`assets/third_party/asset_manifest.json` provenance manifest. It records the
human-approved asset sets, exact pinned source paths, explicit canonical UUID
bindings, roles, local destinations, checksums, approval records, and the
required movement-only technique disclosure. The file rows are approved for
the documented local/private acquisition path only; the RepDB source remains a
candidate for public-repository redistribution, so raw WebPs stay outside
Git.

The current human approval ledger derives 30 approved visual asset sets: 29
START/PEAK pairs and one MAIN-only Plank set. The acquisition plan derives its
file count from the manifest; it does not use a hard-coded business count.

## Public clone to local/private build preparation

1. Clone the pinned RepDB repository into a private build-preparation
   directory and check out the exact commit recorded in the manifest:

   ```text
   git clone https://github.com/RepDB/exercise-dataset /private/repdb/exercise-dataset
   git -C /private/repdb/exercise-dataset checkout --detach 045845b61e4aefd9e684fa84518b84c665ea3cd3
   ```

2. Run the acquisition tool with that checkout:

   ```text
   dart run tool/acquire_r08_repdb_assets.dart \
     --source-dir /private/repdb/exercise-dataset
   ```

   The tool verifies the checkout commit, selects only `production` RepDB
   entries from the provenance manifest, rejects premium/animation paths,
   copies only the exact source-relative files, verifies every SHA-256, and
   fails on missing, corrupt, duplicate, or unexpected image files.

   The CLI refuses an output path other than the managed
   `assets/generated/repdb/` directory. The lower-level testable runner may
   use a temporary directory for synthetic checksum tests, but the real
   acquisition command cannot redirect raw media into source or test trees.

   Without `--source-dir`, the tool downloads the exact pinned raw GitHub URLs
   derived from the manifest. `--dry-run` lists the selected files without
   writing them.

3. The generated files are written only to:

   `assets/generated/repdb/`

   Flutter bundles this directory after acquisition. A clean public clone has
   only the tracked directory sentinel and manifest; it remains a normal
   runtime state because `ExerciseVisual` falls through when a local file is
   absent or invalid.

4. Run the public-repository check before review or release preparation:

   ```text
   dart run tool/validate_r08_0_3_public_repo.dart
   ```

   Raw RepDB WebPs are narrowly ignored by `.gitignore` and must remain
   untracked. The check rejects any tracked WebP (including one copied into
   review artifacts, tests, or an unrelated directory) and verifies that a
   representative generated WebP path is ignored.

## Runtime and cleanup behavior

`ExerciseVisual` performs exact canonical UUID lookup only. A valid local
approved image is presented as a selected START, PEAK, or MAIN pose; poses are
not auto-looped. Missing or checksum-invalid local files fall through to the
canonical IndiFit muscle map, then the typed `IndiFitIcons` equipment/movement
symbol, then a neutral fallback. Unknown UUIDs and rejected families never
select a visually similar RepDB image.

The generated WebPs can be removed from the local preparation directory
without affecting canonical exercise identity, user data, database schema, or
history. After cleanup the same fallback chain is used. Release validation
should run the acquisition tool in strict mode before a build that expects
Tier-1 RepDB artwork.

The detail-surface API can expose the manifest's required disclosure:

> This illustration represents the underlying movement and equipment. It is
> not an exact demonstration of pause duration, tempo, or other IndiFit
> technique prescriptions. Follow the IndiFit cues and set prescription for
> technique details.

Attribution remains: **Exercise data by RepDB (repdb.co)**. This document does
not make a legal determination about public-repository redistribution; the
open licensing question remains whether RepDB explicitly permits these raw
artworks to be committed to a public source repository. R08-0.3 intentionally
avoids that distribution path.

## Size measurement

The acquisition command prints the exact acquired file count, total raw bytes,
minimum, median, p95, and maximum file size. These are measured only after a
local acquisition and must be recorded as facts for the release packet. This
implementation makes no decode-time, frame-rate, or device-memory claims.
