# B05 — UI and Education: Implementation Plan

## Architecture

B05 is a presentation-and-content composition batch. It adds one durable M19
boundary and consumes existing domain authorities; widgets neither calculate
domain facts nor write Drift rows directly.

```text
B01/B02/B03/B04 repositories and read models
                  │
                  ▼
       feature controllers / presentation adapters
                  │                         ▲
                  │                         │
                  ▼                         │
 Today module descriptors ── preferences ───┘
                  │
                  ▼
          semantic components / routed screens

bundled content registry ──► content-progress repository ──► education UI
      (read-only)               (v19 / v10)       ▲
                                                   │
               B01 setup cues + B02 muscle taxonomy┘
```

- **Theme ownership:** `AppTheme` and the semantic extension own colors,
  typography, space, radii and state styles. Feature screens consume context
  tokens or shared primitives, never the fixed dark palette.
- **Today ownership:** a B05 descriptor registry defines stable module IDs and
  valid typed configurations; a B05 repository owns only user choice/order/
  visibility/size. `DashboardController` and B04/B03/B02 read boundaries keep
  domain data ownership.
- **Education ownership:** a bundled versioned content registry owns shipped
  text, checklist and media metadata. The v19 repository owns user progress;
  B01 owns personal cues and B02 owns muscle taxonomy. Missing/unknown content
  has an accessible unavailable state, not a generated substitute.
- **Navigation ownership:** GoRouter owns cross-feature destinations and
  restoration-safe route parameters. Local `Navigator` remains appropriate for
  dialogs, sheets and returning a transient result.

## Schema and backup decision

**B05 requires schema v19 and Backup v10.** The version increase is justified
by actual portable user-owned state, not by the batch number.

| Entity | Ownership and constraints | Migration / backup treatment |
|---|---|---|
| `dashboard_module_preferences` | Existing local profile scope; stable registered module ID; unique ordinal and module per owner; typed visibility, size and configuration only | Starts empty on v18→v19. Backup v10 includes it after the legacy/B03/B04 graphs. Unknown module IDs are retained as unavailable preferences, never instantiated blindly. |
| `education_content_progress` | Existing local profile scope; stable content ID plus immutable content version; explicit progress state and timestamps | Starts empty. Backup v10 preserves progress so a bundled revision can show its own completion state. An unavailable registry item remains hidden/unavailable rather than being invented. |
| `downloaded_media_manifests` | Existing local profile scope; verified asset ID/version/checksum/declared byte count and local availability state; no URI secrets, source image, raw payload or file-system path | Starts empty. Backup v10 preserves manifest intent/verification metadata only; it never embeds a media binary or triggers a restore download. |

Existing `ExerciseUserPreferences`, `ExerciseSetupValues` and
`ExercisePersonalCues` remain B01 tables and v6+ backup records. B05 must not
replace or recopy them.

Migration order is table creation, indexes/constraints, then no backfill. B05
has no historical domain fact to infer. Restore is one transaction after the
existing v9 graph: validate the full v10 graph before mutation, restore module
preferences, then content progress, then media manifests. Every migration or
restore failure rolls the database and preference mutation back together.

Backups v5–v9 import with an empty B05 graph; v10 round-trips the B05 graph.
Downgrading an app that does not understand v19/v10 cannot preserve B05 state
and is unsupported; users retain a v10 export before a downgrade. A later app
may retain a structurally valid unknown content/media record but must not render
or download it until its bundled registry recognizes it.

## Dependency DAG

```text
B05-01 ─┬─► B05-02 ─┬─► B05-04 ─┐
        │            ├─► B05-05 ─┼─► B05-07 ─► B05-08 ─► B05-09 ─► B05-10
        └─► B05-03 ─┘            │
                     B05-02 ─► B05-06 ────────────────────────────┘
```

`B05-09` depends on every B05-01 through B05-08 task. `B05-10` is the final
integrated review task and depends only on a clean, verified B05-09 integration
head.

## Execution waves

Each implementation task follows: implement → one fresh review-and-resolve
session → merge. At most two tasks are active at once, and parallel tasks begin
from the same approved integration baseline.

| Wave | Tasks | Why this is safe |
|---|---|---|
| 0 | B05-01 | Schema and backup are a central durable contract and must be serialized. |
| 1 | B05-02, B05-03 | Token primitives and the B05 module repository have no shared files or central controller. |
| 2 | B05-04, B05-05 | Today/navigation ownership and training/execution/progress presentation have separate feature files after Wave 1. |
| 3 | B05-06, B05-07 | Nutrition/settings/profile presentation and education/exercise-content work have separate feature ownership. B05-07 begins only after B05-05, which owns the surrounding player migration. |
| 4 | B05-08 | Onboarding touches the central route and integrates the merged content/Today contracts. |
| 5 | B05-09 | Release assurance observes all merged features and may create a scoped remediation task only for an actual defect. |
| 6 | B05-10 | Final fresh Sol review runs on a clean integrated head. |

Never parallelize a task that changes `app_database.dart`, a backup adapter,
the B05 module repository, `app_router.dart`, `DashboardScreen`/
`DashboardController`, or shared semantic primitives with another task touching
the same owner.

## Integration sequence

1. Merge B05-01 and run migration/backup compatibility tests before exposing
   any B05 preference or content UI.
2. Merge B05-02 and B05-03, then use their accepted token/module APIs rather
   than copying constants into feature tasks.
3. Merge B05-04 before B05-08 because it owns the Today route/module
   composition. Merge B05-05 before B05-07 because it owns the general
   workout-player presentation boundary.
4. Merge B05-06 and B05-07 after focused UI/accessibility tests. They may be
   reviewed independently because their screen sets and repositories differ.
5. Merge onboarding only after its route/content dependencies are settled.
6. B05-09 runs release-focused verification on the current integration head;
   any concrete defect is fixed by a small reviewed remediation task before the
   final review. B05-10 does not absorb feature work.

## Model routing

| Task | Implementation model | Fresh review-and-resolve model | Reason |
|---|---|---|---|
| B05-01 | Sol High | Sol High | Schema/backup graph, compatibility and transactional safety. |
| B05-02 | Terra High | Terra High | Semantic system, responsive primitives and accessibility. |
| B05-03 | Luna | Terra High | Bounded repository/codec/fixtures with a production state-ownership review. |
| B05-04 | Terra High | Terra High | Today orchestration, navigation and multi-module UI. |
| B05-05 | Terra High | Terra High | Cross-screen production presentation and accessibility. |
| B05-06 | Terra High | Terra High | Nutrition/settings workflow integration and destructive-action UX. |
| B05-07 | Terra High | Terra High | Content/cue/muscle presentation across production education surfaces. |
| B05-08 | Terra High | Terra High | Router, onboarding state ownership and accessible multi-screen flow. |
| B05-09 | Sol High | Sol High | Privacy/platform/release boundary and cross-domain regressions. |
| B05-10 | Sol High | Sol High | Final integrated code and launch-critical review. |

## Conditional media gate

The mandatory B05 DAG ships bundled text/checklists and an asset-manifest seam,
not unlicensed media. The following require a product-owner decision and a
separate, appended task/DAG before implementation:

- source/licence/commissioning authority for animation and anatomy assets;
- optional-pack distribution, storage limit, update/removal and pricing model;
- playlist provider, URL allowlist and disclosure behavior.

Until then, a missing media asset is explicitly unavailable, the checklist/text
fallback stays available offline, and no network access is required for a core
education journey.
