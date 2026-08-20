# IndiFit Third-Party Assets and Provenance Register

**Status:** R08-0.1 foundation; no third-party exercise artwork or anatomy geometry is approved or vendored  
**Acquisition check:** 2026-08-20 UTC  
**Machine-readable authority:** `assets/third_party/asset_manifest.json`

This register explains the source, license, approval, and clean-room boundaries represented by the checked-in B05-compatible manifest. It is an engineering provenance record, not legal advice or a declaration that unresolved redistribution questions are settled.

## Authority and workflow

The JSON manifest is the single source-controlled provenance authority. A later B05 runtime media manifest may be generated from or validated against it; it must not become an independently edited source of licensing, approval, or canonical exercise bindings.

The manifest currently contains source records and **zero asset rows**. An upstream repository being open source or pinned does not approve any media. Future asset rows require exact source paths, local destinations, SHA-256 values computed from acquired bytes, media roles, modification state, approval records, and exact canonical UUID bindings where applicable.

Approval states are deliberately separate:

- **production candidate:** a pinned source whose specific files may be considered after the applicable R08 approval gate;
- **reference / QA only:** facts or visuals may be inspected, but no content enters production under the current decision;
- **prohibited production content:** content that must not enter IndiFit under the current boundary.

## User-visible RepDB attribution contract

If and only if approved RepDB free-tier content ships, the About/Credits surface must include a visible link with this exact text:

> Exercise data by RepDB (repdb.co)

Link target: <https://repdb.co>

R08G owns final Settings/About placement. R08-0.1 defines the contract only.

## Production candidate sources

### RepDB exercise dataset free tier

- **Repository:** <https://github.com/RepDB/exercise-dataset>
- **Immutable commit:** `045845b61e4aefd9e684fa84518b84c665ea3cd3`
- **Tag/release:** none used; the commit is authoritative
- **Acquired:** `2026-08-20T05:54:28Z`
- **Source code license:** MIT, limited by upstream to its viewer/example code; vendored at `LICENSES/RepDB-LICENSE-CODE-MIT.txt`
- **Data/content/media license:** RepDB Free Tier License v1.0; vendored at `LICENSES/RepDB-LICENSE-DATA-v1.0.md`
- **Required attribution:** exact visible link defined above
- **Permitted:** personal/commercial use inside applications; approved images may be resized, cropped, or recolored for in-app use
- **Prohibited:** redistribution/repackaging as a dataset, repository, or API; generative-model input/reference/conditioning/training; production use of paid-tier preview animations
- **Redistribution constraint:** the grant says in-app use and prohibits dataset redistribution. Whether RepDB artwork may be committed to a public IndiFit source repository is **unresolved**. Do not vendor artwork until the licensor or qualified legal review confirms the intended distribution path, or an approved private acquisition/build path is used.
- **Modification constraint:** allowed in-app resizing/cropping/recoloring does not relax redistribution restrictions; every modification must be recorded deterministically
- **IndiFit intended use:** manually approved local movement illustrations only; metadata remains enrichment/QA and never overrides canonical exercise identity or taxonomy
- **Current approval:** pinned candidate; no assets or mappings approved

### MuscleMap

- **Repository:** <https://github.com/melihcolpan/MuscleMap>
- **Immutable commit:** `7dc03071e03052e8bd4f6351e9176994cd28aa7d`
- **Tag/release:** `1.6.4`
- **Acquired:** `2026-08-20T05:54:28Z`
- **Source code license:** MIT; vendored at `LICENSES/MuscleMap-MIT.txt`
- **Geometry/content license:** MIT at the pinned repository state
- **Required attribution/notice:** preserve the MIT copyright and permission notice in copies or substantial portions; the future credits model may identify MuscleMap and its repository
- **Permitted:** use and modification under MIT terms
- **Prohibited:** geometry import before file-level path provenance review; external taxonomy controlling B02 or catalog classification
- **Redistribution constraint:** retain the MIT notice
- **Modification constraint:** record exact source files plus every conversion/port transformation
- **IndiFit intended use:** candidate primary geometry source for the future local Flutter renderer under B05
- **Current approval:** pinned candidate; no geometry imported or approved

## Reference / QA-only sources

### Anatome

