import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/program_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository repository;

  setUp(() async {
    db = AppDatabase.memory();
    repository = ProgramRepository(db);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('exercise-bench-v1'),
            name: 'Flat Barbell Bench Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
  });

  tearDown(() => db.close());

  ExercisePrescriptionInput prescription({int ordinal = 0, String? id}) {
    return ExercisePrescriptionInput(
      id: id,
      exerciseId: 'exercise-bench-v1',
      exerciseNameSnapshot: 'Flat Barbell Bench Press',
      plannedSets: 4,
      repsRange: '8-10',
      ordinal: ordinal,
    );
  }

  List<ProgramBlockInput> groupedGraph({
    B02GroupType groupType = B02GroupType.superset,
    int extraPrescriptions = 0,
  }) {
    final memberCount = groupType == B02GroupType.giantSet ? 3 : 2;
    final prescriptionCount = memberCount + extraPrescriptions;
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
                name: 'Grouped session',
                ordinal: 0,
                plannedWeekday: 1,
                prescriptions: List.generate(
                  prescriptionCount,
                  (index) => prescription(
                    ordinal: index,
                    id: 'prescription-${index + 1}',
                  ),
                ),
                groups: [
                  ExerciseGroupInput(
                    id: 'group-1',
                    ordinal: 0,
                    groupType: groupType,
                    roundCount: 3,
                    restAfterRoundSeconds: 90,
                    label: 'Main group',
                    members: List.generate(
                      memberCount,
                      (index) => ExerciseGroupMemberInput(
                        id: 'member-${index + 1}',
                        exercisePrescriptionId: 'prescription-${index + 1}',
                        ordinal: index,
                        transitionRestSeconds: index == 0 ? null : 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<ProgramBlockInput> validGraph() {
    return [
      ProgramBlockInput(
        name: 'Accumulation',
        ordinal: 0,
        weeks: [
          ProgramWeekInput(
            name: 'Week 1',
            ordinalInBlock: 0,
            programWeekOrdinal: 0,
            templates: [
              SessionTemplateInput(
                name: 'Push',
                ordinal: 0,
                plannedWeekday: 1,
                prescriptions: [prescription()],
              ),
            ],
          ),
          ProgramWeekInput(
            name: 'Deload',
            ordinalInBlock: 1,
            programWeekOrdinal: 1,
            isDeload: true,
            templates: [
              SessionTemplateInput(
                name: 'Deload push',
                ordinal: 0,
                plannedWeekday: 1,
                prescriptions: [prescription()],
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Future<void> markPublished(String versionId) async {
    await (db.update(
      db.programVersions,
    )..where((row) => row.id.equals(versionId))).write(
      ProgramVersionsCompanion(
        status: const Value('published'),
        publishedAtUtc: Value(DateTime.utc(2026, 1, 1)),
      ),
    );
  }

  group('B01-05 program authoring and lifecycle', () {
    test('creates a validated multi-block draft with a deload week', () async {
      final programId = await repository.createProgram(
        name: 'Hypertrophy',
        blocks: validGraph(),
      );

      final version = (await repository.getVersionsForProgram(
        programId,
      )).single;
      final detail = await repository.getProgramVersionDetail(version.id);
      expect(version.status, 'draft');
      expect(detail!.weeks.map((week) => week.programWeekOrdinal), [0, 1]);
      expect(detail.weeks.last.isDeload, isTrue);
      expect(detail.exercisePrescriptions, hasLength(2));
      expect(
        detail.exercisePrescriptions.every(
          (prescription) => prescription.exerciseId == 'exercise-bench-v1',
        ),
        isTrue,
      );
    });

    test('rejects invalid graph before writing partial program rows', () async {
      await expectLater(
        repository.createProgram(
          name: 'Invalid',
          blocks: [ProgramBlockInput(name: 'Bad', ordinal: 1, weeks: const [])],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repository.getAllPrograms(), isEmpty);

      await expectLater(
        repository.createProgram(
          name: 'Unresolved without intent',
          blocks: [
            ProgramBlockInput(
              name: 'Block',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  templates: [
                    SessionTemplateInput(
                      name: 'Template',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: const [
                        ExercisePrescriptionInput(
                          exerciseNameSnapshot: 'Unknown custom',
                          plannedSets: 1,
                          repsRange: '10',
                          ordinal: 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repository.getAllPrograms(), isEmpty);
    });

    test(
      'copies a published version to an independently editable draft',
      () async {
        final programId = await repository.createProgram(
          name: 'Strength',
          blocks: validGraph(),
        );
        final v1 = (await repository.getVersionsForProgram(programId)).single;
        await markPublished(v1.id);

        final v2Id = await repository.copyToNewDraftVersion(v1.id);
        await repository.updateDraftVersion(v2Id, blocks: []);
        final v1Detail = await repository.getProgramVersionDetail(v1.id);
        final v2Detail = await repository.getProgramVersionDetail(v2Id);

        expect(v2Detail!.version.status, 'draft');
        expect(v2Detail.version.versionNumber, 2);
        expect(v2Detail.version.sourceVersionId, v1.id);
        expect(v1Detail!.exercisePrescriptions, hasLength(2));
        expect(v2Detail.exercisePrescriptions, isEmpty);
      },
    );

    test(
      'rejects published graph edits without deleting its children',
      () async {
        final programId = await repository.createProgram(
          name: 'Immutable',
          blocks: validGraph(),
        );
        final version = (await repository.getVersionsForProgram(
          programId,
        )).single;
        await markPublished(version.id);

        await expectLater(
          repository.updateDraftVersion(version.id, blocks: []),
          throwsA(isA<StateError>()),
        );
        expect(
          (await repository.getProgramVersionDetail(
            version.id,
          ))!.exercisePrescriptions,
          hasLength(2),
        );
      },
    );

    test('guards active and referenced draft deletion', () async {
      final programId = await repository.createProgram(
        name: 'Draft',
        blocks: [],
      );
      final version = (await repository.getVersionsForProgram(
        programId,
      )).single;
      await (db.update(
        db.trainingPlanSettings,
      )..where((row) => row.id.equals(1))).write(
        TrainingPlanSettingsCompanion(
          activeProgramVersionId: Value(version.id),
        ),
      );

      await expectLater(
        repository.deleteDraftVersion(version.id),
        throwsA(isA<StateError>()),
      );
      expect(await repository.getProgramVersionDetail(version.id), isNotNull);
    });

    test('repository and reactive provider share the database owner', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(programRepositoryProvider),
        isA<ProgramRepository>(),
      );
      expect(await container.read(programListProvider.future), isEmpty);
      await repository.createProgram(name: 'Provider graph');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(programListProvider).value, hasLength(1));
    });

    test('authors and reads an explicit group graph by stable IDs', () async {
      final programId = await repository.createProgram(
        name: 'Grouped program',
        blocks: groupedGraph(groupType: B02GroupType.giantSet),
      );
      final version = (await repository.getVersionsForProgram(
        programId,
      )).single;
      final detail = await repository.getProgramVersionDetail(version.id);

      expect(detail!.groups.single.groupType, 'giantSet');
      expect(detail.groups.single.roundCount, 3);
      expect(detail.groups.single.restAfterRoundSeconds, 90);
      expect(detail.groupMembers.map((member) => member.ordinal), [0, 1, 2]);
      expect(
        detail.groupMembers.map((member) => member.exercisePrescriptionId),
        ['prescription-1', 'prescription-2', 'prescription-3'],
      );
    });

    test(
      'rejects invalid group cardinality, ordinals and membership',
      () async {
        final invalidCardinality = groupedGraph();
        final template =
            invalidCardinality.single.weeks.single.templates.single;
        invalidCardinality.single.weeks.single.templates[0] =
            SessionTemplateInput(
              name: template.name,
              ordinal: template.ordinal,
              plannedWeekday: template.plannedWeekday,
              prescriptions: template.prescriptions,
              groups: [
                ExerciseGroupInput(
                  id: 'bad-cardinality',
                  ordinal: 0,
                  groupType: B02GroupType.superset,
                  roundCount: 1,
                  members: [
                    const ExerciseGroupMemberInput(
                      id: 'only-member',
                      exercisePrescriptionId: 'prescription-1',
                      ordinal: 0,
                    ),
                  ],
                ),
              ],
            );
        await expectLater(
          repository.createProgram(
            name: 'Bad cardinality',
            blocks: invalidCardinality,
          ),
          throwsA(isA<B02ValidationException>()),
        );
        expect(await repository.getAllPrograms(), isEmpty);

        final invalidReference = groupedGraph();
        final referenceTemplate =
            invalidReference.single.weeks.single.templates.single;
        invalidReference.single.weeks.single.templates[0] =
            SessionTemplateInput(
              name: referenceTemplate.name,
              ordinal: referenceTemplate.ordinal,
              plannedWeekday: referenceTemplate.plannedWeekday,
              prescriptions: referenceTemplate.prescriptions,
              groups: [
                ExerciseGroupInput(
                  id: 'bad-reference',
                  ordinal: 0,
                  groupType: B02GroupType.superset,
                  roundCount: 1,
                  members: const [
                    ExerciseGroupMemberInput(
                      id: 'member-a',
                      exercisePrescriptionId: 'prescription-1',
                      ordinal: 0,
                    ),
                    ExerciseGroupMemberInput(
                      id: 'member-b',
                      exercisePrescriptionId: 'outside-template',
                      ordinal: 1,
                    ),
                  ],
                ),
              ],
            );
        await expectLater(
          repository.createProgram(
            name: 'Bad reference',
            blocks: invalidReference,
          ),
          throwsA(isA<B02ValidationException>()),
        );
        expect(await repository.getAllPrograms(), isEmpty);
      },
    );

    test(
      'draft group CRUD compacts ordinals and rejects published mutation',
      () async {
        final programId = await repository.createProgram(
          name: 'Group editing',
          blocks: groupedGraph(extraPrescriptions: 2),
        );
        final version = (await repository.getVersionsForProgram(
          programId,
        )).single;
        final template = (await repository.getProgramVersionDetail(
          version.id,
        ))!.sessionTemplates.single;

        await repository.createExerciseGroup(
          template.id,
          const ExerciseGroupInput(
            id: 'group-2',
            ordinal: 1,
            groupType: B02GroupType.superset,
            roundCount: 2,
            members: [
              ExerciseGroupMemberInput(
                id: 'group-2-member-1',
                exercisePrescriptionId: 'prescription-3',
                ordinal: 0,
              ),
              ExerciseGroupMemberInput(
                id: 'group-2-member-2',
                exercisePrescriptionId: 'prescription-4',
                ordinal: 1,
              ),
            ],
          ),
        );
        await repository.reorderExerciseGroups(template.id, const [
          'group-2',
          'group-1',
        ]);
        expect(
          (await repository.getProgramVersionDetail(
            version.id,
          ))!.groups.map((group) => '${group.id}:${group.ordinal}'),
          ['group-2:0', 'group-1:1'],
        );
        await repository.deleteExerciseGroup('group-2');

        await repository.updateExerciseGroup(
          'group-1',
          ExerciseGroupInput(
            id: 'group-1',
            ordinal: 0,
            groupType: B02GroupType.circuit,
            roundCount: 4,
            members: const [
              ExerciseGroupMemberInput(
                id: 'member-1',
                exercisePrescriptionId: 'prescription-1',
                ordinal: 0,
              ),
              ExerciseGroupMemberInput(
                id: 'member-2',
                exercisePrescriptionId: 'prescription-2',
                ordinal: 1,
              ),
            ],
          ),
        );
        await repository.addExerciseGroupMember(
          'group-1',
          const ExerciseGroupMemberInput(
            id: 'member-3',
            exercisePrescriptionId: 'prescription-3',
            ordinal: 2,
          ),
        );
        await repository.reorderExerciseGroupMembers('group-1', const [
          'member-3',
          'member-1',
          'member-2',
        ]);
        final afterReorder = await repository.getProgramVersionDetail(
          version.id,
        );
        expect(
          afterReorder!.groupMembers
              .where((member) => member.exerciseGroupId == 'group-1')
              .map((member) => '${member.id}:${member.ordinal}')
              .toList(),
          ['member-3:0', 'member-1:1', 'member-2:2'],
        );

        await repository.deleteExerciseGroupMember('member-2');
        final afterDelete = await repository.getProgramVersionDetail(
          version.id,
        );
        expect(
          afterDelete!.groupMembers
              .where((member) => member.exerciseGroupId == 'group-1')
              .map((member) => member.ordinal),
          [0, 1],
        );

        await expectLater(
          repository.reorderExerciseGroups(template.id, const [
            'missing-group',
          ]),
          throwsA(isA<ArgumentError>()),
        );
        await markPublished(version.id);
        await expectLater(
          repository.deleteExerciseGroup('group-1'),
          throwsA(isA<StateError>()),
        );
        expect(
          (await repository.getProgramVersionDetail(version.id))!.groups,
          hasLength(1),
        );
      },
    );

    test(
      'copies groups and member links into a new draft with new IDs',
      () async {
        final programId = await repository.createProgram(
          name: 'Copy grouped program',
          blocks: groupedGraph(),
        );
        final source = (await repository.getVersionsForProgram(
          programId,
        )).single;
        await markPublished(source.id);

        final copiedId = await repository.copyToNewDraftVersion(source.id);
        final sourceDetail = (await repository.getProgramVersionDetail(
          source.id,
        ))!;
        final copiedDetail = (await repository.getProgramVersionDetail(
          copiedId,
        ))!;
        expect(copiedDetail.groups, hasLength(1));
        expect(copiedDetail.groupMembers, hasLength(2));
        expect(
          copiedDetail.groups.single.id,
          isNot(sourceDetail.groups.single.id),
        );
        expect(
          copiedDetail.groupMembers.map(
            (member) => member.exercisePrescriptionId,
          ),
          copiedDetail.exercisePrescriptions.map(
            (prescription) => prescription.id,
          ),
        );
        expect(
          copiedDetail.groupMembers.map((member) => member.id),
          everyElement(isNot('member-1')),
        );
      },
    );
  });
}
