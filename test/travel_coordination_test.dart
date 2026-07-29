import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/travel_repository.dart';
import 'package:indifit/features/travel/travel_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CalendarRepository calendarRepo;
  late EquipmentProfileRepository equipRepo;
  late TravelRepository travelRepo;
  late ProgramRepository programRepo;
  late ProgramActivationCoordinator coordinator;

  setUp(() {
    db = AppDatabase.memory();
    final dates = LocalScheduleDateService();
    calendarRepo = CalendarRepository(db, dates: dates);
    equipRepo = EquipmentProfileRepository(db);
    travelRepo = TravelRepository(
      db: db,
      calendarRepo: calendarRepo,
      equipmentRepo: equipRepo,
    );
    programRepo = ProgramRepository(db);
    coordinator = ProgramActivationCoordinator(db, dates: dates);
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-08B Travel Coordination & Equipment Override Tests', () {
    test(
      '1. Previews travel interval and identifies affected occurrences without mutating program structure',
      () async {
        // 0. Seed exercise with stableId in catalog
        const benchPressUuid = 'ex-bench-press-uuid';
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                stableId: const Value(benchPressUuid),
                name: 'Flat Barbell Bench Press',
                muscleGroups: 'Chest',
                equipment: 'barbell',
                difficulty: 'Intermediate',
                formCues: 'Arch upper back',
                commonMistakes: 'Bouncing bar off chest',
              ),
            );

        // 1. Create equipment profiles
        final homeProfileId = await equipRepo.createProfile(
          name: 'Home Gym',
          items: [
            const EquipmentProfileItemInput(
              equipmentCode: 'barbell',
              isAvailable: true,
            ),
            const EquipmentProfileItemInput(
              equipmentCode: 'dumbbell',
              isAvailable: true,
            ),
          ],
        );
        await equipRepo.setDefaultProfileId(homeProfileId);

        final hotelProfileId = await equipRepo.createProfile(
          name: 'Hotel Gym',
          items: [
            const EquipmentProfileItemInput(
              equipmentCode: 'dumbbell',
              isAvailable: true,
            ),
            const EquipmentProfileItemInput(
              equipmentCode: 'barbell',
              isAvailable: false,
            ),
          ],
        );

        // 2. Create and activate a 1-week program
        final programId = await programRepo.createProgram(
          name: 'Travel Test Program',
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
                      name: 'Day 1 Bench Press',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseId: benchPressUuid,
                          exerciseNameSnapshot: 'Flat Barbell Bench Press',
                          plannedSets: 4,
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
        await coordinator.activate(
          ActivateProgramVersionCommand(
            programVersionId: v1.id,
            commandId: 'cmd-activate-1',
            activationLocalDate: '2026-08-03', // Monday
            timezoneId: 'Asia/Kolkata',
          ),
        );

        // Preview travel for 2026-08-03 to 2026-08-05
        final preview = await travelRepo.previewTravelContext(
          startLocalDate: '2026-08-03',
          endLocalDate: '2026-08-05',
          timezoneId: 'Asia/Kolkata',
          equipmentProfileId: hotelProfileId,
        );

        expect(preview.affectedOccurrences.length, equals(1));
        expect(
          preview.affectedOccurrences.first.effectiveLocalDate,
          equals('2026-08-03'),
        );
        expect(preview.occurrenceIncompatibleExercises.isNotEmpty, isTrue);

        // Assert program structure (blocks/weeks/templates) was NOT mutated
        final detail = await programRepo.getProgramVersionDetail(v1.id);
        expect(detail!.weeks.first.isDeload, isFalse);
        expect(detail.blocks.first.ordinal, equals(0));
      },
    );

    test(
      '2. Applies travel context, stores explicit membership, and resolves effective equipment profile',
      () async {
        final defaultProfileId = await equipRepo.createProfile(
          name: 'Default Profile',
        );
        await equipRepo.setDefaultProfileId(defaultProfileId);

        final travelProfileId = await equipRepo.createProfile(
          name: 'Travel Hotel Profile',
        );

        // Create travel context
        final travelId = await travelRepo.createAndApplyTravelContext(
          startLocalDate: '2026-08-10',
          endLocalDate: '2026-08-17',
          timezoneId: 'Asia/Kolkata',
          equipmentProfileId: travelProfileId,
          note: 'Business trip to Mumbai',
        );

        expect(travelId, isNotEmpty);

        // Verify active travel context
        final activeTravel = await travelRepo.getActiveTravelContext(
          localDate: '2026-08-12',
        );
        expect(activeTravel, isNotNull);
        expect(activeTravel!.id, equals(travelId));
        expect(activeTravel.equipmentProfileId, equals(travelProfileId));

        // Resolve effective profile during travel date vs outside travel date
        expect(
          await travelRepo.getEffectiveEquipmentProfileId(
            localDate: '2026-08-12',
          ),
          equals(travelProfileId),
        );
        expect(
          await travelRepo.getEffectiveEquipmentProfileId(
            localDate: '2026-08-20',
          ),
          equals(defaultProfileId),
        );
      },
    );

    test(
      '3. Cancelling travel context restores default equipment profile',
      () async {
        final defaultId = await equipRepo.createProfile(
          name: 'Default Profile',
        );
        await equipRepo.setDefaultProfileId(defaultId);

        final travelId = await equipRepo.createProfile(name: 'Travel Profile');

        final tcId = await travelRepo.createAndApplyTravelContext(
          startLocalDate: '2026-09-01',
          endLocalDate: '2026-09-07',
          timezoneId: 'Asia/Kolkata',
          equipmentProfileId: travelId,
        );

        expect(
          await travelRepo.getEffectiveEquipmentProfileId(
            localDate: '2026-09-03',
          ),
          equals(travelId),
        );

        // Cancel travel
        await travelRepo.cancelTravelContext(tcId);

        expect(
          await travelRepo.getActiveTravelContext(localDate: '2026-09-03'),
          isNull,
        );
        expect(
          await travelRepo.getEffectiveEquipmentProfileId(
            localDate: '2026-09-03',
          ),
          equals(defaultId),
        );
      },
    );

    test(
      '4. TravelController manages travel preview, apply, and cancel state reactively',
      () async {
        final profileId = await equipRepo.createProfile(
          name: 'Hotel Gym Profile',
        );

        final controller = TravelController(travelRepo: travelRepo);

        await controller.previewTravel(
          startLocalDate: '2026-10-01',
          endLocalDate: '2026-10-07',
          timezoneId: 'Asia/Kolkata',
          equipmentProfileId: profileId,
        );

        expect(controller.state.previewResult, isNotNull);

        await controller.applyTravel(note: 'Vacation in Goa');
        expect(controller.state.activeTravelContext, isNotNull);

        await controller.cancelActiveTravel();
        expect(controller.state.activeTravelContext, isNull);
      },
    );
  });
}
