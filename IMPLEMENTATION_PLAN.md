# IndiFit — Comprehensive Implementation Plan

> Generated: 2026-07-24  
> Scope: All 18 user-reported issues + UI analysis findings  
> Estimated Effort: 6–8 weeks (1 developer, full-time)

---

## 1. Issue Consolidation

### User's 18 Points (Cross-Referenced with Codebase Findings)

| # | User Issue | Root Cause Found in Code | Priority |
|---|-----------|-------------------------|----------|
| 1 | No manual split creation, no preloaded templates, only AI generation | `RoutineDisplayScreen` only shows AI-generated routines; `WorkoutRepository.saveRoutine` exists but no UI for manual entry | P1 |
| 2 | Exercise library empty, no search results | `seedExercisesFromAsset()` in `app_database.dart:163` has empty `catch (_) {}`; `searchExercises` query in `workout_repository.dart:44` may fail if table is empty; `exercises.json` may be missing from `pubspec.yaml` assets | P0 |
| 3 | BMI uses hardcoded 170cm; height never asked in onboarding | `progress_screen.dart:121` has `const double heightCm = 170.0`; onboarding (`onboarding_screen.dart`) DOES ask height but stores it — `progress_screen` ignores the stored value | P1 |
| 4 | Onboarding broken or missing | `onboarding_screen.dart` exists and is functional, but `main.dart` skips it — no `onboarding_completed` gate before launching app | P1 |
| 5 | Health activity should be at bottom | Dashboard layout order: date bar → streak → calories → health → meals; user wants health moved below meals | P2 |
| 6 | Light mode: tabs, headers invisible | `AppTheme.lightTheme` uses `Color(0xFFF8FAFC)` scaffold bg but some widgets hardcode `AppColors.background` (dark); `AppBar` titles in light mode may use wrong color | P1 |
| 7 | Streak freeze can be spammed to 100 tokens | `StreakFreezeCard` calls `controller.purchaseStreakFreeze()` with no cost logic; `purchaseStreakFreeze` in `dashboard_controller.dart:145` just increments count unconditionally | P1 |
| 8 | AI meal estimator cut off in Log Food Item sheet | `QuickLogBottomSheet` only shows 4 meal-type buttons; AI estimate/thali builder/barcode scanner options are not surfaced here | P1 |
| 9 | No section to log today's workout after/during workout | `WorkoutSummaryScreen` exists but is minimal; no "Log Past Workout" flow for days other than today; dashboard has no workout logging CTA | P1 |
| 10 | Hydration tracker default is 2500ml, not adjustable | `WaterNotifier` in `providers.dart:65` hardcodes `waterGoal: 8` (8 × 250ml = 2000ml); settings screen may not expose glass size adjuster | P2 |
| 11 | Need popular splits: BRO, PPL | No preloaded routine templates in DB or UI | P2 |
| 12 | Achievements system | `achievement_service.dart` and `achievements_screen.dart` exist but not wired into main nav; no achievement triggers in workout/food flows | P2 |
| 13 | Very low engagement/interactivity | No gamification, no social features, no streak animations, no milestone celebrations beyond PR confetti | P3 |
| 14 | Correct form description/visuals missing | `Exercise` table has `formCues` and `commonMistakes` columns but `ExerciseDetailsSheet` may not render them; no images/videos linked | P2 |
| 15 | No-equipment workout doesn't work; only gym equipment shown | AI routine generator always assumes gym; no bodyweight/home workout template | P2 |
| 16 | Shouldn't start workout for past days; only log past workouts | `RoutineDisplayScreen` allows starting any day's workout; no date validation | P1 |
| 17 | Timer pauses when app minimized/screen off | `RestTimerBottomSheet` likely uses `Timer.periodic` without `WakelockPlus` or background isolate; `wakelock_plus` is in pubspec but may not be used in timer | P1 |
| 18 | Music integration (Spotify/YouTube Music) | Not implemented; requires platform-specific plugins (`audio_service`, `spotify_sdk`) | P3 |

