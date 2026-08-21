import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/exercise_picker_repository.dart';
import 'package:indifit/features/exercise_picker/exercise_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExercisePickerRepository repository;

  setUp(() {
    repository = ExercisePickerRepository.fromSource(
      _FakeExerciseSource(_exercises),
    );
  });

  group('R08B.4 shared catalog search and identity', () {
    test(
      'search matches canonical name, equipment, and secondary muscle',
      () async {
        final name = await repository.search(
          const ExercisePickerQuery(text: 'flat bench'),
        );
        expect(name.map((exercise) => exercise.stableId), contains('bench-id'));

        final equipment = await repository.search(
          const ExercisePickerQuery(text: 'cable'),
        );
        expect(
          equipment.map((exercise) => exercise.stableId),
          contains('triceps-id'),
        );

        final secondary = await repository.search(
          const ExercisePickerQuery(text: 'triceps'),
        );
        expect(
          secondary.map((exercise) => exercise.stableId),
          contains('bench-id'),
        );
      },
    );

    test(
      'selection resolves by exact stable UUID and rejects unknown identity',
      () async {
        final selected = await repository.readByStableId('bench-id');
        expect(selected?.name, 'Flat Barbell Bench Press');
        expect(await repository.readByStableId('missing-id'), isNull);
        expect(
          () => ExercisePickerSelection.fromExercise(_exercises.last),
          throwsArgumentError,
        );
      },
    );

    test('primary-muscle category filtering is exact-primary-only', () async {
      final triceps = await repository.search(
        const ExercisePickerQuery(primaryMuscle: 'Triceps'),
      );
      expect(triceps.map((exercise) => exercise.stableId), ['triceps-id']);

      final chest = await repository.search(
        const ExercisePickerQuery(primaryMuscle: 'Chest'),
      );
      expect(
        chest.map((exercise) => exercise.stableId),
        containsAll(<String>['bench-id', 'replacement-id']),
      );
      expect(
        chest.map((exercise) => exercise.stableId),
        isNot(contains('triceps-id')),
      );
    });

    test(
      'equipment filter is presentation filtering, never replacement authority',
      () async {
        final cable = await repository.search(
          const ExercisePickerQuery(equipment: 'Cable'),
        );
        expect(cable.map((exercise) => exercise.stableId), ['triceps-id']);
      },
    );

    test(
      'filter options use display primary semantics and preserve equipment labels',
      () async {
        expect(await repository.readPrimaryMuscles(), ['Chest', 'Triceps']);
        expect(await repository.readEquipmentOptions(), [
          'Barbell',
          'Cable',
          'Dumbbell',
        ]);
      },
    );
  });

  group('R08B.4 typed replacement contract', () {
    test('unknown canonical compatibility fails closed', () {
      final compatibility = CanonicalReplacementCompatibility.unknown(
        currentPerformedExerciseId: 'bench-id',
      );
      final candidate = compatibility.forExerciseId('replacement-id');
      expect(candidate.state, CanonicalReplacementCandidateState.unknown);
      expect(candidate.isSelectable, isFalse);
      expect(
        candidate.consumerUnavailableReason,
        'This replacement is unavailable right now.',
      );

      final malformed = CanonicalReplacementCompatibility(
        currentPerformedExerciseId: 'bench-id',
        knowledge: CanonicalReplacementKnowledge.unknown,
        candidates: const [
          CanonicalReplacementCandidate(
            exerciseId: 'replacement-id',
            state: CanonicalReplacementCandidateState.allowed,
          ),
        ],
      );
      expect(malformed.forExerciseId('replacement-id').isSelectable, isFalse);
    });

    test(
      'same-muscle or same-equipment similarity cannot make a candidate valid',
      () {
        final compatibility = CanonicalReplacementCompatibility(
          currentPerformedExerciseId: 'bench-id',
          knowledge: CanonicalReplacementKnowledge.known,
          candidates: const [
            CanonicalReplacementCandidate(
              exerciseId: 'replacement-id',
              state: CanonicalReplacementCandidateState.unavailable,
              unavailableReason:
                  CanonicalReplacementUnavailableReason.notAvailableForWorkout,
            ),
          ],
        );
        expect(
          compatibility.forExerciseId('replacement-id').isSelectable,
          isFalse,
        );
      },
    );

    test('planned target retains occurrence and source identity', () {
      final target = _plannedTarget();
      final result = ExerciseReplacementResult(
        target: target,
        selection: const ExercisePickerSelection(
          exerciseId: 'replacement-id',
          exerciseNameSnapshot: 'Incline Dumbbell Press',
        ),
        status: ExerciseReplacementCommitStatus.committed,
        preservesLoggedEvidence: true,
      );

      expect(result.remainsPlanned, isTrue);
      expect(result.remainsQuick, isFalse);
      expect(
        (result.target as PlannedExerciseReplacementTarget)
            .scheduledOccurrenceId,
        'occurrence-1',
      );
      expect(
        (result.target as PlannedExerciseReplacementTarget).expectedExerciseId,
        'bench-id',
      );
      expect(result.target.draftId, 41);
    });

    test(
      'Quick target remains occurrence-less and keeps one draft identity',
      () {
        final target = _quickTarget();
        final result = ExerciseReplacementResult(
          target: target,
          selection: const ExercisePickerSelection(
            exerciseId: 'replacement-id',
            exerciseNameSnapshot: 'Incline Dumbbell Press',
          ),
          status: ExerciseReplacementCommitStatus.committed,
          preservesLoggedEvidence: false,
        );

        expect(result.remainsQuick, isTrue);
        expect(result.remainsPlanned, isFalse);
        expect(result.target.draftId, 42);
        expect(result.target, isA<QuickExerciseReplacementTarget>());
      },
    );
  });

  group('R08B.4 picker presentation', () {
    testWidgets(
      'renders dense rows with primary muscle, equipment, and quiet secondary context',
      (tester) async {
        await tester.pumpWidget(_host(_picker(repository)));
        await _settlePicker(tester);

        expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
        expect(find.text('Chest · Barbell'), findsOneWidget);
        expect(find.text('Also works Triceps, Shoulders'), findsOneWidget);
        expect(find.text('Search exercises'), findsOneWidget);
      },
    );

    testWidgets(
      'search is immediately usable and can discover secondary muscle results',
      (tester) async {
        await tester.pumpWidget(_host(_picker(repository)));
        await _settlePicker(tester);

        await tester.enterText(find.byType(TextField), 'shoulders');
        await tester.pump(const Duration(milliseconds: 180));

        expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
        expect(find.text('Tricep Pushdown'), findsNothing);
      },
    );

    testWidgets(
      'category chip uses primary semantics instead of secondary substring matches',
      (tester) async {
        await tester.pumpWidget(_host(_picker(repository)));
        await _settlePicker(tester);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Triceps'));
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Tricep Pushdown'), findsOneWidget);
        expect(find.text('Flat Barbell Bench Press'), findsNothing);
      },
    );

    testWidgets(
      'equipment chip narrows the generic picker without changing selection semantics',
      (tester) async {
        await tester.pumpWidget(_host(_picker(repository)));
        await _settlePicker(tester);

        await tester.drag(find.byType(ListView).first, const Offset(-360, 0));
        await tester.pump();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Cable'));
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Tricep Pushdown'), findsOneWidget);
        expect(find.text('Flat Barbell Bench Press'), findsNothing);
      },
    );

    testWidgets('generic selection returns the exact canonical UUID', (
      tester,
    ) async {
      ExercisePickerSelection? selected;
      await tester.pumpWidget(
        _host(
          ExercisePicker(
            selectionContext: const QuickExercisePickerContext(),
            repository: repository,
            onExerciseSelected: (_, result) => selected = result,
          ),
        ),
      );
      await _settlePicker(tester);

      await tester.tap(find.text('Flat Barbell Bench Press'));
      await tester.pump();

      expect(selected?.exerciseId, 'bench-id');
      expect(selected?.exerciseNameSnapshot, 'Flat Barbell Bench Press');
    });

    testWidgets(
      'invalid and unknown replacement candidates are visibly disabled and never committed',
      (tester) async {
        var commits = 0;
        final context = ExerciseReplacementPickerContext(
          target: _plannedTarget(),
          compatibility: CanonicalReplacementCompatibility(
            currentPerformedExerciseId: 'bench-id',
            knowledge: CanonicalReplacementKnowledge.known,
            candidates: const [
              CanonicalReplacementCandidate(
                exerciseId: 'replacement-id',
                state: CanonicalReplacementCandidateState.allowed,
                effect: CanonicalReplacementEffect.remainingUnloggedWork,
                preservesLoggedEvidence: true,
              ),
              CanonicalReplacementCandidate(
                exerciseId: 'triceps-id',
                state: CanonicalReplacementCandidateState.unavailable,
                unavailableReason: CanonicalReplacementUnavailableReason
                    .notAvailableForWorkout,
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          _host(
            ExercisePicker(
              selectionContext: context,
              repository: repository,
              onReplacementCommit:
                  ({required target, required selection}) async {
                    commits++;
                  },
            ),
          ),
        );
        await _settlePicker(tester);

        expect(
          find.text('This exercise is not available for this workout.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Tricep Pushdown'));
        await tester.pump();
        expect(commits, 0);
        expect(find.text('B02'), findsNothing);
        expect(find.text('UUID'), findsNothing);
      },
    );

    testWidgets(
      'valid replacement commits once, reuses the draft, and returns exact result',
      (tester) async {
        ExerciseReplacementResult? result;
        Future<ExerciseReplacementResult?>? resultFuture;
        var commits = 0;
        final committedDraftIds = <int>[];
        final replacementContext = _replacementContext(
          requiresConfirmation: false,
        );
        await tester.pumpWidget(
          _launcherHost(
            onOpen: (context) {
              resultFuture = showExerciseReplacementPicker(
                context: context,
                selectionContext: replacementContext,
                repository: repository,
                onReplacementCommit:
                    ({required target, required selection}) async {
                      commits++;
                      committedDraftIds.add(target.draftId);
                    },
              );
            },
          ),
        );
        await tester.tap(find.text('Open picker'));
        await _settlePicker(tester);
        await tester.tap(find.text('Incline Dumbbell Press'));
        await tester.pumpAndSettle();
        result = await resultFuture;

        expect(commits, 1);
        expect(committedDraftIds, [41]);
        expect(result?.committed, isTrue);
        expect(result?.selection.exerciseId, 'replacement-id');
        expect(result?.target.draftId, 41);
        expect(
          (result?.target as PlannedExerciseReplacementTarget)
              .scheduledOccurrenceId,
          'occurrence-1',
        );
      },
    );

    testWidgets('material replacement consequence gets concise confirmation', (
      tester,
    ) async {
      Future<ExerciseReplacementResult?>? resultFuture;
      final replacementContext = _replacementContext(
        requiresConfirmation: true,
      );
      await tester.pumpWidget(
        _launcherHost(
          onOpen: (context) {
            resultFuture = showExerciseReplacementPicker(
              context: context,
              selectionContext: replacementContext,
              repository: repository,
            );
          },
        ),
      );
      await tester.tap(find.text('Open picker'));
      await _settlePicker(tester);
      await tester.tap(find.text('Incline Dumbbell Press'));
      await tester.pump();
      expect(
        find.textContaining('New sets use Incline Dumbbell Press.'),
        findsOneWidget,
      );
      expect(find.text('Use replacement'), findsOneWidget);
      await tester.tap(find.text('Use replacement'));
      await tester.pumpAndSettle();
      final result = await resultFuture;
      expect(result?.committed, isFalse);
      expect(result?.selection.exerciseId, 'replacement-id');
    });

    testWidgets(
      'large text remains scrollable and keeps labelled search field',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _host(_picker(repository)),
          ),
        );
        await _settlePicker(tester);

        expect(find.bySemanticsLabel('Search exercises'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('empty and no-results states are consumer-readable', (
      tester,
    ) async {
      final emptyRepository = ExercisePickerRepository.fromSource(
        _FakeExerciseSource(const []),
      );
      await tester.pumpWidget(
        _host(
          ExercisePicker(
            selectionContext: const ExerciseLibraryPickerContext(),
            repository: emptyRepository,
          ),
        ),
      );
      await _settlePicker(tester);
      expect(find.text('No exercises yet'), findsOneWidget);
      expect(find.textContaining('No exercises are available'), findsOneWidget);

      await tester.pumpWidget(_host(_picker(repository)));
      await _settlePicker(tester);
      await tester.enterText(find.byType(TextField), 'does-not-exist');
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text('No matching exercises'), findsOneWidget);
      expect(find.textContaining('No exercises match'), findsOneWidget);
    });

    testWidgets('picker is reusable without the player screen', (tester) async {
      await tester.pumpWidget(
        _host(
          ExercisePicker(
            selectionContext: const ExerciseLibraryPickerContext(),
            repository: repository,
          ),
        ),
      );
      await _settlePicker(tester);
      expect(find.byType(ExercisePicker), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ListTile), findsAtLeastNWidgets(1));
    });
  });
}

Widget _host(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

Widget _launcherHost({required void Function(BuildContext) onOpen}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onOpen(context),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settlePicker(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

ExercisePicker _picker(ExercisePickerRepository repository) {
  return ExercisePicker(
    selectionContext: const ExerciseLibraryPickerContext(),
    repository: repository,
  );
}

ExerciseReplacementPickerContext _replacementContext({
  required bool requiresConfirmation,
}) {
  return ExerciseReplacementPickerContext(
    target: _plannedTarget(),
    compatibility: CanonicalReplacementCompatibility(
      currentPerformedExerciseId: 'bench-id',
      knowledge: CanonicalReplacementKnowledge.known,
      candidates: [
        CanonicalReplacementCandidate(
          exerciseId: 'replacement-id',
          state: CanonicalReplacementCandidateState.allowed,
          effect: CanonicalReplacementEffect.remainingUnloggedWork,
          requiresConfirmation: requiresConfirmation,
          preservesLoggedEvidence: true,
        ),
      ],
    ),
  );
}

PlannedExerciseReplacementTarget _plannedTarget() {
  return PlannedExerciseReplacementTarget(
    draftId: 41,
    scheduledOccurrenceId: 'occurrence-1',
    slotId: 'slot-1',
    expectedExerciseId: 'bench-id',
    currentPerformedExerciseId: 'bench-id',
    currentExerciseNameSnapshot: 'Flat Barbell Bench Press',
  );
}

QuickExerciseReplacementTarget _quickTarget() {
  return QuickExerciseReplacementTarget(
    draftId: 42,
    slotId: 'quick-slot-1',
    currentPerformedExerciseId: 'bench-id',
    currentExerciseNameSnapshot: 'Flat Barbell Bench Press',
  );
}

final class _FakeExerciseSource implements ExerciseCatalogSource {
  _FakeExerciseSource(this.rows);

  final List<Exercise> rows;

  @override
  Future<List<Exercise>> readAll() async => List<Exercise>.of(rows);

  @override
  Future<Exercise?> readByStableId(String stableId) async {
    final id = stableId.trim();
    for (final row in rows) {
      if (row.stableId == id) return row;
    }
    return null;
  }
}

const _exercises = <Exercise>[
  Exercise(
    id: 1,
    stableId: 'bench-id',
    name: 'Flat Barbell Bench Press',
    muscleGroups: 'Chest,Triceps,Shoulders',
    equipment: 'Barbell',
    difficulty: 'Intermediate',
    formCues: 'Brace',
    commonMistakes: 'Rushing',
    isCustom: false,
  ),
  Exercise(
    id: 2,
    stableId: 'replacement-id',
    name: 'Incline Dumbbell Press',
    muscleGroups: 'Chest,Shoulders',
    equipment: 'Dumbbell',
    difficulty: 'Intermediate',
    formCues: 'Brace',
    commonMistakes: 'Rushing',
    isCustom: false,
  ),
  Exercise(
    id: 3,
    stableId: 'triceps-id',
    name: 'Tricep Pushdown',
    muscleGroups: 'Triceps',
    equipment: 'Cable',
    difficulty: 'Beginner',
    formCues: 'Keep elbows close',
    commonMistakes: 'Swinging',
    isCustom: false,
  ),
  Exercise(
    id: 4,
    stableId: null,
    name: 'Unresolved Exercise',
    muscleGroups: 'Back',
    equipment: 'Machine',
    difficulty: 'Beginner',
    formCues: '',
    commonMistakes: '',
    isCustom: true,
  ),
];
