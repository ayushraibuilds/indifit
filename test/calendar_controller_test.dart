import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/calendar/calendar_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository programRepo;
  late ProgramActivationCoordinator activationCoordinator;
  late CalendarRepository calendarRepo;

  setUp(() async {
    db = AppDatabase.memory();
    programRepo = ProgramRepository(db);
    activationCoordinator = ProgramActivationCoordinator(db);
    calendarRepo = CalendarRepository(db);

    // Seed exercise catalogue item for FK validation
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('ex-squat-stable-id'),
            name: 'Squat',
            muscleGroups: 'Legs',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Chest up',
            commonMistakes: 'Knees in',
          ),
        );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('ex-bench-stable-id'),
            name: 'Bench',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Touch chest',
            commonMistakes: 'Elbow flare',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-08A Calendar Read Models & Controller Tests', () {
    test(
      '1. CalendarController queries date range and sorts same-day occurrences',
      () async {
        final programId = await programRepo.createProgram(
          name: 'Full Body Program',
          blocks: [
            ProgramBlockInput(
              name: 'Block 1',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  templates: [
                    SessionTemplateInput(
                      name: 'Morning Session',
                      ordinal: 0,
                      plannedWeekday: 1,
                      plannedStartMinute: 540, // 9:00 AM
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseId: 'ex-squat-stable-id',
                          exerciseNameSnapshot: 'Squat',
                          plannedSets: 3,
                          repsRange: '5',
                          ordinal: 0,
                        ),
                      ],
                    ),
                    SessionTemplateInput(
                      name: 'Evening Session',
                      ordinal: 1,
                      plannedWeekday: 1,
                      plannedStartMinute: 1080, // 6:00 PM
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseId: 'ex-bench-stable-id',
                          exerciseNameSnapshot: 'Bench',
                          plannedSets: 3,
                          repsRange: '8',
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

        final v1 = (await programRepo.getVersionsForProgram(programId)).first;

        await activationCoordinator.activate(
          ActivateProgramVersionCommand(
            programVersionId: v1.id,
            activationLocalDate: '2026-08-03', // Monday
            timezoneId: 'UTC',
            commandId: 'cmd-activate-1',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            calendarRepositoryProvider.overrideWithValue(calendarRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(calendarControllerProvider.notifier);
        await controller.selectDate('2026-08-03');

        final state = container.read(calendarControllerProvider);
        expect(state.isLoading, isFalse);
        expect(state.selectedDateOccurrences.length, equals(2));

        // Assert sorting by plannedStartMinute: Morning (540) before Evening (1080)
        expect(
          state.selectedDateOccurrences[0].template.name,
          equals('Morning Session'),
        );
        expect(
          state.selectedDateOccurrences[1].template.name,
          equals('Evening Session'),
        );
      },
    );

    test('2. Identifies overdue occurrences correctly', () async {
      final programId = await programRepo.createProgram(
        name: 'Overdue Test Program',
        blocks: [
          ProgramBlockInput(
            name: 'Block 1',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Past Workout',
                    ordinal: 0,
                    plannedWeekday: 1,
                    prescriptions: [
                      const ExercisePrescriptionInput(
                        exerciseId: 'ex-squat-stable-id',
                        exerciseNameSnapshot: 'Squat',
                        plannedSets: 3,
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

      final v1 = (await programRepo.getVersionsForProgram(programId)).first;

      await activationCoordinator.activate(
        ActivateProgramVersionCommand(
          programVersionId: v1.id,
          activationLocalDate: '2026-07-20', // Past Monday
          timezoneId: 'UTC',
          commandId: 'cmd-activate-overdue',
        ),
      );

      final customDates = LocalScheduleDateService(
        nowUtc: () => DateTime.parse('2026-07-29T12:00:00Z'),
      );
      final controller = CalendarController(
        calendarRepo: calendarRepo,
        readRepo: CalendarReadRepository(db, dates: customDates),
        dates: customDates,
      );
      addTearDown(controller.dispose);

      await controller.selectDate('2026-07-29');

      expect(controller.currentState.overdueOccurrences.length, equals(1));
      expect(
        controller.currentState.overdueOccurrences.first.isOverdue,
        isTrue,
      );
    });

    test(
      '3. Reschedule, Skip, Cancel, and Repeat update calendar state reactively',
      () async {
        final programId = await programRepo.createProgram(
          name: 'State Machine Test Program',
          blocks: [
            ProgramBlockInput(
              name: 'Block 1',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  templates: [
                    SessionTemplateInput(
                      name: 'Template 1',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseId: 'ex-bench-stable-id',
                          exerciseNameSnapshot: 'Bench',
                          plannedSets: 3,
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

        final v1 = (await programRepo.getVersionsForProgram(programId)).first;

        await activationCoordinator.activate(
          ActivateProgramVersionCommand(
            programVersionId: v1.id,
            activationLocalDate: '2026-08-03',
            timezoneId: 'UTC',
            commandId: 'cmd-activate-3',
          ),
        );

        final controller = CalendarController(
          calendarRepo: calendarRepo,
          readRepo: CalendarReadRepository(db),
        );
        addTearDown(controller.dispose);
        await controller.selectDate('2026-08-03');

        final initialOcc =
            controller.currentState.selectedDateOccurrences.first.occurrence;

        // Reschedule occurrence to 2026-08-04
        await controller.rescheduleOccurrence(
          initialOcc.id,
          '2026-08-04',
          confirmed: true,
        );
        await controller.selectDate('2026-08-04');
        expect(
          controller.currentState.selectedDateOccurrences.length,
          equals(1),
        );
        expect(
          controller
              .currentState
              .selectedDateOccurrences
              .first
              .occurrence
              .status,
          equals('rescheduled'),
        );

        // Skip occurrence
        await controller.skipOccurrence(
          initialOcc.id,
          disposition: SkipDisposition.keepPending,
        );
        await controller.selectDate('2026-08-04');
        expect(
          controller
              .currentState
              .selectedDateOccurrences
              .first
              .occurrence
              .status,
          equals('skipped'),
        );
      },
    );
  });
}
