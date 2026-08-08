import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/core/widgets/consumer_task_primitives.dart';
import 'package:indifit/core/widgets/indi_fit_bottom_sheet.dart';
import 'package:indifit/core/widgets/skeleton_loader.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/features/calendar/occurrence_actions_sheet.dart';
import 'package:indifit/features/calendar/program_calendar_screen.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/exercise_library/exercise_library_screen.dart';
import 'package:indifit/features/food_log/ai_meal_logger_screen.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/profile/profile_screen.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/settings/nutrition_constraints_screen.dart';
import 'package:indifit/features/workout_player/widgets/manual_log_sheet.dart';
import 'package:indifit/features/workout_player/widgets/plate_calculator_sheet.dart';
import 'package:indifit/features/workout_player/workout_player_screen.dart';
import 'package:indifit/features/workout_player/workout_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

late AppDatabase _certificationDatabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    _certificationDatabase = AppDatabase.memory();
  });

  group('UX Wave 6 visual system', () {
    final productionRoutes = <_CertificationRoute>[
      _CertificationRoute('onboarding', () => const OnboardingScreen()),
      _CertificationRoute(
        'meal logging',
        () => AiMealLoggerScreen(
          mealType: 'dinner',
          selectedDate: DateTime(2026, 8, 8),
        ),
      ),
      _CertificationRoute(
        'manual workout logging',
        () => Scaffold(
          body: Material(
            color: Colors.transparent,
            child: ManualLogSheet(selectedDate: DateTime(2026, 8, 8)),
          ),
        ),
      ),
      _CertificationRoute(
        'workout player',
        () => WorkoutPlayerScreen(
          routineName: 'Upper body strength',
          exercises: const [_certificationRoutineExercise],
        ),
      ),
      _CertificationRoute(
        'workout summary',
        () => const WorkoutSummaryScreen(
          routineName: 'Upper body strength',
          elapsedSeconds: 2700,
          loggedSets: [],
        ),
      ),
      _CertificationRoute(
        'plate calculator',
        () => const Scaffold(
          body: Material(
            color: Colors.transparent,
            child: PlateCalculatorSheet(targetWeight: 80),
          ),
        ),
      ),
      _CertificationRoute('progress', () => const ProgressScreen()),
      _CertificationRoute('calendar', () => const ProgramCalendarScreen()),
      _CertificationRoute(
        'calendar workout actions sheet',
        () => Scaffold(
          body: IndiFitBottomSheet(
            semanticLabel: 'Workout actions',
            child: OccurrenceActionsSheet(
              occurrenceItem: _certificationOccurrenceItem(),
            ),
          ),
        ),
      ),
      _CertificationRoute(
        'dietary needs',
        () => const NutritionConstraintsScreen(),
      ),
      _CertificationRoute('profile', () => const ProfileScreen()),
      _CertificationRoute(
        'exercise library',
        () => const ExerciseLibraryScreen(),
      ),
      _CertificationRoute(
        'exercise details',
        () => const Scaffold(
          body: Material(
            color: Colors.transparent,
            child: ExerciseDetailsSheet(exercise: _certificationExercise),
          ),
        ),
      ),
    ];

    final goldenRoutes = <_GoldenRoute>[
      _GoldenRoute(
        name: 'onboarding dark',
        fileName: 'ux_w06_onboarding_dark.png',
        brightness: Brightness.dark,
        builder: () => const OnboardingScreen(),
      ),
      _GoldenRoute(
        name: 'meal logging dark',
        fileName: 'ux_w06_meal_logging_dark.png',
        brightness: Brightness.dark,
        builder: () => AiMealLoggerScreen(
          mealType: 'dinner',
          selectedDate: DateTime(2026, 8, 8),
        ),
      ),
      _GoldenRoute(
        name: 'manual workout logging dark',
        fileName: 'ux_w06_manual_workout_logging_dark.png',
        brightness: Brightness.dark,
        builder: () => Scaffold(
          body: Material(
            color: Colors.transparent,
            child: ManualLogSheet(selectedDate: DateTime(2026, 8, 8)),
          ),
        ),
      ),
      _GoldenRoute(
        name: 'workout player dark',
        fileName: 'ux_w06_workout_player_dark.png',
        brightness: Brightness.dark,
        builder: () => WorkoutPlayerScreen(
          routineName: 'Upper body strength',
          exercises: const [_certificationRoutineExercise],
        ),
      ),
      _GoldenRoute(
        name: 'workout player dark at 2x text',
        fileName: 'ux_w06_workout_player_dark_2x.png',
        brightness: Brightness.dark,
        size: Size(320, 568),
        textScale: 2,
        builder: () => WorkoutPlayerScreen(
          routineName: 'Upper body strength',
          exercises: const [_certificationRoutineExercise],
        ),
      ),
      _GoldenRoute(
        name: 'workout summary dark',
        fileName: 'ux_w06_workout_summary_dark.png',
        brightness: Brightness.dark,
        builder: () => WorkoutSummaryScreen(
          routineName: 'Upper body strength',
          elapsedSeconds: 2700,
          loggedSets: [
            const WorkoutSetsCompanion(
              sessionId: Value(0),
              exerciseName: Value('Flat Barbell Bench Press'),
              weight: Value(60.0),
              reps: Value(8),
              setNumber: Value(1),
            ),
          ],
        ),
      ),
      _GoldenRoute(
        name: 'plate calculator dark',
        fileName: 'ux_w06_plate_calculator_dark.png',
        brightness: Brightness.dark,
        builder: () => const Scaffold(
          body: Material(
            color: Colors.transparent,
            child: PlateCalculatorSheet(targetWeight: 80),
          ),
        ),
      ),
      _GoldenRoute(
        name: 'progress empty light',
        fileName: 'ux_w06_progress_empty_light.png',
        brightness: Brightness.light,
        builder: () => const ProgressScreen(),
      ),
      _GoldenRoute(
        name: 'calendar loading dark',
        fileName: 'ux_w06_calendar_loading_dark.png',
        brightness: Brightness.dark,
        builder: () => const ProgramCalendarScreen(),
        target: () => find.byType(ConsumerStatusRow).last,
      ),
      _GoldenRoute(
        name: 'calendar workout actions sheet dark',
        fileName: 'ux_w06_calendar_actions_sheet_dark.png',
        brightness: Brightness.dark,
        builder: () => Scaffold(
          body: IndiFitBottomSheet(
            semanticLabel: 'Workout actions',
            child: OccurrenceActionsSheet(
              occurrenceItem: _certificationOccurrenceItem(),
            ),
          ),
        ),
        target: () => find.byType(IndiFitBottomSheet),
      ),
      _GoldenRoute(
        name: 'dietary needs light',
        fileName: 'ux_w06_dietary_needs_light.png',
        brightness: Brightness.light,
        builder: () => const NutritionConstraintsScreen(),
      ),
      _GoldenRoute(
        name: 'profile light',
        fileName: 'ux_w06_profile_light.png',
        brightness: Brightness.light,
        builder: () => const ProfileScreen(),
      ),
      _GoldenRoute(
        name: 'exercise details dark',
        fileName: 'ux_w06_exercise_details_dark.png',
        brightness: Brightness.dark,
        builder: () => const Scaffold(
          body: Material(
            color: Colors.transparent,
            child: ExerciseDetailsSheet(exercise: _certificationExercise),
          ),
        ),
      ),
    ];

    test(
      'semantic surface and navigation levels retain accessible contrast',
      () {
        for (final colors in [
          B05SemanticColors.dark,
          B05SemanticColors.light,
        ]) {
          expect(
            _contrast(colors.textPrimary, colors.page),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(colors.navigationSelected, colors.navigationSurface),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(colors.navigationUnselected, colors.navigationSurface),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(colors.onAction, colors.action),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(colors.textSecondary, colors.page),
            greaterThanOrEqualTo(4.5),
          );
          for (final role in [
            colors.success,
            colors.warning,
            colors.danger,
            colors.info,
            colors.unavailable,
          ]) {
            expect(
              _contrast(role.foreground, role.container),
              greaterThanOrEqualTo(4.5),
            );
          }
          expect(colors.section, isNot(colors.inset));
          expect(colors.inset, isNot(colors.selected));
          expect(colors.selected, isNot(colors.interactive));
        }
      },
    );

    testWidgets(
      'surface, action, loading and sheet primitives honour motion, touch and semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _app(
              theme: AppTheme.darkTheme,
              media: const MediaQueryData(disableAnimations: true),
              child: const _VisualSystemPreview(),
            ),
          );

          expect(find.bySemanticsLabel('Primary action'), findsOneWidget);
          expect(find.bySemanticsLabel('Secondary action'), findsOneWidget);
          expect(find.bySemanticsLabel('Tertiary action'), findsOneWidget);
          expect(find.byType(AnimatedSwitcher), findsNothing);
          expect(
            tester.getSize(find.byType(B05TouchTarget).first).height,
            greaterThanOrEqualTo(B05Layout.minTouchTarget),
          );
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Open sheet'));
          await tester.pumpAndSettle();
          expect(find.byType(IndiFitBottomSheet), findsOneWidget);
          expect(find.bySemanticsLabel('Visual system sheet'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    for (final route in productionRoutes) {
      testWidgets(
        '${route.name} has no exception in the light/dark accessibility matrix',
        (tester) async {
          addTearDown(tester.view.reset);
          for (final brightness in Brightness.values) {
            await _assertProductionRouteRenders(
              tester,
              route: route,
              brightness: brightness,
            );
          }
        },
      );
    }

    for (final golden in goldenRoutes) {
      testWidgets('${golden.name} representative golden', (tester) async {
        addTearDown(tester.view.reset);
        await _expectProductionRouteGolden(tester, golden);
      });
    }

    testWidgets(
      'highest-frequency forms remain usable at 320/390 and 1x/1.5x/2x text',
      (tester) async {
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});

        final forms = <String, Widget Function()>{
          'onboarding': () => const OnboardingScreen(),
          'meal logging': () => AiMealLoggerScreen(
            mealType: 'breakfast',
            selectedDate: DateTime(2026, 8, 8),
          ),
          'manual workout logging': () => Scaffold(
            body: Material(
              color: Colors.transparent,
              child: ManualLogSheet(selectedDate: DateTime(2026, 8, 8)),
            ),
          ),
          'plate calculator': () => const Scaffold(
            body: Material(
              color: Colors.transparent,
              child: PlateCalculatorSheet(targetWeight: 80),
            ),
          ),
        };

        for (final size in const [Size(320, 568), Size(390, 844)]) {
          for (final scale in const [1.0, 1.5, 2.0]) {
            for (final entry in forms.entries) {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              await tester.pumpWidget(
                _providerApp(
                  database: _certificationDatabase,
                  theme: AppTheme.darkTheme,
                  media: MediaQueryData.fromView(tester.view).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: entry.value(),
                ),
              );
              await tester.pump(const Duration(milliseconds: 250));
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '${entry.key} overflowed at ${size.width}pt and ${scale}x text',
              );
            }
          }
        }
      },
    );

    testWidgets(
      'major consumer routes remain free of layout exceptions across the complete visual matrix',
      (tester) async {
        addTearDown(tester.view.reset);
        for (final size in const [Size(320, 568), Size(390, 844)]) {
          for (final textScale in const [1.0, 1.5, 2.0]) {
            for (final brightness in Brightness.values) {
              for (final route in productionRoutes) {
                await _assertProductionRouteRenders(
                  tester,
                  route: route,
                  brightness: brightness,
                  size: size,
                  textScale: textScale,
                );
              }
            }
          }
        }
      },
    );

    testWidgets('visual system dark golden', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          media: const MediaQueryData(disableAnimations: true),
          child: const _VisualSystemPreview(),
        ),
      );
      await expectLater(
        find.byType(_VisualSystemPreview),
        matchesGoldenFile('goldens/ux_w06_visual_system_dark.png'),
      );
    });

    testWidgets('visual system light golden', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          media: const MediaQueryData(disableAnimations: true),
          child: const _VisualSystemPreview(),
        ),
      );
      await expectLater(
        find.byType(_VisualSystemPreview),
        matchesGoldenFile('goldens/ux_w06_visual_system_light.png'),
      );
    });

    testWidgets('standard bottom sheet dark golden', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          media: const MediaQueryData(disableAnimations: true),
          child: const _VisualSystemPreview(),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(IndiFitBottomSheet),
        matchesGoldenFile('goldens/ux_w06_standard_bottom_sheet_dark.png'),
      );
    });
  });
}