- **Repository:** <https://github.com/Rippy1911/anatome>
- **Immutable commit:** `ea36eedbc0a65d4576d1ef10abd42af3c407f11e`
- **Acquired:** `2026-08-20T05:54:28Z`
- **Source code license:** Apache-2.0; self-hostable
- **Content licenses:** anatomy SVG paths attributed upstream to MIT `react-native-body-highlighter`; exercise metadata attributed to Unlicense `free-exercise-db`; proxied exercise photography is explicitly described by upstream as unverified and not cleared for redistribution/commercial use
- **Attribution:** upstream says “Anatome by NextSolutions” is appreciated, not required
- **Permitted:** reference anatomy-rendering and taxonomy behavior during QA
- **Prohibited:** runtime dependency for R08; importing or redistributing proxied exercise photography
- **IndiFit intended use/current approval:** reference/QA only; exercise imagery prohibited

### react-native-body-highlighter

- **Repository:** <https://github.com/HichamELBSI/react-native-body-highlighter>
- **Immutable commit:** `15df9e2dbc621450001960bed5a30e6a75357faa`
- **Acquired:** `2026-08-20T05:54:28Z`
- **Source/geometry license:** MIT, copyright ELABBASSI Hicham
- **Permitted:** independent geometry/taxonomy QA
- **Prohibited:** blending paths into production without separate file-level provenance and approval
- **IndiFit intended use/current approval:** reference/QA only; not the selected primary geometry source

### free-exercise-db

- **Repository:** <https://github.com/yuhonas/free-exercise-db>
- **Immutable commit:** `b0eed061e1c832b3ed815fbaa4b45b3cdc14df49`
- **Acquired:** `2026-08-20T05:54:28Z`
- **Code/metadata license:** repository README declares Unlicense/public-domain JSON metadata
- **Image license:** not independently cleared for IndiFit commercial redistribution; metadata dedication is not treated as proof of image provenance
- **Permitted:** alias/equipment metadata QA
- **Prohibited:** images and any external metadata override of canonical IndiFit data
- **IndiFit intended use/current approval:** metadata QA only; images prohibited

### Phosphor Icons for Flutter

- **Repository:** <https://github.com/phosphor-icons/flutter>
- **Immutable commit:** `290a73304d62a5b74af3dbb38121121b92b2dcc5`
- **Acquired:** `2026-08-20T05:54:28Z`
- **Source/icon license:** MIT
- **Permitted:** future selective use if a concrete semantic gap is approved
- **Prohibited in R08-0.1:** adding the dependency, importing glyphs, or migrating icons
- **IndiFit intended use/current approval:** future candidate only; not adopted

## Prohibited production content and clean-room boundaries

### openGym

- **Canonical repository URL:** <https://github.com/DuarteSantos8/openGym>
- **Immutable commit:** unavailable; `git ls-remote` returned repository-not-found on 2026-08-20, so no hash is invented
- **Last independently documented source license:** GNU AGPL-3.0
- **Exercise data/media:** separate upstream terms, not covered by openGym's AGPL license
- **Permitted:** high-level product-concept study only
- **Strict prohibition:** no AGPL source, copied functions, source snippets, converted code, implementation structure, or assets may enter IndiFit
- **Clean-room rule:** any similar feature is implemented independently from IndiFit's frozen requirements and canonical B01/B02 decisions. This register and the R08 decision memo—not openGym source—define the implementation boundary.
- **Current approval:** prohibited production content; reference only even while the repository is unavailable

### hasaneyldrm/exercises-dataset media

- **Repository:** <https://github.com/hasaneyldrm/exercises-dataset>
- **Immutable commit:** `7455efae41b330c265e7cd4b78dfa848e7ce5ebd`
- **Acquired:** `2026-08-20T05:54:28Z`
- **Code/text license:** MIT with an explicit media exception
- **Media license:** images/videos are identified as Gym visual content; the upstream license explicitly says cloning does not grant a downstream media license
- **Permitted:** metadata-structure QA only
- **Prohibited:** importing thumbnails, images, GIFs, videos, or derivatives
- **IndiFit intended use/current approval:** metadata reference only; all media prohibited

## Asset admission rules

A file may enter a managed production root only when all of these are true:

1. its source record is pinned to a full immutable commit;
2. its applicable code/data/content/media license is recorded, any vendored license file exists, and its byte-for-byte SHA-256 matches the manifest authority;
3. the source classification permits production candidacy;
4. the exact source ID/path and local destination are recorded;
5. SHA-256 is computed from the acquired local bytes;
6. its role is one of the allowlisted manifest roles;
7. all modifications are recorded;
8. its approval status is `production` with a non-empty approval record ID;
9. every exercise UUID binding exists in the canonical 140-entry catalog;
10. the validator finds no missing, duplicate, checksum-mismatched, or unmanifested file.

No checksum is recorded for a file that has not been acquired. Candidate mapping rows and repository metadata never bypass these rules.
