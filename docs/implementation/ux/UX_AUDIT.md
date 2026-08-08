# IndiFit UX Stabilization Audit

Status: canonical planning document; presentation and UX scope only

This audit is based on the physical-iPhone screenshots `IMG_1143.PNG` through
`IMG_1158.PNG` and a corresponding inspection of the production Flutter
widgets. It is a consumer-product audit, not an implementation-contract or
domain-authority verification exercise.

## Introductory contract

1. B01–B05 remain authoritative for domain behavior, calculations, gating,
   evidence, persistence, and mutation.
2. This audit governs presentation, interaction, accessibility, layout, copy,
   and UX composition only.
3. Old dashboard screenshots `IMG_1076.PNG` and `IMG_1077.PNG` are the primary
   historical visual references for visual confidence, personality,
   glanceability, and data density.
4. Those screenshots are visual references only. They must not be used to
   restore obsolete architecture, business logic, or data authorities.
5. The intended product character is calm, premium, athletic, modern,
   accessible, and consumer-facing.
6. Domain complexity must be translated through consumer presentation models
   before rendering. Raw IDs, reason codes, evidence payloads, exceptions, and
   rule metadata belong in logs or deliberate detail surfaces, not default UI.

No application code is changed by this document. A presentation adapter may
read an authoritative B01–B05 output and select truthful consumer copy; it may
not recalculate, infer, persist, or mutate domain behavior.

## Executive assessment

The captured build is not production-ready. The release-blocking risks are a
Flutter `DropdownButton` assertion, visible `RenderFlex` overflows, a
keyboard/focus lifecycle that blocks onboarding, an opaque-sheet composition
failure that exposes the underlying app, unstable text-field controllers in a
manual-log sheet, and light-mode navigation with insufficient contrast.

The most damaging product-level issue is not any single color choice. The app
frequently renders internal state as if it were consumer guidance, wraps status
cards inside bordered cards, and gives empty/loading/error states no clear next
action. Stabilization should therefore start with runtime safety and a shared
presentation/state layer before screen-by-screen visual polish.

## P0 — Runtime and layout defects

### P0.1 — Diet preference dropdown assertion

- **Screenshot/screen:** `IMG_1154.PNG`, Profile diet preference.
- **Production target:** [`ProfileScreen`](../../../lib/features/profile/profile_screen.dart:413), [`OnboardingScreen`](../../../lib/features/onboarding/onboarding_screen.dart:39), and the persisted profile read boundary.
- **Problem:** onboarding writes `non-veg`, while the Profile dropdown offers `non_veg`. Flutter asserts because the selected value does not match exactly one menu item.
- **User impact:** a production screen turns into a red Flutter error page.
- **Proposed experience:** add a UI-boundary `DietPreferenceOption` adapter that accepts legacy aliases, renders one valid option or a safe unselected state, and maps back through the existing profile authority. Do not change B01–B05 storage or business rules as part of the UI fix.
- **Affected shared primitive:** persisted-choice/display-value adapter.
- **Scope:** global for persisted enum-like choices; first migration is onboarding/profile.
- **Regression/widget/golden tests:** seed `veg`, `vegan`, `non-veg`, `non_veg`, and unknown values; assert a unique menu match and `tester.takeException() == null`; add profile light/dark goldens.

### P0.2 — Responsive form overflow in constraints and plate calculator

- **Screenshot/screen:** `IMG_1156.PNG`, Add dietary constraint; `IMG_1158.PNG`, Plate Calc.
- **Production target:** [`_AddConstraintDialog`](../../../lib/features/settings/nutrition_constraints_screen.dart:514), [`_buildPlateCalculatorTab`](../../../lib/features/exercise_library/exercise_history_screen.dart:374), and the duplicate plate-calculator sheet.
- **Problem:** fixed horizontal field groups, long labels, dropdown values, and dialog sizing produce visible `RIGHT OVERFLOWED` stripes.
- **User impact:** safety settings and a core strength tool are unusable at normal phone widths or larger text sizes, and the debug stripe destroys trust.
- **Proposed experience:** stack related fields below a width/text-scale breakpoint; make dropdown content expand or ellipsize safely; use a scrolling form sheet for complex forms; reuse one responsive plate-loading presentation in both calculator surfaces.
- **Affected shared primitive:** `ResponsiveFieldGroup`, `IndiFitFormSheet`, and shared plate-loading presentation.
- **Scope:** responsive form behavior is global; calculator migration is screen-specific.
- **Regression/widget/golden tests:** 320×568 and 390×844, 200% text scale, long labels, large plate counts, dropdown tests, and dark/light goldens with no Flutter exceptions.

