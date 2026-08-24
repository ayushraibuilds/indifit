import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/calendar/occurrence_actions_sheet.dart';
import 'package:indifit/features/program_authoring/program_author_screen.dart';
import 'package:indifit/features/program_authoring/program_review_screen.dart';

class _ReviewProgramRepository extends ProgramRepository {
  final ProgramDetailAggregate detail;

  _ReviewProgramRepository(super.db, this.detail);

  @override
  Future<ProgramDetailAggregate?> getProgramVersionDetail(
    String versionId,
  ) async => versionId == detail.version.id ? detail : null;
}

ProgramDetailAggregate _reviewDetail({String status = 'draft'}) {
  final now = DateTime.utc(2026, 8, 1);
  const programId = 'program-review';
  const versionId = 'version-review';
  const blockId = 'block-review';
  const weekId = 'week-review';
  const templateId = 'template-review';
  return ProgramDetailAggregate(
    program: Program(
      id: programId,
      name: 'Review Test Plan',
      createdAtUtc: now,
    ),
    version: ProgramVersion(
      id: versionId,
      programId: programId,
      versionNumber: 1,
      status: status,
      origin: 'user',
      createdAtUtc: now,
    ),
    blocks: const [
      ProgramBlock(
        id: blockId,
        programVersionId: versionId,
        ordinal: 0,
        name: 'Block 1',
      ),
    ],
    weeks: const [
      ProgramWeek(
        id: weekId,
        programVersionId: versionId,
        programBlockId: blockId,
        ordinalInBlock: 0,
        programWeekOrdinal: 0,
        isDeload: false,
      ),
    ],
    sessionTemplates: const [
      SessionTemplate(
        id: templateId,
        programWeekId: weekId,
        ordinal: 0,
        name: 'Template 1',
        plannedWeekday: DateTime.monday,
        activityType: 'strength',
      ),
    ],
    exercisePrescriptions: const [
      ExercisePrescription(
        id: 'prescription-review',
        sessionTemplateId: templateId,
        ordinal: 0,
        exerciseNameSnapshot: 'Squat',
        plannedSets: 3,
        repsRange: '5',
      ),
      ExercisePrescription(
        id: 'prescription-review-2',
        sessionTemplateId: templateId,
        ordinal: 1,
        exerciseNameSnapshot: 'Row',
        plannedSets: 3,
        repsRange: '8',
      ),
    ],
    groups: const [
      ExerciseGroup(
        id: 'group-review',
        sessionTemplateId: templateId,
        ordinal: 0,
        groupType: 'superset',
        roundCount: 3,
        restAfterRoundSeconds: 90,
      ),
    ],
    groupMembers: const [
      ExerciseGroupMember(
        id: 'group-member-review-1',
        exerciseGroupId: 'group-review',
        exercisePrescriptionId: 'prescription-review',
        ordinal: 0,
      ),
      ExerciseGroupMember(
        id: 'group-member-review-2',
        exerciseGroupId: 'group-review',
        exercisePrescriptionId: 'prescription-review-2',
        ordinal: 1,
      ),
    ],
  );
}

