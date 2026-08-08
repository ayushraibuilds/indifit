import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/presentation/consumer_date_label.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/consumer_task_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/legacy_workout_compatibility_adapter.dart';
import 'package:indifit/features/calendar/program_calendar_screen.dart';
import 'package:indifit/features/food_log/ai_meal_logger_screen.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/workout_player/player_setup_cues_panel.dart';
import 'package:indifit/features/workout_player/player_setup_presentation.dart';
import 'package:indifit/features/workout_player/widgets/exercise_set_input_card.dart';
import 'package:indifit/features/workout_player/widgets/manual_log_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> setCompactViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget themed(Widget child, {double textScale = 1}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    );
  }

  testWidgets('task shell keeps the primary action above the keyboard', (
    tester,
  ) async {
    await setCompactViewport(tester);
    var pressed = false;
    await tester.pumpWidget(
      themed(
        ConsumerTaskScaffold(
          body: const TextField(decoration: InputDecoration(labelText: 'Name')),
          primaryAction: FilledButton(
            onPressed: () => pressed = true,
            child: const Text('Continue'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(pressed, isTrue);
  });

  testWidgets('empty state is actionable and remains usable at 2x text', (
    tester,
  ) async {
    await setCompactViewport(tester);
    var pressed = false;
    await tester.pumpWidget(
      themed(
        ProductEmptyState(
          icon: Icons.fitness_center,
          title: 'Your progress starts here',
          message: 'Complete your first workout to see activity and trends.',
          action: () => pressed = true,
          actionLabel: 'Start a workout',
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Start a workout'));
    await tester.tap(find.text('Start a workout'));
    expect(pressed, isTrue);
  });

  testWidgets('onboarding shell keeps required choice and CTA visible', (
    tester,
  ) async {
    await setCompactViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: themed(const OnboardingScreen(), textScale: 1.5),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Welcome to IndiFit!'), findsOneWidget);
    expect(find.text('Select your biological sex:'), findsOneWidget);
    expect(find.text('Next Step'), findsOneWidget);
    expect(find.textContaining('0/100'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal logger presents one estimate path and a photo secondary', (
    tester,
  ) async {
    await setCompactViewport(tester);
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          foodLogsForDayProvider.overrideWith((ref, date) async => []),
        ],
        child: themed(
          AiMealLoggerScreen(
            mealType: 'dinner',
            selectedDate: DateTime(2026, 8, 8),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Log dinner'), findsOneWidget);
    expect(find.text('Estimate nutrition'), findsOneWidget);
    expect(find.text('Use a photo (optional)'), findsOneWidget);
    expect(find.text('Parse Items'), findsNothing);
    expect(find.text('Logged meals'), findsOneWidget);
    await tester.ensureVisible(find.text('Logged meals'));
    await tester.tap(find.text('Logged meals'));
    await tester.pump();
    expect(find.text('No food logged for this day'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('empty logged-food snapshot resolves without a stream wait', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final logs = await container.read(
      foodLogsForDayProvider(DateTime(2026, 8, 8)).future,
    );
    expect(logs, isEmpty);
  });

  testWidgets('meal task remains legible in both themes', (tester) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            foodLogsForDayProvider.overrideWith((ref, date) async => []),
          ],
          child: MaterialApp(
            theme: theme,
            home: const AiMealLoggerScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Log lunch'), findsOneWidget);
      expect(find.text('Describe your meal'), findsOneWidget);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        theme.extension<B05SemanticColors>()?.page,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('manual logging remains scrollable and responsive', (
    tester,
  ) async {
    await setCompactViewport(tester);
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: themed(
          Material(
            color: Colors.transparent,
            child: ManualLogSheet(selectedDate: DateTime(2026, 8, 8)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Log Completed Workout'), findsOneWidget);
    expect(find.text('Add your first exercise'), findsOneWidget);
    expect(find.text('Save Workout Session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('set entry fields stack at narrow width and large text', (
    tester,
  ) async {
    await setCompactViewport(tester);
    final weight = TextEditingController(text: '20');
    final reps = TextEditingController(text: '10');
    final duration = TextEditingController();
    final distance = TextEditingController();
    final incline = TextEditingController();
    addTearDown(() {
      weight.dispose();
      reps.dispose();
      duration.dispose();
      distance.dispose();
      incline.dispose();
    });
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: themed(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Material(
              color: Colors.transparent,
              child: SingleChildScrollView(
                child: ExerciseSetInputCard(
                  currentExercise: const RoutineExercise(
                    id: 1,
                    dayId: 1,
                    exerciseName: 'Bench Press',
                    sets: 3,
                    repsRange: '8-10',
                    orderIndex: 0,
                  ),
                  currentSetIndex: 0,
                  weightController: weight,
                  repsController: reps,
                  durationController: duration,
                  distanceController: distance,
                  inclineController: incline,
                  executionMetadata: const LegacyExerciseExecutionMetadata(
                    isCardio: false,
                    recommendedRestSeconds: 90,
                    formCue: 'Keep your shoulders steady.',
                  ),
                  isWarmUp: false,
                  selectedSetType: 'working',
                  selectedRpe: null,
                  onWarmUpChanged: (_) {},
                  onSetTypeChanged: (_) {},
                  onRpeChanged: (_) {},
                  onCompleteSet: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Log set'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('calendar labels stay natural and timezone-free', () {
    expect(
      ConsumerDateLabel.day('2026-08-08', today: DateTime(2026, 8, 8)),
      'Today',
    );
    expect(
      ConsumerDateLabel.range(
        '2026-08-08',
        '2026-08-14',
        today: DateTime(2026, 8, 8),
      ),
      'Aug 8 – Aug 14, 2026',
    );
  });

  testWidgets('calendar empty state provides a setup exit', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CalendarEmptyState(
          isDay: false,
          hasActiveProgram: false,
          onAction: () => pressed = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nothing planned here'), findsOneWidget);
    expect(find.text('Set up a training plan'), findsOneWidget);
    await tester.tap(find.text('Set up a training plan'));
    expect(pressed, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CalendarEmptyState(
          isDay: true,
          hasActiveProgram: true,
          onAction: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nothing planned today'), findsOneWidget);
    expect(find.text('Open training plan'), findsOneWidget);
    expect(
      find.textContaining('No workout is scheduled for this day'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress empty state resolves without a stream wait', (
    tester,
  ) async {
    final database = AppDatabase.memory();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProgressScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.textContaining('UTC'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('setup context is normalized before it reaches the player', () {
    final presentation = PlayerSetupPresentation.fromContext({
      'generalNote': 'Keep your ribs down.',
      'setupValues': [
        {'label': 'Bench', 'value': 'Medium'},
        {'label': 'Internal ID', 'value': 42},
      ],
      'personalCues': [
        {'cueText': 'Drive through your feet.'},
        99,
      ],
    });

    expect(presentation.note, 'Keep your ribs down.');
    expect(presentation.setupValues.map((value) => value.label), ['Bench']);
    expect(presentation.cues, ['Drive through your feet.']);
  });

  testWidgets('player setup ignores malformed persisted exercise IDs', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        PlayerSetupCuesPanel(
          exerciseName: 'Bench Press',
          frozenContext: const {
            'exerciseId': 42,
            'personalCues': [
              {'cueText': 'Keep your ribs down.'},
            ],
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Your Setup & Cues'), findsOneWidget);
    expect(find.text('Keep your ribs down.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: ProductEmptyState(
              icon: Icons.auto_graph_rounded,
              title: 'Your progress starts here',
              message:
                  'Complete your first workout to see activity and trends.',
              actionLabel: 'Start a workout',
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(ProductEmptyState),
      matchesGoldenFile('goldens/ux_w04_empty_state.png'),
    );
  });
}
