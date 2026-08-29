import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/exercise_library/exercise_library_screen.dart';
import 'package:indifit/features/media/b05_exercise_visual_registry.dart';
import 'package:indifit/features/workout_player/widgets/plate_calculator_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockExercises = [
    const Exercise(
      id: 1,
      stableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
      name: 'Flat Barbell Bench Press',
      muscleGroups: 'Chest,Triceps,Shoulders',
      equipment: 'Barbell',
      difficulty: 'Intermediate',
      formCues: 'Keep feet flat on floor\nLower bar to chest',
      commonMistakes: 'Flaring elbows',
      isCustom: false,
    ),
    const Exercise(
      id: 2,
      stableId: '256fb9bd-77a8-5ea5-ab07-cb10d65bce67',
      name: 'Incline Dumbbell Bench Press',
      muscleGroups: 'Chest,Shoulders,Triceps',
      equipment: 'Dumbbells',
      difficulty: 'Intermediate',
      formCues: 'Set incline to 30 degrees',
      commonMistakes: 'Arching back',
      isCustom: false,
    ),
    const Exercise(
      id: 3,
      stableId: '9cb62691-e65f-56f4-9a93-c82a4834a448',
      name: 'Tricep Pushdown',
      muscleGroups: 'Triceps',
      equipment: 'Cable',
      difficulty: 'Beginner',
      formCues: 'Keep elbows tucked',
      commonMistakes: 'Using torso momentum',
      isCustom: false,
    ),
    const Exercise(
      id: 4,
      stableId: '30dcad52-0a4d-55a4-a33b-e8923f85a51a',
      name: 'Lat Pulldown',
      muscleGroups: 'Back,Biceps',
      equipment: 'Cable',
      difficulty: 'Beginner',
      formCues: 'Pull elbows down and back',
      commonMistakes: 'Swinging backward',
      isCustom: false,
    ),
    const Exercise(
      id: 5,
      stableId: 'd3b5ab04-74f6-5155-9621-50238644eeda',
      name: 'Barbell Squat',
      muscleGroups: 'Quads,Glutes,Hamstrings',
      equipment: 'Barbell',
      difficulty: 'Advanced',
      formCues: 'Keep chest upright\nDrive through heels',
      commonMistakes: 'Knee valgus',
      isCustom: false,
    ),
  ];

  late _MockWorkoutRepository mockRepo;

  setUp(() {
    mockRepo = _MockWorkoutRepository(mockExercises);
  });

  Widget createTestWidget({
    _MockWorkoutRepository? repo,
    ThemeData? theme,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(repo ?? mockRepo),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const ExerciseLibraryScreen(),
        ),
      ),
    );
  }

  void setTestViewport(WidgetTester tester, {Size size = const Size(1080, 1920)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('R08C.8: Exercise Library Browsing & Search', () {
    testWidgets('Displays all exercises with compact rows and secondary muscle hints', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
      expect(find.text('Chest · Barbell'), findsOneWidget);
      expect(find.text('Also works Triceps, Shoulders'), findsOneWidget);

      expect(find.text('Lat Pulldown'), findsOneWidget);
      expect(find.text('Back · Cable'), findsOneWidget);
      expect(find.text('Also works Biceps'), findsOneWidget);
    });

    testWidgets('Multi-token text search discovers exercise by secondary muscle', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Search "triceps" -> Should match Bench Press (secondary) and Tricep Pushdown (primary)
      await tester.enterText(find.byType(TextField), 'triceps');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
      expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
      expect(find.text('Tricep Pushdown'), findsOneWidget);
      expect(find.text('Lat Pulldown'), findsNothing);
      expect(find.text('Barbell Squat'), findsNothing);
    });

    testWidgets('Category filtering strictly uses PRIMARY muscle only', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Triceps category
      await tester.tap(find.byKey(const ValueKey('m_Triceps')));
      await tester.pumpAndSettle();

      // Only Tricep Pushdown should appear, Bench Press should NOT
      expect(find.text('Tricep Pushdown'), findsOneWidget);
      expect(find.text('Flat Barbell Bench Press'), findsNothing);
      expect(find.text('Incline Dumbbell Bench Press'), findsNothing);
    });

    testWidgets('Empty search shows ProductEmptyState and clear button resets results', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nonexistentexercise123');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('No matching exercises'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);

      await tester.tap(find.text('Clear search'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
    });

    testWidgets('Database error shows ProductFailureCard with retry action', (tester) async {
      setTestViewport(tester);
      final errorRepo = _FailingWorkoutRepository();
      await tester.pumpWidget(createTestWidget(repo: errorRepo));
      await tester.pumpAndSettle();

      expect(find.text('Exercises unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('R08C.8: Exercise Details Sheet', () {
    testWidgets('Renders exercise name, difficulty, visual, muscles and action buttons', (tester) async {
      setTestViewport(tester);
      final ex = mockExercises.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ExerciseDetailsSheet(exercise: ex),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(ex.name), findsOneWidget);
      expect(find.text(ex.difficulty), findsOneWidget);
      expect(find.text('Chest · Primary'), findsOneWidget);
      expect(find.text('Triceps · Secondary'), findsOneWidget);
      expect(find.text('Shoulders · Secondary'), findsOneWidget);
      expect(find.text(ex.equipment), findsOneWidget);

      // ExerciseVisual widget is present
      expect(find.byType(ExerciseVisual), findsOneWidget);

      // Performance actions
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Plate calculator'), findsOneWidget);

      // Form cues
      expect(find.text('Keep feet flat on floor'), findsOneWidget);
      expect(find.text('Lower bar to chest'), findsOneWidget);
      expect(find.text('View full guide'), findsOneWidget);
    });

    testWidgets('Opening Plate calculator from details sheet opens PlateCalculatorSheet', (tester) async {
      setTestViewport(tester);
      final ex = mockExercises.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ExerciseDetailsSheet(exercise: ex),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plate calculator'));
      await tester.pumpAndSettle();

      expect(find.byType(PlateCalculatorSheet), findsOneWidget);
      expect(find.byType(PlateCalculatorView), findsOneWidget);
      expect(find.text('Target Weight (kg)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PlateCalculatorSheet),
          matching: find.text('Barbell'),
        ),
        findsOneWidget,
      );
    });
  });

  group('R08C.8: Consolidated Plate Calculator', () {
    testWidgets('Calculates plates correctly for 80kg with 20kg bar', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: PlateCalculatorView(initialTargetWeight: 80, isEditable: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // (80 - 20) / 2 = 30kg per side -> 1x 25kg + 1x 5kg
      expect(find.text('1x 25.0kg  +  1x 5.0kg'), findsOneWidget);
    });

    testWidgets('Shows exact banner when target weight equals bar weight', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: PlateCalculatorView(initialTargetWeight: 20, isEditable: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Barbell alone covers target weight.'), findsOneWidget);
    });
  });

  group('R08C.8: Accessibility & Responsiveness', () {
    testWidgets('Exercise Library renders cleanly at 320pt with 2x text without overflow', (tester) async {
      setTestViewport(tester, size: const Size(320, 800));
      await tester.pumpWidget(createTestWidget(textScale: 2.0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ExerciseLibraryScreen), findsOneWidget);
    });

    testWidgets('Exercise Details Sheet renders cleanly at 320pt with 2x text without overflow', (tester) async {
      setTestViewport(tester, size: const Size(320, 800));
      final ex = mockExercises.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: ExerciseDetailsSheet(exercise: ex),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(ex.name), findsOneWidget);
    });
  });
}

class _MockWorkoutRepository implements WorkoutRepository {
  final List<Exercise> _exercises;

  _MockWorkoutRepository(this._exercises);

  @override
  Future<List<Exercise>> searchExercises(String query) async {
    if (query.trim().isEmpty) return _exercises;
    final clean = query.toLowerCase().trim();
    return _exercises
        .where(
          (ex) =>
              ex.name.toLowerCase().contains(clean) ||
              ex.muscleGroups.toLowerCase().contains(clean) ||
              ex.equipment.toLowerCase().contains(clean),
        )
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingWorkoutRepository extends _MockWorkoutRepository {
  _FailingWorkoutRepository() : super(const []);

  @override
  Future<List<Exercise>> searchExercises(String query) async {
    throw Exception('Database disk I/O error');
  }
}
