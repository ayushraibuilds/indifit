# B05 — UI, Personalization and Education: Implementation Plan

## Delivery contract

B05 is a focused presentation, personalization, and offline-content batch on
top of the stable B01–B04 domain model. It must not introduce a dashboard data
authority, alter domain algorithms, or turn widgets into nutrition/coaching
calculators. Every visible fact arrives through the established repository or
controller that owns it; B05 decides only how it is composed, labelled, and
acted upon.

The approved top-20 media/diagram package is a required B05 deliverable. Work
can start with its durable contract and text fallback, but the batch cannot be
complete until the asset/license gate in CHARTER.md is satisfied.

## Target architecture

~~~text
 B01 schedule/execution     B02 activity/muscles     B03 nutrition     B04 briefing/coaching
           │                         │                     │                    │
           └─────────────────────────┴──────────┬──────────┴────────────────────┘
                                                 ▼
                              feature controllers / presentation adapters
                                                 │
                 ┌──────────────────────────────┼─────────────────────────────┐
                 ▼                              ▼                             ▼
      Today module registry + prefs     Food/workout action surfaces   Exercise/onboarding surfaces
                 │                              │                             │
                 ▼                              ▼                             ▼
   v19 dashboard preferences       existing B03/B01 commands     versioned content registry
                                                                      │       │
                                              ┌───────────────────────┘       └───────────────────┐
                                              ▼                                                    ▼
                               v19 content progress / media manifest             approved top-20 media pack
                                                                                   + canonical B02 mappings

       v19 playlist preference ──► provider/reference validator ──► safe external launcher

        semantic tokens + responsive/a11y/reduced-motion primitives wrap every B05-owned surface
~~~

Widgets may select a declared module, invoke an existing command, or render a
typed state. They may not query Drift directly, reconstruct B03 totals,
calculate B04 advice, create a workout occurrence, or infer user health /
dietary conditions.

## Durable and packaged contracts

### One v19 migration and Backup v10 extension

| Contract | Minimum semantics | Restore/migration rule |
|---|---|---|
| Dashboard module preferences | One row per known stable module ID: ordinal, visible, collapsed, updated-at | Defaults are deterministic. Unknown/malformed rows never construct UI; restore validates IDs and normalizes collisions deterministically. |
| Education content progress | Stable content ID, content version, explicit state, updated-at | Completion is version-aware. New content revisions can intentionally request re-read while preserving historical completion. |
| Downloaded media manifests | Approved pack/asset IDs, version, checksum, availability, updated-at | Records package availability only. Restore never transports clips, local file paths, auth, or download bytes. A local reconciler verifies the pack after restore. |
| Workout playlist preference | Allowlisted provider ID, validated playlist reference, optional display label, updated-at | No OAuth/session data. Invalid or obsolete references render an editable unavailable state and cannot trigger a launch. |

The database has a single local user profile today, so preferences use the same
current local-profile ownership pattern as the existing app. If an existing
user/profile key is required by the database convention, use it consistently;
do not invent a parallel identity layer.

Backup v10 imports v5–v9 with safe empty B05 records. It validates all v10
records before transactional mutation, exports only portable metadata, and
retains the current all-or-nothing restore model. B05-01 owns all schema,
generated code, migration, backup adapter, fixtures, and documentation changes
that flow from this contract.

### Central registries, not user-provided behavior

The following registries are immutable packaged data/code and are the only
source of identifiers:

| Registry | Required contents | Safety rule |
|---|---|---|
| Dashboard descriptor registry | Stable module ID, default ordinal/visibility/collapse capability, accessibility label, eligibility/read adapter, customization label | Stored preferences select only known descriptors; they never name a widget/class or executable behavior. |
| Education registry | Stable lesson/checklist IDs, version, topic, body, relevance tags, completion policy, exercise linkage | The five lesson topics are exactly RPE, progressive overload, protein, energy balance, and recovery. |
| Top-20 media registry | Exact stable exercise ID, pack ID, media/checklist asset IDs, content version, checksum, source/license/attribution identifier, still/reduced-motion fallback | No item is published without approved rights and a verified checksum. |
| Muscle visual registry | Canonical B02 muscle IDs mapped to approved diagram regions/labels and text order | The diagram is a visual projection of B02 data; the accessible list is always available. |
| Playlist provider registry | Provider ID, allowed URI/deep-link/URL formats, display name, platform fallback | No arbitrary scheme/URL launch and no provider credential handling. |

### Media packaging and licensing flow

1. Product owner approves the exact 20 exercise IDs, rights/source terms,
   attribution, permitted derivative/use, and visual diagram source.