---

## 2. Priority Matrix

| Priority | Theme | Count | Sprint Allocation |
|----------|-------|-------|-------------------|
| **P0 — Ship Blocker** | Data integrity, crashes, empty states | 1 | Sprint 1 |
| **P1 — High** | Core flow broken, UX confusion, missing features | 8 | Sprints 1–3 |
| **P2 — Medium** | Feature gaps, template content, polish | 6 | Sprints 3–5 |
| **P3 — Nice-to-Have** | Engagement, social, music | 3 | Sprints 5–6 |

---

## 3. Phase-by-Phase Implementation

---

### Phase 1: Critical Data & Onboarding (Week 1)

**Goal:** Fix broken data flows, ensure onboarding works, fix exercise library.

#### 1.1 Fix Exercise Library Seeding
**Files:** `lib/data/database/app_database.dart`, `pubspec.yaml`

The exercise library is empty because `seedExercisesFromAsset()` silently fails. Possible causes:
- `assets/data/exercises.json` not declared in `pubspec.yaml`
- JSON parse error swallowed by `catch (_) {}`
- `exercises.json` file missing or malformed

**Implementation:**

```dart
// app_database.dart — replace seedExercisesFromAsset
Future<void> seedExercisesFromAsset() async {
  try {
    final exercisesJson = await rootBundle.loadString('assets/data/exercises.json');
    final List<dynamic> exercisesList = jsonDecode(exercisesJson);
    
    if (exercisesList.isEmpty) {
      AppLogger.warning('exercises.json is empty');
      return;
    }
    
    final exerciseCompanions = exercisesList.map((item) {
      return ExercisesCompanion.insert(
        name: item['name'] as String,
        muscleGroups: (item['muscle_groups'] as List<dynamic>).join(','),
        equipment: item['equipment'] as String,
        difficulty: item['difficulty'] as String,
        formCues: (item['form_cues'] as List<dynamic>).join('\n'),
        commonMistakes: (item['common_mistakes'] as List<dynamic>).join('\n'),
        youtubeId: Value(item['youtube_id'] as String?),
      );
    }).toList();
    
    await batch((b) => b.insertAll(exercises, exerciseCompanions));
    AppLogger.info('Seeded ${exerciseCompanions.length} exercises');
  } catch (e, st) {
    AppLogger.error('Failed to seed exercises', e, st, 'AppDatabase');
    // Do NOT swallow — rethrow so caller can show error UI
    rethrow;
  }
}
```

**Also verify in `pubspec.yaml`:**
```yaml
assets:
  - assets/data/
  - assets/data/regional/
  # Ensure exercises.json exists at assets/data/exercises.json
```

**Add a fallback empty-state retry button in `exercise_library_screen.dart`:**
```dart
// In _buildEmptyState()
if (query.isEmpty) ...[
  const SizedBox(height: 16),
  ElevatedButton.icon(
    onPressed: () async {
      setState(() => _loading = true);
      try {
        await ref.read(databaseProvider).seedExercisesFromAsset();
        await _loadExercises();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load exercises: $e')),
        );
      }
    },
    icon: const Icon(Icons.refresh),
    label: const Text('Reload Exercise Database'),
  ),
]
```

---

#### 1.2 Fix Onboarding Gate
**Files:** `lib/main.dart`, `lib/core/router/app_router.dart`

Onboarding exists but is never shown on first launch. Add a check before routing.

```dart
// main.dart — add before runApp
final prefs = await SharedPreferences.getInstance();
final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

// Pass this to the router or App
```

```dart
// app_router.dart — add redirect logic
final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  
  return GoRouter(
    initialLocation: onboardingCompleted ? '/' : '/onboarding',
    routes: [
      // ... existing routes
    ],
  );
});
```

---

#### 1.3 Fix Floating-Point Weight Display
**Files:** `lib/features/progress/progress_screen.dart`, `lib/features/dashboard/widgets/weight_sparkline_card.dart`

