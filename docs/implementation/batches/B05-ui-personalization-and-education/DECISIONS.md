# B05 — UI, Personalization and Education: Decisions

## D01 — B05 is a consumer of B01–B04 domain authorities

**Decision:** B05 adds presentation adapters, content registries, preferences
and interaction affordances only. B01 schedule/execution, B02 activity/muscle,
B03 nutrition/constraints, and B04 goals/recommendations remain the only
owners of their facts and commands.

**Why:** The product needs a better daily surface, not another calculation
path. A dashboard value is safe only when it preserves the source authority’s
known/range/unavailable state.

**Implication:** Widgets cannot query Drift directly or calculate nutrition,
coaching, activity, or schedule state. Every new action calls its owning
repository/controller.

## D02 — Introduce one v19 migration and Backup v10 extension

**Decision:** B05 adds four portable metadata contracts:

1. dashboard module preference: stable module ID, ordinal, visible, collapsed,
   updated-at;
2. education content progress: stable content ID, version, explicit state,
   updated-at;
3. media-pack preference/identity: selected or requested pack ID, manifest
   identity, advisory last-known installed version, user download preference,
   user deletion choice, content acknowledgement and updated-at; and
4. playlist preference: allowlisted provider ID, validated playlist reference,
   optional display label, updated-at.

**Why:** These are user-owned choices/progress that must survive backup and
restore. Existing B01 exercise setup/personal-cue records already own their
state and must be reused.

**Implication:** Backup v10 contains no media bytes, local paths, actual
availability, verified-on-this-device state, temporary progress/cache status,
raw provider payload, telemetry, free-text prompts, OAuth/session/token data,
or second exercise preference aggregate. After restore, a local reconciler
derives available/absent/invalid from physical files on that device. v5–v9
imports produce safe empty B05 state.

## D03 — Stable dashboard descriptors own personalization

**Decision:** A single packaged registry defines stable dashboard module IDs,
default order, eligibility, labels and collapse capability. Users can reorder,
hide and collapse only those known modules; a customization UI has a
keyboard/screen-reader alternative to drag-and-drop.

**Why:** Stable identities make preferences portable, testable and safe when
modules evolve. They prevent persisted data from choosing arbitrary widgets.

**Implication:** The prior planning notion of module “size” is removed.
Unknown/deleted IDs never execute/render arbitrary behavior; they are safely
normalized by one exact algorithm: ignore unknown IDs; keep the first valid
duplicate; sort the remainder by stored ordinal then stable ID; append new
descriptors in registry-default order; apply defaults for missing visibility
and collapse; force non-collapsible modules open; and persist the normalized
result only after an explicit mutation or dedicated reconciliation step.

## D04 — Semantic tokens and an 8/10/12 radius scale are mandatory on B05 surfaces

**Decision:** Shared semantic light/dark tokens become the source for
background, surface, text, border, focus, disabled, status, action, meal and
media states. B05 uses 8 px, 10 px and 12 px radii, with fewer nested cards and
consistent type/spacing/icon rules.

**Why:** Themes/picker already exist, but broad direct palette use causes
inconsistent brightness, hierarchy and accessible states.

**Implication:** No new direct AppColors usage in B05-owned production
surfaces. This is a targeted migration, not a forced rework of every screen in
the repository.

## D05 — Accessibility and reduced motion are feature contracts, not final QA

**Decision:** Compact layouts, large text, labels/values/hints, logical focus
order, non-swipe equivalents, touch targets, non-color-only status and platform
reduced-motion behavior are acceptance criteria for every B05 surface.

**Why:** Motion, small-screen and assistive failures change whether the daily
product is usable; they cannot be repaired reliably after the interaction
model is fixed.

**Implication:** Animation/clip playback has still/text/checklist alternatives
and honors reduced-motion settings. Android/iOS state and action meaning remain
the same even where platform affordances differ.

## D06 — Today answers the four daily questions in a fixed conceptual order

**Decision:** Today’s default composition explicitly answers:

1. What should I do?
2. What should I eat?
3. How am I progressing?
4. What is my next action?

Users may customize order/visibility/collapse, but the default respects that
action-first structure and next action is a concrete accessible command/link.

**Why:** A generic dashboard obscures what matters now. The daily surface
should reduce decision effort without synthesizing facts.

**Implication:** B03 and B04 values arrive through their read models/controllers
with uncertainty preserved. Today does not become an alternate weekly report,
recommendation engine, or nutrition calculator.

## D07 — Swipe actions are repository-backed and undoable when destructive

**Decision:** Food entries receive edit, copy and delete actions; workout items
receive complete and skip actions. Each has a visible non-gesture alternative.
Destructive state changes expose a time-bounded, repository-supported undo and
handle failure/pending/duplicate input explicitly.

**Why:** Swipe is efficient only if it is recoverable and does not bypass
existing immutability, audit, safety or transaction guarantees.

**Implication:** No list-local removal, silent completion, or undocumented
inverse mutation. Food deletion may undo only through a B03-supported restore
or append-only correction. Workout complete/skip may undo only when B01 says
the inverse remains valid after any downstream execution event. If an existing
command cannot support safe undo, the UI uses a confirmation or omits the
destructive swipe rather than fabricating one.

