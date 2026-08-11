import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/features/calendar/calendar_read_model.dart';
import 'package:indifit/features/calendar/program_calendar_screen.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/training/training_screen.dart';
import 'package:indifit/features/workout_player/widgets/manual_log_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late final AppDatabase database;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    database = AppDatabase.memory();
  });

  for (final brightness in Brightness.values) {
    testWidgets('Training landing ${brightness.name} golden', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => _populatedTrainingSnapshot,
            ),
          ],
          child: _app(
            brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme,
            const TrainingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Start workout'), findsOneWidget);
      expect(find.text('Upper / Lower Strength'), findsOneWidget);
      expect(find.text('Lower body'), findsOneWidget);
      expect(find.text('Manage plan'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(TrainingScreen),
        matchesGoldenFile(
          'goldens/ux_r04_training_landing_${brightness.name}.png',
        ),
      );
    });
  }

  testWidgets('Training empty state remains useful at 320 and 2x text', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingLandingSnapshotProvider.overrideWith(
            (ref) async => const TrainingLandingSnapshot(
              localDate: '2026-08-09',
              timezoneId: 'Asia/Kolkata',
              todayWorkout: null,
              upcoming: [],
              recentSessions: [],
              activeProgramName: null,
            ),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _app(AppTheme.darkTheme, const TrainingScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing planned today'), findsOneWidget);
    expect(find.text('No training plan yet'), findsOneWidget);
    expect(find.text('View plan'), findsOneWidget);
    expect(find.text('Log workout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Training exposes a saved Quick Workout as the first resume action',
    (tester) async {
      _setViewport(tester, const Size(320, 568));
      final draft = WorkoutDraft(
        id: 7,
        routineName: 'Quick workout',
        currentExerciseIndex: 0,
        currentSetIndex: 0,
        elapsedSeconds: 75,
        loggedSetsJson: '{}',
        updatedAt: DateTime.utc(2026, 8, 11),
        executionSnapshotJson: '{"version":1}',
        draftSchemaVersion: 2,
        activityType: 'strength',
        executionStateJson: '{}',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => TrainingLandingSnapshot(
                localDate: '2026-08-11',
                timezoneId: 'Asia/Kolkata',
                todayWorkout: null,
                upcoming: const [],
                recentSessions: const [],
                activeProgramName: null,
                activeStrengthDraft: draft,
              ),
            ),
          ],
          child: _app(AppTheme.lightTheme, const TrainingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resume Quick workout'), findsOneWidget);
      expect(find.textContaining('active time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Training keeps Travel inside More and only with a plan', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingLandingSnapshotProvider.overrideWith(
            (ref) async => _populatedTrainingSnapshot,
          ),
        ],
        child: _app(AppTheme.darkTheme, const TrainingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More training options'));
    await tester.pumpAndSettle();
    expect(find.text('Travel mode'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingLandingSnapshotProvider.overrideWith(
            (ref) async => const TrainingLandingSnapshot(
              localDate: '2026-08-09',
              timezoneId: 'Asia/Kolkata',
              todayWorkout: null,
              upcoming: [],
              recentSessions: [],
              activeProgramName: null,
            ),
          ),
        ],
        child: _app(AppTheme.darkTheme, const TrainingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More training options'));
    await tester.pumpAndSettle();
    expect(find.text('Travel mode'), findsNothing);
    expect(find.text('Manage plan'), findsOneWidget);
  });

  test('Training only launches actionable B01 occurrence states', () {
    expect(
      canLaunchTrainingOccurrence(
        _calendarItem(
          name: 'Planned',
          localDate: '2026-08-09',
          status: 'planned',
          prescriptionCount: 1,
        ),
      ),
      isTrue,
    );
    expect(
      canLaunchTrainingOccurrence(
        _calendarItem(
          name: 'Resume',
          localDate: '2026-08-09',
          status: 'inProgress',
          prescriptionCount: 1,
        ),
      ),
      isTrue,
    );
    for (final status in const ['completed', 'partiallyCompleted', 'skipped']) {
      expect(
        canLaunchTrainingOccurrence(
          _calendarItem(
            name: status,
            localDate: '2026-08-09',
            status: status,
            prescriptionCount: 1,
          ),
        ),
        isFalse,
      );
    }
  });

  test('Training prioritizes an in-progress workout on Today', () {
    final completed = _calendarItem(
      name: 'Completed first',
      localDate: '2026-08-09',
      status: 'completed',
      prescriptionCount: 1,
    );
    final planned = _calendarItem(
      name: 'Planned later',
      localDate: '2026-08-09',
      status: 'planned',
      prescriptionCount: 1,
    );
    final resume = _calendarItem(
      name: 'Resume now',
      localDate: '2026-08-09',
      status: 'inProgress',
      prescriptionCount: 1,
    );

    expect(
      selectTrainingTodayWorkout([completed, planned, resume], '2026-08-09'),
      same(resume),
    );
  });

  testWidgets(
    'Training landing stays free of layout exceptions across the phone matrix',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final size in const [Size(320, 568), Size(390, 844)]) {
        for (final scale in const [1.0, 1.5, 2.0]) {
          for (final brightness in Brightness.values) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  trainingLandingSnapshotProvider.overrideWith(
                    (ref) async => _populatedTrainingSnapshot,
                  ),
                ],
                child: MediaQuery(
                  data: MediaQueryData.fromView(tester.view).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: _app(
                    brightness == Brightness.dark
                        ? AppTheme.darkTheme
                        : AppTheme.lightTheme,
                    const TrainingScreen(),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 250));
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Training overflowed at ${size.width}pt, ${scale}x, ${brightness.name}',
            );
          }
        }
      }
    },
  );

  testWidgets('Calendar empty state uses natural period language', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        AppTheme.darkTheme,
        Scaffold(
          appBar: AppBar(title: const Text('Calendar')),
          body: CalendarEmptyState(
            view: CalendarView.week,
            hasActiveProgram: false,
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.text('Nothing planned this week'), findsOneWidget);
    expect(
      find.text('Choose a plan when you’re ready to schedule workouts.'),
      findsOneWidget,
    );
    expect(find.textContaining('UTC'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CalendarEmptyState),
      matchesGoldenFile('goldens/ux_r04_calendar_empty_dark.png'),
    );
  });

  testWidgets('manual logging keeps a compact golden after stacking fields', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 568));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: _app(
          AppTheme.darkTheme,
          Material(
            color: Colors.transparent,
            child: ManualLogSheet(selectedDate: DateTime(2026, 8, 9)),
          ),
          textScale: 2,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ManualLogSheet),
      matchesGoldenFile('goldens/ux_r04_manual_log_compact_2x.png'),
    );
  });

  testWidgets('exercise detail keeps history and guide behind clear actions', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: _app(
          AppTheme.darkTheme,
          Scaffold(
            body: Material(
              color: Colors.transparent,
              child: ExerciseDetailsSheet(exercise: _exercise),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Plate calculator'), findsOneWidget);
    expect(find.text('View full guide'), findsOneWidget);
    expect(find.textContaining('stable-exercise'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ExerciseDetailsSheet),
      matchesGoldenFile('goldens/ux_r04_exercise_detail_dark.png'),
    );
  });
}

Widget _app(ThemeData theme, Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _populatedTrainingSnapshot = TrainingLandingSnapshot(
  localDate: '2026-08-09',
  timezoneId: 'Asia/Kolkata',
  todayWorkout: _calendarItem(
    name: 'Push day',
    localDate: '2026-08-09',
    status: 'planned',
    prescriptionCount: 6,
  ),
  upcoming: [
    _calendarItem(
      name: 'Lower body',
      localDate: '2026-08-11',
      status: 'planned',
      prescriptionCount: 5,
    ),
  ],
  recentSessions: [
    WorkoutSession(
      id: 1,
      name: 'Pull day',
      totalVolume: 1200,
      durationSeconds: 3300,
      estimatedCalories: 240,
      completedAt: DateTime.utc(2026, 8, 7),
      isSynced: false,
      activityType: 'strength',
      activitySchemaVersion: 1,
    ),
  ],
  activeProgramName: 'Upper / Lower Strength',
);

CalendarOccurrenceReadItem _calendarItem({
  required String name,
  required String localDate,
  required String status,
  required int prescriptionCount,
}) {
  final createdAt = DateTime.utc(2026, 8, 1);
  return CalendarOccurrenceReadItem(
    occurrence: ScheduledSessionOccurrence(
      id: 'r04-$name-$localDate',
      programVersionId: 'r04-version',
      sessionTemplateId: 'r04-template-$name',
      programBlockOrdinal: 0,
      programWeekOrdinal: 2,
      sessionOrdinal: 0,
      repeatOrdinal: 0,
      originalLocalDate: localDate,
      originalTimezoneId: 'Asia/Kolkata',
      effectiveLocalDate: localDate,
      effectiveTimezoneId: 'Asia/Kolkata',
      status: status,
      progressionDisposition: 'pending',
      createdAtUtc: createdAt,
    ),
    template: SessionTemplate(
      id: 'r04-template-$name',
      programWeekId: 'r04-week',
      ordinal: 0,
      name: name,
      plannedWeekday: DateTime.monday,
      activityType: 'strength',
    ),
    week: const ProgramWeek(
      id: 'r04-week',
      programVersionId: 'r04-version',
      programBlockId: 'r04-block',
      ordinalInBlock: 0,
      programWeekOrdinal: 2,
      isDeload: false,
    ),
    block: const ProgramBlock(
      id: 'r04-block',
      programVersionId: 'r04-version',
      ordinal: 0,
      name: 'Base block',
    ),
    version: ProgramVersion(
      id: 'r04-version',
      programId: 'r04-program',
      versionNumber: 1,
      status: 'published',
      origin: 'authoring',
      createdAtUtc: createdAt,
    ),
    program: Program(
      id: 'r04-program',
      name: 'Upper / Lower Strength',
      createdAtUtc: createdAt,
    ),
    prescriptions: [
      for (var index = 0; index < prescriptionCount; index++)
        ExercisePrescription(
          id: 'r04-prescription-$name-$index',
          sessionTemplateId: 'r04-template-$name',
          ordinal: index,
          exerciseNameSnapshot: 'Exercise ${index + 1}',
          plannedSets: 3,
          repsRange: '8–10',
        ),
    ],
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}

const _exercise = Exercise(
  id: 1,
  stableId: 'stable-exercise-r04',
  name: 'Flat Barbell Bench Press',
  muscleGroups: 'Chest,Triceps',
  equipment: 'Barbell',
  difficulty: 'Intermediate',
  formCues: 'Keep your feet planted.\nPress with control.',
  commonMistakes: 'Lifting your hips.\nBouncing the bar.',
  isCustom: false,
);