### P0.3 — Onboarding keyboard and focus lifecycle

- **Screenshot/screen:** `IMG_1143.PNG` and `IMG_1144.PNG`, onboarding steps 1 and 6.
- **Production target:** [`_nextPage`](../../../lib/features/onboarding/onboarding_screen.dart:199), the onboarding [`PageView`](../../../lib/features/onboarding/onboarding_screen.dart:443), and [`_buildSexPage`](../../../lib/features/onboarding/onboarding_screen.dart:544).
- **Problem:** focus is retained across steps, the keyboard remains open after navigation, and an optional name field can obscure the required choice below it.
- **User impact:** users cannot see or complete the active step and may abandon onboarding.
- **Proposed experience:** dismiss focus on step change, submit, and selection; scroll the active field into view; move the CTA above keyboard insets; place optional identity input after required setup or below the required selection. Preserve the existing medically necessary data collection contract.
- **Affected shared primitive:** keyboard-aware form-flow scaffold and focus policy.
- **Scope:** global form-flow behavior; onboarding is the first migration.
- **Regression/widget/golden tests:** simulated keyboard insets, active text and numeric keyboard transitions, focus-order semantics, 200% text scale, and keyboard-state goldens.

### P0.4 — Manual workout sheet composition and input ownership

- **Screenshot/screen:** `IMG_1152.PNG`, Log Completed Workout.
- **Production target:** [`RoutineDisplayScreen`](../../../lib/features/workout_player/routine_display_screen.dart:122) and [`ManualLogSheet`](../../../lib/features/workout_player/widgets/manual_log_sheet.dart:205).
- **Problem:** one caller sets a transparent sheet background; the sheet has a fixed 85% height; and set-row `TextEditingController`s are created inside `build`.
- **User impact:** the underlying page and navigation bleed through the modal, keyboard resizing can hide controls, and entered set values can reset during rebuilds.
- **Proposed experience:** use an opaque, safe-area-aware sheet with drag handle, close action, scrollable content, keyboard avoidance, and a reserved primary save area; own row controllers in state and dispose them predictably.
- **Affected shared primitive:** global `IndiFitBottomSheet` and stable form-row controller pattern.
- **Scope:** global sheet behavior; manual workout is the first migration.
- **Regression/widget/golden tests:** add/edit/delete set tests, keyboard and resize tests, controller persistence tests, focus semantics, and light/dark modal goldens.

### P0.5 — Light-mode navigation contrast failure

- **Screenshot/screen:** `IMG_1151.PNG`, Today in light mode.
- **Production target:** [`MainNavigationScaffold`](../../../lib/features/dashboard/main_navigation_scaffold.dart:30) and its hard-coded navigation colors.
- **Problem:** light page content is paired with a dark navigation surface while inherited icon and label colors remain light.
- **User impact:** users cannot reliably discover or switch tabs.
- **Proposed experience:** drive `NavigationBarThemeData` from semantic light/dark tokens with explicit selected and unselected colors and accessible contrast.
- **Affected shared primitive:** global theme/navigation primitive.
- **Scope:** global.
- **Regression/widget/golden tests:** dark/light navigation goldens, contrast assertions, selected/unselected semantics, and large-text navigation layout tests.

## P1 — Consumer-facing information and copy defects

### P1.1 — Today exposes internal evidence, IDs, and reason codes

