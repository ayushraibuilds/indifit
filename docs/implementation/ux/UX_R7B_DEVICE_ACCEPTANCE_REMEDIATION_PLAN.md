# UX-R7B Physical Device Acceptance Remediation Plan

## Scope

Resolve only the production defects reproduced during the R7B iPhone acceptance pass. Preserve the accepted B01/B02 execution, rest, persistence, ancestry, duration, and finalization behavior. Do not merge or broaden into R7C.

## Root-cause summary

1. Quick Workout attempts a new unscheduled draft without first reading the single active execution draft. The repository correctly rejects the conflict, but the screen prints the raw exception and offers no canonical resume/discard path.
2. Training's active-draft projection filters out scheduled drafts, and the completed-Today surface has no Quick Workout action even though unscheduled sessions remain valid after planned completion.
3. The retained routine display/editor routes expose storage-migration terminology when a scheduled plan is active instead of presenting consumer plan-management routes.
4. Calendar skip uses a default route-spanning snackbar, and skipped cards render a diagnostic unavailable-actions panel.
5. The iPhone search path reaches the provider but receives an HTTP bad response from the legacy full-text endpoint. The current Open Food Facts full-text service is the privacy-preserving Search-a-licious `POST /search` API.

## Implementation

- Add an active-draft preflight to Quick Workout with separate Quick/planned consumer recovery surfaces. Resume through the existing B02 recovery controller; discard through `StrengthExecutionCompatibilityAdapter.discardDraft`; guard discard/start against repeated taps; never expose domain exception text.
- Project every active canonical strength draft into Training. Keep resume first, and add an immediately reachable Quick Workout action to the completed-Today state.
- Adapt the old routine display/editor entry points for an active scheduled plan: show the plan name where available and offer Calendar and Change plan routes. Do not expose an end-plan action because no safe public deactivation command exists.
- Use a shared compact, floating, theme-aware undo snackbar. Clear feedback before workout-player navigation and remove the skipped-state diagnostic action panel.
- Move remote name search from legacy `GET /cgi/search.pl` to Search-a-licious `POST /search`, parse `hits`, keep the dedicated credential-free Dio client, and retain privacy-safe category/status/elapsed diagnostics without logging queries.

## Regression coverage

- Quick/planned conflict copy and actions; active plan without a draft; canonical discard followed by one new Quick draft; raw exception absence.
- Completed scheduled Today surface retains Quick Workout; existing same-day session identity coverage remains green.
- Active-plan display/editor contain no internal terminology and keep Calendar/Change plan reachable.
- Skip feedback is floating/theme-aware and cleared before player navigation; skipped cards remain quiet and distinct.
- Search-a-licious success parsing, HTTP failure, timeout, cancellation, stale-query suppression, and local-first fallback.
- Add one representative compact/dark golden for the conflict recovery surface and inspect it visually.

## Validation

Run Dart formatting, static analysis, diff checks, affected R7A/R7B/B01/B02/B03 suites, the full serial Flutter suite, then an iOS build/install using the physical-device configuration. Exercise only scenarios actually reachable on the phone and report all others as not tested.
