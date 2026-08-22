# IndiFit R08 Agent Operating Contract & Execution Protocol

**Status:** **AUTHORITATIVE OPERATIONAL SPECIFICATION**  
**Effective Date:** 2026-08-22  
**Target Release:** IndiFit R08 Redesign Program  
**Authority:** IndiFit Engineering & Product Governance  

---

## 1. Purpose & Scope

This contract governs the behavior, standards, boundaries, and multi-agent coordination protocol for all AI coding agents, review subagents, and automated validation tools executing tasks in the **IndiFit R08 Master Implementation Roadmap**.

Every participating agent must adhere strictly to the rules, responsibilities, verification gates, and handoff protocols defined in this document without exception.

---

## 2. Source-of-Truth Hierarchy

When requirements, interpretations, or implementation details appear in tension, agents must resolve them strictly according to this descending hierarchy of authority:

```text
1. Canonical B01–B05 Domain Decisions, Database Contracts, & Persisted Schemas
     ↓
2. Frozen Product Audit & Redesign Reference Manual
     ↓
3. R08-0 Final Pre-Implementation Decision Review
     ↓
4. R08 Master Implementation Roadmap (R08_MASTER_IMPLEMENTATION_ROADMAP.md)
     ↓
5. Package / Wave Implementation Specs & Binding Approval Summaries
     ↓
6. Historical Spikes & Initial Candidate Evidence
```