- **Screenshot/screen:** `IMG_1146.PNG` and `IMG_1147.PNG`, “What can I eat now?”.
- **Production target:** [`B04CurrentFoodCard`](../../../lib/features/coaching/b04_production_surface_widgets.dart:431) and its direct detail formatters.
- **Problem:** UUIDs, timezone strings, `daily_totals_missing`, source IDs, goal versions, evidence states, and raw reason codes are rendered as normal product copy.
- **User impact:** the app reads like a failed internal tool and exposes information users cannot act on.
- **Proposed experience:** map B04 availability to short truthful states such as “Log a meal to see today’s nutrition” or “We need a little more information.” Put provenance and unavailable reasons behind an optional “Why can’t I see advice?” disclosure.
- **Affected shared primitive:** consumer presentation mapper for B04-derived UI.
- **Scope:** global mapper; wording is screen-specific.
- **Regression/widget/golden tests:** cover all B04 states; assert no UUID, source ID, or reason-code leakage; test accessible disclosure and available/unavailable goldens.

### P1.2 — Empty states use contract language instead of outcomes

- **Screenshot/screen:** `IMG_1145.PNG`–`IMG_1147.PNG` and `IMG_1153.PNG`.
- **Production target:** [`TodayDailyActionSurface`](../../../lib/features/dashboard/today_daily_action_surface.dart:601) and [`B02ProgressOverview`](../../../lib/features/progress/b02_progress_widgets.dart:49).
- **Problem:** phrases such as “canonical nutrition totals,” “persisted activity rows,” “frozen rule version,” and raw UTC ranges dominate no-data states.
- **User impact:** users learn system mechanics instead of what to do next.
- **Proposed experience:** show a meaningful status plus one next step: “No meals logged yet — Log a meal” or “Your progress starts with your first workout.” Keep provenance in a secondary details view.
- **Affected shared primitive:** `ProductStatePresentation` and `ConsumerDateLabel`.
- **Scope:** global state/date primitives; screen-specific copy.
- **Regression/widget/golden tests:** assert consumer output contains no `UTC`, `canonical`, `persisted`, or evidence-contract wording; test empty and loaded Today/progress states.

### P1.3 — Dietary constraints and measures expose technical vocabulary

- **Screenshot/screen:** `IMG_1156.PNG` and `IMG_1157.PNG`.
- **Production target:** [`NutritionConstraintsScreen`](../../../lib/features/settings/nutrition_constraints_screen.dart:560) and [`HouseholdMeasuresScreen`](../../../lib/features/settings/household_measures_screen.dart:105).
- **Problem:** “Stable target ID,” “approved portable ID,” `allergen`, and “unresolved” are consumer-facing labels.
- **User impact:** safety settings feel risky, administrative, and difficult to understand.
- **Proposed experience:** ask “What should we avoid?” with familiar categories and searchable choices; show “Needs measuring” for vessel capacity while retaining the important volume-not-grams rule in plain language.
- **Affected shared primitive:** display-label/presentation adapter and consumer choice picker.
- **Scope:** global labeling primitive; settings flows are screen-specific.
- **Regression/widget/golden tests:** assert consumer and VoiceOver labels contain no raw IDs or “unresolved”; test add/edit flows at 200% text scale.

### P1.4 — Playlist is a dead end presented as functionality

- **Screenshot/screen:** `IMG_1155.PNG`, Workout playlist.
- **Production target:** the empty provider registry and [`B05PlaylistSettingsPanel`](../../../lib/features/media/b05_playlist_launcher.dart:509).
- **Problem:** settings routes users to setup even though no provider can be selected.
- **User impact:** users conclude the app is broken.
- **Proposed experience:** hide or disable the entry until a configured provider exists; preserve the allowlist guard, but use a short friendly fallback for legacy/deep links with a clear exit.
- **Affected shared primitive:** feature-availability gate and unavailable-state component.
- **Scope:** global availability gate; screen-specific fallback.
- **Regression/widget/golden tests:** empty registry never opens a dead-end setup flow; configured providers remain launchable; assert no “allowlist” language in consumer UI.

### P1.5 — AI Meal Estimator misrepresents interaction

