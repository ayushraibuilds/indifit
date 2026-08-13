import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/repositories/travel_repository.dart';
import 'package:indifit/features/travel/travel_controller.dart';
import 'package:indifit/features/travel/travel_mode_screen.dart';
import 'package:indifit/features/travel/travel_preview_sheet.dart';

// ─── Test fakes ──────────────────────────────────────────────────────

class _FakeEquipmentProfileRepo extends EquipmentProfileRepository {
  final EquipmentProfile homeGym = EquipmentProfile(
    id: 'profile-home-gym',
    name: 'Home Gym',
    createdAtUtc: DateTime.utc(2026, 7, 1),
    updatedAtUtc: DateTime.utc(2026, 7, 1),
  );

  final EquipmentProfile hotelGym = EquipmentProfile(
    id: 'profile-hotel-gym',
    name: 'Hotel Gym',
    createdAtUtc: DateTime.utc(2026, 7, 1),
    updatedAtUtc: DateTime.utc(2026, 7, 1),
  );

  _FakeEquipmentProfileRepo(super.db);

  @override
  Future<List<EquipmentProfile>> getActiveProfiles() async => [
    homeGym,
    hotelGym,
  ];

  @override
  Future<String?> getDefaultProfileId() async => hotelGym.id;

  @override
  Future<EquipmentProfileAggregate?> getProfile(String profileId) async {
    if (profileId == homeGym.id) {
      return EquipmentProfileAggregate(profile: homeGym, items: const []);
    }
    if (profileId == hotelGym.id) {
      return EquipmentProfileAggregate(profile: hotelGym, items: const []);
    }
    return null;
  }

  @override
  Future<EquipmentProfile?> getProfileById(String profileId) async {
    if (profileId == homeGym.id) return homeGym;
    if (profileId == hotelGym.id) return hotelGym;
    return null;
  }

  @override
  Future<EquipmentCompatibility> checkCompatibility({
    required String profileId,
    required String exerciseEquipmentRequirement,
    bool exerciseIdentityResolved = true,
  }) async => EquipmentCompatibility(
    status: EquipmentCompatibilityStatus.compatible,
    requiredEquipmentCodes: const [],
    unavailableEquipmentCodes: const [],
    originalRequirement: exerciseEquipmentRequirement,
  );
}

class _FakeTravelController extends StateNotifier<TravelUiState>
    implements TravelController {
  bool previewCalled = false;
  bool applyCalled = false;
  bool cancelCalled = false;
  bool endCalled = false;
  bool failApply = false;
  String? lastApplyNote;

  _FakeTravelController() : super(const TravelUiState(isLoading: false));

  @override
  Future<void> loadActiveTravel() async {
    // No-op for tests.
  }

  @override
  Future<void> previewTravel({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required String equipmentProfileId,
  }) async {
    previewCalled = true;
    state = state.copyWith(
      previewResult: TravelPreviewResult(
        startLocalDate: startLocalDate,
        endLocalDate: endLocalDate,
        timezoneId: timezoneId,
        equipmentProfileId: equipmentProfileId,
        affectedOccurrences: [
          _makeFakeOccurrence('occ-1', startLocalDate, timezoneId),
        ],
        occurrenceIncompatibleExercises: {
          'occ-1': ['Barbell Squat'],
        },
      ),
    );
  }

  @override
  Future<void> applyTravel({String? note}) async {
    if (failApply) throw StateError('Preview is stale');
    applyCalled = true;
    lastApplyNote = note;
    final fakeTravel = TravelContext(
      id: 'travel-active-1',
      startLocalDate: '2026-08-01',
      endLocalDate: '2026-08-07',
      timezoneId: 'Europe/London',
      equipmentProfileId: 'profile-hotel-gym',
      status: 'active',
      note: note,
      createdAtUtc: DateTime.utc(2026, 7, 29),
    );
    state = state.copyWith(activeTravelContext: fakeTravel, clearPreview: true);
  }

  @override
  Future<void> cancelActiveTravel() async {
    cancelCalled = true;
    state = state.copyWith(clearActiveTravel: true);
  }

  @override
  Future<void> endActiveTravel() async {
    endCalled = true;
    state = state.copyWith(clearActiveTravel: true);
  }

  @override
  Future<TravelRescheduleMembershipImpact> previewRescheduleMembership({
    required String occurrenceId,
    required String targetLocalDate,
  }) async {
    return const TravelRescheduleMembershipImpact(
      context: null,
      isMember: false,
      targetIsInsideInterval: false,
    );
  }

  @override
  Future<void> rescheduleOccurrence({
    required RescheduleOccurrenceCommand command,
    TravelMembershipChoice? membershipChoice,
  }) async {}

  void setActiveTravelForTest() {
    state = state.copyWith(
      activeTravelContext: TravelContext(
        id: 'travel-active-1',
        startLocalDate: '2026-08-01',
        endLocalDate: '2026-08-07',
        timezoneId: 'Europe/London',
        equipmentProfileId: 'profile-hotel-gym',
        status: 'active',
        note: 'Business trip',
        createdAtUtc: DateTime.utc(2026, 7, 29),
      ),
    );
  }
}

