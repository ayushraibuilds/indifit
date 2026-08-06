# B05 — UI and Education: Decisions

Only decisions that change implementation are recorded here. The task entries
are the primary delivery authority.

## B05-D01 — B05 owns E6, release-ready E7 and the E8 gate

- **Decision:** B05 implements the canonical E6/F5 work, the E7/F6 outcomes
  that can ship with bundled/verified content, M19, and the final E8 release
  gate. It is the final planned feature and launch-readiness batch.
- **Consequence:** B05 has one release-assurance task and one final review,
  rather than creating a new product domain or absorbing unrelated launch-plan
  debt.

## B05-D02 — M19 is schema v19 / Backup v10

- **Decision:** Create one v19 migration and one v10 backup extension for
  dashboard preferences, educational progress and optional-media manifests.
  Existing B01 exercise setup/cue rows remain untouched.
- **Consequence:** The migration starts new tables empty; v5–v9 imports supply
  an empty B05 graph; v10 restores atomically and never contains media bytes,
  local paths, secrets, prompts or raw provider payloads.

## B05-D03 — Presentation consumes, never recomputes, domain facts

- **Decision:** Today and education surfaces read B01–B04 repositories/read
  models through controllers/adapters. In particular, B03 is the nutrition
  history/totals authority and B04 remains the only recommendation authority.
- **Consequence:** Remove/contain direct dashboard totals calculations and
  legacy fallback authority. Unknown, range, permission and unavailable states
  render as supplied; B05 does not substitute an exact value.

## B05-D04 — Semantic tokens are the sole screen-level presentation authority

- **Decision:** Theme-level semantic tokens and shared primitives own light/dark
  surface, text, border, status, accent, typography, spacing, radius, focus and
  motion treatment. A screen may use a stable feature accent only through the
  semantic extension.
- **Consequence:** `AppColors` stays as palette input to the theme; feature
  screen references to fixed dark semantic colors are migrated. Token changes
  are snapshot/widget-tested in both brightness modes and at compact/large text
  sizes.

## B05-D05 — Dashboard customization is typed and stable

- **Decision:** Module IDs are registered code contracts. User preferences may
  change order, visibility, size and registered typed configuration; they may
  not create arbitrary module IDs, execute code, or change domain rules.
- **Consequence:** Default modules are deterministic, newly introduced modules
  can be added without erasing custom order, and a removed/unavailable module
  is retained safely but not instantiated. B04 cards remain B04 consumers.

## B05-D06 — Content is bundled and versioned; progress is user-owned

- **Decision:** Core lesson/checklist/cue text ships in a bundled registry with
  stable IDs and content versions. Completion is recorded against that version;
  a later revision never rewrites historical completion.
- **Consequence:** Screens can work offline, B01 personal cues overlay rather
  than replace catalogue cues, and B02 taxonomy powers muscle insight. Content
  selection may use explicit profile/progress/recommendation links but not infer
  health, dietary or medical state.

## B05-D07 — Media is optional and fails honestly

- **Decision:** The main DAG includes an asset-manifest verification seam and
  text/checklist fallback, but no unlicensed animation, anatomy or playlist
  content. Optional packs are disabled/unavailable until a product owner
  supplies licence/source/distribution decisions.
- **Consequence:** No media download or external URL is needed for core
  education. Strict offline mode blocks external media, and restore never
  initiates a download.

## B05-D08 — Route policy distinguishes durable navigation from local UI

- **Decision:** Cross-feature, deep-linkable destinations use GoRouter. Modal
  sheets, dialogs and transient return values may keep `Navigator`.
- **Consequence:** B05 replaces only the durable-route inconsistencies in the
  scoped Today/onboarding journeys; it does not introduce a high-risk global
  navigation rewrite.

## B05-D09 — Release evidence is honest and proportionate

- **Decision:** Each task gets focused tests, format, analysis and diff checks,
  then one fresh review-and-resolve. B05 ends with one fresh Sol review on a
  clean integration head. Device checks are recorded as performed, not assumed.
- **Consequence:** An actual migration, build, privacy, offline, safety,
  accessibility or runtime defect blocks completion. Missing historical review
  transcripts and unavailable physical-device checks are follow-ups unless they
  expose such a defect.