- **Screenshot/screen:** `IMG_1149.PNG`.
- **Production target:** [`AiMealLoggerScreen`](../../../lib/features/food_log/ai_meal_logger_screen.dart:720) and [`FoodLogEntriesPanel`](../../../lib/features/food_log/food_log_surface.dart:62).
- **Problem:** the microphone button inserts a canned meal and announces “Voice input captured”; the empty state refers to a nonexistent search; the safety text is 10.5pt.
- **User impact:** false capability claims undermine trust and the primary task is unclear.
- **Proposed experience:** remove faux voice capture until speech input exists; lead with “Describe your meal” and “Estimate nutrition”; make photo secondary; use readable, concise safety copy and truthful empty-state guidance.
- **Affected shared primitive:** shared task-entry action group and status-state primitive.
- **Scope:** shared action semantics; meal flow behavior is screen-specific.
- **Regression/widget/golden tests:** no fake microphone result, truthful unavailable labels, text-scale/overflow tests, keyboard tests, and input/result goldens.

### P1.6 — Generic failures can render raw exception text

- **Screenshot/screen:** any async failure, including Today and meal logging.
- **Production target:** [`FailureStateWidget`](../../../lib/core/widgets/failure_state_widget.dart:75) and [`FoodLogEntriesPanel`](../../../lib/features/food_log/food_log_surface.dart:46).
- **Problem:** `technicalDetails` and `error.toString()` can reach consumer surfaces.
- **User impact:** failures are confusing, inconsistent, and potentially expose sensitive implementation details.
- **Proposed experience:** one production-safe failure state with a plain explanation, Retry/back action, and optional non-sensitive support reference; retain raw details only in telemetry/support diagnostics.
- **Affected shared primitive:** global `ProductFailureState`.
- **Scope:** global.
- **Regression/widget/golden tests:** inject representative exceptions and assert no stack/error/model text is visible; test retry semantics and light/dark error goldens.

## P2 — Structural UX redesign

### P2.1 — Today should be a daily plan, not a diagnostic-card dashboard

- **Screenshot/screen:** `IMG_1145.PNG`–`IMG_1151.PNG` and `IMG_1150.PNG` customization sheet.
- **Production target:** [`TodayDailyActionSurface`](../../../lib/features/dashboard/today_daily_action_surface.dart:395), [`DashboardDateBar`](../../../lib/features/dashboard/widgets/dashboard_date_bar.dart:37), and [`DashboardModuleCustomizationPanel`](../../../lib/features/dashboard/widgets/dashboard_module_customization_panel.dart:14).
- **Problem:** four “What should I…” cards, permanent status text, nested loading/status cards, duplicate CTAs, and low-level customization controls create density without hierarchy.
- **User impact:** users cannot identify the one best action for today.
- **Proposed experience:** make Today a “Daily focus” surface with one primary action based on existing authority output, up to two compact supporting summaries, and an unobtrusive “Edit Today” flow. Keep accessible reorder/hide controls, but progressively disclose them.
- **Affected shared primitive:** `DailyFocusLayout`, CTA hierarchy, and standard sheet.
- **Scope:** shared layout primitives; Today composition is screen-specific.
- **Regression/widget/golden tests:** zero-data, workout-day, meal-day, loading, and unavailable states; assert exactly one primary CTA; verify semantic reading order and dark/light goldens.

### P2.2 — Calendar empty state needs a productive exit

- **Screenshot/screen:** `IMG_1148.PNG`, Training Calendar.
- **Production target:** [`ProgramCalendarScreen`](../../../lib/features/calendar/program_calendar_screen.dart:115).
- **Problem:** an empty week shows only an icon and “No workouts scheduled,” while date controls expose raw UTC data.
- **User impact:** users hit a dead end after following an “Open workout plan” action.
- **Proposed experience:** use natural date labels, clear Day/Week/Month controls, and an empty state with one existing next action such as “Open workout plan” or “Browse workouts.”
- **Affected shared primitive:** `ProductEmptyState` and `ConsumerDateLabel`.
- **Scope:** shared state/date primitives; calendar CTA is screen-specific.
- **Regression/widget/golden tests:** day/week/month empty and populated states, timezone-boundary regression, text-scale tests, and goldens.

### P2.3 — Progress needs an outcome-first empty experience

