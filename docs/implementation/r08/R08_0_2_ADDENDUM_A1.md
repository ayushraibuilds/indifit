# R08-0.2 Addendum A1 — three rejected families approved (13 Oct 2026)

The original review (R08_0_2_REPDB_MAPPING_APPROVALS.csv) is left unchanged as the historical record. The product owner later approved three of the five rejected families. Their manifest assets carry approval record `<original record>-A1`.

| Family | Decision | Basis |
|---|---|---|
| FAM-17 Seated Leg Curl | Exercise renamed **Lying Leg Curl** (same UUIDs) | The RepDB artwork shows a lying leg curl. The name and cues now match the picture instead of the picture being forced onto a seated exercise. |
| FAM-35 Hanging Leg Raise | Exercise renamed **Hanging Knee Raise** (same UUIDs) | The RepDB artwork shows a bent-knee raise. Cues changed from straight legs to bent knees. |
| FAM-19 Walking Lunges | Approved as is | One forward lunge step. The disclosure says walking repeats the step, alternating legs. |

Still rejected (no media, muscle-map fallback): FAM-03 Decline Hammer Strength Press (no candidate artwork) and FAM-18 Standing Calf Raise (artwork is a loaded machine; the catalogue exercise is bodyweight and is used by the home plans).

Old names stay resolvable through `approvedAliases`. Existing installs update the row in place because seeding matches on the stable ID.

Result: 65 files, 33 asset sets, 132 UUID bindings. Run `dart run tool/acquire_r08_repdb_assets.dart` to fetch the six new files; they are git-ignored like the rest.
