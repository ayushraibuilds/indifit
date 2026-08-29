# IndiFit R08 Agent Contract

This file defines the standing implementation/review rules for all remaining
R08 packages.

Package prompts define ONLY the task-specific delta. This contract applies
unless the package prompt explicitly overrides it.

---

## 1. Authority Order

When requirements conflict, use:

1. Canonical B01–B05 domain/product documentation
2. Frozen Product Audit
3. R08 final pre-implementation decision review
4. R08 Master Implementation Roadmap
5. Integrated implementation established by completed/frozen R08 packages
6. Package-specific task notes

Do not invent policy to resolve ambiguity.

If a material domain/product decision is genuinely undefined, report the
blocker instead of guessing.

---

## 2. Frozen Foundations

Completed/frozen packages must not be casually redesigned.

### R08A

R08A.1
- date-scoped nutrition-target authority

R08A.2
- Today/Training current-next workout authority

R08A.3
- workout lifecycle
- elapsed/resume
- persistence
- completion
- retry/idempotency

R08A.5
- guard precedence
- fail-closed state handling
- consumer-safe failure language

### R08B

R08B.1
- shared Planned/Quick execution shell

R08B.2
- compact editable set table
- stable set mutation identity

R08B.3
- evidence-backed previous performance
- safe prefill semantics

R08B.4
- canonical exercise replacement
- shared picker

R08B.5
- canonical advanced/group execution semantics
- execution progression

R08B.6
- rest authority
- session-wide wakelock ownership

R08B.7
- exact exercise-context/media identity
- approved visual fallback chain

R08B.8
- persisted workout review/completion evidence

Change these only when the current package exposes a concrete regression.

---

## 3. Product Principles

- One obvious primary action.
- Common actions must be fast.
- Complexity belongs underneath the interface.
- Results/actions first; explanation second.
- Visualize when faster than prose.
- Advanced controls use progressive disclosure.
- Recommendations are defaults, not commands.
- AI is an accelerator, never a dependency.
- Valid empty/rest/no-history states are not errors.
- Fail closed when authoritative state cannot be resolved.
- Do not expose internal implementation language.

---

## 4. Consumer Language

Normal product UI must not expose raw/internal terms such as:

- B01/B02/B03/B04/B05
- UUIDs
- repository/provider/controller
- Drift/SQLite/database terminology
- raw enums
- reason IDs
- stack traces
- exception class names
- persistence/internal lifecycle terminology

Developer diagnostics may remain technical.

Never make reassurance claims stronger than the actual persisted state.

---

## 5. Domain Guardrails

Do not add without explicit canonical authority:

- e1RM
- workout calorie estimates
- invented PR detection/celebration
- readiness/recovery numeric scores
- arbitrary training/quality/strain scores
- progression formulas
- fabricated exercise equivalence
- unsupported set/group techniques
- AI-generated canonical coaching facts

Historical evidence is not automatically a recommendation.

---

## 6. Exercise Identity / Media

Exercise identity is canonical UUID-based.

Do not use runtime:

- fuzzy matching
- name matching as identity
- RepDB family inference
- muscle similarity
- equipment similarity

as domain authority.

RepDB production/review media must follow the existing public-repository-safe
R08-0 provenance pipeline.

Do not commit raw RepDB WebPs or introduce unapproved external artwork.

Missing media must gracefully use the existing fallback chain.

---

## 7. Implementation Scope

Implement only the package requested.

Do not opportunistically implement future R08 packages.

Small prerequisite infrastructure is allowed when required, but document it.

Do not perform broad refactors unless necessary to remove a concrete duplicate
authority or correctness problem.

Prefer the smallest architecture that cleanly solves the package.

---

## 8. Review Policy

Each package gets:

IMPLEMENT
→ TARGETED VALIDATION
→ ONE FRESH REVIEW-AND-RESOLVE
→ COMMIT

Do not add another review cycle unless the reviewer identifies a genuine
unresolved blocker requiring different expertise.

Reviewer routing:

- canonical/domain/lifecycle correctness → Sol High
- complex IndiFit architecture → Luna Max
- visual/product UX → Terra Max
- bounded/mechanical work → Gemini Flash 3.7 High

Wave-end review handles holistic cross-package UX/integration.

---

## 9. Testing Policy

### Ordinary package

Run:

- new package tests
- directly affected regression suites
- relevant frozen-authority regressions
- `flutter analyze --no-pub`
- `git diff --check`

Do NOT run the full Flutter suite by default.

### Full serial suite required when

- database/schema/migration changed
- central routing infrastructure materially changed
- lifecycle/persistence authority changed
- broad shared domain infrastructure changed
- parallel batch is being integrated
- wave is being closed
- reviewer identifies unusually high regression risk

Otherwise defer the full suite to integration.

---

## 10. Git / Worktree Policy

Use isolated package branches/worktrees.

Do not modify the integration branch during implementation.

After PASS/PASS WITH FIXES:

1. inspect `git status --short`
2. inspect `git diff --check`
3. selectively stage reviewed package files
4. inspect `git diff --cached`
5. commit on the package branch

Never use indiscriminate staging when unrelated files may exist.

Do not modify the original dirty/root worktree.

---

## 11. Agent Commit Policy

A clean isolated package agent MAY commit after its single fresh review passes.

It must:

- stage only reviewed package files
- verify cached diff
- use the package's recommended commit message
- report the commit hash

It must NOT merge into the integration branch.

Integration remains a separate step.

---

## 12. Physical Devices / Screenshots

Agents do not perform physical-device testing.

Human device acceptance is deferred unless explicitly requested.

Do not require new manually captured screenshots for ordinary packages.

Use existing/generate-small focused widget/golden states where visual inspection
is useful.

Do not claim device-visible behavior unless it was actually rendered/tested.

---

## 13. Accessibility / Responsiveness

For changed consumer UI, test appropriate combinations of:

- narrow phone width
- normal phone width
- elevated text scale
- light/dark theme where relevant

Critical actions must:

- remain reachable
- have meaningful semantics
- not rely solely on color
- meet reasonable tap-target expectations

Avoid noisy live announcements, especially timers.

---

## 14. Completion Report

Return only:

VERDICT:
PASS / PASS WITH FIXES / BLOCKED

COMMIT:
<hash> or UNCOMMITTED

CHANGED:
- concise file/component groups

KEY DECISIONS:
- maximum 6 bullets

REVIEW FIXES:
- concise bullets, or none

VALIDATION:
- focused: <result>
- analyze: PASS/FAIL
- diff-check: PASS/FAIL
- full suite: <result or SKIPPED BY PACKAGE POLICY>

DEFERRED / INTEGRATION HOOK:
- only if applicable

BLOCKERS:
- none / exact blocker

Do not repeat the entire task specification in the completion report.

## 15.  Visual / screenshot evidence

For any visual/product package:

1. Read `docs/reference/ui/REFERENCE_GUIDE_UPDATED.md`.
2. Read the package's frozen R08 audit/roadmap findings.
3. Inspect all applicable screenshots under `docs/reference/ui/R08_baseline/<area>/`.
4. Treat those screenshots as pre-R08 audit evidence, not desired final designs.
5. Inspect the current integrated implementation/rendered state.
6. Use applicable competitor/legacy references only for presentation and interaction quality.

Screenshots never override canonical domain/persistence authorities.