- **Screenshot/screen:** `IMG_1153.PNG`, Progress & Analytics.
- **Production target:** [`ProgressScreen`](../../../lib/features/progress/progress_screen.dart) and [`B02ProgressOverview`](../../../lib/features/progress/b02_progress_widgets.dart:49).
- **Problem:** multiple outlined technical no-data cards compete for attention and none offers a meaningful next action.
- **User impact:** new users see absence rather than a motivating starting point.
- **Proposed experience:** one full-page empty state with a concise promise and action (“Log your first workout”); reveal charts and evidence details progressively when data exists.
- **Affected shared primitive:** global empty/loading state; progress-specific information architecture.
- **Scope:** state primitive global; progress composition screen-specific.
- **Regression/widget/golden tests:** no-data, partial-data, and populated states; one-action assertion; progressive-disclosure semantics and goldens.

### P2.4 — Meal logging needs one dominant path

- **Screenshot/screen:** `IMG_1149.PNG`, AI Meal Estimator.
- **Production target:** [`AiMealLoggerScreen`](../../../lib/features/food_log/ai_meal_logger_screen.dart:610).
- **Problem:** warning, status, text card, parser chips, estimate CTA, and photo card all have similar visual weight; prompt chips clip horizontally.
- **User impact:** users do not know whether to type, parse, choose a prompt, upload, or search.
- **Proposed experience:** “Log a meal” starts with a text field and one primary Estimate action. Examples wrap below the field or open in a “More examples” surface; photo is a secondary route; review-before-save remains explicit.
- **Affected shared primitive:** task-entry scaffold and action group.
- **Scope:** shared entry structure; meal flow screen-specific.
- **Regression/widget/golden tests:** 320/390pt widths, 200% text, chip wrapping, keyboard behavior, and input/photo/result goldens.

### P2.5 — Safety and household-measure setup should be contextual

- **Screenshot/screen:** `IMG_1156.PNG` and `IMG_1157.PNG`.
- **Production target:** [`NutritionConstraintsScreen`](../../../lib/features/settings/nutrition_constraints_screen.dart) and [`HouseholdMeasuresScreen`](../../../lib/features/settings/household_measures_screen.dart).
- **Problem:** dense implementation-shaped forms and large unresolved measure grids appear before users have a clear task.
- **User impact:** configuration feels like administration rather than support for safe eating and accurate logging.
- **Proposed experience:** place constraints in a concise “Dietary needs” area with a friendly add flow; make personal vessels primary; ask for a measure contextually during meal logging instead of exposing every unresolved standard measure at once.
- **Affected shared primitive:** searchable choice picker, product empty state, and contextual measure selector.
- **Scope:** shared picker/state primitives; flow structure screen-specific.
- **Regression/widget/golden tests:** first-run, existing-data, and add/edit flows; screen-reader labels; no dead-end states; dark/light goldens.

## P3 — Visual polish and accessibility

### P3.1 — Replace border stacking with semantic surface levels

- **Screenshot/screen:** `IMG_1145.PNG`–`IMG_1151.PNG`, `IMG_1149.PNG`, and `IMG_1153.PNG`.
- **Production target:** [`AppTheme` CardTheme](../../../lib/core/theme/app_theme.dart:29) and [`B05Surface`](../../../lib/core/widgets/b05_accessibility_primitives.dart:80).
- **Problem:** outlined cards sit inside outlined cards with outlined statuses and loaders.
- **User impact:** visual noise, weak hierarchy, and an unfinished feel.
- **Proposed experience:** define page, section, inset, and status surface levels; allow at most one physical boundary per information group. Prefer spacing, tonal contrast, and typography over repeated borders.
- **Affected shared primitive:** semantic surface system, extending B05 primitives rather than creating a parallel system.
- **Scope:** global; migrate screens incrementally.
- **Regression/widget/golden tests:** representative Today, meal, progress, and settings goldens in both themes.

### P3.2 — Unify dark/light tokens, typography, and CTA hierarchy

