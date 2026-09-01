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
import 'package:indifit/features/calendar/workout_contextual_action_controller.dart';
import 'package:indifit/features/calendar/workout_contextual_actions.dart';
import 'package:indifit/features/training/training_screen.dart';

import 'support/indifit_test_harness.dart';

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

  late TestDatabaseScope databases;

  setUp(() {
    databases = TestDatabaseScope();
  });

  group('R08C.10 — Remove Travel Mode from Release Product', () {
    // ── Widget tests: use pump(), never pumpAndSettle() ──

    testWidgets('1. No release entry in Training landing More options sheet', (
      tester,
    ) async {
      final widgetDb = databases.create();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      _closeDatabaseAfterWidget(tester, databases);

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
    });

    testWidgets(
      '2. No release entry or travel banner in ProgramCalendarScreen',
      (tester) async {
        final widgetDb = databases.create();
        final calendarRepo = CalendarRepository(widgetDb);
        final calendarReadRepo = CalendarReadRepository(widgetDb);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        _closeDatabaseAfterWidget(tester, databases);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(widgetDb),
              calendarRepositoryProvider.overrideWithValue(calendarRepo),
              calendarReadRepositoryProvider.overrideWithValue(
                calendarReadRepo,
              ),
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
        _unmountWidget(tester);
        final mockOccurrence = _createMockOccurrenceItem();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutOccurrenceActionGatewayProvider.overrideWithValue(
                const _StubWorkoutOccurrenceActionGateway(),
              ),
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
        final container = ProviderContainer(
          overrides: [
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
        final router = container.read(appRouterProvider);
        router.go('/travel-mode');
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          container.dispose();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(router.routeInformationProvider.value.uri.path, '/training');
        expect(find.byType(TrainingScreen), findsOneWidget);
        expect(find.text('Travel Mode'), findsNothing);
      },
    );

    test('5. Surrounding Training routes remain valid', () {
      final container = ProviderContainer(
        overrides: [onboardingCompletedProvider.overrideWith((ref) => true)],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      router.go('/training');
      expect(router.routeInformationProvider.value.uri.path, '/training');

      router.go('/exercises');
      expect(router.routeInformationProvider.value.uri.path, '/exercises');

      router.go('/equipment-profiles');
      expect(
        router.routeInformationProvider.value.uri.path,
        '/equipment-profiles',
      );
    });

    // ── Pure data tests: use tester.runAsync to bridge real async ──

    testWidgets(
      '6. Persisted database compatibility — TravelRepository and tables remain intact',
      (tester) async {
        final dataDb = databases.create();
        final equipRepo = EquipmentProfileRepository(dataDb);
        final travelRepo = TravelRepository(
          db: dataDb,
          calendarRepo: CalendarRepository(dataDb),
          equipmentRepo: equipRepo,
        );
        addTearDown(databases.close);
        await tester.runAsync(() async {
          final activeTravel = await travelRepo.getActiveTravelContext();
          expect(activeTravel, isNull);

          final memberships = await travelRepo.getActiveTravelMembershipIds();
          expect(memberships, isEmpty);

          final allTravelRows = await dataDb
              .select(dataDb.travelContexts)
              .get();
          expect(allTravelRows, isEmpty);

          final allMembershipRows = await dataDb
              .select(dataDb.travelContextOccurrences)
              .get();
          expect(allMembershipRows, isEmpty);
        });
      },
    );

    testWidgets(
      '7. EquipmentPreferenceRepository can archive profile without active travel',
      (tester) async {
        final dataDb = databases.create();
        final equipRepo = EquipmentProfileRepository(dataDb);
        addTearDown(databases.close);
        await tester.runAsync(() async {
          final profileId = await equipRepo.createProfile(
            name: 'Temporary Gym',
          );
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

class _StubWorkoutOccurrenceActionGateway
    implements WorkoutOccurrenceActionGateway {
  const _StubWorkoutOccurrenceActionGateway();

  @override
  Future<ScheduledSessionOccurrence?> getOccurrence(
    String occurrenceId,
  ) async => null;

  @override
  Future<OccurrenceMutationResult> restore(RestoreOccurrenceCommand command) =>
      throw UnsupportedError('Presentation-only test gateway.');

  @override
  Future<OccurrenceMutationResult> skip(SkipOccurrenceCommand command) =>
      throw UnsupportedError('Presentation-only test gateway.');
}

void _closeDatabaseAfterWidget(
  WidgetTester tester,
  TestDatabaseScope databases,
) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await databases.close();
  });
}

void _unmountWidget(WidgetTester tester) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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
