# Premium redesign: tokens, motion and five signature moments

**Status:** approved direction (Ayush, 2026-10-08) · **Owner:** Claude (code), Ayush (review, device feel checks) · **Last updated:** 2026-10-08 (V0 open as #86; open questions answered)

Related:
- [Visual review, 8 Oct](../audit/visual-review-2026-10-08/index.html) (artifact https://claude.ai/artifact/1zPcdBAuptLj8GV8SMHAVz): the findings, concepts and screenshots this plan builds on. F1–F8 and concepts A–G are referenced by ID below.
- [TRAINING_PROGRESS_PREMIUM_PLAN.md](TRAINING_PROGRESS_PREMIUM_PLAN.md): TP-9, TP-10 and TP-11 overlap this plan. § 1 says which plan owns what.
- [LAUNCH_ROADMAP_FINAL.md](LAUNCH_ROADMAP_FINAL.md) § 0: the hard rules (CI green, one PR per topic, tracker updated, ask before push/merge, full suite in a scratch worktree, freeze about 3 days before a store build).
- [REFERENCE_GUIDE_UPDATED.md](../reference/ui/REFERENCE_GUIDE_UPDATED.md) § 9–10: product principles and visual direction ("premium, athletic, calm during workouts, not monochromatic"). This plan makes § 10 concrete.

---

## 0. Tracker

Update this table in every PR that touches the redesign. Status values: Not started · In progress (PR #) · Merged (PR #) · Blocked (reason).

| ID | Work item | Concept / finding | Depends on | Gate before merge | Status |
|---|---|---|---|---|---|
| V0 | Contrast and correctness: `actionFill`, thali labels, dark default, current-plan state, stable search, number formats, headers | F1–F7 | — | Goldens refreshed | In progress (#86) |
| V1 | Tokens 2.0: radii and squircles, three surface levels, tabular figures, text roles, one section-header style, macro colour map, remove `percent_indicator` | F7, F8, TP-11 | V0 | Contrast tests extended; goldens | Not started |
| V2 | Motion kit: `animations`, `IndiFitMotion` presets, Add → tick, count-ups, container and shared-axis transitions | TP-10 | V1 | Reduce Motion and haptic tests; device feel check | Not started |
| V4 | Steel thali: shaded plate, filled katoris, legend, drop-in | A | V1, V2 | Prototype screenshots approved; device feel check | Not started |
| V5 | Player: rest takeover, exercise-done beat, exercise images, muscle map | B, G | V2; RepDB import (§ 9) | Credits updated; device feel check | Not started |
| V3 | Today ring with depth and log feedback | E | V2 | Goldens | Not started |
| V6 | Summary hero and share card | C | V2 | Share card checked in Instagram/WhatsApp | Not started |
| V7 | Medals: 3D badge art, tilt, sheen | D | V1, V2 | Art licence in manifest | Not started |
| V8 | Onboarding: animated mark, ruler pickers, target reveal | F | V2 | IPA size check (no new assets or packages) | In progress (#96 rulers, reveal, no Skip on step 5; `feat/v8-welcome-intro` welcome screen) |

**Order:** V0 → V1 → V2 → V4 → V5 → V3 → V6 → V7 → V8 (decision 5: the thali comes first after V0–V2). V3 and V6 are small and can move earlier if a slot opens. Nothing here has a date; only the store-build freeze applies.

---

## 1. Decision record

**Decisions (Ayush, 2026-10-08, "yes to all")**
1. **Dark is the first-run theme.** Light stays as an option. Shipped in V0 (`ThemeModeNotifier.defaultMode`).
2. **Rive, not Lottie,** for the few hero animations (V8, optionally V7). *Superseded for V8 (2026-10-11):* the welcome mark is drawn in code (§ 8.1), so the app takes no Rive dependency for now.
3. **Medal and illustration art starts with Microsoft Fluent Emoji 3D (MIT).** Commission one consistent set once Plus revenue starts.
4. **Import RepDB free-tier exercise images,** with attribution in About & credits.
5. **The steel thali (V4) is the first signature moment** after V0–V2.

**Decisions on the plan's open questions (Ayush, 2026-10-08, "go with your recommendations")**
6. **Fat icon:** Phosphor `DropHalf` (duotone), via `phosphor_flutter` 2.1.0 (MIT). Water keeps Material `water_drop`. Phosphor becomes the source for any later icon gaps.
7. **Light theme depth:** soft shadows instead of borders on sections (§ 4.2). Inputs and control outlines keep their 3:1 borders.
8. **Thali tilt:** ships in V4 (not a separate V4b): gyroscope ±6°, only while the thali screen is visible, off under Reduce Motion.
9. **Share card:** the workout only, no name or other personal data. A name option can come later if people ask.

**Changes to earlier plans**
- TRAINING_PROGRESS_PREMIUM_PLAN § 9 said Lottie and Rive were "not now". Superseded by decision 2 for V8 only.
- **`animations` must be 2.2.0, not 3.0.0.** 3.0.0 needs Flutter ≥ 3.44 and Dart ^3.12. The repo and CI pin Flutter 3.41.4 (Dart 3.11). Checked on pub.dev 2026-10-08.
- TP-10 (`animations` transitions) moves into V2. TP-11 (remove `percent_indicator`) moves into V1. The training plan's tracker should point here.
- TP-9 (muscle map and heatmap on Progress, Plus) stays in the training plan. It reuses the `IndiFitMuscleMap` widget that V5 puts on screen first.

**Rules this plan keeps** (from the Reference Guide and B05)
- Colour is never the only signal; labels stay.
- Red is reserved for "over target". No macro uses red as its base colour (`todayMacroColorRole`).
- Haptics fire after the save succeeds, never on tap (`IndiFitHaptics` rule).
- Under Reduce Motion everything is instant and final values render on the first frame (`B05MotionPolicy`).
- No invented data: concept mock-ups use real values or say "example".

---

## 2. Goals and non-goals

**Goals**
- Every text-bearing colour passes WCAG AA (4.5:1) on the surface it sits on, in both themes.
- One visual language: the same radii, surfaces, header style and number format on every tab.
- Five moments that feel like a reward: thali, rest, summary, medals, Today ring. Each pairs motion with an existing haptic.
- Exercise screens show the movement (images) and the muscles (map).

**Non-goals**
- No real-time 3D engine (`flutter_scene`, `model_viewer_plus`, `flutter_cube`). "3D" means depth, light and tilt from art, painters and shaders.
- No domain, data or persistence changes. No new nutrition or training numbers.
- No change to the free/Plus line (market doc § 6.5).
- No Android-specific design work; the app ships iPhone-first and portrait (decision 2026-10-06). Android must still render correctly.

---

## 3. What exists (reuse, don't rebuild)

| Piece | Where | Use in |
|---|---|---|
| `B05SemanticColors` incl. `action` / `actionFill` (V0) | `lib/core/theme/b05_semantic_colors.dart` | V1 adds tokens here |
| `B05Surface` (224 call sites), `B05Radii` (8/10/12), `B05Layout` | `lib/core/widgets/b05_accessibility_primitives.dart` | V1 changes the look through these, not per screen |
| `B05Typography` roles: caption 344, body 208, title 174, label 132, pageTitle 24, metric 10 uses | same file | V1 adds `number` and `sectionLabel` |
| `B05MotionPolicy` (160/240/360 ms, `easeOutCubic`, `reduceMotion`) and `B05MotionContent` | same file | V2 builds presets on these |
| `IndiFitHaptics`: `selection`, `confirmation`, `success`, `restEnd`, `warning`, `debugHandler` | `lib/core/services/indifit_haptics.dart` | V2–V7 |
| `ConfettiOverlay` | `lib/core/widgets/confetti_overlay.dart` | V6, V7 (one burst per moment) |
| `CalorieRing` / `CalorieRingPainter` | `lib/features/dashboard/widgets/today_nutrition_widgets.dart:356` | V3 |
| `CircularThaliPlate`, `ThaliPlatePainter`, `ThaliDishCategory` (9 categories) | `lib/features/food_log/thali/` | V4 |
| `RestCard` (112 pt ring) and `StickyRestBar` | `lib/features/workout_player/widgets/b02_player_cards.dart:671, 913` | V5 |
| `IndiFitMuscleMap` (front/back, exercise and intensity modes; geometry ported, **not yet on any screen**) | `lib/features/media/indifit_muscle_map.dart` | V5, then TP-9 |
| `B05ExerciseVisualRegistry` (approved local images by canonical exercise UUID) | `lib/features/media/b05_exercise_visual_registry.dart` | V5 RepDB import |
| `AchievementCelebrationSheet`, `AchievementsScreen` (9 badges) | `lib/features/workout_player/widgets/`, `lib/features/progress/` | V7 |
| `workout_summary_screen.dart` (shares text only today), `b02_strength_summary_screen.dart` | `lib/features/workout_player/` | V6 |
| Onboarding `_StepperButton` (± steppers) | `lib/features/onboarding/widgets/onboarding_step_widgets.dart:442` | V8 |
| `flutter_animate` 4.5.2 (dependency, used in 1 file), `share_plus`, `fl_chart` 0.67 | pubspec | V2, V6 |

---

## 4. V1: Tokens 2.0

The look changes through the primitives and the theme only. Screens are not edited one by one, except to swap ALL-CAPS headers and hard-coded number formats.

### 4.1 Radii and corners
- New `B05Radii`: `row 16`, `card 22`, `sheet 28`, `control 14` (buttons, inputs), `chip 12`, `pill 999`. The old `small/medium/large` (8/10/12) stay as aliases for one release, then go.
- Corners are continuous (squircle) via `figma_squircle` `SmoothBorderRadius(cornerRadius: r, cornerSmoothing: 0.6)` in `B05Surface`, card, sheet, dialog, button and input themes.
- The 100+ direct `BorderRadius.circular(...)` sites are migrated only when a later PR touches that file. A test fails if `b05_accessibility_primitives.dart` or `app_theme.dart` uses `BorderRadius.circular`.

### 4.2 Surfaces (depth instead of borders)
| Level | Dark | Light | Use |
|---|---|---|---|
| page | #060A12 (unchanged) | #F6F8FA | Scaffold |
| section | #0F172A + 1 px top highlight (white 6 %) | #FFFFFF + shadow 0 1 2 rgba(15,23,42,0.06) | Default `B05Surface` |
| raised | gradient #16213A → #111A2E + shadow 0 8 24 black 35 % | #FFFFFF + shadow 0 8 24 rgba(15,23,42,0.10) | Hero cards (Today nutrition, summary hero, thali plate panel) |
| inset | #162033 (unchanged) | #F1F5F9 | Metrics and inputs inside a section |

- New `borderSubtle` (dark white 14 %, light #E2E8F0) for decorative card edges. `border` (dark white 40 %) stays for inputs and control outlines, which need 3:1.
- `B05Surface(showBorder: true)` switches to `borderSubtle`.

### 4.3 Type
- `B05Typography.number(context, {double size})`: Outfit with `FontFeature.tabularFigures()`; used for every timer, counter, kcal and weight value. `metric` gains tabular figures.
- `B05Typography.sectionLabel(context)`: 13 pt, w600, `textSecondary`, letter spacing 0.2, sentence case. It replaces the ALL-CAPS section headers, such as Training's "THIS WEEK", "MORE TRAINING" and "WHAT TO DO NOW" (`toUpperCase()` appears 18 times in `lib/features`; not all are headers), and restyles Progress `ProgressSectionHeading`.
- Hard-coded `fontSize:` (189 sites in 55 files) is not migrated wholesale. Files touched by V1–V8 move to roles.

### 4.4 Macro colour map (F8)
One map used by Today, the diary, the thali, portion sheets and Progress:

| Macro | Dark indicator / text | Light indicator / text | Icon |
|---|---|---|---|
| Protein | teal #2DD4BF / #5EEAD4 | #0D9488 / #0F766E | egg (unchanged) |
| Carbs | amber #FBBF24 / #FCD34D | #D97706 / #B45309 | grain (unchanged) |
| Fat | **orange #FB923C / #FDBA74** | #EA580C / #C2410C | **not a water drop** (see below) |
| Fibre | violet #A78BFA / #C4B5FD | #7C3AED / #6D28D9 | leaf (unchanged) |
| Water | blue (hydration only) | blue | drop |

- Orange keeps fat away from red ("over target") and from hydration blue. It sits next to amber, so fat and carbs also differ by icon and label.
- **Fat icon (decision 6):** Phosphor `DropHalf` duotone. Water keeps Material `water_drop`.
- `breakfast` currently uses orange too (meal accent). Meal accents only tint the meal icon chip, so they don't collide in practice; the V1 golden review checks Today where both appear.

### 4.5 Housekeeping
- Remove `percent_indicator` (no imports; TP-11).
- Add `figma_squircle: ^0.6.3` (MIT, aloisdeniel.com).

### 4.6 Tests and verification
- Contrast test: every role's `foreground` on page/section/inset/selected ≥ 4.5; every `indicator` ≥ 3:1 on section; `action` on all surfaces (V0 test, kept).
- Primitives test: no `BorderRadius.circular` in primitives or theme; `B05Surface` uses `SmoothBorderRadius`.
- Golden refresh once at the end of the PR; review a dark and a light shot of each tab.
- Simulator pass: all five tabs, dark and light.

---

## 5. V2: Motion kit

### 5.1 Dependencies
- `animations: ^2.2.0` (BSD-3, flutter.dev). Not 3.0.0 (§ 1).
- `flutter_animate` stays at ^4.5.0 and becomes the standard for entrances and count-ups.

### 5.2 `IndiFitMotion` presets (`lib/core/motion/indifit_motion.dart`)
All presets read `B05MotionPolicy.reduceMotion(context)` and return the final state instantly when it is on.

| Preset | Spec | First users |
|---|---|---|
| `enter` | fade 0 → 1 + slide 8 pt up, 240 ms, `easeOutCubic` | section reveals on first view |
| `stagger` | `enter` with 40 ms between children, first build only, max 6 children animated | Today modules, summary blocks |
| `countUp` | number tweens from old to new value, 360 ms, tabular figures; first frame shows final value under Reduce Motion | Today kcal, summary total, week ring |
| `successMorph` | button content cross-fades to a tick, scale 0.9 → 1 on a spring (stiffness 380, damping 28), holds 900 ms, then back | food search "Add" |
| `pop` | scale 0.92 → 1 spring, 220 ms | chips, badges, new-best tag |

- Route transitions: keep Cupertino on iOS. `OpenContainer` from the Today and Training workout cards into the plan/player; `SharedAxisTransition` (horizontal) between exercises in the player (TP-10).

### 5.3 Applied in V2
- Food search "Add": `successMorph` plus the existing `confirmation()` haptic, both after the log is saved. The snackbar with Undo stays.
- Diary rows: new row `enter`.
- Today: kcal and macro values `countUp` when returning from logging.

### 5.4 Tests
- `debugHandler`: each event emits one haptic, after persistence.
- `MediaQuery(disableAnimations: true)`: no `AnimationController` ticking after `pump()`, final values on frame one.
- No leaked tickers (`tester.binding.hasScheduledFrame` false after settle).

---

## 6. V4: Steel thali (concept A)

### 6.1 Prototype first
1. Build the plate painter in isolation behind a debug route.
2. Send Ayush simulator screenshots of: empty plate, North Indian Classic, 8 dishes (overflow), 320 pt width, light theme.
3. Adjust, then wire into `ThaliBuilderScreen`.

### 6.2 Spec
- **Plate:** diameter `min(width − 32, 340)`. Steel drawn with a radial gradient plus a brushed-steel fragment shader (`shaders/brushed_steel.frag`, declared under `flutter: shaders:`). If the shader fails to load (tests, old devices) the gradient alone is used.
- **Rim:** the existing macro ring, now in the V1 macro colours, animating from old to new split.
- **Katoris:** steel bowl (radial gradient + rim highlight) filled by `ThaliDishCategory`:

  | Category | Fill |
  |---|---|
  | Dal / Sambar | golden yellow #F2C14E → #C98E1B |
  | Sabzi / Veg | green #8DB04A → #4E7A23 with 3 lighter flecks |
  | Curry / Protein | orange-red gravy #E07A3A → #A8461A |
  | Curd / Raita | off-white #FBF8F1 → #E4DCCB |
  | Sweet / Dessert | saffron #F6B26B → #D9822B |
  | Chutney / Salad | leaf green #5FA052 → #2F6B2A |
  | Side dish | neutral steel |
  | Rice / Grain (centre) | white mound with grain noise |
  | Roti / Staple (centre) | stacked brown discs with char spots, one disc per piece up to 3 |

  No per-dish art and no food identity inferred beyond the existing category.
- **Fill level:** quantity relative to the dish's default portion, clamped 0.35–1.0, so a half katori looks half full.
- **Labels:** inside a katori only the kcal number (tabular). Names and quantities move to the dish list under the plate, which already exists. Semantics labels are unchanged.
- **Motion:** an added dish drops in (spring, from −24 pt, 420 ms) with `IndiFitHaptics.selection()`; quantity changes animate the fill; removing fades out. Instant under Reduce Motion.
- **Tilt (decision 8):** `sensors_plus` gyroscope, ±6°, only while the screen is visible, off under Reduce Motion.

### 6.3 Tests and verification
- Goldens: 320, 390 and 430 pt widths, dark and light, empty / classic / overflow.
- Every katori and the add slot keep ≥ 48 pt targets; semantics unchanged (existing tests).
- Profile build on a real iPhone: no dropped frames while adding dishes (Ayush).

---

## 7. V5: Player (concepts B and G)

### 7.1 Rest takeover
- After "Log set", `RestCard` moves to the top of the player as a takeover: 200 pt ring (V1 tabular timer), "Up next: Set 2 · 60 kg × 8", and −15 / +30 / Skip as 56 pt targets.
- Scrolling the set list or tapping a set row collapses it into `StickyRestBar` (existing). Expanding again is a tap on the bar.
- Timing and intent logic (`b02OpenRestPeriod`, rest intents, notifications) do not change. The ring reads the same durable start timestamp.
- At zero: one pulse animation and the existing `restEnd()` haptic.
- The lock-screen Live Activity (TP-14) reuses the same layout later.

### 7.2 Exercise-done beat
- When the last set of an exercise is saved: a 1 s card "Leg Press done · 3 × 8 · 60 kg" (plus "New best" if TP-2 found one), then `SharedAxisTransition` to the next exercise. Tapping skips it. No haptic beyond the set's own.

### 7.3 Exercise images and muscle map
- Import RepDB free-tier images (§ 9). Map catalogue exercise UUIDs to RepDB ids in a checked-in table; register them in `B05ExerciseVisualRegistry`. Unmatched exercises fall back to the muscle map.
- Player: a 16:9 image area at the top of the exercise (collapsible), replacing the 24 pt start/peak figures.
- Muscle map: `IndiFitMuscleMap.exercise(primaryMuscle, secondaryMuscles)` in the player's exercise sheet and the exercise library detail.
- Library rows get a 56 pt thumbnail.

### 7.4 Tests and verification
- The existing rest-intent and notification tests must pass unchanged (they guard the bugs fixed in #27).
- New: takeover ↔ bar transitions; Skip/+30 from the takeover; Reduce Motion.
- Coverage report in the PR: how many catalogue exercises got an image.

---

## 8. V3, V6, V7, V8

### 8.1 V8 welcome mark: drawn in code, not Rive (2026-10-11)
- The mark is the app icon traced into paths (`IndiFitMarkPainter`, 1024-unit icon space) and animated with one `AnimationController`. No `.riv` file needed authoring in the Rive editor, and the app takes no new package, asset, native download or IPA size.
- The Rive spike is therefore not needed. If a later hero animation needs Rive, the original checks still apply: `rive` 0.14.x downloads `rive_native` libraries during `flutter build` (CI time, offline builds, IPA size), with `rive: 0.13.20` as the fallback.

### 8.2 V3 Today ring (concept E)
- `CalorieRingPainter`: `SweepGradient` arc (#34D399 → #2DD4BF), soft glow (blurred duplicate arc at 30 %), 14 pt stroke, track `inset`.
- Returning from a log: ring and numbers `countUp` from the old value; a "+230 kcal · Poha" chip floats up once (`enter`, 1.5 s, then fades).
- Over target keeps today's red treatment.

### 8.3 V6 Summary hero and share card (concept C)
- Order: tick (pop) → workout name → one hero number "1,440 kg total lifted" (`countUp`) → one row of three stats (sets, reps, duration) → week-goal pill → "vs last time" lines → what you logged. Removes the repeated stat tiles.
- Share: render the hero block at 1080 × 1920 via `RepaintBoundary` → PNG → `Share.shareXFiles`. Brand gradient, IndiFit mark, the workout only: no name or other personal data (decision 9).
- One celebration per workout (existing TP-6 rule).

### 8.4 V7 Medals (concept D)
- Art: Fluent Emoji 3D PNGs are 256 × 256 (verified), sharp up to about 85 pt at @3x. Use them for the badge grid and the unlock sheet at ≤ 85 pt. Larger hero medals wait for commissioned art.
- Suggested mapping (confirm in the PR): First Sweat → Sports medal; Iron Lifter → 1st place medal; consistency badges → Fire; nutrition badges → Pot of food / Curry rice.
- Tilt with `sensors_plus` (±10°) and a sheen `FragmentShader` on unlock only. Locked badges: matte desaturated silhouette of the same art.
- Licence: add the files and MIT notice to `assets/third_party/asset_manifest.json` and About & credits.

### 8.5 V8 Onboarding (concept F)
- Welcome screen before step 1: animated IndiFit mark (drawn in code, § 8.1), one line of value, "Get started".
- Height and weight: horizontal ruler pickers (custom `ListWheelScrollView`-based, 1 cm / 0.5 kg ticks) with `selection()` haptic per tick; typing stays available for accessibility.
- Step 5: a 1.5 s "Building your targets" beat, then the calorie ring fills to the target and protein/carbs/fat appear above the fold; the recap of answers moves below.
- Drop "Skip for now" on step 5.
- **Built so far (`feat/v8-onboarding`):** `OnboardingRulerPicker` (`lib/features/onboarding/widgets/onboarding_ruler_picker.dart`) under the height and weight fields, replacing their ± steppers; it is a custom-painted ruler driven by horizontal drag rather than a `ListWheelScrollView`, with a slider for screen readers, arrow keys, and the text field kept for typing. Age keeps its steppers. `OnboardingTargetReveal` (`onboarding_target_reveal.dart`) puts the ring and macros at the top of step 5 and the recap below; it plays once per session, and under Reduce Motion it is final on the first frame. Skip is hidden on step 5.
- **Welcome screen (`feat/v8-welcome-intro`):** `OnboardingWelcome` (`onboarding_welcome.dart`), shown only on the first-run `/onboarding` route when no draft is restored. In 2.6 s the two strength bars slide in from opposite sides, the centre leaf grows out of them and the side leaves unfold, a ring pulses once and a light sweep crosses the mark; the wordmark, value line and "Get started" rise in after it. Tapping anywhere jumps to the end; under Reduce Motion the finished frame shows at once. Settings and Profile still open setup without it.

---

## 9. Assets and licences

| Asset | Licence (verified) | Steps |
|---|---|---|
| RepDB free tier (exercise WebP) | RepDB Free Tier Licence 1.0, commercial in-app use with attribution (licence file already in `LICENSES/`, pinned in `asset_manifest.json`, status "not approved") | Change status to approved; import only mapped exercises; add attribution to About & credits; record per-file provenance |
| Fluent Emoji 3D | MIT (repo `microsoft/fluentui-emoji`, checked 2026-10-08) | Add source entry, licence text, per-file list |
| MuscleMap geometry | MIT, already ported (`indifit_muscle_map_geometry.g.dart`) | None |
| Welcome mark | In-house; traced from `assets/branding/indifit_app_icon_master.png` | None (paths in code) |

Size budget for V4–V8 combined: +3 MB to the release IPA, measured in each PR.

---

## 10. Libraries (pub.dev, 2026-10-08)

| Package | Version | Licence, publisher | Constraint check | Step |
|---|---|---|---|---|
| `figma_squircle` | 0.6.3 (2025-03-08) | MIT, aloisdeniel.com | Dart ≥ 3.4 ✓ | V1 |
| `animations` | **2.2.0** (3.0.0 needs Flutter 3.44) | BSD-3, flutter.dev | Flutter ≥ 3.35 ✓ | V2 |
| `flutter_animate` | 4.5.2 (in pubspec) | BSD-3 | ✓ | V2 |
| `sensors_plus` | 7.1.1 (2026-10-01) | BSD-3, fluttercommunity.dev, Flutter Favorite | Flutter ≥ 3.19 ✓ | V4, V7 |
| `rive` | not used for now (§ 8.1); 0.14.11, fallback 0.13.20 | MIT, rive.app | Flutter ≥ 3.28 ✓; native download | — |
| `phosphor_flutter` | 2.1.0 (2024-05-10) | MIT | ✓ | V1 (fat icon, decision 6) |
| `flutter_svg` | not needed: MuscleMap geometry is already Dart paths | — | — | — |
| `percent_indicator` | remove | — | — | V1 |

---

## 11. Per-PR checklist

- [ ] Tracker row updated (§ 0).
- [ ] `flutter analyze` clean; full suite `--exclude-tags golden` in a scratch worktree.
- [ ] Reduce Motion test for anything that animates; haptic `debugHandler` test for any new haptic.
- [ ] Contrast test still passes; new colours added to it.
- [ ] Goldens refreshed with `update-goldens.yml`, a sample reviewed old vs new.
- [ ] Simulator screenshots of the changed screens, dark and light, in the PR description.
- [ ] For V2, V4, V5: Ayush checks feel and haptics on a real iPhone before merge.
- [ ] IPA size delta noted for PRs that add assets or packages.
- [ ] `docs/architecture/code-graph.json` regenerated.

---

## 12. Open questions for Ayush

None open. The four questions from the first draft (fat icon, light-theme depth, thali tilt, share card contents) were answered on 2026-10-08; see decisions 6–9 in § 1.
