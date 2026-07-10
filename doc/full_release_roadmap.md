# IndiFit Release Readiness Roadmap (Phases 0 - 8)

This document maps out the complete, phased release readiness roadmap for the **IndiFit** app, incorporating current progress, resolved compile issues, and upcoming requirements to transition from a local sandbox to production launch.

---

## Phase 0: Restore A Green Baseline
Status: **COMPLETED**

- [x] **Import Resolution**: Fixed the dashboard screen's missing `providers.dart` import so `waterProvider` resolves cleanly.
- [x] **Dependency Check**: Added `crypto` and `encrypt` directly to `pubspec.yaml` rather than relying on unmanaged/transitive PointyCastle imports.
- [x] **Warning Cleanups**: Removed unused helper methods (e.g., `_buildMacroResult` in AI meal logger) and cleaned up type warnings.
- [x] **Baseline Validation**: Ensured that the compiler analyze checks (`flutter analyze`) and tests (`flutter test`) pass with zero errors.

---

## Phase 1: Make Personal Data Trustworthy
Status: **COMPLETED**

- [x] **Secure Cryptography (AES-GCM)**: Replaced weak custom XOR-streams with AES-GCM (authenticated encryption) using a key derived from a user-supplied password via **PBKDF2** (10,000 iterations). Nonces/salts are generated randomly per backup.
- [x] **Save to Files Sharing**: Integrated Flutter's system sharesheet (`share_plus` and `path_provider`) to allow standard file storage/exporting instead of clipboard-only sharing.
- [x] **Destructive Restore Safeguards**: Reordered database wiping commands in a child-first order (e.g., deleting `workoutSets` and `foodLogs` before parent `workoutSessions` and `foodItems`) to prevent foreign-key constraint violations. Added a prominent red warning dialog before wipes.
- [x] **Backup Metadata & Restore Preview**: Added pre-decryption checking, wrong-password/corruption alerts, backup metadata parsing (version, creation date), and database record counts in a detailed **Restore Preview** modal.
- [x] **Data Controls & Privacy Disclosures**: Implemented options to export, restore, wipe all local data, and reset onboarding. Added a detailed privacy disclaimer card explaining local storage versus cloud sync.
- [x] **Platform Disclosures**: Clearly labelled health syncing as a simulated sandbox flow and disabled native triggers when sandbox mode is off to manage user trust honestly.

---

## Phase 2: Make Daily Logging Effortless
Status: **PARTIALLY COMPLETED**

- [ ] **Meal Grouping abstraction**: Introduce a first-class `Meal` grouping database model or identifier so "Repeat Last Meal" repeats one specific meal occurrence rather than every same-type meal logged on that day.
- [x] **Prefilled Active Workouts**: Changed "Repeat Last Workout" to launch the workout player pre-filled with the last session's exercises and sets, allowing editing before saving.
- [x] **Shared Hydration State**: Linked water goal updates and resets using the Riverpod `waterProvider` notifier to guarantee immediate multi-screen refreshes (dashboard and settings).
- [ ] **Hydration UX Refinements**: 
  - [ ] Add a quick decrement button (-250ml).
  - [ ] Support custom serving sizes.
  - [ ] Render a visible goal-progress ring.
- [ ] **Shortcut Additions**: Add "recent foods", favourites, custom recipes, and repeat-last meal shortcuts to bring logging time under 15 seconds.

---

## Phase 3: Make Training Genuinely Useful
Status: **NOT STARTED**

- [ ] **Progressive Overload Guidance**: Plot exercise logs over time showing previous best set details, estimated 1RM trends, total volume, and suggested next-set weight.
- [ ] **Set Customization**: Support RPE (Rate of Perceived Exertion) / RIR (Reps in Reserve), warm-up sets, customizable rest timers, and exercise substitutions.
- [ ] **Active Workout Drafts**: Maintain state for interrupted workouts, auto-persisting set records immediately and prompting confirmations before discarding drafts.
- [ ] **Library Enhancements**: Add custom exercise library entries, routine builders, cues, alternatives, and offline-safe instruction media.

---

## Phase 4: Make Nutrition Dependable
Status: **PARTIALLY COMPLETED**

- [ ] **Dataset Audit**: Audit the 413 auto-seeded Indian food items for household serving measures and calorie/macro accuracy.
- [ ] **Search Enhancements**: Add debouncing to food search text inputs and clearly segment local database, barcode scans, and online result feeds.
- [x] **AI Verification step**: Re-labeled AI estimate outputs as "Live AI estimate" or "Offline estimate" without misleading confidence qualifiers. Allowed users to edit portions, macro counts, and times before logging.

---

## Phase 5: Polish The UI
Status: **NOT STARTED**

- [ ] **Multi-device Layout Audit**: Standardize padding, component border radiuses, and spacing targets across 320px, 360px, 390px, tablet layouts, and landscape modes.
- [ ] **Today Workflow**: Consolidate daily food logs, water, workouts, and quick-track cards into a unified, clean central dashboard.
- [ ] **A11y (Accessibility)**: Ensure 44px minimum tap targets, screen-reader support, semantic labels, dynamic text scaling, and keyboard-safe inputs.
- [ ] **Skeletons**: Replace generic loaders with contextual loading skeletons.

---

## Phase 6: Production Backend And Sync
Status: **NOT STARTED**

- [ ] **FastAPI Backend Deployment**: Host FastAPI endpoints behind HTTPS with environment-managed database credentials.
- [ ] **Identity & Rate Limits**: Require active user credentials for sync and AI endpoints. Set strict rate limits and request size constraints.
- [ ] **UUID Sync Resolution**: Replace local autoincrement IDs with client-generated UUID keys to prevent synchronization conflicts.
- [ ] **Supabase Sync Policies**: Establish Supabase Row-Level Security (RLS) rules, conflict resolution routines, and sync progress bars.

---

## Phase 7: Real Platform Integrations
Status: **NOT STARTED**

- [ ] **Native Health Integrations**: Write production integrations for iOS HealthKit and Android Health Connect to import steps, active cals, weight, and workouts.
- [ ] **Permissions & Hardware**: Implement just-in-time permission prompts for camera access, photo libraries, and notification channels.
- [ ] **Device Robustness**: Verify persistence across timezone shifts, system restarts, and OS battery-optimization events.

---

## Phase 8: Beta And Launch
Status: **NOT STARTED**

- [ ] **Targeted Test Coverage**: Write widget and integration tests covering backups, midnight water resets, repeated meals, repeated workouts, and DB migrations.
- [ ] **Closed Beta Trial**: Execute a 7-day trial followed by a 10–20 person private test group.
- [ ] **Telemetry & Store Prep**: Configure privacy-preserving crash reporting, draft privacy statements, capture store screenshots, and organize release stages.