```dart
// progress_screen.dart:404
final dateStr = '${m.recordedAt.day}/${m.recordedAt.month}/${m.recordedAt.year}';
final List<String> details = [];
if (m.weight != null) details.add('Weight: ${m.weight!.toStringAsFixed(1)}kg');
// Also fix the measurement list in the bottom sheet:
Text('Weight: ${m.weight?.toStringAsFixed(1) ?? "--"} kg')
```

---

### Phase 2: Core UX Fixes (Weeks 2–3)

#### 2.1 Fix BMI Using Stored Height (Not Hardcoded 170cm)
**Files:** `lib/features/progress/progress_screen.dart`

```dart
// progress_screen.dart:121 — replace hardcoded height
Widget _buildBmiHealthCard() {
  final double? weightKg = _measurements.isNotEmpty ? _measurements.first.weight : null;

  if (weightKg == null || weightKg <= 0) {
    return const SizedBox.shrink();
  }

  // Read height from SharedPreferences (set during onboarding)
  final heightCm = _userHeightCm ?? 170.0; // fallback only if never onboarded
  
  // ... rest of BMI calc
}
```

Add `_userHeightCm` field to state, load it in `_loadProgressLogs`:
```dart
Future<void> _loadProgressLogs() async {
  // ... existing code ...
  final prefs = await SharedPreferences.getInstance();
  _userHeightCm = prefs.getDouble('user_height') ?? 170.0;
  // ...
}
```

---

#### 2.2 Fix Light Mode Visibility
**Files:** `lib/core/theme/app_theme.dart`, `lib/core/theme/colors.dart`

Several screens use `AppBar` with `backgroundColor: AppColors.background` which is dark even in light mode.

```dart
// app_theme.dart — add adaptive app bar theme
static ThemeData get lightTheme {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFC),
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
    ),
    // ... rest
  );
}
```

Audit all screens that manually set `AppBar` background:
- `routine_display_screen.dart:63` — remove `backgroundColor: AppColors.background`
- `exercise_library_screen.dart:92` — remove `backgroundColor: AppColors.background`
- `progress_screen.dart:69` — remove `backgroundColor: AppColors.background`
- `settings_screen.dart` — check and fix similarly

Replace with `backgroundColor: Theme.of(context).colorScheme.surface`.

---

#### 2.3 Fix Streak Freeze Spam
**Files:** `lib/features/dashboard/widgets/streak_freeze_card.dart`, `lib/features/dashboard/dashboard_controller.dart`

The freeze button has no cost mechanic. Add a weekly cooldown:

```dart
// dashboard_controller.dart
Future<void> purchaseStreakFreeze() async {
  final prefs = await SharedPreferences.getInstance();
  final lastClaimed = prefs.getInt('streak_freeze_last_claimed_week');
  final now = DateTime.now();
  final currentWeek = now.year * 100 + ((now.dayOfYear - 1) ~/ 7);
  
  if (lastClaimed == currentWeek) {
    throw StateError('You can only claim 1 freeze per week');
  }
  
  final current = prefs.getInt('streak_freezes_count') ?? 1;
  await prefs.setInt('streak_freezes_count', current + 1);
  await prefs.setInt('streak_freeze_last_claimed_week', currentWeek);
  await computeStreak();
}
```

```dart
// streak_freeze_card.dart — handle error
ElevatedButton(
  onPressed: () async {
    try {
      await controller.purchaseStreakFreeze();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claimed 1 Streak Freeze token! ❄️')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  },
)
```

---

#### 2.4 Fix Quick-Log Bottom Sheet (Add AI & Barcode)
**Files:** `lib/features/dashboard/widgets/quick_log_bottom_sheet.dart`

The current sheet only shows meal type selectors. Add AI estimate, barcode scanner, and thali builder.

