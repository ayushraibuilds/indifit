import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/program_authoring/program_author_screen.dart';

class _FailingSaveProgramRepository extends ProgramRepository {
  _FailingSaveProgramRepository(super.db);

  @override
  Future<String> createProgram({
    required String name,
    String? goal,
    String? notes,
    List<ProgramBlockInput> blocks = const [],
  }) async {
    throw StateError('simulated write failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProgramRepository repository;

  setUp(() async {
    database = AppDatabase.memory();
    repository = ProgramRepository(database);
    await database.batch((batch) {
      batch.insert(
        database.exercises,
        ExercisesCompanion.insert(
          stableId: const Value('c4-bench-id'),
          name: 'C4 Bench Press',
          muscleGroups: 'Chest, Triceps',
          equipment: 'Barbell',
          difficulty: 'Intermediate',
          formCues: 'Brace',
          commonMistakes: 'Bounce',
        ),
      );
      batch.insert(
        database.exercises,
        ExercisesCompanion.insert(
          stableId: const Value('c4-row-id'),
          name: 'C4 Row',
          muscleGroups: 'Back, Biceps',
          equipment: 'Cable',
          difficulty: 'Intermediate',
          formCues: 'Stay tall',
          commonMistakes: 'Swinging',
        ),
      );
    });
  });

  tearDown(() => database.close());

  test('creates, reopens, and edits exact ordered plan content', () async {
    final programId = await repository.createProgram(
      name: 'C4 plan',
      notes: 'Initial notes',
      blocks: _graph(),
    );
    final version = (await repository.getVersionsForProgram(programId)).single;
    final created = await repository.getProgramVersionDetail(version.id);

    expect(created!.program.name, 'C4 plan');
    expect(created.exercisePrescriptions.map((row) => row.exerciseId), [
      'c4-bench-id',
      'c4-row-id',
    ]);
    expect(created.exercisePrescriptions.map((row) => row.ordinal), [0, 1]);

    await repository.saveDraft(
      versionId: version.id,
      name: 'C4 edited plan',
      notes: 'Updated notes',
      blocks: _graph(reverseExercises: true),
    );
    final reopened = await repository.getProgramVersionDetail(version.id);

    expect(reopened!.program.name, 'C4 edited plan');
    expect(reopened.program.notes, 'Updated notes');
    expect(reopened.exercisePrescriptions.map((row) => row.exerciseId), [
      'c4-row-id',
      'c4-bench-id',
    ]);
    expect(reopened.exercisePrescriptions.map((row) => row.ordinal), [0, 1]);
  });

  test(
    'invalid identity is rejected before an existing plan is replaced',
    () async {
      final programId = await repository.createProgram(
        name: 'Safe plan',
        blocks: _graph(),
      );
      final version = (await repository.getVersionsForProgram(
        programId,
      )).single;

      await expectLater(
        repository.saveDraft(
          versionId: version.id,
          name: 'Should not save',
          blocks: _graph(exerciseIdOverride: 'missing-canonical-id'),
        ),
        throwsA(isA<ArgumentError>()),
      );

      final unchanged = await repository.getProgramVersionDetail(version.id);
      expect(unchanged!.program.name, 'Safe plan');
      expect(unchanged.exercisePrescriptions.first.exerciseId, 'c4-bench-id');
    },
  );

  test(
    'persistence failure rolls back metadata and the complete graph',
    () async {
      // Reserve explicit row identities in a different plan so the target save
      // fails during insertion, after its transaction has attempted metadata
      // update and graph deletion.
      await repository.createProgram(name: 'Identity owner', blocks: _graph());
      final targetProgramId = await repository.createProgram(
        name: 'Atomic target',
        notes: 'Original notes',
        blocks: _graph(reverseExercises: true, includeRowIds: false),
      );
      final targetVersion = (await repository.getVersionsForProgram(
        targetProgramId,
      )).single;
      final before = await repository.getProgramVersionDetail(targetVersion.id);

      await expectLater(
        repository.saveDraft(
          versionId: targetVersion.id,
          name: 'Partially written name',
          notes: 'Partially written notes',
          blocks: _graph(),
        ),
        throwsA(anything),
      );

      final after = await repository.getProgramVersionDetail(targetVersion.id);
      expect(after!.program.name, 'Atomic target');
      expect(after.program.notes, 'Original notes');
      expect(
        after.exercisePrescriptions.map((row) => row.id),
        before!.exercisePrescriptions.map((row) => row.id),
      );
      expect(after.exercisePrescriptions.map((row) => row.exerciseId), [
        'c4-row-id',
        'c4-bench-id',
      ]);
    },
  );

  test(
    'group member identity and order remain canonical through save',
    () async {
      final programId = await repository.createProgram(
        name: 'Grouped plan',
        blocks: _groupedGraph(),
      );
      final version = (await repository.getVersionsForProgram(
        programId,
      )).single;
      final detail = await repository.getProgramVersionDetail(version.id);

      expect(detail!.groups.single.groupType, 'superset');
      expect(
        detail.groupMembers.map((member) => member.exercisePrescriptionId),
        ['c4-prescription-row', 'c4-prescription-bench'],
      );
      expect(detail.groupMembers.map((member) => member.ordinal), [0, 1]);

      await repository.saveDraft(
        versionId: version.id,
        name: 'Grouped plan',
        blocks: _groupedGraph(),
      );
      final reopened = await repository.getProgramVersionDetail(version.id);
      expect(
        reopened!.groupMembers.map((member) => member.exercisePrescriptionId),
        ['c4-prescription-row', 'c4-prescription-bench'],
      );
      expect(reopened.groupMembers.first.transitionRestSeconds, 10);
    },
  );

  test(
    'copying an in-use version creates an isolated editable version',
    () async {
      final programId = await repository.createProgram(
        name: 'Frozen source',
        blocks: _graph(),
      );
      final source = (await repository.getVersionsForProgram(programId)).single;
      await (database.update(
        database.programVersions,
      )..where((row) => row.id.equals(source.id))).write(
        ProgramVersionsCompanion(
          status: const Value('published'),
          publishedAtUtc: Value(DateTime.utc(2026, 8, 24)),
        ),
      );

      final copiedId = await repository.copyToNewDraftVersion(source.id);
      await repository.saveDraft(
        versionId: copiedId,
        // Program metadata is canonical program identity shared by the
        // versions; this test is about graph isolation, not a new per-version
        // naming policy.
        name: 'Frozen source',
        blocks: _graph(reverseExercises: true, includeRowIds: false),
      );

      final sourceDetail = await repository.getProgramVersionDetail(source.id);
      final copiedDetail = await repository.getProgramVersionDetail(copiedId);
      expect(sourceDetail!.program.name, 'Frozen source');
      expect(sourceDetail.exercisePrescriptions.map((row) => row.exerciseId), [
        'c4-bench-id',
        'c4-row-id',
      ]);
      expect(copiedDetail!.program.name, 'Frozen source');
      expect(copiedDetail.exercisePrescriptions.map((row) => row.exerciseId), [
        'c4-row-id',
        'c4-bench-id',
      ]);
    },
  );

  testWidgets('authoring exposes the shared exact-identity exercise picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ProgramAuthorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Build your plan'), findsOneWidget);
    final addExercise = find.text('Add exercise');
    await tester.ensureVisible(addExercise);
    await tester.tap(addExercise);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Choose from exercise library'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
  });

  testWidgets('authoring keeps labelled actions reachable at large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: ProgramAuthorScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Plan name'), findsOneWidget);
    final savePlan = find.text('Save plan');
    await tester.ensureVisible(savePlan);
    expect(savePlan, findsOneWidget);
  });

  testWidgets('failed save keeps edits without offering a destructive reload', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          programRepositoryProvider.overrideWithValue(
            _FailingSaveProgramRepository(database),
          ),
        ],
        child: const MaterialApp(home: ProgramAuthorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final nameField = find.bySemanticsLabel('Plan name');
    await tester.enterText(nameField, 'Unsaved retained plan');
    final savePlan = find.text('Save plan');
    await tester.ensureVisible(savePlan);
    await tester.tap(savePlan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Unsaved retained plan'), findsOneWidget);
    expect(find.text('Plan could not be loaded'), findsNothing);
    expect(
      find.text('The plan could not be saved. Try again.'),
      findsOneWidget,
    );
  });
}

