import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/exercise_picker_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/exercise_library/exercise_history_screen.dart';
import 'package:indifit/features/exercise_library/exercise_library_screen.dart';
import 'package:indifit/features/exercise_picker/exercise_picker.dart';
import 'package:indifit/features/media/b05_exercise_visual_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3B Exercise Library', () {
    testWidgets('generic browse renders one dense base row with variations', (
      tester,
    ) async {
      await _pumpLibrary(tester);

      expect(find.text('Barbell Deadlift'), findsOneWidget);
      expect(find.text('Barbell Deadlift (Standard)'), findsNothing);
      expect(find.text('Pause Barbell Deadlift'), findsNothing);
      expect(find.text('3 variations'), findsOneWidget);
      expect(find.text('Independent Row'), findsOneWidget);
    });

    testWidgets('exact variant search keeps the exact identity discoverable', (
      tester,
    ) async {
      await _pumpLibrary(tester);
      await tester.enterText(find.byType(TextField), 'standard deadlift');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Barbell Deadlift (Standard)'), findsOneWidget);
      expect(find.text('Barbell Deadlift'), findsNothing);
      expect(find.text('Standard variation'), findsOneWidget);
    });

    testWidgets('generic family search keeps the base as the only top row', (
      tester,
    ) async {
      await _pumpLibrary(tester);
      await tester.enterText(find.byType(TextField), 'deadlift');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Barbell Deadlift'), findsOneWidget);
      expect(find.text('Barbell Deadlift (Standard)'), findsNothing);
      expect(find.text('Pause Barbell Deadlift'), findsNothing);
      expect(find.text('3 variations'), findsOneWidget);
    });

    testWidgets('detail variations switch exact history identity', (
      tester,
    ) async {
      await _pumpLibrary(tester);
      await tester.tap(find.text('Barbell Deadlift'));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseDetailsSheet), findsOneWidget);
      expect(find.text('VARIATIONS'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Base'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Standard'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Pause'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Slow eccentric'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Standard'));
      await tester.pumpAndSettle();
      expect(find.text('Barbell Deadlift (Standard)'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Standard'))
            .selected,
        isTrue,
      );

      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final history = tester.widget<ExerciseHistoryScreen>(
        find.byType(ExerciseHistoryScreen),
      );
      expect(history.stableExerciseId, _deadliftStandardId);
      expect(history.exerciseName, 'Barbell Deadlift (Standard)');
    });

    testWidgets('base detail keeps history on the base identity', (
      tester,
    ) async {
      await _pumpLibrary(tester);
      await tester.tap(find.text('Barbell Deadlift'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final history = tester.widget<ExerciseHistoryScreen>(
        find.byType(ExerciseHistoryScreen),
      );
      expect(history.stableExerciseId, _deadliftBaseId);
      expect(history.exerciseName, 'Barbell Deadlift');
    });

    testWidgets('ungrouped exercise has no variations section', (tester) async {
      await _pumpLibrary(tester);
      await tester.tap(find.text('Independent Row'));
      await tester.pumpAndSettle();
      expect(find.text('VARIATIONS'), findsNothing);
    });

    testWidgets('family rows remain usable at 320pt and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpLibrary(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Barbell Deadlift'), findsOneWidget);
      expect(find.text('3 variations'), findsOneWidget);
    });
  });

  group('Phase 3B Exercise Picker', () {
    testWidgets(
      'browse groups family and expansion selects the exact variant',
      (tester) async {
        ExercisePickerSelection? selected;
        await _pumpPicker(
          tester,
          onSelected: (_, selection) async {
            selected = selection;
          },
        );
        await _browseAll(tester);

        expect(find.text('Barbell Deadlift'), findsOneWidget);
        expect(find.text('Barbell Deadlift (Standard)'), findsNothing);
        expect(find.text('3 variations'), findsOneWidget);

        await tester.tap(
          find.byTooltip('Show variations for Barbell Deadlift'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Standard'), findsOneWidget);
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Slow eccentric'), findsOneWidget);

        await tester.tap(find.text('Standard'));
        await tester.pump();
        expect(selected?.exerciseId, _deadliftStandardId);
        expect(selected?.exerciseNameSnapshot, 'Barbell Deadlift (Standard)');
      },
    );

    testWidgets('exact variant query returns the exact canonical identity', (
      tester,
    ) async {
      ExercisePickerSelection? selected;
      await _pumpPicker(
        tester,
        onSelected: (_, selection) async {
          selected = selection;
        },
      );

      await tester.enterText(find.byType(TextField), 'standard deadlift');
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();

      expect(find.text('Barbell Deadlift (Standard)'), findsOneWidget);
      expect(find.text('Barbell Deadlift'), findsNothing);
      await tester.tap(find.text('Barbell Deadlift (Standard)'));
      await tester.pump();
      expect(selected?.exerciseId, _deadliftStandardId);
    });

    testWidgets('an already-selected variant stays visible and clear', (
      tester,
    ) async {
      await _pumpPicker(
        tester,
        context: const ExerciseLibraryPickerContext(
          selectedExerciseId: _deadliftStandardId,
        ),
      );
      await _browseAll(tester);

      final standardRow = find.ancestor(
        of: find.text('Standard'),
        matching: find.byType(ListTile),
      );
      expect(standardRow, findsOneWidget);
      expect(tester.widget<ListTile>(standardRow).selected, isTrue);
    });

    testWidgets('family expansion does not override replacement authority', (
      tester,
    ) async {
      var commits = 0;
      final replacementContext = ExerciseReplacementPickerContext(
        target: PlannedExerciseReplacementTarget(
          draftId: 1,
          scheduledOccurrenceId: 'occurrence-1',
          slotId: 'slot-1',
          expectedExerciseId: _deadliftBaseId,
          currentPerformedExerciseId: _deadliftBaseId,
          currentExerciseNameSnapshot: 'Barbell Deadlift',
        ),
        compatibility: CanonicalReplacementCompatibility(
          currentPerformedExerciseId: _deadliftBaseId,
          knowledge: CanonicalReplacementKnowledge.known,
          candidates: const [
            CanonicalReplacementCandidate(
              exerciseId: _deadliftStandardId,
              state: CanonicalReplacementCandidateState.unavailable,
              unavailableReason:
                  CanonicalReplacementUnavailableReason.notAvailableForWorkout,
            ),
          ],
        ),
      );
      await _pumpPicker(
        tester,
        context: replacementContext,
        onCommit: ({required target, required selection}) async => commits++,
      );
      await _browseAll(tester);
      await tester.tap(find.byTooltip('Show variations for Barbell Deadlift'));
      await tester.pumpAndSettle();

      expect(
        find.text('This exercise is not available for this workout.'),
        findsWidgets,
      );
      await tester.tap(find.text('Standard'));
      await tester.pump();
      expect(commits, 0);
    });

    testWidgets('expanded family stays usable at 320pt and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpPicker(tester, textScale: 2);
      await tester.enterText(find.byType(TextField), 'deadlift');
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show variations for Barbell Deadlift'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Standard'), findsOneWidget);
    });
  });

  group('Phase 3B focused goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('mapped library ${brightness.name}', (tester) async {
        _setViewport(tester);
        await _pumpLibrary(tester, brightness: brightness);
        await expectLater(
          find.byType(Scaffold).first,
          matchesGoldenFile(
            'goldens/rc_phase3b_library_family_${brightness.name}.png',
          ),
        );
      });
    }

    testWidgets('expanded picker family dark', (tester) async {
      _setViewport(tester);
      await _pumpPicker(tester);
      await _browseAll(tester);
      await tester.tap(find.byTooltip('Show variations for Barbell Deadlift'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/rc_phase3b_picker_family_dark.png'),
      );
    });

    testWidgets('detail variations light', (tester) async {
      _setViewport(tester);
      await _pumpLibrary(tester);
      await tester.tap(find.text('Barbell Deadlift'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ExerciseDetailsSheet),
        matchesGoldenFile('goldens/rc_phase3b_detail_variations_light.png'),
      );
    });
  });
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(
          _FamilyWorkoutRepository(_catalogue),
        ),
        b05ExerciseVisualRegistryProvider.overrideWith(
          (ref) async => const B05ExerciseVisualRegistry.empty(),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ExerciseLibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  ExercisePickerSelectionContext context = const ExerciseLibraryPickerContext(),
  Future<void> Function(Exercise, ExercisePickerSelection)? onSelected,
  ExerciseReplacementCommitter? onCommit,
  double textScale = 1,
}) async {
  final repository = ExercisePickerRepository.fromSource(
    _FamilyExerciseSource(_catalogue),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ExercisePicker(
          selectionContext: context,
          repository: repository,
          onExerciseSelected: onSelected,
          onReplacementCommit: onCommit,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _browseAll(WidgetTester tester) async {
  await tester.tap(find.text('Browse all exercises'));
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _FamilyExerciseSource implements ExerciseCatalogSource {
  const _FamilyExerciseSource(this.exercises);

  final List<Exercise> exercises;

  @override
  Future<List<Exercise>> readAll() async => exercises;

  @override
  Future<Exercise?> readByStableId(String stableId) async {
    for (final exercise in exercises) {
      if (exercise.stableId == stableId) return exercise;
    }
    return null;
  }

  @override
  Future<List<Exercise>> readRecent() async => const [];
}

class _FamilyWorkoutRepository implements WorkoutRepository {
  const _FamilyWorkoutRepository(this.exercises);

  final List<Exercise> exercises;

  @override
  Future<List<Exercise>> searchExercises(String query) async => exercises;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _catalogue = <Exercise>[
  _exercise(1, _deadliftBaseId, 'Barbell Deadlift'),
  _exercise(2, _deadliftStandardId, 'Barbell Deadlift (Standard)'),
  _exercise(3, _deadliftPauseId, 'Pause Barbell Deadlift'),
  _exercise(4, _deadliftSlowId, 'Slow Eccentric Barbell Deadlift'),
  _exercise(5, 'independent-id', 'Independent Row', custom: true),
];

Exercise _exercise(
  int id,
  String stableId,
  String name, {
  bool custom = false,
}) => Exercise(
  id: id,
  stableId: stableId,
  name: name,
  muscleGroups: 'Back,Hamstrings',
  equipment: 'Barbell',
  difficulty: 'Intermediate',
  formCues: 'Keep the bar close.\nBrace before lifting.',
  commonMistakes: 'Rounding the back.',
  isCustom: custom,
);

const _deadliftBaseId = 'b102bfa4-6cc5-5e60-accb-82a1ae39b8bc';
const _deadliftStandardId = '7fd950ce-79e5-5558-86d7-fc197b1026ea';
const _deadliftPauseId = '18b6bdf9-9941-5bb1-9369-1c8d73f41560';
const _deadliftSlowId = '3bc421ec-ab46-5c7c-a9fb-ce137b9bf737';