```dart
class QuickLogBottomSheet extends StatelessWidget {
  // ... existing meal buttons ...
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Log Food Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Row 1: Meal types
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mealQuickActionButton(context, 'Breakfast', 'breakfast', Icons.breakfast_dining_rounded),
              _mealQuickActionButton(context, 'Lunch', 'lunch', Icons.lunch_dining_rounded),
              _mealQuickActionButton(context, 'Dinner', 'dinner', Icons.dinner_dining_rounded),
              _mealQuickActionButton(context, 'Snacks', 'snack', Icons.cookie_rounded),
            ],
          ),
          const Divider(height: 32),
          // Row 2: Smart logging
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _smartActionButton(context, 'AI Estimate', Icons.auto_awesome_rounded, () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AiMealLoggerScreen(mealType: 'snack')));
              }),
              _smartActionButton(context, 'Barcode', Icons.qr_code_scanner_rounded, () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
              }),
              _smartActionButton(context, 'Thali Builder', Icons.set_meal_rounded, () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ThaliBuilderScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _smartActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
```

---

#### 2.5 Fix Workout Timer (Background + Wakelock)
**Files:** `lib/features/workout_player/widgets/rest_timer_bottom_sheet.dart`

Use `WakelockPlus` to keep screen on and consider a foreground service for background timer.

```dart
// In RestTimerBottomSheet initState
@override
void initState() {
  super.initState();
  WakelockPlus.enable(); // Keep screen on during rest
  _startTimer();
}

@override
void dispose() {
  WakelockPlus.disable();
  _timer?.cancel();
  super.dispose();
}
```

For background timer persistence, save the end timestamp to SharedPreferences and check elapsed on resume:
```dart
// When timer starts
final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
prefs.setString('rest_timer_end', endTime.toIso8601String());

// In initState, check if a timer was running
final savedEnd = prefs.getString('rest_timer_end');
if (savedEnd != null) {
  final end = DateTime.parse(savedEnd);
  final now = DateTime.now();
  if (end.isAfter(now)) {
    // Resume with remaining time
    remainingSeconds = end.difference(now).inSeconds;
  }
}
```

---

#### 2.6 Fix Hydration Tracker Default & Adjustability
**Files:** `lib/core/di/providers.dart`, `lib/features/settings/widgets/water_settings_section.dart`

```dart
// providers.dart — read from prefs, allow adjustment
class WaterNotifier extends StateNotifier<WaterState> {
  // ... existing code ...
  
  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final savedDate = prefs.getString('water_last_logged_date') ?? todayStr;
    
    int logged = prefs.getInt('water_logged') ?? 0;
    int goal = prefs.getInt('water_goal') ?? 8;        // 8 glasses default
    int size = prefs.getInt('water_glass_size') ?? 250; // 250ml per glass
    
    // ... rest of loadState
  }
}
```

Add water goal adjustment in settings:
```dart
// water_settings_section.dart
ListTile(
  title: const Text('Daily Water Goal'),
  subtitle: Text('${state.waterGoal} glasses (${state.waterGoal * state.glassSize}ml)'),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () => notifier.updateGoal((state.waterGoal - 1).clamp(4, 16)),
      ),
      Text('${state.waterGoal}'),
      IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => notifier.updateGoal((state.waterGoal + 1).clamp(4, 16)),
      ),
    ],
  ),
)
```

---

#### 2.7 Prevent Starting Workouts for Past Days
**Files:** `lib/features/workout_player/routine_display_screen.dart`

```dart
// In _buildRoutineLayout, before Start Workout button:
final isToday = _selectedDayOfWeek == DateTime.now().weekday;

if (!day.isRestDay && exercises.isNotEmpty)
  ElevatedButton.icon(
    onPressed: isToday
        ? () { /* start workout */ }
        : () {
            // Show "Log Past Workout" dialog instead
            showModalBottomSheet(
              context: context,
              builder: (_) => _buildPastWorkoutLogger(day, exercises),
            );
          },
    icon: Icon(isToday ? Icons.play_arrow_rounded : Icons.edit_calendar_rounded),
    label: Text(isToday ? 'Start Workout' : 'Log Past Workout'),
  )
```