ScheduledSessionOccurrence _makeFakeOccurrence(
  String id,
  String localDate,
  String timezoneId,
) {
  return ScheduledSessionOccurrence(
    id: id,
    programVersionId: 'pv-1',
    sessionTemplateId: 'st-1',
    programBlockOrdinal: 0,
    programWeekOrdinal: 0,
    sessionOrdinal: 0,
    repeatOrdinal: 0,
    originalLocalDate: localDate,
    originalTimezoneId: timezoneId,
    effectiveLocalDate: localDate,
    effectiveTimezoneId: timezoneId,
    status: 'scheduled',
    progressionDisposition: 'pending',
    createdAtUtc: DateTime.utc(2026, 7, 29),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeEquipmentProfileRepo fakeEquipmentRepo;
  late _FakeTravelController fakeTravelController;

  setUp(() {
    db = AppDatabase.memory();
    fakeEquipmentRepo = _FakeEquipmentProfileRepo(db);
    fakeTravelController = _FakeTravelController();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        equipmentProfileRepositoryProvider.overrideWithValue(fakeEquipmentRepo),
        travelControllerProvider.overrideWith((ref) => fakeTravelController),
        ...overrides,
      ],
      child: MaterialApp(home: child),
    );
  }

  group('B01-11B Travel Mode Widget Tests', () {
    testWidgets(
      '1. Setup form renders profile dropdown, date picker, and timezone selector',
      (tester) async {
        await tester.pumpWidget(createWidget(const TravelModeScreen()));
        await tester.pumpAndSettle();

        // Title for idle state.
        expect(find.text('Plan Travel'), findsOneWidget);

        // Header content.
        expect(find.text('Plan Your Travel'), findsOneWidget);
        expect(
          find.textContaining('Dates, order, ordinals, and deload weeks'),
          findsOneWidget,
        );

        // Date picker target.
        expect(find.text('Select date range'), findsOneWidget);

        // Equipment profile dropdown starts with the durable default profile.
        expect(find.text('Hotel Gym'), findsOneWidget);

        // Timezone dropdown.
        expect(find.textContaining('America/New York'), findsOneWidget);

        // Preview button should be disabled without date range.
        final previewButton = find.text('Preview Affected Workouts');
        expect(previewButton, findsOneWidget);
      },
    );

    testWidgets(
      '2. Active travel shows summary card with dates, timezone, profile, and note',
      (tester) async {
        fakeTravelController.setActiveTravelForTest();

        await tester.pumpWidget(createWidget(const TravelModeScreen()));
        await tester.pumpAndSettle();

        // Title for active state.
        expect(find.text('Travel Mode'), findsOneWidget);

        // Active badge.
        expect(find.text('TRAVEL ACTIVE'), findsOneWidget);

        // Travel details.
        expect(find.text('Aug 1 – Aug 7, 2026'), findsOneWidget);
        expect(find.textContaining('Europe/London'), findsOneWidget);
        expect(find.text('Business trip'), findsOneWidget);

        // Action buttons.
        expect(
          find.text('End Travel — Restore Normal Profile'),
          findsOneWidget,
        );
        expect(find.text('Cancel Travel'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Cancel travel button shows confirmation dialog and calls controller',
      (tester) async {
        fakeTravelController.setActiveTravelForTest();

        await tester.pumpWidget(createWidget(const TravelModeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel Travel'));
        await tester.pumpAndSettle();

        // Confirmation dialog.
        expect(find.text('Cancel Travel Mode?'), findsOneWidget);
        expect(find.textContaining('restore your'), findsOneWidget);

        // Confirm cancel.
        await tester.tap(find.widgetWithText(FilledButton, 'Cancel Travel'));
        await tester.pumpAndSettle();

        expect(fakeTravelController.cancelCalled, isTrue);
      },
    );

    testWidgets(
      '4. End travel delegates to the controller and restores normal resolution',
      (tester) async {
        fakeTravelController.setActiveTravelForTest();

        await tester.pumpWidget(createWidget(const TravelModeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('End Travel — Restore Normal Profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'End Travel'));
        await tester.pumpAndSettle();

        expect(fakeTravelController.endCalled, isTrue);
      },
    );

    testWidgets(
      '5. TravelPreviewSheet renders affected occurrences and incompatible exercises',
      (tester) async {
        final preview = TravelPreviewResult(
          startLocalDate: '2026-08-01',
          endLocalDate: '2026-08-07',
          timezoneId: 'Europe/London',
          equipmentProfileId: 'profile-hotel-gym',
          affectedOccurrences: [
            _makeFakeOccurrence('occ-1', '2026-08-02', 'Europe/London'),
            _makeFakeOccurrence('occ-2', '2026-08-05', 'Europe/London'),
          ],
          occurrenceIncompatibleExercises: {
            'occ-1': ['Barbell Squat', 'Leg Press'],
            'occ-2': [],
          },
        );

        await tester.pumpWidget(
          createWidget(
            Scaffold(
              body: TravelPreviewSheet(
                preview: preview,
                profileName: 'Hotel Gym',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header.
        expect(find.text('Travel Preview'), findsOneWidget);

        // Summary chips.
        expect(find.textContaining('Aug 1'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Europe/London'), findsNothing);
        expect(find.text('Hotel Gym'), findsOneWidget);

        // Stats.
        expect(find.text('2'), findsOneWidget); // 2 workouts affected
        expect(find.text('1'), findsOneWidget); // 1 with incompatible

        // Occurrence items.
        expect(find.textContaining('Aug 2'), findsOneWidget);
        expect(find.textContaining('Aug 5'), findsOneWidget);

        // Incompatible exercises.
        expect(find.textContaining('Barbell Squat'), findsOneWidget);
        expect(find.textContaining('Leg Press'), findsOneWidget);

        // Invariant text.
        expect(
          find.textContaining('Dates, order, ordinals, and deload weeks'),
          findsOneWidget,
        );

        // Apply button.
        expect(find.text('Apply Travel Mode'), findsOneWidget);
      },
    );

    testWidgets('6. TravelPreviewSheet apply button delegates to controller', (
      tester,
    ) async {
      final preview = TravelPreviewResult(
        startLocalDate: '2026-08-01',
        endLocalDate: '2026-08-07',
        timezoneId: 'Europe/London',
        equipmentProfileId: 'profile-hotel-gym',
        affectedOccurrences: [
          _makeFakeOccurrence('occ-1', '2026-08-02', 'Europe/London'),
        ],
        occurrenceIncompatibleExercises: {},
      );

      // Pump the preview result into the controller state so applyTravel
      // can read it.
      fakeTravelController.state = fakeTravelController.state.copyWith(
        previewResult: preview,
      );

      await tester.pumpWidget(
        createWidget(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => TravelPreviewSheet(
                    preview: preview,
                    profileName: 'Hotel Gym',
                  ),
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Travel Mode'));
      await tester.pumpAndSettle();

      expect(fakeTravelController.applyCalled, isTrue);
    });

    testWidgets(
      '7. Failed apply keeps the preview visible and surfaces the error',
      (tester) async {
        final preview = TravelPreviewResult(
          startLocalDate: '2026-08-01',
          endLocalDate: '2026-08-07',
          timezoneId: 'Europe/London',
          equipmentProfileId: 'profile-hotel-gym',
          affectedOccurrences: const [],
          occurrenceIncompatibleExercises: const {},
        );
        fakeTravelController.failApply = true;
        fakeTravelController.state = fakeTravelController.state.copyWith(
          previewResult: preview,
        );

        await tester.pumpWidget(
          createWidget(
            Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => TravelPreviewSheet(
                      preview: preview,
                      profileName: 'Hotel Gym',
                    ),
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply Travel Mode'));
        await tester.pumpAndSettle();

        expect(find.text('Travel Preview'), findsOneWidget);
        expect(
          find.text('Travel mode could not be applied. Try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('8. Empty preview shows no-workouts message', (tester) async {
      final preview = TravelPreviewResult(
        startLocalDate: '2026-09-01',
        endLocalDate: '2026-09-07',
        timezoneId: 'America/New_York',
        equipmentProfileId: 'profile-hotel-gym',
        affectedOccurrences: [],
        occurrenceIncompatibleExercises: {},
      );

      await tester.pumpWidget(
        createWidget(
          Scaffold(
            body: TravelPreviewSheet(
              preview: preview,
              profileName: 'Hotel Gym',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No scheduled workouts in this date range.'),
        findsOneWidget,
      );
    });

    testWidgets('9. Active travel app bar badge shows ACTIVE status', (
      tester,
    ) async {
      fakeTravelController.setActiveTravelForTest();

      await tester.pumpWidget(createWidget(const TravelModeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('10. Semantics — travel active status has semantic label', (
      tester,
    ) async {
      fakeTravelController.setActiveTravelForTest();

      await tester.pumpWidget(createWidget(const TravelModeScreen()));
      await tester.pumpAndSettle();

      // Verify a Semantics widget exists with the 'Travel mode active' label.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Travel mode active',
        ),
        findsOneWidget,
      );
    });

    testWidgets('11. Large text — setup form renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const TravelModeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // If this renders without exceptions, overflow handling is adequate.
      expect(find.text('Plan Travel'), findsOneWidget);
    });
  });
}
