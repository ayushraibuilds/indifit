# R08E.3 — Today foundation

R08E.3 establishes the Today composition foundation only. It does not add a
new current-action resolver, nutrition target calculation, schedule scanner,
activity metric, progress engine, or customization policy.

## Authorities retained

- `todaySurfaceSnapshotProvider` remains the read boundary for the selected
  civil date.
- `NutritionTargetAuthority` remains the source for date-scoped nutrition
  targets. Today only presents the target already returned by that authority.
- `resolveTrainingNextAction` remains the shared Today/Training current/next
  decision. The foundation only changes where its presentation appears.
- `DashboardPersonalizationRepository` and its registry remain the persistence
  and normalization authority for user module order/visibility/collapse.
- `LocalScheduleDateService` and the existing `DashboardDateBar` remain the
  date selection/navigation authority.

## Foundation hierarchy

The default new-user order is:

1. Next up — the one current actionable state.
2. Nutrition — the existing factual daily summary.
3. Meals — direct meal rows and add actions.

Workout, Activity, and Progress remain registered and can be shown through
Customize Today, but are not default-visible. This keeps the common path from
rendering several equal-weight cards before the later E.4 conditional evidence
work is available. Existing saved layout choices remain untouched.

The default hierarchy is presentation-only. It does not change what a date,
workout occurrence, active draft, target, meal, or progress record means.

## Date context

The header now labels the selected date as `Today`, `Past day`, or `Upcoming`
alongside the full civil date. The existing compact date bar remains the
interactive navigation control and continues to pass the selected date through
the existing dashboard controller.

## Density and failure behavior

Module spacing is reduced modestly and optional default-hidden modules are not
mounted in the common path. Nutrition and meal rows retain their existing
facts and actions. Loading and unavailable primary states remain explicit and
consumer-safe; no provider/error terminology is shown.

## Deferred module hooks

E.4 can add conditional Next Up/Activity/Progress evidence behind the existing
registered module IDs and presentation models. E.5 can refine the nutrition
summary and Meal Ideas gating without moving the Today authority boundary.
E.6 and E.7 retain their later entry points; no empty placeholder cards are
introduced by this package.