Create `_buildPastWorkoutLogger` that opens the workout player in "past logging mode" (no timer, date picker pre-selected).

---

### Phase 3: Feature Additions (Weeks 3–5)

#### 3.1 Preloaded Workout Splits (BRO, PPL, UL, Full Body)
**Files:** `lib/data/repositories/workout_repository.dart`, `lib/features/workout_player/routine_display_screen.dart`

Add a `WorkoutTemplate` class and seed popular splits:

```dart
// workout_repository.dart — add method
Future<void> seedPreloadedTemplates() async {
  final templates = [
    // Bro Split
    _buildRoutineData(
      name: 'Classic Bro Split',
      goal: 'hypertrophy',
      days: [
        RoutineDayWithExercises(dayName: 'Day 1: Chest', dayOfWeek: 1, isRestDay: false, exercises: [
          RoutineExerciseInput(name: 'Flat Barbell Bench Press', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Incline Dumbbell Press', sets: 3, repsRange: '10-12'),
          RoutineExerciseInput(name: 'Cable Fly', sets: 3, repsRange: '12-15'),
        ]),
        RoutineDayWithExercises(dayName: 'Day 2: Back', dayOfWeek: 2, isRestDay: false, exercises: [
          RoutineExerciseInput(name: 'Lat Pulldown', sets: 4, repsRange: '10-12'),
          RoutineExerciseInput(name: 'Barbell Row', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Deadlift', sets: 3, repsRange: '5'),
        ]),
        // ... etc
      ],
    ),
    // Push Pull Legs
    _buildRoutineData(
      name: 'Push Pull Legs (PPL)',
      goal: 'hypertrophy',
      days: [
        RoutineDayWithExercises(dayName: 'Push: Chest/Shoulders/Triceps', dayOfWeek: 1, isRestDay: false, exercises: [
          RoutineExerciseInput(name: 'Flat Barbell Bench Press', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Dumbbell Shoulder Press', sets: 3, repsRange: '10-12'),
          RoutineExerciseInput(name: 'Tricep Pushdown', sets: 3, repsRange: '12-15'),
        ]),
        RoutineDayWithExercises(dayName: 'Pull: Back/Biceps', dayOfWeek: 2, isRestDay: false, exercises: [
          RoutineExerciseInput(name: 'Lat Pulldown', sets: 4, repsRange: '10-12'),
          RoutineExerciseInput(name: 'Barbell Row', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Bicep Dumbbell Curl', sets: 3, repsRange: '12'),
        ]),
        RoutineDayWithExercises(dayName: 'Legs: Quads/Hams/Calves', dayOfWeek: 3, isRestDay: false, exercises: [
          RoutineExerciseInput(name: 'Barbell Squat', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Romanian Deadlift', sets: 4, repsRange: '10'),
          RoutineExerciseInput(name: 'Leg Press', sets: 3, repsRange: '12-15'),
        ]),
        // Rest day template
      ],
    ),
    // Full Body (Beginner)
    _buildRoutineData(
      name: 'Full Body 3x/Week',
      goal: 'strength',
      days: [
        RoutineDayWithExercises(dayName: 'Full Body A', dayOfWeek: 1, isRestDay: false, exercises: [
          RoutineExerciseInput(name: 'Barbell Squat', sets: 3, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Flat Barbell Bench Press', sets: 3, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Lat Pulldown', sets: 3, repsRange: '10-12'),
        ]),
        // ...
      ],
    ),
  ];
  
  for (final template in templates) {
    await saveRoutine(
      name: template.name,
      goal: template.goal,
      days: template.days,
    );
  }
}
```

**UI in `RoutineDisplayScreen` empty state:**
```dart
// Add below "Generate Split with AI" button:
const SizedBox(height: 12),
OutlinedButton.icon(
  onPressed: () => _showTemplatePicker(context),
  icon: const Icon(Icons.folder_open_outlined),
  label: const Text('Choose Pre-built Split'),
),
```