2. B05-01 records the signed-off manifest shape, package budget, checksum
   policy, optional-download/delete behavior, and offline/reduced-motion
   fallback.
3. B05-08 validates the delivered assets against that manifest, bundles the
   required offline core or installs a verified optional pack, and makes a
   text/list/still fallback available before playback.
4. On launch and after restore, the manifest reconciler distinguishes
   available, absent, invalid, and download-pending content without blocking
   exercise cues or workouts.

No unapproved YouTube/embed, scraped clip, copied anatomy art, remote
auto-fetch, or user-generated package can enter the core path. Optional
downloads are a convenience, never a prerequisite for checklists or coaching
cues, and must honor strict-offline mode.

## Presentation, accessibility, and platform contract

### Semantic design system

B05-02 adds semantic light/dark tokens for page/background/surface, text,
border, focus, disabled, status, action, meal category, and media states.
Shared components consume those tokens rather than hard-coded palette values.
The concrete radius scale is **8 px, 10 px, and 12 px**; use the smallest
appropriate scale and avoid decorative nested cards. Typography, spacing,
icon sizing, and touch-target rules become shared constraints.

The migration goal is no new direct AppColors use in B05-owned production
surfaces and targeted removal where B05 touches them. It is not a repository-
wide ban or a reason to re-style untouched screens.

### Responsive and assistive behavior

Every B05-owned interaction must:

- fit compact phone widths and at least 2× text scaling without clipped primary
  actions;
- expose semantic names, values, hints, selected/collapsed state, and
  non-color-only status meaning;
- use a logical focus/traversal order and a discoverable non-swipe equivalent;
- meet the shared minimum touch target and retain an operable action after
  scrolling/reflow;
- honor the platform reduced-motion preference: no required animation,
  autoplay, parallax, or motion-only state change; and
- preserve the same state model and action meaning on Android and iOS, while
  using platform-appropriate affordances where the framework supports them.

### Scoped modernization perimeter

Required migration surfaces are Today/dashboard customization, high-frequency
food log and Today meal sections, calendar/workout player actions, exercise
detail/education, adaptive onboarding, and settings needed for theme, media
and playlist preference. Other screens are touched only when a shared primitive
or confirmed B05 regression requires it.

## Feature designs

### Today as the daily action surface

Today’s default visible sequence must make these four prompts explicit:

1. **What should I do?** — next applicable B01 workout/activity action plus
   B04 briefing when available.
2. **What should I eat?** — B03 canonical daily food/totals/status and B04
   current-food interpretation where applicable.
3. **How am I progressing?** — existing B02 progress/activity and B04 review
   summaries, with unknown/range status preserved.
4. **What is my next action?** — one accessible, actionable deep link or
   command chosen from already-authoritative available actions.

The module registry handles default ordering, visibility, collapse behavior,
empty/unavailable states, customization UI, and stable analytics-free IDs.
The page is a consumer of B01–B04 outputs; no module makes a hidden second
call path for totals or recommendations.

### Personalization

Users can reorder known modules, hide a module, reveal it again, and collapse
it without losing its availability. The customization screen exposes a
keyboard/screen-reader equivalent to drag reorder. Restored or newly added
modules use deterministic defaults. The old “size” concept is explicitly out
of this batch because it was not requested and complicates the responsive
contract.

### Contextual swipe actions

Food rows offer labelled edit, copy, and delete actions. Workout-item rows
offer labelled complete and skip actions. Each action has a button/menu
equivalent. A mutation:

- invokes its B03 or B01 owner, not a widget-local list edit;
- disables/reconciles duplicate input while pending;
- presents success/failure honestly;
- provides an undo affordance for deletion or other destructive state change,
  using a repository-supported inverse/restore command; and
- never hides an irreversible/safety-sensitive operation behind a swipe.

### Education and exercise insight

The education registry provides the five named mini lessons offline, each with
versioned completion semantics. Exercise surfaces combine catalogue cues,
existing B01 personal cues, checklists, and B02 muscle mappings. The UI labels
primary, secondary, and stabilizing roles separately; it does not represent an
unknown mapping as zero contribution.

The top-20 approved media experience contains a reduced-motion still or
non-animated alternative, transcript/cue/checklist equivalent, optional
verified download behavior where approved, and an accessible diagram/list
toggle. The diagram has semantic region labels and is never the only way to
learn a muscle role.

### Goal-aware onboarding

Onboarding uses a declarative mapping from the user’s selected existing goal
to relevant lesson IDs. It saves uncommitted answers as a bounded local draft,
records declared educational completion in B05 content progress, resumes the
last incomplete eligible step, and skips previously completed sections unless
the user chooses to revisit them. Final profile/routine changes continue
through UserProfileNotifier, RoutineWizardScreen, and their current
authorities exactly once. No medical, dietary, readiness, or coaching inference
is introduced.