> [!IMPORTANT]
> **Frozen Audit Integrity:** The frozen product audit is historical product evidence. Agents must never modify or rewrite historical audit observations. All dynamic progress, commit hashes, review decisions, and resolution states must be recorded in [`R08_AUDIT_TRACEABILITY.csv`](file:///Users/dankmagician/Documents/New%20project/indifit/docs/implementation/r08/R08_AUDIT_TRACEABILITY.csv).

---

## 3. Core Operating Principles & Non-Negotiable Guardrails

### 3.1 Zero Placeholder Tolerance
- **No Stubs:** Never write placeholder or incomplete code (`// TODO: implement`, `// ...`, temporary mock returns).
- **Production-Ready:** Every file edit, class, function, and test must be fully implemented, robust, and production-ready.

### 3.2 Type Safety & Language Precision
- **Strict Dart Typing:** All Dart code must be strongly typed. Prohibit `dynamic` unless interacting with untyped JSON primitives, and immediately cast/parse into immutable, type-safe data classes.
- **Explicit Generics:** Always supply explicit generic type parameters for collections, streams, providers, and futures.

### 3.3 Scope Containment
- **Strict Boundaries:** Implement only the exact scope defined by the active roadmap task.
- **No Preemptive Refactoring:** Do not modify downstream systems, unassigned feature folders, or unrelated tests ahead of their scheduled wave.
- **Dependency Hygiene:** Do not add external packages to `pubspec.yaml` without explicit roadmap authorization.

### 3.4 Data Authority & Offline-First Integrity
- **No Synthetic Authority:** Do not calculate or display synthetic estimates for workout calories, e1RM, recovery/readiness scores, or PR authority where untrusted.
- **Unknown is Not Zero:** Missing or unavailable historical data must render as neutral/unrecorded, never as misleading zeros.
- **Fail-Closed External Assets:** External visual assets fail closed. If an asset is missing, unapproved, or mismatched, the system falls back to canonical muscle diagrams and neutral text. Wrong artwork is strictly worse than no artwork.

### 3.5 Schema & Migration Safety
- **No Silent Migrations:** Schema changes must follow standard Drift versioning, accompanying migration tests, and Backup v9 graph verification.
- **Preserve User History:** History editing must never silently delete or corrupt logged workouts, nutritional entries, or personal records.

### 3.6 Consumer UI Terminology
- **Mask Internal Jargon:** Internal architectural codes (`B01`, `B02`, `B03`, `B04`, `B05`, `R08`, `UUID`, `DraftVersion`, `ActivationState`) must never be exposed in consumer-facing UI text, error dialogues, or accessibility labels.

---

## 4. Multi-Model Role Matrix & Pairing Model

To maintain maximum velocity while guaranteeing deterministic correctness, work is partitioned across specialized model profiles:

| Work Profile | Primary Implementer | Primary Fresh Reviewer | Escalation Authority |
|---|---|---|---|
| **Deterministic Data / Fixtures / Provenance / Tests** | Gemini Flash 3.7 High | Sol High | Human Product Owner |
| **Bounded Flutter Widgets / Components / Design System** | GLM 5.3 High | Terra Max | Sol High |
| **Complex Stateful UI / Multi-Screen Flows / Navigation** | GLM 5.3 Max | Sol High | Human Product Owner |
| **Deep Architecture / Domain Plumbing / Database Wiring** | Luna Max | Sol High / Terra Max | Human Product Owner |
| **Visual QA / Biomechanical Correctness / Contact Sheets** | Terra Max | Sol High | Human Product Owner |
| **Canonical Identity / Provenance / Life-Cycle Architecture** | Sol High | Terra Max | Human Product Owner |

---

## 5. Standard Task Lifecycle & Execution Protocol

Every task in the R08 roadmap must progress through five deterministic stages:

```text
[Stage 1: Context Ingestion]
        │
        ▼
[Stage 2: Implementation]
        │
        ▼
[Stage 3: Automated Verification]
        │
        ▼
[Stage 4: Fresh Review-and-Resolve]
        │
        ▼
[Stage 5: Traceability Ledger Update]
```

### Stage 1: Context Ingestion & Pre-Flight Check
1. Read the Roadmap task specification and referenced architectural audit documents.
2. Confirm the active working tree status and branch isolation.
3. Verify all necessary dependencies and fixtures exist before writing code.

### Stage 2: Implementation
1. Write type-safe, modular, and well-structured Flutter/Dart code.
2. Ensure rich, modern UI aesthetics adhering to the design system (curated color palettes, dark/light theme support, responsive 320–430px widths, dynamic animations, accessibility contrast).
3. Provide comprehensive documentation and maintain existing code comments.

### Stage 3: Automated Verification
1. Write and execute targeted unit, widget, and integration tests.
2. Run full regression suites across affected packages and prior waves.
3. Run `flutter analyze` to guarantee **0 warnings, 0 errors, and 0 lint issues**.

### Stage 4: Fresh Review-and-Resolve
1. Execute **one focused review-and-resolve pass** by the assigned reviewer model.
2. The reviewer inspects exact diffs, test coverage, fail-closed behaviors, and security boundaries.
3. Immediately resolve all valid reviewer findings in the same task lifecycle before handoff. Do not enter circular review loops.

### Stage 5: Traceability Ledger Update
1. Create isolated, semantic git commits following conventional commit syntax:
   - `feat(<scope>): <description> (R08-<task.id>)`
   - `fix(<scope>): <description> (R08-<task.id>)`
2. Update [`docs/implementation/r08/R08_AUDIT_TRACEABILITY.csv`](file:///Users/dankmagician/Documents/New%20project/indifit/docs/implementation/r08/R08_AUDIT_TRACEABILITY.csv) with:
   - `Status`: `IMPLEMENTED`
   - `Implementation_Commit`: Exact git hash
   - `Review_Model`: Reviewer model name
   - `Review_Commit`: Exact git hash
   - `Notes`: Critical architectural decisions or caveats.

---

## 6. Shared Hotspot Ownership & Concurrency Protocol

Certain modules are designated as **Critical Shared Hotspots**. Only one active task may modify a shared hotspot at any given time:

| Hotspot Area | Protected Paths | Write Authority Rule |
|---|---|---|
| **B05 Media Contracts & Registry** | `lib/features/media/`<br>`lib/core/fixtures/b05_*` | Strictly isolated to R08-0, R08-0.3, R08-0.5 |
| **Exercise Catalog & Identity** | `assets/data/exercises.json`<br>`lib/core/fixtures/exercise_identity_*` | 140 Golden UUIDs are immutable; no base keys |
| **Workout Player & Active State** | `lib/features/workout/`<br>`lib/data/database/tables/workout_*` | Managed exclusively under Wave R08B |
| **Nutrition Authority & Targets** | `lib/features/nutrition/`<br>`lib/features/food/` | Managed exclusively under Wave R08D / R08E |
| **Dependencies & Configuration** | `pubspec.yaml`<br>`assets/third_party/asset_manifest.json` | Requires provenance and manifest gate pass |

---

## 7. Mandatory Quality & Acceptance Gates

A task is considered complete and eligible for wave integration only when all of the following criteria are satisfied:

1. [x] **Full Feature Implementation:** All required behavior from the task specification is written and active.
2. [x] **Comprehensive Test Suite:** Targeted tests verify positive paths, edge cases, malformed data, and fail-closed fallbacks.
3. [x] **Zero Static Analysis Violations:** `flutter analyze` runs with 0 errors, warnings, or lint diagnostics.
4. [x] **Regression Cleanliness:** All existing B01–B05 tests and prior R08 wave suites pass without regression.
5. [x] **Review Passed:** The designated reviewer model has formally verified and accepted the implementation.
6. [x] **Ledger Synchronized:** Traceability ledger reflects the exact commit hash and review record.

---

## 8. Escalation Protocol

Agents must immediately halt execution and request Human Product Owner intervention under the following conditions:
- **Legal or License Ambiguity:** Any newly discovered third-party asset with unclear licensing or missing attribution.
- **Exercise Taxonomy Conflict:** An exercise mapping that cannot be truthfully reconciled with canonical biomechanics.
- **Breaking Schema Alterations:** Any scenario risking data loss or backward-incompatibility with persisted user data.
- **Underspecified Product Requirements:** Any feature where UI/UX intent is fundamentally ambiguous.

---

*This contract is binding across all R08 releases and remains active until final R08RC acceptance.*