---

#### 3.2 Manual Split Creator
**Files:** `lib/features/workout_player/routine_editor_screen.dart` (enhance existing)

The `routine_editor_screen.dart` already exists but may be minimal. Expand it to:
1. Add/remove days
2. Add/remove exercises per day
3. Edit sets/reps
4. Save as custom routine

Add a route in `app_router.dart`:
```dart
GoRoute(
  path: '/routine-editor',
  builder: (context, state) => const RoutineEditorScreen(),
),
```

Add FAB to `RoutineDisplayScreen`:
```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: () => context.push('/routine-editor'),
  icon: const Icon(Icons.edit),
  label: const Text('Edit Split'),
),
```

---

#### 3.3 Home Workout / No Equipment Templates
**Files:** `lib/data/repositories/ai_routine_service.dart`, `backend/main.py`

Backend: add `equipment: "none"` support:
```python
@app.post("/api/ai/routine")
async def generate_routine(req: RoutineRequest):
    # ... existing prompt ...
    if req.equipment.lower() == "none" or req.equipment.lower() == "bodyweight":
        prompt += "\nIMPORTANT: The user has NO equipment. Only bodyweight exercises."
```

Preload home workout templates:
```dart
// Home Workout Template
_buildRoutineData(
  name: 'Home Bodyweight',
  goal: 'general_fitness',
  days: [
    RoutineDayWithExercises(dayName: 'Upper Body', dayOfWeek: 1, isRestDay: false, exercises: [
      RoutineExerciseInput(name: 'Push-ups', sets: 4, repsRange: '15-20'),
      RoutineExerciseInput(name: 'Diamond Push-ups', sets: 3, repsRange: '10-15'),
      RoutineExerciseInput(name: 'Chair Dips', sets: 3, repsRange: '12-15'),
    ]),
    RoutineDayWithExercises(dayName: 'Lower Body', dayOfWeek: 2, isRestDay: false, exercises: [
      RoutineExerciseInput(name: 'Air Squats', sets: 4, repsRange: '20-25'),
      RoutineExerciseInput(name: 'Lunges', sets: 3, repsRange: '15 each'),
      RoutineExerciseInput(name: 'Glute Bridges', sets: 3, repsRange: '20'),
    ]),
    // ...
  ],
),
```

---

#### 3.4 Enhanced Workout Summary Screen
**Files:** `lib/features/workout_player/workout_summary_screen.dart`

Expand with:
- Total volume, duration, calories
- PRs hit (list)
- Comparison to last session
- Shareable card (image generation)
- "Log Post-Workout Meal" button
- Rate workout difficulty (RPE)