List<ProgramBlockInput> _graph({
  bool reverseExercises = false,
  String? exerciseIdOverride,
  bool includeRowIds = true,
}) {
  final exercises = reverseExercises
      ? <({String id, String name})>[
          (id: 'c4-row-id', name: 'C4 Row'),
          (id: 'c4-bench-id', name: 'C4 Bench Press'),
        ]
      : <({String id, String name})>[
          (id: exerciseIdOverride ?? 'c4-bench-id', name: 'C4 Bench Press'),
          (id: 'c4-row-id', name: 'C4 Row'),
        ];
  return [
    ProgramBlockInput(
      name: 'Block 1',
      ordinal: 0,
      weeks: [
        ProgramWeekInput(
          name: 'Week 1',
          ordinalInBlock: 0,
          programWeekOrdinal: 0,
          templates: [
            SessionTemplateInput(
              name: 'Upper body',
              ordinal: 0,
              plannedWeekday: DateTime.monday,
              plannedStartMinute: 540,
              prescriptions: [
                for (var index = 0; index < exercises.length; index++)
                  ExercisePrescriptionInput(
                    id: includeRowIds ? 'c4-prescription-${index + 1}' : null,
                    exerciseId: exercises[index].id,
                    exerciseNameSnapshot: exercises[index].name,
                    plannedSets: index == 0 ? 4 : 3,
                    repsRange: index == 0 ? '6-8' : '8-10',
                    ordinal: index,
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}

List<ProgramBlockInput> _groupedGraph() {
  return [
    ProgramBlockInput(
      name: 'Grouped block',
      ordinal: 0,
      weeks: [
        ProgramWeekInput(
          ordinalInBlock: 0,
          programWeekOrdinal: 0,
          templates: [
            SessionTemplateInput(
              name: 'Grouped workout',
              ordinal: 0,
              plannedWeekday: DateTime.wednesday,
              prescriptions: const [
                ExercisePrescriptionInput(
                  id: 'c4-prescription-bench',
                  exerciseId: 'c4-bench-id',
                  exerciseNameSnapshot: 'C4 Bench Press',
                  plannedSets: 3,
                  repsRange: '8',
                  ordinal: 0,
                ),
                ExercisePrescriptionInput(
                  id: 'c4-prescription-row',
                  exerciseId: 'c4-row-id',
                  exerciseNameSnapshot: 'C4 Row',
                  plannedSets: 3,
                  repsRange: '10',
                  ordinal: 1,
                ),
              ],
              groups: [
                ExerciseGroupInput(
                  id: 'c4-group',
                  ordinal: 0,
                  groupType: B02GroupType.superset,
                  roundCount: 3,
                  restAfterRoundSeconds: 60,
                  members: const [
                    ExerciseGroupMemberInput(
                      id: 'c4-member-row',
                      exercisePrescriptionId: 'c4-prescription-row',
                      ordinal: 0,
                      transitionRestSeconds: 10,
                    ),
                    ExerciseGroupMemberInput(
                      id: 'c4-member-bench',
                      exercisePrescriptionId: 'c4-prescription-bench',
                      ordinal: 1,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