- **Screenshot/screen:** all screens; most visible in `IMG_1143.PNG`, `IMG_1149.PNG`, and `IMG_1151.PNG`.
- **Production target:** [`AppTheme`](../../../lib/core/theme/app_theme.dart) and the semantic B05 color tokens.
- **Problem:** legacy colors, hard-coded component colors, oversized copy, and filled/outlined controls are mixed without a consistent hierarchy.
- **User impact:** the product cannot reliably feel calm, premium, or accessible.
- **Proposed experience:** consolidate onto semantic tokens; use one filled primary CTA per task, quiet secondary/text actions, consistent minimum targets, readable Dynamic Type, and clear selected/unselected states.
- **Affected shared primitive:** global theme, button, input, and navigation tokens.
- **Scope:** global.
- **Regression/widget/golden tests:** contrast checks, 1.0/1.5/2.0 text scale, dark/light golden suite, and semantic target-size tests.

### P3.3 — Make loading states quiet and informative

- **Screenshot/screen:** `IMG_1145.PNG`–`IMG_1147.PNG`.
- **Production target:** [B04 loading/status cards](../../../lib/features/coaching/b04_production_surface_widgets.dart:755) and the shared skeleton loader.
- **Problem:** large bordered blanks with isolated spinners look broken and add surface density.
- **User impact:** users cannot tell whether content is loading, unavailable, or empty.
- **Proposed experience:** use compact inline loading for modules, content-shaped skeletons only when useful, explicit unavailable states, and reduced-motion behavior.
- **Affected shared primitive:** global loading/status system.
- **Scope:** global.
- **Regression/widget/golden tests:** loading-to-content transitions, reduced-motion behavior, live-region semantics, and goldens.

## Repeated anti-patterns requiring shared fixes

1. **Widgets formatting domain objects directly.** Add consumer presentation
   adapters for B02/B03/B04 outputs. Widgets should receive display-ready
   title, body, action, and state values.
2. **Card → status card → loader card nesting.** Evolve `B05Surface` into
   semantic variants instead of defaulting every surface to an outline.
3. **Ad hoc sheets and dialogs.** Standardize opaque sheets, safe areas,
   keyboard handling, max-height behavior, drag/close affordances, and pinned
   action spacing.
4. **Raw exceptions and reason codes.** Route async errors through one
   consumer-safe failure component; retain technical details in telemetry or
   support diagnostics.
5. **Hard-coded horizontal form rows.** Use a responsive field-group primitive
   and test narrow widths, long labels, and large text.
6. **Hard-coded colors outside the theme.** Move navigation, buttons, inputs,
   and status surfaces to semantic light/dark tokens.
7. **Permanent diagnostic copy.** Reserve explanation for deliberate details;
   default states should communicate outcome plus one meaningful next action.

## Suggested implementation waves

### Wave 0 — Release stabilization

Fix the diet dropdown assertion, both overflow classes, onboarding keyboard
lifecycle, manual-log sheet/controller lifecycle, and light-navigation contrast.
Add a CI gate that fails on Flutter exceptions and `RenderFlex` overflow.

### Wave 1 — Consumer trust layer

Introduce presentation, error, and date adapters. Remove IDs, reason codes,
`error.toString()`, faux voice capture, raw UTC, technical evidence language,
and unavailable-provider terminology from default product surfaces.

### Wave 2 — Task-flow redesign

Migrate Today to Daily Focus, then calendar empty states, progress empty states,
meal logging, and dietary/measure setup. Build shared state, sheet, surface,
and action primitives before migrating each screen.

### Wave 3 — Visual and accessibility certification

Consolidate semantic tokens and surfaces, establish dark/light golden baselines,
verify 320/390pt widths and 200% text, test keyboard and sheet focus, VoiceOver
order, contrast, reduced motion, and physical-device screenshots.

## Release-quality gates

- No `DropdownButton` assertions, `RenderFlex` overflows, or uncaught Flutter
  exceptions in widget and integration tests.
- No raw UUIDs, stable IDs, reason codes, evidence IDs, internal state names,
  stack traces, or technical exception strings in consumer rendering paths.
- All primary journeys tested at compact phone widths, normal and 200% text,
  dark and light themes, loading, empty, unavailable, and error states.
- Every empty or unavailable state has a truthful explanation and one sensible
  next action, unless the domain authority explicitly provides no safe action.
- Keyboard transitions, modal focus trapping/return, screen-reader order,
  minimum touch targets, contrast, and reduced-motion behavior are verified.