```dart
class WorkoutSummaryScreen extends StatelessWidget {
  // ... existing params ...
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 64),
              const Text('Workout Complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildStatsGrid(),
              if (prs.isNotEmpty) _buildPrsSection(),
              _buildComparisonSection(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/food?mealType=snack'),
                icon: const Icon(Icons.restaurant),
                label: const Text('Log Post-Workout Meal'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _shareWorkout,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

#### 3.5 Achievements System Wiring
**Files:** `lib/core/services/achievement_service.dart`, `lib/features/progress/achievements_screen.dart`

Wire achievements into workout completion, food logging, and streak events:

```dart
// achievement_service.dart
class AchievementService {
  static Future<void> checkWorkoutAchievements({
    required int totalWorkouts,
    required int totalVolume,
    required int prsThisSession,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // First Workout
    if (totalWorkouts == 1) await _unlock('first_workout', prefs);
    // 10 Workouts
    if (totalWorkouts == 10) await _unlock('ten_workouts', prefs);
    // 50K Volume
    if (totalVolume >= 50000) await _unlock('fifty_k_volume', prefs);
    // PR Hunter
    if (prsThisSession >= 3) await _unlock('pr_hunter', prefs);
  }
  
  static Future<void> _unlock(String id, SharedPreferences prefs) async {
    final key = 'achievement_$id';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    await prefs.setInt('${key}_unlocked_at', DateTime.now().millisecondsSinceEpoch);
    // TODO: Show in-app notification
  }
}
```

Call from `workout_player_screen.dart` after `finishWorkout`:
```dart
await AchievementService.checkWorkoutAchievements(
  totalWorkouts: sessions.length,
  totalVolume: state.loggedSets.fold(0, (sum, s) => sum + (s.weight.value * s.reps.value).round()),
  prsThisSession: state.loggedSets.where((s) => s.isPr.value == true).length,
);
```

Add achievements tab to bottom nav or progress screen.

---

#### 3.6 Exercise Form Visuals
**Files:** `lib/features/exercise_library/exercise_details_sheet.dart`

Render `formCues` and `commonMistakes` with better formatting. Add placeholder for video/image:

```dart
// exercise_details_sheet.dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (exercise.youtubeId != null)
      Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_filled, size: 48, color: AppColors.primary),
              const SizedBox(height: 8),
              Text('Form Video', style: TextStyle(color: AppColors.textSecondary)),
              // Use url_launcher to open YouTube
            ],
          ),
        ),
      ),
    const SizedBox(height: 16),
    _buildSection('Form Cues', exercise.formCues.split('\n')),
    _buildSection('Common Mistakes', exercise.commonMistakes.split('\n')),
  ],
)
```

---

### Phase 4: Engagement & Polish (Weeks 5–6)

#### 4.1 Move Health Activity to Bottom
**Files:** `lib/features/dashboard/dashboard_screen.dart`

Reorder the dashboard Column:
```dart
// Current order: Header → Date → Streak → Calories → Health → Meals → Workout → Water → Weight
// New order: Header → Date → Streak → Calories → Meals → Workout → Water → Weight → Health
```

---

#### 4.2 Macro Visualization (Donut Chart)
**Files:** `lib/features/dashboard/widgets/calorie_ring_card.dart`

Replace plain text with `fl_chart` donut chart:

```dart
SizedBox(
  height: 180,
  child: PieChart(
    PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 50,
      sections: [
        PieChartSectionData(
          value: eatenProtein * 4, // caloric value
          color: Colors.green,
          radius: 30,
          title: '${eatenProtein.toStringAsFixed(0)}g',
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        PieChartSectionData(
          value: eatenCarbs * 4,
          color: Colors.amber,
          radius: 30,
          title: '${eatenCarbs.toStringAsFixed(0)}g',
        ),
        PieChartSectionData(
          value: eatenFat * 9,
          color: Colors.red.shade300,
          radius: 30,
          title: '${eatenFat.toStringAsFixed(0)}g',
        ),
        // Remaining calories
        PieChartSectionData(
          value: (calorieGoal - eatenCalories).clamp(0, double.infinity).toDouble(),
          color: AppColors.border,
          radius: 25,
          title: '',
        ),
      ],
    ),
  ),
)
```

---

#### 4.3 Music Integration (Spotify / YT Music)
**Files:** New file `lib/core/services/music_service.dart`

Use `url_launcher` as a lightweight first step:
```dart
class MusicService {
  static Future<void> openSpotify() async {
    final uri = Uri.parse('spotify:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  static Future<void> openYouTubeMusic() async {
    final uri = Uri.parse('vnd.youtube.music:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
```

Add a floating music button in `WorkoutPlayerScreen`:
```dart
floatingActionButton: FloatingActionButton.small(
  onPressed: () => _showMusicPicker(context),
  child: const Icon(Icons.music_note),
),
```

**Future:** For deeper integration (play/pause from app), use `audio_service` + `just_audio` package (already in pubspec).

---

#### 4.4 Dashboard Quick Actions (Meal Templates, Recent Foods)
**Files:** `lib/features/dashboard/widgets/dashboard_meal_section.dart`

Show recent foods and meal templates:
```dart
// Below each meal card, add horizontal scroll of recent items
if (logsForMeal.isNotEmpty)
  SizedBox(
    height: 40,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: logsForMeal.length,
      itemBuilder: (_, i) => Chip(
        label: Text('${logsForMeal[i].name} ${logsForMeal[i].calories}kcal'),
        onDeleted: () => _deleteLog(logsForMeal[i].id),
      ),
    ),
  )
```

---

## 4. Testing Strategy

| Phase | Test Type | Coverage |
|-------|-----------|----------|
| 1 | Unit | Exercise seeding, BMI calc, onboarding prefs |
| 1 | Integration | Onboarding flow → dashboard |
| 2 | Widget | Light/dark theme toggle, bottom sheet actions |
| 2 | Integration | Workout player timer behavior (background/foreground) |
| 3 | Unit | Template generation, achievement unlocking |
| 3 | Integration | Full workout flow: start → log sets → finish → summary |
| 4 | Widget | Dashboard chart rendering, settings adjustments |
| 4 | E2E | Day-in-the-life: log meals → workout → view progress |

---

## 5. Acceptance Criteria Summary

### P0 (Must Pass Before Any Release)
- [ ] Exercise library loads and shows exercises on first install
- [ ] Search for "bench" returns "Flat Barbell Bench Press"
- [ ] Weight displays as `76.4 kg` not `76.39999999999989kg`
- [ ] Onboarding runs on first launch and stores height/weight

### P1 (v1.0 Quality Bar)
- [ ] BMI uses actual user height from onboarding
- [ ] Light mode is fully usable (all text visible)
- [ ] Streak freeze limited to 1 per week
- [ ] Quick-log sheet shows AI estimate, barcode, thali builder
- [ ] Rest timer keeps running when screen off (via wakelock + timestamp)
- [ ] Water goal adjustable in settings (4–16 glasses)
- [ ] Past days show "Log Past Workout" not "Start Workout"

### P2 (Feature Complete)
- [ ] Preloaded splits available: Bro, PPL, Full Body, Home Bodyweight
- [ ] Manual split editor works
- [ ] Workout summary shows PRs, comparison, share button
- [ ] Achievements unlock and display
- [ ] Exercise details show form cues and common mistakes
- [ ] Home workout option in AI generator

### P3 (Engagement Layer)
- [ ] Health activity card moved to bottom
- [ ] Calorie ring shows donut chart
- [ ] Music launcher in workout player
- [ ] Dashboard shows recent foods per meal

---

## 6. File Reference Map

| Feature | Primary Files | Secondary Files |
|---------|--------------|-----------------|
| Exercise Library | `exercise_library_screen.dart`, `app_database.dart` | `workout_repository.dart`, `pubspec.yaml` |
| Onboarding | `main.dart`, `app_router.dart` | `onboarding_screen.dart` |
| BMI | `progress_screen.dart` | `onboarding_screen.dart` (height storage) |
| Light Mode | `app_theme.dart`, `colors.dart` | All `AppBar` declarations |
| Streak Freeze | `streak_freeze_card.dart`, `dashboard_controller.dart` | `providers.dart` |
| Quick Log | `quick_log_bottom_sheet.dart` | `dashboard_screen.dart` |
| Timer | `rest_timer_bottom_sheet.dart` | `workout_player_screen.dart` |
| Water | `providers.dart` | `water_settings_section.dart` |
| Splits | `routine_display_screen.dart`, `workout_repository.dart` | `routine_editor_screen.dart` |
| Summary | `workout_summary_screen.dart` | `workout_player_screen.dart` |
| Achievements | `achievement_service.dart` | `achievements_screen.dart` |
| Music | `music_service.dart` (new) | `workout_player_screen.dart` |
| Charts | `calorie_ring_card.dart` | `fl_chart` usage |

---

> **Ready to start implementing?** I recommend beginning with **Phase 1** (exercise seeding fix + onboarding gate) as these are ship-blockers that affect every new user. I can write the exact code changes for any of these items.
