# R07F-2 Product Feel & Interaction Review

## Review state

- Branch: `ux/r07f-product-feel`
- Baseline: `7632481e58c0b2c104aaa2522e7250400d7b6aa4` — Merge R07F-1 training lifecycle
- Reviewed implementation: `4cddc6f5a5585deb3b99d5711f130669b02ce16d` — `ux(feel): implement R07F-2 product feel, haptics, and motion polish`
- Review-fix commit: `e822d8b` — `fix(r07f2): resolve product feel review findings`
- Review date: 2026-08-17

## Assessment

R07F-2 is clearly improved. Feedback remains tied to authoritative outcomes and adds concise confirmation to high-value actions without turning normal interaction into continuous tactile noise. The review deliberately left domain rules, quantities, targets, workout metrics, and lifecycle authority unchanged.

## Findings resolved

1. **P1 — confirmation timing and stale success feedback.** B02 summary finalization and rest-expiry completion could report success after a controller failure because their futures did not expose success. `finalize` and `completeRest` now return a success result; the presentation layer emits confirmation only after canonical persistence produces a successful authoritative state. The elapsed-rest guard remains in place, so repeated zero-value rebuilds do not repeat feedback.
2. **P1 — Saved Meal concurrent re-log and delete timing.** Rapid taps could begin two re-log attempts before the first asynchronous timezone lookup, and delete feedback occurred before deletion. Saved Meal actions now use synchronous in-flight guards. Re-log has one confirmation after its committed snapshot; deletion returns success before the warning feedback and subsequent reload. Cancelling or failing deletion produces no feedback.
3. **P2 — redundant/early selection feedback.** Food multi-select feedback now follows the actual local selection mutation. Progress range feedback occurs only when the selected range changes, not when the current range is tapped again. Start-rest and custom-rest no longer add feedback before their state transition; `-15`, `+15`, and Skip retain restrained selection feedback.
4. **P2 — animation accessibility.** The legacy calorie/macro painter is excluded from semantics while the stable outer semantic label exposes the final value. This prevents a screen reader from seeing intermediate animated values alongside the final state.
5. **P2 — haptic fail-safety and narrow Saved Meal layout.** The haptic test hook now sits inside the platform-safety boundary so it cannot throw into user interaction. Saved Meal popup labels flex and ellipsize at narrow widths, avoiding the exposed overflow.

## Haptic policy, timing, and duplication

`IndiFitHaptics` keeps selection for genuine selection/control changes, confirmation for successful commits, and warning for destructive confirmed actions. Its platform calls are best-effort and cannot block interaction. No new settings or domain machinery was introduced.

The active R07F-2 paths have no raw `HapticFeedback` plus `IndiFitHaptics` duplication: B02 set completion, rest completion/controls, Food Fast Add/multi-select, and Saved Meals use the centralized policy. Remaining raw calls are legacy paths outside this review scope and were not mechanically migrated.

Reviewed confirmation/warning actions follow the intended sequence: user action, in-flight guard, canonical mutation, authoritative success, feedback, then presentation/navigation. This covers Food Fast Add and batch finalize, Saved Meal re-log/delete, B02 set/rest and workout finalization, Training Finish/Leave, and weight logging. Failed validation, repository failures, cancellation, and duplicate taps do not produce success feedback.

## Motion, Today continuity, and accessibility

R07F-2 animations use `B05MotionPolicy`; reduced motion renders the final state immediately while preserving essential loading/progress behavior. No reviewed R07F-2 animation bypasses `disableAnimations`.

Today calorie and macro transitions are presentation-only. The `TweenAnimationBuilder` values use the current displayed value when an end value changes; first mount and remount settle at the current value rather than replaying from zero. Regression coverage verifies first render, forward update, remount, and reduced-motion behavior. Macro labels expose final canonical values only, while the painted interpolation is excluded from semantics. B03 arithmetic and over-target/zero-intake truthfulness are unchanged.

## Functional review

- **Food:** Fast Add remains finalize → confirmation → Undo. Multi-select finalizes atomically and gives one confirmation per successful batch; identities, quantities, dates, idempotency, and Undo/delete behavior remain canonical.
- **Saved Meals:** Fast re-log feedback follows the snapshot commit exactly once. Delete feedback follows success, not dialog acceptance; cancellation is silent. Recipe and Saved Meal domain state is untouched.
- **Training lifecycle:** Finish Plan and Leave Plan remain post-transaction feedback paths. Failure leaves canonical state visible and produces no false confirmation. The separate Training and routine-display entry points do not double-fire for one action.
- **Set completion and rest:** B02 validates and guards before persistence, then gives one confirmation after success. Completed-set and rest states remain static/clear rather than celebratory. Rest timing starts immediately from controller state; feedback does not affect start, adjustment, skip, expiry, pause/resume, or timer math. Expiry feedback is exactly once through the `_finishingElapsedRest` guard plus successful durable completion.
- **Workout completion:** Completion feedback follows finalization success only. The completion surface remains a simple canonical summary with no PR claim, e1RM, fabricated calorie metric, or confetti. Reopening historical summaries cannot replay feedback.
- **Progress:** Range selection feedback fires only for a changed range. Weight logging confirms only after persistence; direction is not treated as success or failure. No R07E chart or target semantics changed.

## Replay protection and performance

Provider rebuilds, tab/route returns, theme changes, text-scale changes, and historical re-entry do not create a new semantic event. Today renders its present value on construction; event feedback stays inside successful user-action handlers rather than rebuild listeners.

No persistent animation controller was added for Today. Its implicit transitions are bounded by the motion duration tokens. The rest ticker exists only while a rest period is active and is cancelled when rest ends or the widget disposes. No battery-use claim was made or measured.

## Canonical integrity

- **B01:** Finish/Leave lifecycle transaction semantics unchanged.
- **B02:** Set persistence, rest timing, loading, history, and workout truthfulness unchanged.
- **B03:** Logging quantities, arithmetic, search, and Saved Meal snapshots unchanged.
- **B04:** Target and weight semantics unchanged.

No animation or haptic participates in business logic, and no new PR, e1RM, or workout-calorie authority was introduced.

## Visual review and validation

Representative settled Today, workout player, workout completion, Saved Meals, and Progress states were inspected against current references. No intentional settled-state change required a golden update; unrelated pre-existing R07D golden changes were preserved.

- Focused R07F-2 test: `flutter test test/ux_r07f2_product_feel_test.dart --reporter compact` — 11 passed.
- Focused B02 timing tests: `flutter test test/b02_strength_execution_controller_test.dart test/b02_workout_preparation_integration_test.dart --reporter compact` — 7 passed.
- R07F-2 plus R07D Saved Meals regression: `flutter test test/ux_r07f2_product_feel_test.dart test/ux_r07d_recipes_saved_meals_test.dart --reporter compact` — 22 passed.
- Cross-feature R07F-2, B05/Today, R07D Food/Saved Meals, R07C, R07F-0, R07F-1, R07E, and B02 selection passed.
- Full serial suite: `flutter test -j 1 --reporter compact` — **1,438 passed, 0 failed, 0 skipped**.
- `dart format` — clean (12 review Dart files, 0 changed).
- `flutter analyze --no-pub` — clean.
- `git diff --check` — clean.
- iOS: `flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=test_key` — passed.

Physical-device testing was deferred and not attempted.
