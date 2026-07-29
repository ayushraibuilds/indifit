import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/calendar/occurrence_actions_sheet.dart';
import 'package:indifit/features/calendar/program_calendar_screen.dart';
import 'package:indifit/features/program_authoring/program_author_screen.dart';
import 'package:indifit/features/program_authoring/program_review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: child),
    );
  }

  group('B01-11A Program Authoring & Calendar Widget Tests', () {
    testWidgets(
      '1. ProgramAuthorScreen renders draft name input and save buttons',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(const ProgramAuthorScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Program Authoring'), findsOneWidget);
        expect(find.text('New Program'), findsOneWidget);
        expect(find.text('Save Draft'), findsOneWidget);
        expect(find.text('Review & Activate'), findsOneWidget);
      },
    );

    testWidgets(
      '2. ProgramReviewScreen displays version details and activation button',
      (tester) async {
        final repo = ProgramRepository(db);
        final progId = await repo.createProgram(
          name: 'Review Test Plan',
          blocks: [
            ProgramBlockInput(
              name: 'Block 1',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  templates: [
                    const SessionTemplateInput(
                      name: 'Template 1',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        ExercisePrescriptionInput(
                          exerciseNameSnapshot: 'Squat',
                          plannedSets: 3,
                          repsRange: '5',
                          ordinal: 0,
                          allowUnresolvedRawFallback: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final versionId = (await repo.getVersionsForProgram(progId)).first.id;

        await tester.pumpWidget(
          createWidgetUnderTest(
            ProgramReviewScreen(programVersionId: versionId),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Review & Activate'), findsOneWidget);
        expect(find.text('Review Test Plan'), findsOneWidget);
        expect(find.text('Publish & Activate Program'), findsOneWidget);
      },
    );

    testWidgets('3. ProgramCalendarScreen renders tabs and loads occurrences', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(const ProgramCalendarScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Training Calendar'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('All Range'), findsOneWidget);
    });

    testWidgets(
      '4. OccurrenceActionsSheet displays B01-PD01 skip options dialog on tap',
      (tester) async {
        final dates = LocalScheduleDateService();
        final calendarRepo = CalendarRepository(db, dates: dates);
        final programRepo = ProgramRepository(db);
        final coordinator = ProgramActivationCoordinator(db, dates: dates);

        final progId = await programRepo.createProgram(
          name: 'Action Sheet Plan',
          blocks: [
            ProgramBlockInput(
              name: 'Block 1',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  templates: [
                    const SessionTemplateInput(
                      name: 'Day 1 Bench',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        ExercisePrescriptionInput(
                          exerciseNameSnapshot: 'Bench Press',
                          plannedSets: 3,
                          repsRange: '8',
                          ordinal: 0,
                          allowUnresolvedRawFallback: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final v1 = (await programRepo.getVersionsForProgram(progId)).first;
        await coordinator.activate(
          ActivateProgramVersionCommand(
            programVersionId: v1.id,
            commandId: 'cmd-act-sheet',
            activationLocalDate: '2026-08-03',
            timezoneId: 'Asia/Kolkata',
          ),
        );

        final items = await calendarRepo.getOccurrencesInLocalDateRange(
          startLocalDate: '2026-08-01',
          endLocalDate: '2026-08-10',
        );
        expect(items.isNotEmpty, isTrue);

        final readModel = await calendarRepo.getCalendarOccurrenceItem(
          items.first.id,
        );
        expect(readModel, isNotNull);

        await tester.pumpWidget(
          createWidgetUnderTest(
            OccurrenceActionsSheet(occurrenceItem: readModel!),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Day 1 Bench'), findsOneWidget);
        expect(find.text('Start Workout'), findsOneWidget);
        expect(find.text('Reschedule'), findsOneWidget);
        expect(find.text('Skip Workout'), findsOneWidget);

        // Tap Skip Workout to verify B01-PD01 choices
        await tester.tap(find.text('Skip Workout'));
        await tester.pumpAndSettle();

        expect(find.text('Skip Workout'), findsOneWidget);
        expect(find.text('1. Keep Pending (Make up later)'), findsOneWidget);
        expect(find.text('2. Skip & Advance Progression'), findsOneWidget);
      },
    );
  });
}