CalendarOccurrenceReadItem _plannedOccurrenceItem() {
  final detail = _reviewDetail();
  return CalendarOccurrenceReadItem(
    occurrence: ScheduledSessionOccurrence(
      id: 'occurrence-review',
      programVersionId: detail.version.id,
      sessionTemplateId: detail.sessionTemplates.single.id,
      programBlockOrdinal: 0,
      programWeekOrdinal: 0,
      sessionOrdinal: 0,
      repeatOrdinal: 0,
      originalLocalDate: '2026-08-03',
      originalTimezoneId: 'Asia/Kolkata',
      effectiveLocalDate: '2026-08-03',
      effectiveTimezoneId: 'Asia/Kolkata',
      status: 'planned',
      progressionDisposition: 'pending',
      createdAtUtc: DateTime.utc(2026, 8, 1),
    ),
    template: detail.sessionTemplates.single,
    week: detail.weeks.single,
    block: detail.blocks.single,
    version: detail.version,
    program: detail.program,
    prescriptions: detail.exercisePrescriptions,
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), ...overrides],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('B01-11A Program Authoring & Calendar Widget Tests', () {
    testWidgets(
      '1. ProgramAuthorScreen renders plan name input and save buttons',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(const ProgramAuthorScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Build your plan'), findsOneWidget);
        expect(find.text('New plan'), findsOneWidget);
        expect(find.text('Add group'), findsOneWidget);
        expect(find.text('Save plan'), findsOneWidget);
        expect(find.text('Review plan'), findsOneWidget);
      },
    );

    testWidgets(
      '2. ProgramReviewScreen displays version details and use button',
      (tester) async {
        final detail = _reviewDetail();

        await tester.pumpWidget(
          createWidgetUnderTest(
            ProgramReviewScreen(programVersionId: detail.version.id),
            overrides: [
              programRepositoryProvider.overrideWithValue(
                _ReviewProgramRepository(db, detail),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Review your plan'), findsOneWidget);
        expect(find.text('Review Test Plan'), findsOneWidget);
        expect(find.text('Use this plan'), findsOneWidget);
        await tester.tap(find.text('Block 1'));
        await tester.pumpAndSettle();
        expect(find.text('Superset • 3 rounds • 2 exercises'), findsOneWidget);
      },
    );

    testWidgets('2a. ProgramReviewScreen surfaces an unavailable plan', (
      tester,
    ) async {
      final detail = _reviewDetail();
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ProgramReviewScreen(programVersionId: 'missing-version'),
          overrides: [
            programRepositoryProvider.overrideWithValue(
              _ReviewProgramRepository(db, detail),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('This plan is no longer available.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('2b. In-use plan metadata is read-only until copied', (
      tester,
    ) async {
      final detail = _reviewDetail(status: 'published');
      await tester.pumpWidget(
        createWidgetUnderTest(
          ProgramAuthorScreen(programVersionId: detail.version.id),
          overrides: [
            programRepositoryProvider.overrideWithValue(
              _ReviewProgramRepository(db, detail),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, isNotEmpty);
      expect(fields.every((field) => field.readOnly), isTrue);
      expect(find.text('Make a copy'), findsOneWidget);
    });

    testWidgets(
      '3. ProgramAuthorScreen renders persisted group type, rounds and members',
      (tester) async {
        final detail = _reviewDetail();

        await tester.pumpWidget(
          createWidgetUnderTest(
            ProgramAuthorScreen(programVersionId: detail.version.id),
            overrides: [
              programRepositoryProvider.overrideWithValue(
                _ReviewProgramRepository(db, detail),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Exercise groups'), findsOneWidget);
        expect(find.text('Superset • 3 rounds'), findsOneWidget);
        expect(
          find.text('Exercises: Squat → Row • 90s rest after round'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '4. OccurrenceActionsSheet displays B01-PD01 skip options dialog on tap',
      (tester) async {
        final readModel = _plannedOccurrenceItem();

        await tester.pumpWidget(
          createWidgetUnderTest(
            OccurrenceActionsSheet(occurrenceItem: readModel),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Template 1'), findsOneWidget);
        expect(find.text('Start Workout'), findsOneWidget);
        expect(find.text('Reschedule'), findsOneWidget);
        expect(find.text('Skip Workout'), findsOneWidget);

        // Tap Skip Workout to verify B01-PD01 choices
        await tester.tap(find.text('Skip Workout'));
        await tester.pumpAndSettle();

        // The action row remains visible behind the confirmation dialog.
        expect(find.text('Skip Workout'), findsNWidgets(2));
        expect(find.text('Make it up later'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Skip Workout'),
          findsOneWidget,
        );
      },
    );
  });
}
