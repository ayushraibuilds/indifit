import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/services/b02_occurrence_snapshot_customizer.dart';
import 'package:indifit/features/calendar/occurrence_actions_sheet.dart';
import 'package:indifit/features/training/training_workout_customization.dart';
import 'package:indifit/features/training/training_workout_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08C.2 occurrence-scoped preview', () {
    test(
      'parses the exact planned order, groups, targets, and substitutions',
      () {
        final item = _previewItem();
        final preview = TrainingWorkoutPreviewData.fromOccurrence(
          item,
          snapshotJson: jsonEncode(_richSnapshot()),
        );

        expect(preview.isSnapshotBacked, isTrue);
        expect(preview.occurrenceItem.occurrence.id, 'occurrence-preview');
        expect(preview.exercises.map((exercise) => exercise.name), [
          'Bench Press',
          'Cable Row',
        ]);
        expect(preview.exercises.first.plannedSets, 3);
        expect(preview.exercises.first.repsRange, '8–10');
        expect(preview.exercises.first.targets.first.targetLoadKg, 60);
        expect(preview.exercises.first.targets.first.targetRepsMin, 8);
        expect(preview.exercises.first.targets.first.targetRpe, 7);
        expect(preview.groups.single.typeLabel, 'Superset');
        expect(preview.groups.single.members.map((member) => member.name), [
          'Bench Press',
          'Cable Row',
        ]);
        expect(preview.durationSeconds, 2700);
        expect(preview.substitutions.single.actualName, 'Cable Row');
      },
    );

    test('fails closed when a snapshot belongs to another occurrence', () {
      final snapshot = _richSnapshot()..['occurrenceId'] = 'another-occurrence';

      expect(
        () => TrainingWorkoutPreviewData.fromOccurrence(
          _previewItem(),
          snapshotJson: jsonEncode(snapshot),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fails closed when the frozen exercise order is inconsistent', () {
      final snapshot = _richSnapshot();
      final prescriptions = snapshot['prescriptions']! as List<dynamic>;
      final first = prescriptions.removeAt(0);
      prescriptions.add(first);

      expect(
        () => TrainingWorkoutPreviewData.fromOccurrence(
          _previewItem(),
          snapshotJson: jsonEncode(snapshot),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fails closed on an invalid planned target instead of guessing', () {
      final snapshot = _richSnapshot();
      final prescriptions = snapshot['prescriptions']! as List<dynamic>;
      final bench = prescriptions.first as Map<String, dynamic>;
      final targets = bench['strengthSetPrescriptions']! as List<dynamic>;
      (targets.first as Map<String, dynamic>)['targetRpe'] = 11;

      expect(
        () => TrainingWorkoutPreviewData.fromOccurrence(
          _previewItem(),
          snapshotJson: jsonEncode(snapshot),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('R08C.2 preview presentation', () {
    testWidgets('keeps one obvious Start and puts details behind disclosure', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpPreview(tester, _previewData());

      expect(find.text('Workout preview'), findsOneWidget);
      expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
      expect(find.text('Start workout'), findsOneWidget);
      expect(find.text('Customize today'), findsOneWidget);
      expect(find.text('Quick workout'), findsNothing);
      expect(find.text('Show planned targets'), findsOneWidget);
      expect(find.text('PLANNED STRUCTURE'), findsOneWidget);
      expect(find.text('PLANNED EXERCISES'), findsOneWidget);
      expect(find.text('PLANNED CHANGES'), findsOneWidget);
      expect(find.text('Planned set 1'), findsNothing);

      await tester.tap(find.text('Show planned targets'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Planned set 1'), findsWidgets);
      expect(find.textContaining('60 kg'), findsNWidgets(2));
      expect(find.textContaining('RPE 7'), findsNWidgets(3));
      expect(find.textContaining('Actual'), findsNothing);
    });

    testWidgets(
      'opens the occurrence customization flow without a routing sheet',
      (tester) async {
        _setViewport(tester, const Size(390, 844));
        var starts = 0;
        var customizations = 0;
        await _pumpPreview(
          tester,
          _previewData(),
          onStartWorkout: () => starts++,
          onOpenCustomization: () => customizations++,
        );

        await tester.tap(find.text('Customize today'));
        await tester.pumpAndSettle();
        expect(customizations, 1);
        expect(starts, 0);
        expect(find.text('Move or skip this workout'), findsNothing);
        expect(find.text('Edit exercises and sets'), findsNothing);
        expect(find.text('Workout preview'), findsNothing);
      },
    );

    testWidgets(
      'terminal states keep the preview truthful and offer no Start',
      (tester) async {
        for (final status in ['completed', 'partiallyCompleted']) {
          await _pumpPreview(
            tester,
            TrainingWorkoutPreviewData.fromOccurrence(
              _previewItem(status: status),
              snapshotJson: jsonEncode(_richSnapshot()),
            ),
          );

          expect(find.text('Start workout'), findsNothing);
          expect(find.text('Customize today'), findsNothing);
          expect(
            find.textContaining(
              status == 'completed' ? 'Completed' : 'Partially completed',
            ),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('narrow width and elevated text scale remain usable', (
      tester,
    ) async {
      _setViewport(tester, const Size(320, 844));
      await _pumpPreview(tester, _previewData(), textScale: 2);

      expect(find.text('Workout preview'), findsOneWidget);
      await tester.ensureVisible(find.text('Start workout'));
      expect(find.text('Start workout'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Show planned targets'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Show planned targets'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('PLANNED CHANGES'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PLANNED CHANGES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'customization editor exposes direct exercise actions and one save',
      (tester) async {
        _setViewport(tester, const Size(320, 844));
        List<OccurrenceExerciseCustomization>? saved;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: TrainingWorkoutCustomizationScreen(
                preview: _previewData(),
                onSave: ({required baseSnapshotJson, required changes}) async {
                  saved = changes;
                },
                onOpenScheduleActions: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'These changes apply to this workout only. Your future plan stays the same.',
          ),
          findsOneWidget,
        );
        expect(find.text('Replace'), findsNWidgets(2));
        expect(find.text('Edit target'), findsNWidgets(2));
        await tester.ensureVisible(find.text('Edit target').first);
        await tester.pump();
        await tester.tap(find.text('Edit target').first);
        await tester.pumpAndSettle();
        expect(find.text('Edit Bench Press'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, '6–8');
        await tester.tap(find.text('Done').last);
        await tester.pumpAndSettle();
        expect(find.text('Save changes'), findsOneWidget);
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();

        expect(saved, isNotNull);
        expect(saved, hasLength(1));
        expect(saved!.single.repsRange, '6–8');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('exposes concise labels and one semantic Start action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _setViewport(tester, const Size(390, 844));
      await _pumpPreview(tester, _previewData());

      expect(
        find.bySemanticsLabel(
          RegExp(r'^Today’s planned workout preview\. Exact Friday\.'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Start workout'), findsOneWidget);
      expect(find.bySemanticsLabel('Customize today'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('schedule customization does not reintroduce Start', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: OccurrenceActionsSheet(
                occurrenceItem: _previewItem(),
                scheduleAdjustmentsOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reschedule'), findsOneWidget);
      expect(find.text('Skip Workout'), findsOneWidget);
      expect(find.text('Start Workout'), findsNothing);
      expect(find.text('Cancel Workout'), findsNothing);
      expect(find.text('View History'), findsNothing);
    });

    testWidgets('dark preview golden keeps Start visually dominant', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpPreview(tester, _previewData(), theme: AppTheme.darkTheme);

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(TrainingWorkoutPreviewScreen),
        matchesGoldenFile('goldens/r08c2_training_workout_preview_dark.png'),
      );
    });
  });

  group('R08C.2 canonical snapshot read', () {
    late AppDatabase db;
    late CalendarRepository calendar;
    late CalendarReadRepository reader;
    late CalendarOccurrenceReadItem occurrenceItem;
    late LocalScheduleDateService dates;
    late String laterVersionId;

    setUp(() async {
      db = AppDatabase.memory();
      final now = DateTime.utc(2026, 8, 21, 8);
      dates = LocalScheduleDateService(nowUtc: () => now);
      await db.batch(
        (batch) => batch.insertAll(db.exercises, [
          ExercisesCompanion.insert(
            stableId: const Value('bench-press'),
            name: 'Bench Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Keep your feet planted.',
            commonMistakes: 'Do not bounce the bar.',
          ),
          ExercisesCompanion.insert(
            stableId: const Value('cable-row'),
            name: 'Cable Row',
            muscleGroups: 'Back',
            equipment: 'Cable',
            difficulty: 'Intermediate',
            formCues: 'Keep your chest tall.',
            commonMistakes: 'Do not swing.',
          ),
        ]),
      );
      final programs = ProgramRepository(db);
      final programId = await programs.createProgram(
        name: 'Snapshot Plan',
        blocks: [
          ProgramBlockInput(
            name: 'Base block',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                name: 'Week 1',
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Exact Friday',
                    ordinal: 0,
                    plannedWeekday: DateTime.friday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        exerciseId: 'bench-press',
                        exerciseNameSnapshot: 'Bench Press',
                        plannedSets: 3,
                        repsRange: '8–10',
                        ordinal: 0,
                      ),
                      ExercisePrescriptionInput(
                        exerciseId: 'cable-row',
                        exerciseNameSnapshot: 'Cable Row',
                        plannedSets: 3,
                        repsRange: '10–12',
                        ordinal: 1,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final versionId = (await programs.getVersionsForProgram(
        programId,
      )).single.id;
      final laterProgramId = await programs.createProgram(
        name: 'Later Plan',
        blocks: [
          ProgramBlockInput(
            name: 'Later block',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                name: 'Later week',
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Later Friday',
                    ordinal: 0,
                    plannedWeekday: DateTime.friday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        exerciseId: 'bench-press',
                        exerciseNameSnapshot: 'Bench Press',
                        plannedSets: 2,
                        repsRange: '5',
                        ordinal: 0,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      laterVersionId = (await programs.getVersionsForProgram(
        laterProgramId,
      )).single.id;
      await ProgramActivationCoordinator(
        db,
        dates: dates,
        nowUtc: () => now,
      ).activate(
        ActivateProgramVersionCommand(
          programVersionId: versionId,
          commandId: 'activate::$versionId',
          activationLocalDate: '2026-08-21',
          timezoneId: 'UTC',
        ),
      );
      reader = CalendarReadRepository(db, dates: dates);
      occurrenceItem = (await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      )).rangeOccurrences.single;
      calendar = CalendarRepository(db, dates: dates, nowUtc: () => now);
    });

    tearDown(() => db.close());

    test(
      'builds preview data from the occurrence ancestry before start',
      () async {
        final snapshot = await calendar.readWorkoutPreviewSnapshot(
          occurrenceItem.occurrence.id,
        );
        final preview = TrainingWorkoutPreviewData.fromOccurrence(
          occurrenceItem,
          snapshotJson: snapshot,
        );

        expect(preview.isSnapshotBacked, isTrue);
        expect(
          preview.occurrenceItem.occurrence.id,
          occurrenceItem.occurrence.id,
        );
        expect(preview.exercises.map((exercise) => exercise.name), [
          'Bench Press',
          'Cable Row',
        ]);
      },
    );

    test(
      'keeps the frozen prescription readable after the active plan changes',
      () async {
        await calendar.start(
          StartOccurrenceCommand(
            occurrenceId: occurrenceItem.occurrence.id,
            commandId: 'start::preview',
            expectedStatus: OccurrenceStatus.planned,
          ),
        );
        final startedSnapshot = await calendar.readWorkoutPreviewSnapshot(
          occurrenceItem.occurrence.id,
        );
        await (db.update(
          db.trainingPlanSettings,
        )..where((row) => row.id.equals(1))).write(
          TrainingPlanSettingsCompanion(
            activeProgramVersionId: Value(laterVersionId),
          ),
        );

        final preview = TrainingWorkoutPreviewData.fromOccurrence(
          occurrenceItem,
          snapshotJson: startedSnapshot,
        );

        expect(preview.workoutName, 'Exact Friday');
        expect(preview.exercises.first.name, 'Bench Press');
        expect(preview.exercises[1].name, 'Cable Row');
      },
    );

    test(
      'fails closed for an unstarted occurrence after a plan switch',
      () async {
        await (db.update(
          db.trainingPlanSettings,
        )..where((row) => row.id.equals(1))).write(
          TrainingPlanSettingsCompanion(
            activeProgramVersionId: Value(laterVersionId),
          ),
        );

        expect(
          () =>
              calendar.readWorkoutPreviewSnapshot(occurrenceItem.occurrence.id),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
      },
    );
  });
}

Future<void> _pumpPreview(
  WidgetTester tester,
  TrainingWorkoutPreviewData preview, {
  ThemeData? theme,
  double textScale = 1,
  VoidCallback? onStartWorkout,
  VoidCallback? onOpenCustomization,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: _PreviewHost(
          key: UniqueKey(),
          preview: preview,
          onStartWorkout: onStartWorkout ?? () {},
          onOpenCustomization: onOpenCustomization ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _PreviewHost extends StatefulWidget {
  const _PreviewHost({
    super.key,
    required this.preview,
    required this.onStartWorkout,
    required this.onOpenCustomization,
  });

  final TrainingWorkoutPreviewData preview;
  final VoidCallback onStartWorkout;
  final VoidCallback onOpenCustomization;

  @override
  State<_PreviewHost> createState() => _PreviewHostState();
}

class _PreviewHostState extends State<_PreviewHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainingWorkoutPreviewScreen(
            preview: widget.preview,
            onStartWorkout: widget.onStartWorkout,
            onOpenCustomization: widget.onOpenCustomization,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

TrainingWorkoutPreviewData _previewData({String status = 'planned'}) =>
    TrainingWorkoutPreviewData.fromOccurrence(
      _previewItem(status: status),
      snapshotJson: jsonEncode(_richSnapshot()),
    );

CalendarOccurrenceReadItem _previewItem({
  String status = 'planned',
  String occurrenceId = 'occurrence-preview',
}) {
  final createdAt = DateTime.utc(2026, 8, 1);
  const templateId = 'template-preview';
  const versionId = 'version-preview';
  const weekId = 'week-preview';
  const blockId = 'block-preview';
  return CalendarOccurrenceReadItem(
    occurrence: ScheduledSessionOccurrence(
      id: occurrenceId,
      programVersionId: versionId,
      sessionTemplateId: templateId,
      programBlockOrdinal: 0,
      programWeekOrdinal: 0,
      sessionOrdinal: 0,
      repeatOrdinal: 0,
      originalLocalDate: '2026-08-21',
      originalTimezoneId: 'UTC',
      effectiveLocalDate: '2026-08-21',
      effectiveTimezoneId: 'UTC',
      status: status,
      progressionDisposition: 'pending',
      createdAtUtc: createdAt,
    ),
    template: const SessionTemplate(
      id: templateId,
      programWeekId: weekId,
      ordinal: 0,
      name: 'Exact Friday',
      plannedWeekday: DateTime.friday,
      activityType: 'strength',
    ),
    week: const ProgramWeek(
      id: weekId,
      programVersionId: versionId,
      programBlockId: blockId,
      ordinalInBlock: 0,
      programWeekOrdinal: 0,
      isDeload: false,
    ),
    block: const ProgramBlock(
      id: blockId,
      programVersionId: versionId,
      ordinal: 0,
      name: 'Base block',
    ),
    version: ProgramVersion(
      id: versionId,
      programId: 'program-preview',
      versionNumber: 1,
      status: 'published',
      origin: 'authoring',
      createdAtUtc: createdAt,
    ),
    program: Program(
      id: 'program-preview',
      name: 'Snapshot Plan',
      createdAtUtc: createdAt,
    ),
    prescriptions: const [
      ExercisePrescription(
        id: 'prescription-bench',
        sessionTemplateId: templateId,
        ordinal: 0,
        exerciseNameSnapshot: 'Bench Press',
        plannedSets: 3,
        repsRange: '8–10',
      ),
      ExercisePrescription(
        id: 'prescription-row',
        sessionTemplateId: templateId,
        ordinal: 1,
        exerciseNameSnapshot: 'Cable Row',
        plannedSets: 3,
        repsRange: '10–12',
      ),
    ],
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}

Map<String, dynamic> _richSnapshot({
  String occurrenceId = 'occurrence-preview',
}) => {
  'version': 1,
  'occurrenceId': occurrenceId,
  'routineName': 'Snapshot Plan — Exact Friday',
  'activityType': 'strength',
  'durationSeconds': 2700,
  'template': {'id': 'template-preview', 'name': 'Exact Friday'},
  'prescriptions': [
    {
      'id': 'prescription-bench',
      'ordinal': 0,
      'exerciseNameSnapshot': 'Bench Press',
      'plannedSets': 3,
      'repsRange': '8–10',
      'strengthSetPrescriptions': [
        _plannedSet(
          id: 'bench-set-1',
          prescriptionId: 'prescription-bench',
          ordinal: 0,
          load: 60,
          minimumReps: 8,
          maximumReps: 10,
          rpe: 7,
          rest: 90,
        ),
        _plannedSet(
          id: 'bench-set-2',
          prescriptionId: 'prescription-bench',
          ordinal: 1,
          load: 60,
          minimumReps: 8,
          maximumReps: 10,
          rpe: 7,
          rest: 90,
        ),
      ],
    },
    {
      'id': 'prescription-row',
      'ordinal': 1,
      'exerciseNameSnapshot': 'Cable Row',
      'plannedSets': 3,
      'repsRange': '10–12',
      'strengthSetPrescriptions': [
        _plannedSet(
          id: 'row-set-1',
          prescriptionId: 'prescription-row',
          ordinal: 0,
          load: 45,
          minimumReps: 10,
          maximumReps: 12,
          rpe: 7,
          rest: 75,
        ),
      ],
    },
  ],
  'groups': [
    {
      'id': 'group-preview',
      'ordinal': 0,
      'groupType': 'superset',
      'roundCount': 3,
      'restAfterRoundSeconds': 90,
      'label': 'Push / pull',
      'members': [
        {
          'id': 'member-bench',
          'exercisePrescriptionId': 'prescription-bench',
          'ordinal': 0,
        },
        {
          'id': 'member-row',
          'exercisePrescriptionId': 'prescription-row',
          'ordinal': 1,
        },
      ],
    },
  ],
  'substitutions': [
    {'expectedName': 'Barbell Row', 'actualName': 'Cable Row'},
  ],
};

Map<String, dynamic> _plannedSet({
  required String id,
  required String prescriptionId,
  required int ordinal,
  required double load,
  required int minimumReps,
  required int maximumReps,
  required int rpe,
  required int rest,
}) => {
  'id': id,
  'exercisePrescriptionId': prescriptionId,
  'ordinal': ordinal,
  'targetLoadKg': load,
  'loadBasis': 'totalExternal',
  'targetRepsMin': minimumReps,
  'targetRepsMax': maximumReps,
  'targetRpe': rpe,
  'restSeconds': rest,
  'technique': {'effortMode': 'standard'},
};