## D08 — Educational content is versioned, offline and explicit

**Decision:** Package mini lessons for RPE, progressive overload, protein,
energy balance and recovery in a versioned registry. Exercise education layers
canonical catalogue cues, B01 personal cues, checklists and B02 primary/
secondary/stabilizing labels.

**Why:** Content needs predictable offline availability and portable user
completion without duplicating exercise or muscle facts.

**Implication:** Content completion is version-aware. Unknown B02 mappings
remain unknown. Personal cues remain visibly distinct from catalogue guidance.
Lessons, cues, checklists and muscle labels are independently shippable B05-07
content: a missing or invalid media pack never hides them or blocks a workout.

## D09 — Top-20 media and diagrams are required contracts with gated activation

**Decision:** B05 owns fail-closed infrastructure for bundled media, an
interactive diagram mapped to B02 muscle IDs with a labelled text equivalent,
and the privacy-minimal playlist launcher. Approved offline clips/animations
for exactly 20 stable exercise IDs and graphical diagram content may be
activated when the external approval packet is supplied. Managed remote
download lifecycle is a post-B05 follow-up, not a first-release requirement.

**Why:** The product explicitly requests it, while the audit found no current
asset rights, media manifest or diagram source authority.

**Implication:** B05-01 defines the registry/acceptance template without
waiting for final files. B05-08 software is complete when registries and
validators fail closed, missing content is truthfully unavailable, fallbacks
remain usable, and arbitrary providers or URLs cannot launch. Any later
activation requires product approval of IDs, source/license/attribution,
distribution/retention rights, package budget, checksums, diagram mapping and
fallback. It may never substitute copyrighted remote media, scraped assets or
a full catalogue rollout.

## D10 — Onboarding adapts to a declared goal and resumes state

**Decision:** A static content mapping selects goal-relevant lessons from the
user’s explicitly selected existing goal. Uncommitted answers use the current
bounded draft pattern; completed education uses B05 progress. Incomplete work
resumes and completed sections are skipped unless revisited intentionally.

**Why:** This teaches relevant concepts without forcing repetition or inferring
health, dietary, safety or coaching conditions.

**Implication:** Profile/routine writes remain in existing profile and wizard
authorities. No second onboarding/profile store or behavioral adaptation engine
is introduced.

## D11 — Playlist preference is a privacy-minimal external launcher

**Decision:** Persist an allowlisted provider ID and validated playlist
reference, then launch it through the existing external-launch mechanism from
relevant workout surfaces.

**Why:** Users need a quick launch, not account integration or in-app music.

**Implication:** The provider registry defines allowed URI schemes, HTTPS
hosts, path/identifier form, normalization, maximum length, disallowed query
parameters and platform fallback. Input is parsed into a typed provider
reference, normalized before persistence, and used to reconstruct an approved
launch URI. B05 stores no account, OAuth, token, catalog, playback state or
arbitrary URL. Invalid, unavailable-app, strict-offline and launch-failure
states stay editable and never block a workout.

## D12 — B05-10 owns integrated assurance and remediation

**Decision:** B05-10 is implementation-owned release assurance. It runs the
full automated matrix, Android/iOS build attempts, targeted performance checks,
nearby B01–B04 regressions and actual defect remediation to produce a clean
release candidate.

**Why:** B05 is the final planned batch and must prove its integrations on the
actual current head.

**Implication:** Missing credentials or physical devices are recorded as
external limitations unless a real defect is demonstrated. Secrets, signing
material and fabricated device evidence are prohibited.

## D13 — B05-11 is an independent read-only final disposition

**Decision:** B05-11 reviews the clean release candidate, inspects production
wiring and remaining risk, runs or verifies important gates, and records an
evidence-backed verdict. It does not modify application code.

**Why:** The final reviewer must not silently implement its own fixes while
issuing approval; B05-10 already owns integration remediation.

**Implication:** A concrete B05-11 blocker creates one scoped remediation
task/branch. That task fixes the defect, reruns affected checks, and returns to
a fresh B05-11 disposition.

## D14 — Solo-development exception defers external content activation

**Decision:** For the solo-development scope, B05-08 completion covers the
software infrastructure and truthful unavailable/fallback behavior. The final
approved 20-item media package, graphical diagram assets and optional enabled
playlist-provider defaults are deferred product-content inputs. B05-09 is not
blocked by their absence.

**Why:** These inputs do not exist in the repository and cannot be invented
without weakening the product, licensing or privacy contracts.

**Implication:** The absence of the packet is a non-blocking B05 follow-up
unless it exposes an actual runtime defect. When supplied later, every input
must still satisfy the exact stable-ID, source/license/attribution,
distribution-rights, checksum, package-budget, provider-allowlist,
reduced-motion, accessible-alternative, offline and privacy requirements. No
scraped media, copied anatomy artwork, arbitrary URL, unverified provider or
unapproved scheme may be used as a substitute.
