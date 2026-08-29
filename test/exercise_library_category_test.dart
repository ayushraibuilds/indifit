import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/exercise_library/exercise_library_screen.dart';

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
      formCues: 'Keep feet flat on the floor\nLower the bar to your mid-chest',
      commonMistakes: 'Flaring elbows out too much',
      isCustom: false,
    ),
    const Exercise(
      id: 2,
      stableId: '256fb9bd-77a8-5ea5-ab07-cb10d65bce67',
      name: 'Incline Dumbbell Bench Press',
      muscleGroups: 'Chest,Shoulders,Triceps',
      equipment: 'Dumbbells',
      difficulty: 'Intermediate',
      formCues: 'Set bench to 30-45 degree angle',
      commonMistakes: 'Clashing dumbbells at the top',
      isCustom: false,
    ),
    const Exercise(
      id: 3,
      stableId: '9cb62691-e65f-56f4-9a93-c82a4834a448',
      name: 'Tricep Pushdown',
      muscleGroups: 'Triceps',
      equipment: 'Cable',
      difficulty: 'Beginner',
      formCues: 'Keep elbows locked at your sides',
      commonMistakes: 'Using body momentum',
      isCustom: false,
    ),
    const Exercise(
      id: 4,
      stableId: 'b8f0b194-2d41-5514-bc2c-a2bdabbe056e',
      name: 'Skull Crushers (EZ Bar)',
      muscleGroups: 'Triceps',
      equipment: 'EZ Bar',
      difficulty: 'Intermediate',
      formCues: 'Lower bar to forehead level',
      commonMistakes: 'Flaring elbows wide',
      isCustom: false,
    ),
    const Exercise(
      id: 5,
      stableId: '30dcad52-0a4d-55a4-a33b-e8923f85a51a',
      name: 'Lat Pulldown',
      muscleGroups: 'Back,Biceps',
      equipment: 'Cable',
      difficulty: 'Beginner',
      formCues: 'Pull bar down to upper chest',
      commonMistakes: 'Leaning back excessively',
      isCustom: false,
    ),
    const Exercise(
      id: 6,
      stableId: 'd3b5ab04-74f6-5155-9621-50238644eeda',
      name: 'Barbell Squat',
      muscleGroups: 'Quads,Glutes,Hamstrings',
      equipment: 'Barbell',
      difficulty: 'Intermediate',
      formCues: 'Break at hips and knees together',
      commonMistakes: 'Knees caving inward',
      isCustom: false,
    ),
    const Exercise(
      id: 7,
      stableId: 'custom-001',
      name: 'Custom Grip Press',
      muscleGroups: '  Chest ,  Triceps  ',
      equipment: 'Dumbbells',
      difficulty: 'Intermediate',
      formCues: 'Neutral grip throughout',
      commonMistakes: '',
      isCustom: true,
    ),
    const Exercise(
      id: 8,
      stableId: 'custom-malformed-002',
      name: 'Malformed Muscle Exercise',
      muscleGroups: '',
      equipment: 'Bodyweight',
      difficulty: 'Beginner',
      formCues: '',
      commonMistakes: '',
      isCustom: true,
    ),
  ];

  late _MockWorkoutRepository mockRepo;

  setUp(() {
    mockRepo = _MockWorkoutRepository(mockExercises);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ExerciseLibraryScreen(),
      ),
    );
  }

  void setTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Exercise Library Category Correctness (R08-0.4)', () {
    testWidgets('1. Displays initial All category with total count', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // "All · 8" chip
      expect(find.text('All · 8'), findsOneWidget);
      // All exercises present
      expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
      expect(find.text('Tricep Pushdown'), findsOneWidget);
      expect(find.text('Lat Pulldown'), findsOneWidget);
    });

    testWidgets(
      '2. Category counts strictly reflect PRIMARY display muscle (Triceps count = 2, Chest count = 3)',
      (tester) async {
        setTestViewport(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Chest has 3 primary: Flat Barbell Bench Press, Incline Dumbbell Bench Press, Custom Grip Press
        expect(find.text('Chest · 3'), findsOneWidget);

        // Triceps has 2 primary: Tricep Pushdown, Skull Crushers (EZ Bar).
        // It MUST NOT count Flat Barbell Bench Press or Custom Grip Press as Triceps!
        expect(find.text('Triceps · 2'), findsOneWidget);

        // Back has 1 primary: Lat Pulldown
        expect(find.text('Back · 1'), findsOneWidget);

        // Quads has 1 primary: Barbell Squat
        expect(find.text('Quads · 1'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Selecting Chest category shows Bench Press and excludes Tricep Pushdown',
      (tester) async {
        setTestViewport(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('m_Chest')));
        await tester.pumpAndSettle();

        expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
        expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
        expect(find.text('Custom Grip Press'), findsOneWidget);
        expect(find.text('Tricep Pushdown'), findsNothing);
        expect(find.text('Skull Crushers (EZ Bar)'), findsNothing);
        expect(find.text('Lat Pulldown'), findsNothing);
      },
    );

    testWidgets(
      '4. Selecting Triceps category shows Tricep Pushdown & Skull Crushers, NOT Bench Press',
      (tester) async {
        setTestViewport(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('m_Triceps')));
        await tester.pumpAndSettle();

        expect(find.text('Tricep Pushdown'), findsOneWidget);
        expect(find.text('Skull Crushers (EZ Bar)'), findsOneWidget);

        // CRITICAL REGRESSION CHECK: Bench Press MUST NOT appear in Triceps category
        expect(find.text('Flat Barbell Bench Press'), findsNothing);
        expect(find.text('Incline Dumbbell Bench Press'), findsNothing);
        expect(find.text('Custom Grip Press'), findsNothing);
      },
    );

    testWidgets(
      '5. Exercise Details Sheet preserves primary and secondary muscle display badges',
      (tester) async {
        setTestViewport(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap Flat Barbell Bench Press
        await tester.tap(find.text('Flat Barbell Bench Press'));
        await tester.pumpAndSettle();

        // ExerciseDetailsSheet is open
        expect(find.byType(ExerciseDetailsSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ExerciseDetailsSheet),
            matching: find.text('Chest · Primary'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ExerciseDetailsSheet),
            matching: find.text('Triceps · Secondary'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ExerciseDetailsSheet),
            matching: find.text('Shoulders · Secondary'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ExerciseDetailsSheet),
            matching: find.text('Barbell'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '6. Text search matches secondary muscles when searching globally',
      (tester) async {
        setTestViewport(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter search "tricep"
        await tester.enterText(find.byType(TextField), 'tricep');
        await tester.pumpAndSettle();

        // Both primary Tricep Pushdown and Bench Press (which targets triceps secondarily) appear in search results
        expect(find.text('Tricep Pushdown'), findsOneWidget);
        expect(find.text('Flat Barbell Bench Press'), findsOneWidget);

        // If user then filters by Chest while searching "tricep", only Flat Barbell Bench Press appears
        await tester.tap(find.byKey(const ValueKey('m_Chest')));
        await tester.pumpAndSettle();

        expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
        expect(find.text('Tricep Pushdown'), findsNothing);
      },
    );

    testWidgets('7. Handles malformed muscleGroups without crashing', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Malformed Muscle Exercise'), findsOneWidget);

      // Tap malformed exercise to verify sheet handles empty muscles safely
      await tester.tap(find.text('Malformed Muscle Exercise'));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseDetailsSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExerciseDetailsSheet),
          matching: find.text('Malformed Muscle Exercise'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
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
