import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/repositories/travel_repository.dart';
import 'package:indifit/features/calendar/calendar_controller.dart';
import 'package:indifit/features/calendar/calendar_read_model.dart';
import 'package:indifit/features/calendar/program_calendar_screen.dart';
import 'package:indifit/features/calendar/workout_contextual_actions.dart';
import 'package:indifit/features/training/training_screen.dart';

/// Stub [CalendarController] that never opens Drift stream subscriptions.
/// Prevents lingering timer assertions in widget tests that only verify
/// popup-menu content rather than full calendar interaction.
class _StubCalendarController extends StateNotifier<CalendarUiState>
    implements CalendarController {
  _StubCalendarController()
      : super(
          const CalendarUiState(
            selectedLocalDate: '2026-08-23',
            timezoneId: 'Asia/Kolkata',
            isLoading: false,
          ),
        );

  @override
  CalendarUiState get currentState => state;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Separate databases for widget vs DB tests to avoid Drift stream conflicts.
  late final AppDatabase widgetDb;
  late final AppDatabase dataDb;
  late final CalendarRepository calendarRepo;
  late final CalendarReadRepository calendarReadRepo;
  late final EquipmentProfileRepository equipRepo;
  late final TravelRepository travelRepo;

  setUpAll(() {
    widgetDb = AppDatabase.memory();
    dataDb = AppDatabase.memory();
    calendarRepo = CalendarRepository(widgetDb);
    calendarReadRepo = CalendarReadRepository(widgetDb);
    equipRepo = EquipmentProfileRepository(dataDb);
    travelRepo = TravelRepository(
      db: dataDb,
      calendarRepo: CalendarRepository(dataDb),
      equipmentRepo: equipRepo,
    );
  });

  group('R08C.10 — Remove Travel Mode from Release Product', () {
    // ── Widget tests: use pump(), never pumpAndSettle() ──

    testWidgets(
      '1. No release entry in Training landing More options sheet',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(widgetDb),
              trainingLandingSnapshotProvider.overrideWith(
                (ref) async => const TrainingLandingSnapshot(
                  localDate: '2026-08-23',
                  timezoneId: 'Asia/Kolkata',
                  todayWorkout: null,
                  upcoming: [],
                  recentSessions: [],
                  activeProgramName: 'Hypertrophy Phase 1',
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const TrainingScreen(),
            ),
          ),
        );
        // Let the FutureProvider resolve + one animation frame.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final moreButton = find.byTooltip('More training options');
        expect(moreButton, findsOneWidget);
        await tester.tap(moreButton);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Must NOT contain Travel mode entry or "Coming soon"
        expect(find.text('Travel mode'), findsNothing);
        expect(find.text('Adjust training for a trip.'), findsNothing);
        expect(find.text('Coming soon'), findsNothing);

        // Canonical options remain present
        expect(find.text('Manage plan'), findsOneWidget);
        expect(find.text('Equipment and preferences'), findsOneWidget);
        expect(find.text('Log completed workout'), findsOneWidget);
        expect(find.text('Log other activity'), findsOneWidget);
      },
    );

    testWidgets(
      '2. No release entry or travel banner in ProgramCalendarScreen',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(widgetDb),
              calendarRepositoryProvider.overrideWithValue(calendarRepo),
              calendarReadRepositoryProvider.overrideWithValue(calendarReadRepo),
              calendarControllerProvider.overrideWith(
                (ref) => _StubCalendarController(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProgramCalendarScreen(),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // More options in Calendar AppBar
        final moreButton = find.byTooltip('More training options');
        expect(moreButton, findsOneWidget);
        await tester.tap(moreButton);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // No Travel mode menu item
        expect(find.text('Travel mode'), findsNothing);
        expect(find.text('Travel mode active'), findsNothing);
        expect(find.text('Choose a training plan'), findsOneWidget);

        // No travel active banner
        expect(find.textContaining('Travel mode is on'), findsNothing);
      },
    );

    testWidgets(
      '3. WorkoutContextualActions does not display travel equipment tag',
      (tester) async {
        final mockOccurrence = _createMockOccurrenceItem();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(widgetDb),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: WorkoutContextualActions(
                  item: mockOccurrence,
                  onOpenDetails: () {},
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.textContaining('Travel equipment'), findsNothing);
        expect(find.textContaining('Week 1'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Stale/deep route /travel-mode safely redirects to /training',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(widgetDb),
            onboardingCompletedProvider.overrideWith((ref) => true),
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => const TrainingLandingSnapshot(
                localDate: '2026-08-23',
                timezoneId: 'Asia/Kolkata',
                todayWorkout: null,
                upcoming: [],
                recentSessions: [],
                activeProgramName: null,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Trigger deep link to /travel-mode
        router.go('/travel-mode');
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Router redirects safely to /training
        expect(router.routeInformationProvider.value.uri.path, '/training');
        expect(find.byType(TrainingScreen), findsOneWidget);
        expect(find.text('Travel Mode'), findsNothing);
      },
    );

    testWidgets(
      '5. Surrounding Training routes remain valid',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(widgetDb),
            onboardingCompletedProvider.overrideWith((ref) => true),
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => const TrainingLandingSnapshot(
                localDate: '2026-08-23',
                timezoneId: 'Asia/Kolkata',
                todayWorkout: null,
                upcoming: [],
                recentSessions: [],
                activeProgramName: null,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        router.go('/training');
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(router.routeInformationProvider.value.uri.path, '/training');

        router.go('/exercises');
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(router.routeInformationProvider.value.uri.path, '/exercises');

        router.go('/equipment-profiles');
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          router.routeInformationProvider.value.uri.path,
          '/equipment-profiles',
        );
      },
    );

    // ── Pure data tests: use tester.runAsync to bridge real async ──

    testWidgets(
      '6. Persisted database compatibility — TravelRepository and tables remain intact',
      (tester) async {
        await tester.runAsync(() async {
          final activeTravel = await travelRepo.getActiveTravelContext();
          expect(activeTravel, isNull);

          final memberships = await travelRepo.getActiveTravelMembershipIds();
          expect(memberships, isEmpty);

          final allTravelRows = await dataDb.select(dataDb.travelContexts).get();
          expect(allTravelRows, isEmpty);

          final allMembershipRows =
              await dataDb.select(dataDb.travelContextOccurrences).get();
          expect(allMembershipRows, isEmpty);
        });
      },
    );

    testWidgets(
      '7. EquipmentPreferenceRepository can archive profile without active travel',
      (tester) async {
        await tester.runAsync(() async {
          final profileId =
              await equipRepo.createProfile(name: 'Temporary Gym');
          final profile = await equipRepo.getProfileById(profileId);
          expect(profile, isNotNull);

          await equipRepo.archiveProfile(profileId);
          final archived = await equipRepo.getProfileById(profileId);
          expect(archived?.archivedAtUtc, isNotNull);
        });
      },
    );
  });
}

CalendarOccurrenceReadItem _createMockOccurrenceItem() {
  final created = DateTime.utc(2026, 8, 1);
  final block = ProgramBlock(
    id: 'block-1',
    programVersionId: 'version-1',
    ordinal: 0,
    name: 'Block 1',
  );

  final week = const ProgramWeek(
    id: 'week-1',
    programVersionId: 'version-1',
    programBlockId: 'block-1',
    ordinalInBlock: 0,
    programWeekOrdinal: 0,
    isDeload: false,
  );

  final template = SessionTemplate(
    id: 'template-1',
    programWeekId: 'week-1',
    ordinal: 0,
    name: 'Full body session',
    plannedWeekday: DateTime.friday,
    activityType: 'legacy',
    defaultRestSeconds: null,
  );

  final version = ProgramVersion(
    id: 'version-1',
    programId: 'program-1',
    versionNumber: 1,
    status: 'published',
    origin: 'authoring',
    createdAtUtc: created,
  );

  final program = Program(
    id: 'program-1',
    name: 'Program',
    createdAtUtc: created,
  );

  final occurrence = ScheduledSessionOccurrence(
    id: 'occurrence-1',
    programVersionId: 'version-1',
    sessionTemplateId: 'template-1',
    programBlockOrdinal: 0,
    programWeekOrdinal: 0,
    sessionOrdinal: 0,
    repeatOrdinal: 0,
    originalLocalDate: '2026-08-23',
    originalTimezoneId: 'Asia/Kolkata',
    effectiveLocalDate: '2026-08-23',
    effectiveTimezoneId: 'Asia/Kolkata',
    status: 'planned',
    progressionDisposition: 'pending',
    createdAtUtc: created,
  );

  return CalendarOccurrenceReadItem(
    occurrence: occurrence,
    template: template,
    week: week,
    block: block,
    version: version,
    program: program,
    prescriptions: const [],
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}
