# MuscleMap Geometry Provenance

This record covers the local geometry used by the R08-0.5 IndiFit muscle-map
renderer. It does not grant the upstream anatomy labels any authority over
IndiFit exercise identity or taxonomy.

## Upstream source

| Field | Value |
| --- | --- |
| Repository | https://github.com/melihcolpan/MuscleMap |
| Pinned commit | 7dc03071e03052e8bd4f6351e9176994cd28aa7d |
| Pinned tag | 1.6.4 |
| License | MIT |
| License notice | LICENSES/MuscleMap-MIT.txt |
| Runtime dependency | None; the Flutter app uses generated local Dart path data |

The source is used under the existing R08-0.1 third-party asset/provenance
framework. The upstream MIT notice is retained in the repository license
record. The repository's SwiftUI application code, view code, and runtime
parser are not copied into the Flutter app.

## Converted source groups

| Geometry group | Upstream source-relative file | Upstream region identifier | IndiFit local region identifier | Conversion | Modification status |
| --- | --- | --- | --- | --- | --- |
| Male front | Sources/MuscleMap/Data/MaleFrontPaths.swift | MaleFrontPaths.paths / each BodyPartPathData.slug | male_front_<slug> | common + left + right; relative and smooth path commands resolved; arc commands converted to cubic Béziers; raw coordinates retained against male-front view box (0,95,727,1280) | Modified mechanical port |
| Male back | Sources/MuscleMap/Data/MaleBackPaths.swift | MaleBackPaths.paths / each BodyPartPathData.slug | male_back_<slug> | common + left + right; same deterministic conversion against (718,95,727,1280) | Modified mechanical port |
| Female front | Sources/MuscleMap/Data/FemaleFrontPaths.swift | FemaleFrontPaths.paths / each BodyPartPathData.slug | female_front_<slug> | common + left + right; same deterministic conversion against (0,0,650,1450) | Modified mechanical port |
| Female back | Sources/MuscleMap/Data/FemaleBackPaths.swift | FemaleBackPaths.paths / each BodyPartPathData.slug | female_back_<slug> | common + left + right; same deterministic conversion against (823,0,650,1450) | Modified mechanical port |
| Shared model/view-box definitions | Sources/MuscleMap/Data/BodyPathData.swift | BodyPartPathData, BodyViewBox, BodyPathProvider | Registry model and view-box constants | Model consulted; only the needed data shape and four view boxes were reproduced locally | Adapted model, no application code |

The exact source paths and commit are also recorded in the generated header of
lib/features/media/indifit_muscle_map_geometry.g.dart.

## Converted local data

tool/convert_musclemap_geometry.py is development-only and accepts a local
copy of the pinned source tables. It performs no network access. The generated
registry contains:

- 86 local body/side/region entries;
- 361 upstream source subpaths;
- 4,445 resolved Flutter draw commands;
- no runtime SVG parser, hosted asset, or external API dependency.

The generated file is intentionally a mechanical data port. It does not
rename upstream slugs into B02 IDs and it does not create canonical exercise
or muscle identities.
