# UX-R7B fresh review and remediation plan

Status: implementation in progress

Reviewed target: `c0842b7ea607ae09174f54d2e6f9aaab53a44daa`

## Findings to resolve

1. Make the single active B02 draft discoverable from Training and Quick
   Workout so an unfinished unscheduled session can be resumed instead of
   blocking all new starts behind an opaque repository error.
2. Preserve real elapsed active time across player close, resume, summary and
   finalization. Do not report the draft service's one-second validity floor as
   the workout duration.
3. Persist kilogram input with an explicit canonical load basis when a Quick
   Workout has no prescribed target basis, while keeping target evidence
   separate from performed values.
4. Keep planned substitution identity stable across additional sets and
   resume. Prevent a late substitution from retroactively reattributing sets
   already recorded for the prescribed exercise.
5. Retain performed evidence when a Quick Workout exercise is removed, explain
   that behavior, and keep completion reachable when no selectable slots
   remain.
6. Harden Complete Set, rest adjustment, close, and finalization interactions
   against repeated input. A reduction past the rest deadline must complete the
   canonical period immediately.
7. Suppress initial Drift watch emissions in Training invalidation so active
   program refreshes do not create a provider restart loop.
8. Reproduce or safely classify the startup auto-backup exception. The backup
   path must remain read-only with respect to application data and fail before
   rotating the last good files.
9. Keep Open Food Facts degradation passive when local results exist and
   classify the verified upstream HTTP 503 separately from application health.

## Regression coverage

- Two standalone sessions on one local date remain separate and contribute to
  history/progress volume.
- Six ordered sets persist without overwrite, including decimal load, optional
  RPE and warm-up/working roles.
- Five different exercise instances plus an intentional duplicate survive
  save/resume/removal/finalization in deterministic order.
- Quick and planned draft resume preserve occurrence ancestry distinctions.
- Substitution ancestry and actual identity survive multiple sets and resume.
- Wall-clock rest remaining time covers background/resume, expired deadlines,
  `+15`, `-15`, immediate completion and skip.
- Group transition/round rest retains existing B02 semantics.
- Training invalidation ignores initial watch hydration but fires for active
  plan changes without duplicate subscriptions.
- Player active, rest and completion states render without overflow at compact
  width and large text; representative states receive golden coverage.
- Completion is idempotent and the resulting session appears in canonical
  history with performed values.

## Validation

Run focused R7B, B01, B02, B05, Progress and backup suites, followed by format,
analysis, diff checks, the complete serial Flutter suite, and a physical iOS
build/install. Preserve the user-owned iOS configuration, UI references and
failure artifacts throughout.
