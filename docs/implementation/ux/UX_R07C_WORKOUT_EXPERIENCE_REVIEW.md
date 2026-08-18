# UX-R07C Workout Experience Review

**Date:** 2026-08-13
**Branch:** `ux/r07c-workout-experience`
**Reviewed baseline:** `f1ceda8` (with `d6e42a0` verified as an ancestor)

## Outcome

The reviewed workout experience is release-buildable and the final serial test
suite passes. The changes preserve B01/B02 write authority and improve the
consumer-facing Training, player, review, Guide, and Performance surfaces.

The review intentionally did not modify user-owned reference captures, test
failure artifacts, or iOS signing configuration that were already dirty when
the work began.

## Findings resolved

| Finding | Resolution | Evidence |
| --- | --- | --- |
| Exercise history could rely on a display name and present inferred 1RM/chart data as if it were actual performance. | Added a B02 read repository that joins canonical performed exercises/sets by exact stable exercise ID, filters to strength evidence, and renders individual actual sessions and logged sets. The legacy name-only read remains an explicit fallback only where no stable ID is available. | `B02ExercisePerformanceReadRepository`; `ExerciseHistoryScreen`; exact-ID and prescribed-only tests. |
| The standard 390 pt player unnecessarily stacked Weight and Reps, making the primary logging task taller than needed. | The responsive field threshold now accounts for the screen padding: 390 pt at 1× keeps the two inputs together, while 320 pt and larger text scales stack safely. | Updated R07C player goldens and 320/390/430 × 1×/1.5×/2× × light/dark widget matrix. |
| Training could offer a new start/Quick path while a saved strength draft needed attention. Planned context was also too terse. | A saved draft makes Resume the sole dominant action. Planned Today surfaces now include concise initial prescriptions such as `Exercise 1 · 3 × 8–10`. | Training landing test and refreshed light/dark goldens. |
| Logged-set and summary wording did not consistently distinguish set identity, warm-ups, actual evidence, and targets. | Logged rows now use an explicit ordinal and warm-up label only when applicable. Summary targets use a clear `Target · …` label and are omitted when unavailable. | B02 player activity tests and R07C player tests. |
| The full Guide repeated catalogue guidance through manual sections and the shared education content. Removing scrolling to simplify it introduced a large-text overflow. | The full Guide now has one authoritative education panel; the generic checklist no longer repeats the first catalogue cue. The panel retains its own scroll safety for standalone usage, while the full-guide integration test opens the real sheet. | 2× accessibility/layout test, guide integration tests, and compact Guide golden. |
| The Wave 6 exercise-detail dark golden was stale after the R07C compact-detail redesign. | Reproduced the same 22.26% mismatch in a detached `f1ceda8` worktree, then regenerated the golden from the intended compact surface and visually inspected it. | `ux_w06_exercise_details_dark.png`; isolated golden passes after refresh. |

## Visual/product review

I visually inspected the regenerated 390 pt reference images for Quick and
planned player flows, empty Performance, Training, and dark exercise details.
The resulting hierarchy is compact: the set-entry controls stay adjacent at
normal phone width, planned context precedes entry without competing with it,
and the exercise detail makes Performance and Guide secondary but reachable.

Automated visual/layout coverage exercises the player at 320, 390, and 430 pt
widths; 1×, 1.5×, and 2× text; and light/dark themes. The compact 320 pt and
large-text cases deliberately stack controls rather than clip or overflow.

## Validation

| Check | Result |
| --- | --- |
| `flutter analyze` | Passed with no issues. |
| R07C/R04 golden refresh | `flutter test --update-goldens …` passed 21 tests. |
| B05 education integration and 2× layout test | Passed (including opening the actual full Guide). |
| Wave 6 exercise-detail dark golden refresh | Passed in isolation after baseline attribution. |
| Final serial suite: `flutter test --concurrency=1 --reporter compact` | Passed: **1,338 tests**, 0 failures. |
| Signed iOS Release build | Passed: `build/ios/iphoneos/Runner.app` (60.3 MB), automatically signed for team `KJT3K3UAT8`. |
| `git diff --check` | Passed. |

The full runner printed existing debug-test warnings (notably Drift's
multiple-database warning and caught rendering traces from a W02 test), but
the final test result was clean.

## Remaining limits and follow-up

- This review includes signed Release compilation but not hands-on runtime
  acceptance on a physical iPhone. A device pass should exercise Quick resume,
  planned launch, set logging, finish, and history after installing the build.
- Legacy history rows that lack stable exercise identity remain name-only
  fallback data. They are not mixed into canonical exact-ID performance.
- The iOS build warned that the GoogleMLKit dependency chain does not support
  arm64 for Apple Silicon iOS 26+ simulators. The signed device Release build
  itself succeeded; simulator compatibility is a separate dependency risk.

## Files introduced for this review

- `lib/data/repositories/b02_exercise_performance_read_repository.dart`
- `test/b02_exercise_performance_read_repository_test.dart`
- `docs/implementation/ux/UX_R07C_WORKOUT_EXPERIENCE_REVIEW.md`

No merge or remote push was performed.