### Playlist launcher

Settings lets the user choose a provider from the packaged allowlist and enter
or select a validated playlist reference. Relevant workout surfaces show a
clear launch action only for a valid preference. The app opens the external
provider through the existing launcher mechanism and handles unavailable apps,
malformed references, strict-offline mode, and launch failure without blocking
the workout. It stores no provider sign-in/session/token and does not browse
or control third-party playback.

## Dependency graph and merge order

~~~text
B05-01 durable/content/media/playlist foundation
    ├── B05-02 semantic + a11y/reduced-motion primitives
    │     ├── B05-04 Today action surface
    │     ├── B05-05 workout interactions
    │     ├── B05-06 food interactions
    │     └── B05-07 lessons/cues/muscle labels
    ├── B05-03 module registry + personalization
    │     └── B05-04 Today action surface
    └── B05-07 lessons/cues/muscle labels

B05-05 + B05-07 + approved media/provider gate ──► B05-08 media, diagrams, playlist
B05-07 + B05-04 ─────────────────────────────────► B05-09 adaptive onboarding
B05-04…B05-09 ───────────────────────────────────► B05-10 E8 release assurance
B05-10 ──────────────────────────────────────────► B05-11 final Sol disposition
~~~

| Wave | Tasks | Merge / concurrency rule |
|---|---|---|
| 0 | B05-01 | Serial; sole writer of schema, backup, content contracts, and package gate. |
| 1 | B05-02, B05-03 | May run in parallel after B05-01 because theme primitives and module repository have disjoint ownership; serialize any shared app shell edit. |
| 2 | B05-04, B05-05 | May run in parallel after Wave 1. Today owns dashboard/controller files; workout owns calendar/player action files. |
| 3 | B05-06, B05-07 | May run in parallel after B05-02 and their prerequisites. Food owns food-log paths; education owns exercise/content paths. |
| 4 | B05-08, then B05-09 | Normally serial: B05-08 owns settings/playlist/exercise-media integration; B05-09 owns onboarding/router. Parallelize only if file ownership is confirmed disjoint after Wave 3. |
| 5 | B05-10 | Serial clean-integration verification/remediation only. |
| 6 | B05-11 | Serial final fresh review. |

Never run more than two implementation tasks concurrently. Schema/backup,
shared semantic primitives, app shell/router, dashboard controller, and
settings preference files have one explicit owner per wave.

## Task routing

| Task | Implementation model | Fresh reviewer | Why |
|---|---|---|---|
| B05-01 | Sol High | Sol High | Migration, backup, content contract, media/license boundary and privacy-sensitive preference data |
| B05-02 | Terra High | Terra High | Shared semantic/a11y foundation with focused static and widget checks |
| B05-03 | Luna High | Terra High | Bounded preference repository/registry work with independent validation |
| B05-04 | Terra High | Terra High | Cross-domain composition with strict authority boundaries |
| B05-05 | Terra High | Terra High | Workout gesture behavior and B01 command integration |
| B05-06 | Terra High | Terra High | Food gesture behavior, undo, and B03 safety presentation |
| B05-07 | Terra High | Terra High | Offline content/cue/muscle presentation |
| B05-08 | Sol High | Sol High | Asset verification, privacy, external launch and mandatory license gate |
| B05-09 | Terra High | Terra High | Goal-aware, resumable UI flow bounded by existing owners |
| B05-10 | Sol High | Sol High | Integrated E8 release evidence/remediation |
| B05-11 | Sol High | Sol High | Final production-wiring and launch-risk disposition |

## Non-negotiable integration checks

- Merge B05-01 only after direct v18→v19, supported chained migration,
  v5–v10 backup import/export, malformed payload, restore rollback, and
  no-media-binary tests pass.
- Merge a presentation task only after its compact, large-text, semantics,
  focus, touch target, light/dark and reduced-motion checks pass.
- Merge Today only after its four questions, module ordering/visibility/
  collapse, B03 known/range/unknown, B04 available/unavailable, and next-action
  tests prove it remains a consumer.
- Merge swipes only after action, cancellation, duplicate tap, repository
  failure, undo, assistive alternative, and strict-offline state tests pass.
- Merge B05-08 only with the approved manifest, verifiable licenses/checksums,
  all 20 selected IDs, diagram text equivalent, reduced-motion fallback,
  optional download lifecycle, and playlist launch failure/offline handling.
- Treat unavailable signing credentials or a physical device as an external
  limitation unless they expose an actual defect. Record the attempted command
  and result; never invent success.
