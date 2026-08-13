# UX-R07C Workout and Plan Reliability Gate

## Baseline

- Branch: `ux/r07c-reliability-gate`
- Starting commit: `57d8fca1c7ff13fb5cc52aaf794a672f87bf98cd`
- The starting commit is an ancestor of the working HEAD.
- User-owned iOS configuration, reference captures, and test failure artifacts remain out of scope.

## Investigation plan

1. Reproduce the physical Quick Workout flow against the canonical B02 repository: add the bundled Flat Barbell Bench Press identity, persist performed sets, finalize, read history, verify draft cleanup, and start a second same-day Quick Workout.
2. Exercise retry, duplicate Finish, resume/reconstruction, planned occurrence ancestry, and injected transaction failures without weakening B02 validation.
3. Trace template and generated-plan writes through legacy import compatibility into the single B01 activation coordinator. Verify graph materialization, replacement rules, idempotency, rollback, and Training/Calendar reads.
4. Determine whether program activation is independently defective or is being rejected because the failed workout leaves the canonical active draft intact.
5. Make only root-cause-driven lifecycle and recovery changes. Keep durable writes inside the existing B01/B02 transaction authorities and treat post-commit provider refresh separately from write failure.
6. Add privacy-safe debug diagnostics using operation category, canonical identifiers, command identifiers, state, and database exception metadata where available.
7. Run affected B01/B02/R7A/R7B/R7C tests, analysis, formatting, diff checks, the full serial suite, and a signed physical-device build/install.

## Reproduction and root causes

The physical symptom was represented at repository and widget boundaries. The exact Quick shape uses the bundled Flat Barbell Bench Press identity, canonical load basis, persisted working sets, history projection, draft cleanup, and a second same-day Quick start. It succeeds through the canonical B02 transaction. Injecting a SQLite failure during performed-set insertion proves that the session and performed graph roll back while the draft remains retryable.

The reliability defects were at lifecycle boundaries:

- Workout failure recovery displayed Retry but wired it to slot preparation. It did not retry finalization. The summary now retains the completion kind/reason and reuses its stable command ID for the same logical finish command.
- B02 finalization discarded the underlying exception at the controller boundary. Debug diagnostics now include the operation, draft/occurrence ID, command ID, completion kind, exception type, and underlying debug exception without exposing it to consumers.
- B01 activation intentionally rejects while any workout draft is active. A failed workout therefore explains the shared template/generated symptom: the preserved active draft blocks both flows, while their generic copy previously hid the causal action. Those surfaces now tell the consumer to finish or discard the workout.
- Template and generated retries previously saved a new legacy routine before retrying activation. They now retain the routine ID and activation command ID, so retry addresses the same B01 import version and cannot accumulate retry residue.
- Program review generated a new activation command per tap. It now keeps one command while activation inputs are unchanged.
- Navigation, success presentation, and generated-onboarding draft cleanup were inside write-failure `try` blocks. A failure after canonical commit could therefore be presented as a failed write. Those post-commit operations now occur outside the canonical write catch; cleanup failure is diagnostic-only and cannot reverse or misreport activation.

The original on-device database exception was not recoverable from the supplied screenshot because the baseline emitted only generic copy. Production-shaped canonical cases pass and the new diagnostics will preserve the exact category if a device-specific failure recurs.

## Transaction and lifecycle integrity

- B02 finalization validates first, then inserts the session and performed graph, completes planned occurrence ancestry when present, and removes the exact draft inside one Drift transaction. Failure at any mutation boundary rolls everything back; the same command deterministically resolves to the same session on replay.
- Quick sessions remain occurrence-less and distinct. Planned sessions retain their scheduled-occurrence and program-version ancestry.
- B01 activation validates and materializes occurrences/events, publishes the version, and updates the singleton active pointer inside one transaction. Injected occurrence failure leaves the version as a draft, creates no events/occurrences, and leaves the active pointer unchanged.
- Legacy routine creation and B01 draft synchronization may validly precede activation. A failed activation leaves that draft reviewable and retryable, not half-active.
- Existing replacement rules remain unchanged: the new version becomes current, and prior occurrences remain unless explicitly selected for cancellation.

## Files changed

- `lib/features/workout_player/b02_strength_summary_screen.dart`
- `lib/features/workout_player/b02_strength_execution_controller.dart`
- `lib/features/program_authoring/program_review_screen.dart`
- `lib/features/workout_player/routine_editor_screen.dart`
- `lib/features/onboarding/routine_wizard_screen.dart`
- `test/ux_r07c_reliability_gate_test.dart`
- `docs/implementation/ux/UX_R07C_RELIABILITY_GATE.md`

No schema, legacy authority, signing configuration, reference capture, or failure artifact was changed.

## Tests and validation

- New R07C suite: 9 passed. Covers Quick finalization, exact set attribution, replay/double Finish semantics, injected rollback/retry, reconstruction, planned ancestry, template/generated/manual shared activation, active-plan and Calendar reads, idempotency/no duplicates, activation rollback, and replacement rules.
- Focused B01/B02/R7A/R7B/onboarding matrix: 105 passed.
- Full serial Flutter suite: 1,328 passed (`flutter test --concurrency=1`).
- Repository-wide `flutter analyze`: no issues.
- Formatting and `git diff --check`: passed.

## Physical device

- Target discovered: Ayush's iPhone, iOS 26.2.1, device `00008120-000A5C383C7BA01E`.
- Signed Release build succeeded for `com.justdoit.indifit` with development team `KJT3K3UAT8`; artifact: `build/ios/iphoneos/Runner.app`, 60.3 MB.
- Release install succeeded and `devicectl` verified Indifit 1.0.0 (build 1) on the phone.
- Runtime workout/program exercises were explicitly skipped at the user's request. No claim of physical runtime acceptance is made.

## Remaining issues

- Physical runtime acceptance is deferred by request. If the original device-only failure recurs, the new `B02Finalization`, `ProgramActivation`, `TemplateActivation`, or `SuggestedRoutineActivation` diagnostic will retain its canonical IDs, command ID, and exception category.

## Commit

The final commit hash is reported in the handoff because a commit cannot contain its own resulting hash.