const _certificationExercise = Exercise(
  id: 1,
  stableId: 'exercise-bench-press',
  name: 'Flat Barbell Bench Press',
  muscleGroups: 'Chest,Triceps',
  equipment: 'Barbell',
  difficulty: 'Intermediate',
  formCues: 'Keep your feet planted.\nPress with control.',
  commonMistakes: 'Lifting your hips.\nBouncing the bar.',
  isCustom: false,
);

const _certificationRoutineExercise = RoutineExercise(
  id: 1,
  dayId: 1,
  exerciseName: 'Flat Barbell Bench Press',
  sets: 3,
  repsRange: '8-10',
  orderIndex: 0,
);

CalendarOccurrenceReadItem _certificationOccurrenceItem() {
  final createdAt = DateTime.utc(2026, 8, 1);
  return CalendarOccurrenceReadItem(
    occurrence: ScheduledSessionOccurrence(
      id: 'certification-occurrence',
      programVersionId: 'certification-version',
      sessionTemplateId: 'certification-template',
      programBlockOrdinal: 0,
      programWeekOrdinal: 0,
      sessionOrdinal: 0,
      repeatOrdinal: 0,
      originalLocalDate: '2026-08-08',
      originalTimezoneId: 'Asia/Kolkata',
      effectiveLocalDate: '2026-08-08',
      effectiveTimezoneId: 'Asia/Kolkata',
      status: 'planned',
      progressionDisposition: 'pending',
      createdAtUtc: createdAt,
    ),
    template: SessionTemplate(
      id: 'certification-template',
      programWeekId: 'certification-week',
      ordinal: 0,
      name: 'Full body strength',
      plannedWeekday: DateTime.saturday,
      activityType: 'strength',
    ),
    week: const ProgramWeek(
      id: 'certification-week',
      programVersionId: 'certification-version',
      programBlockId: 'certification-block',
      ordinalInBlock: 0,
      programWeekOrdinal: 0,
      isDeload: false,
    ),
    block: const ProgramBlock(
      id: 'certification-block',
      programVersionId: 'certification-version',
      ordinal: 0,
      name: 'Foundation',
    ),
    version: ProgramVersion(
      id: 'certification-version',
      programId: 'certification-program',
      versionNumber: 1,
      status: 'published',
      origin: 'authoring',
      createdAtUtc: createdAt,
    ),
    program: Program(
      id: 'certification-program',
      name: 'Certification plan',
      createdAtUtc: createdAt,
    ),
    prescriptions: const [
      ExercisePrescription(
        id: 'certification-prescription',
        sessionTemplateId: 'certification-template',
        ordinal: 0,
        exerciseNameSnapshot: 'Goblet squat',
        plannedSets: 3,
        repsRange: '8–10',
      ),
    ],
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}

class _CertificationRoute {
  const _CertificationRoute(this.name, this.builder);

  final String name;
  final Widget Function() builder;
}

class _GoldenRoute {
  const _GoldenRoute({
    required this.name,
    required this.fileName,
    required this.brightness,
    required this.builder,
    this.target,
    this.size = const Size(390, 844),
    this.textScale = 1,
  });

  final String name;
  final String fileName;
  final Brightness brightness;
  final Widget Function() builder;
  final Finder Function()? target;
  final Size size;
  final double textScale;
}

Future<void> _assertProductionRouteRenders(
  WidgetTester tester, {
  required _CertificationRoute route,
  required Brightness brightness,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final theme = brightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.lightTheme;

  try {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _providerApp(
        database: _certificationDatabase,
        theme: theme,
        media: MediaQueryData.fromView(tester.view).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: route.builder(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.takeException(),
      isNull,
      reason:
          '${route.name} must render at ${size.width}pt, $textScale× text, in ${brightness.name} mode',
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Riverpod cancels the calendar's Drift stream during disposal. Give its
    // zero-duration cleanup timer one frame instead of leaving a pending timer
    // in the widget binding.
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Future<void> _expectProductionRouteGolden(
  WidgetTester tester,
  _GoldenRoute golden,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = golden.size;
  tester.view.devicePixelRatio = 1;

  try {
    await tester.pumpWidget(
      _providerApp(
        database: _certificationDatabase,
        theme: golden.brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        media: MediaQueryData.fromView(tester.view).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(golden.textScale),
        ),
        child: golden.builder(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(
      golden.target?.call() ?? find.byType(Scaffold).first,
      matchesGoldenFile('goldens/${golden.fileName}'),
    );
    expect(tester.takeException(), isNull, reason: '${golden.name} rendered');
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }
}

class _VisualSystemPreview extends StatelessWidget {
  const _VisualSystemPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IndiFit visual system')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(B05Layout.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily focus', style: B05Typography.pageTitle(context)),
            const SizedBox(height: B05Layout.space4),
            Text(
              'Clear decisions, useful numbers, and one next step.',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space16),
            B05Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today’s workout', style: B05Typography.title(context)),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    'Upper body strength · 45 min',
                    style: B05Typography.body(context),
                  ),
                  const SizedBox(height: B05Layout.space12),
                  const B05StatusMessage(
                    status: B05SemanticStatus.success,
                    label: 'Ready when you are',
                    value: '3 working sets planned',
                  ),
                  const SizedBox(height: B05Layout.space12),
                  const B05ActionGroup(
                    children: [
                      B05ActionButton(
                        label: 'Primary action',
                        icon: Icons.play_arrow_rounded,
                        onPressed: _noOp,
                      ),
                      B05ActionButton(
                        label: 'Secondary action',
                        emphasis: B05ActionEmphasis.secondary,
                        onPressed: _noOp,
                      ),
                      B05ActionButton(
                        label: 'Tertiary action',
                        emphasis: B05ActionEmphasis.tertiary,
                        onPressed: _noOp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space16),
            const B05Surface(
              tone: B05SurfaceTone.inset,
              child: Row(
                children: [
                  SkeletonBox(width: 40, height: 40, borderRadius: 8),
                  SizedBox(width: B05Layout.space12),
                  Expanded(child: SkeletonBox(width: 180, height: 14)),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space16),
            B05ActionButton(
              label: 'Open sheet',
              icon: Icons.tune_rounded,
              onPressed: () => showIndiFitBottomSheet<void>(
                context: context,
                semanticLabel: 'Visual system sheet',
                builder: (_) => const Padding(
                  padding: EdgeInsets.all(B05Layout.space20),
                  child: Text('A calm, opaque, keyboard-aware sheet.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _app({
  required ThemeData theme,
  required MediaQueryData media,
  required Widget child,
}) {
  return MediaQuery(
    data: media,
    child: MaterialApp(theme: theme, home: child),
  );
}

Widget _providerApp({
  required AppDatabase database,
  required ThemeData theme,
  required MediaQueryData media,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: MediaQuery(
      data: media,
      child: MaterialApp(theme: theme, home: child),
    ),
  );
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void _noOp() {}
