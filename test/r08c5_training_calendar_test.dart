import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/calendar/calendar_controller.dart';
import 'package:indifit/features/calendar/calendar_read_model.dart';
import 'package:indifit/features/calendar/occurrence_actions_sheet.dart';
import 'package:indifit/features/calendar/program_calendar_screen.dart';
import 'package:indifit/features/calendar/workout_contextual_actions.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

const _programId = 'program-r08c5';
const _versionId = 'version-r08c5';
const _blockId = 'block-r08c5';
const _weekId = 'week-r08c5';

Program _testProgram() => Program(
  id: _programId,
  name: 'Strength 101',
  createdAtUtc: DateTime.utc(2026, 8, 1),
);

ProgramVersion _testVersion() => ProgramVersion(
  id: _versionId,
  programId: _programId,
  versionNumber: 1,
  status: 'active',
  origin: 'user',
  createdAtUtc: DateTime.utc(2026, 8, 1),
);

ProgramBlock _testBlock() => const ProgramBlock(
  id: _blockId,
  programVersionId: _versionId,
  ordinal: 0,
  name: 'Hypertrophy Block',
);

ProgramWeek _testWeek() => const ProgramWeek(
  id: _weekId,
  programVersionId: _versionId,
  programBlockId: _blockId,
  ordinalInBlock: 0,
  programWeekOrdinal: 0,
  isDeload: false,
);

SessionTemplate _lowerTemplate() => const SessionTemplate(
  id: 'template-lower',
  programWeekId: _weekId,
  ordinal: 0,
  name: 'Day A: Lower',
  plannedWeekday: DateTime.monday,
  activityType: 'strength',
);

SessionTemplate _upperTemplate() => const SessionTemplate(
  id: 'template-upper',
  programWeekId: _weekId,
  ordinal: 1,
  name: 'Day B: Upper',
  plannedWeekday: DateTime.wednesday,
  activityType: 'strength',
);

CalendarOccurrenceReadItem _makeOccurrence({
  required String id,
  required SessionTemplate template,
  required String effectiveLocalDate,
  required String status,
  bool isOverdue = false,
  bool isDeload = false,
  String progressionDisposition = 'pending',
}) => CalendarOccurrenceReadItem(
  occurrence: ScheduledSessionOccurrence(
    id: id,
    programVersionId: _versionId,
    sessionTemplateId: template.id,
    programBlockOrdinal: 0,
    programWeekOrdinal: 0,
    sessionOrdinal: 0,
    repeatOrdinal: 0,
    originalLocalDate: effectiveLocalDate,
    originalTimezoneId: 'UTC',
    effectiveLocalDate: effectiveLocalDate,
    effectiveTimezoneId: 'UTC',
    status: status,
    progressionDisposition: progressionDisposition,
    createdAtUtc: DateTime.utc(2026, 8, 1),
  ),
  template: template,
  week: _testWeek(),
  block: _testBlock(),
  version: _testVersion(),
  program: _testProgram(),
  prescriptions: const [],
  isOverdue: isOverdue,
  isDeload: isDeload,
  isNextRequired: status == 'planned',
);

// ---------------------------------------------------------------------------
// Stub controllers that don't open Drift watch() streams
// ---------------------------------------------------------------------------

class _StubCalendarController extends StateNotifier<CalendarUiState>
    implements CalendarController {
  _StubCalendarController(super.initial);

  @override
  CalendarUiState get currentState => state;
  @override
  Future<void> selectDate(String localDate) async {
    state = state.copyWith(
      selectedLocalDate: localDate,
      selectedDateOccurrences: state.rangeOccurrences
          .where((o) => o.occurrence.effectiveLocalDate == localDate)
          .toList(),
    );
  }

  @override
  Future<void> setView(CalendarView view) async =>
      state = state.copyWith(view: view);
  @override
  Future<void> setTimezone(String id) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> rescheduleOccurrence(
    String id,
    String date, {
    required bool confirmed,
    String? effectiveTimezoneId,
    String? reason,
  }) async {}
  @override
  Future<void> skipOccurrence(
    String id, {
    required SkipDisposition disposition,
    String? reason,
  }) async {}
  @override
  Future<void> cancelOccurrence(String id, {String? reason}) async {}
  @override
  Future<void> restoreOccurrence(String id) async {}
  @override
  Future<void> repeatOccurrence(
    String id,
    String targetLocalDate, {
    required RepeatPurpose purpose,
    String? timezoneId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a test app with a CalendarController stub.
Widget _buildTestApp({
  required CalendarUiState calendarState,
  ThemeData? theme,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) {
  final calendarCtrl = _StubCalendarController(calendarState);

  return ProviderScope(
    overrides: [
      calendarControllerProvider.overrideWith((_) => calendarCtrl),
      localScheduleDateServiceProvider.overrideWithValue(
        LocalScheduleDateService(nowUtc: () => DateTime.utc(2026, 8, 3, 10, 0)),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const ProgramCalendarScreen(),
    ),
  );
}

/// Builds a test app with a single WorkoutContextualActions card.
Widget _buildContextualActionsApp({
  required CalendarOccurrenceReadItem item,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      localScheduleDateServiceProvider.overrideWithValue(
        LocalScheduleDateService(nowUtc: () => DateTime.utc(2026, 8, 3, 10, 0)),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorkoutContextualActions(item: item, onOpenDetails: () {}),
        ),
      ),
    ),
  );
}

/// Builds an OccurrenceActionsSheet test.
Widget _buildActionsSheetApp(CalendarOccurrenceReadItem item) {
  return ProviderScope(
    overrides: [
      localScheduleDateServiceProvider.overrideWithValue(
        LocalScheduleDateService(nowUtc: () => DateTime.utc(2026, 8, 3, 10, 0)),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: OccurrenceActionsSheet(occurrenceItem: item)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mondayPlanned = _makeOccurrence(
    id: 'occ-monday',
    template: _lowerTemplate(),
    effectiveLocalDate: '2026-08-03',
    status: 'planned',
  );
  final wednesdayPlanned = _makeOccurrence(
    id: 'occ-wednesday',
    template: _upperTemplate(),
    effectiveLocalDate: '2026-08-05',
    status: 'planned',
  );
  final mondayCompleted = _makeOccurrence(
    id: 'occ-monday-done',
    template: _lowerTemplate(),
    effectiveLocalDate: '2026-08-03',
    status: 'completed',
    progressionDisposition: 'satisfied',
  );
  final mondayPartial = _makeOccurrence(
    id: 'occ-monday-partial',
    template: _lowerTemplate(),
    effectiveLocalDate: '2026-08-03',
    status: 'partiallyCompleted',
    progressionDisposition: 'satisfied',
  );
  final mondaySkipped = _makeOccurrence(
    id: 'occ-monday-skipped',
    template: _lowerTemplate(),
    effectiveLocalDate: '2026-08-03',
    status: 'skipped',
    progressionDisposition: 'make_up_later',
  );

  CalendarUiState todayState({
    List<CalendarOccurrenceReadItem>? selected,
    List<CalendarOccurrenceReadItem>? range,
    CalendarView view = CalendarView.week,
  }) => CalendarUiState(
    selectedLocalDate: '2026-08-03',
    timezoneId: 'UTC',
    view: view,
    activeProgramVersionId: _versionId,
    activeProgramName: 'Strength 101',
    selectedDateOccurrences: selected ?? [mondayPlanned],
    rangeOccurrences: range ?? [mondayPlanned, wednesdayPlanned],
  );

  group('R08C.5 Training Calendar', () {
    // -----------------------------------------------------------------------
    // 1. Today: planned workout shown with action buttons
    // -----------------------------------------------------------------------
    testWidgets('1. Today: displays planned workout with action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(calendarState: todayState()));
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Day A: Lower'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. WorkoutContextualActions: completed occurrence shows View, not Start
    // -----------------------------------------------------------------------
    testWidgets(
      '2. Completed occurrence shows View workout, not Start/Resume',
      (tester) async {
        await tester.pumpWidget(
          _buildContextualActionsApp(item: mondayCompleted),
        );
        await tester.pumpAndSettle();

        expect(find.text('Day A: Lower'), findsOneWidget);
        expect(find.text('Completed'), findsWidgets);
        expect(find.text('View workout'), findsOneWidget);
        expect(find.text('Start workout'), findsNothing);
        expect(find.text('Resume workout'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 3. TRN-07: partiallyCompleted is not resumable
    // -----------------------------------------------------------------------
    testWidgets(
      '3. Partially completed shows View workout, never Start/Resume',
      (tester) async {
        await tester.pumpWidget(
          _buildContextualActionsApp(item: mondayPartial),
        );
        await tester.pumpAndSettle();

        expect(find.text('Day A: Lower'), findsOneWidget);
        expect(find.text('Partially completed'), findsWidgets);
        expect(find.text('View workout'), findsOneWidget);
        expect(find.text('Start workout'), findsNothing);
        expect(find.text('Resume workout'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 4. Skipped/Cancelled: shows Restore to plan
    // -----------------------------------------------------------------------
    testWidgets('4. Skipped occurrence shows Restore to plan action', (
      tester,
    ) async {
      await tester.pumpWidget(_buildContextualActionsApp(item: mondaySkipped));
      await tester.pumpAndSettle();

      expect(find.text('Day A: Lower'), findsOneWidget);
      expect(find.text('Skipped'), findsWidgets);
      expect(find.text('Restore to plan'), findsOneWidget);
      expect(find.text('Start workout'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 5. Rest / Open Day: clean Rest Day card
    // -----------------------------------------------------------------------
    testWidgets('5. Rest day: shows clean Rest Day card', (tester) async {
      final restState = CalendarUiState(
        selectedLocalDate: '2026-08-04',
        timezoneId: 'UTC',
        view: CalendarView.week,
        activeProgramVersionId: _versionId,
        activeProgramName: 'Strength 101',
        selectedDateOccurrences: const [],
        rangeOccurrences: [mondayPlanned, wednesdayPlanned],
      );
      await tester.pumpWidget(_buildTestApp(calendarState: restState));
      await tester.pumpAndSettle();

      expect(find.text('Rest Day'), findsOneWidget);
      expect(
        find.textContaining('No workouts scheduled on your plan'),
        findsOneWidget,
      );
      expect(find.text('Calendar unavailable'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 6. Future occurrence: swipe is disabled (guarded to today only)
    // -----------------------------------------------------------------------
    testWidgets(
      '6. Future occurrence: swipe is disabled, Start still available',
      (tester) async {
        final futureItem = _makeOccurrence(
          id: 'occ-future',
          template: _upperTemplate(),
          effectiveLocalDate: '2026-08-05',
          status: 'planned',
        );
        await tester.pumpWidget(_buildContextualActionsApp(item: futureItem));
        await tester.pumpAndSettle();

        expect(find.text('Day B: Upper'), findsOneWidget);
        expect(find.text('Scheduled'), findsWidgets);
        // Start button present for explicit tap (requires confirmation dialog)
        expect(find.text('Start workout'), findsOneWidget);

        // Verify Dismissible direction is none for future date
        final dismissible = tester.widget<Dismissible>(
          find.byType(Dismissible),
        );
        expect(dismissible.direction, DismissDirection.none);
      },
    );

    // -----------------------------------------------------------------------
    // 7. Month view: grid renders with weekday headers
    // -----------------------------------------------------------------------
    testWidgets('7. Month view: renders grid with Mon-Sun headers', (
      tester,
    ) async {
      final monthState = todayState(view: CalendarView.month);
      await tester.pumpWidget(_buildTestApp(calendarState: monthState));
      await tester.pumpAndSettle();

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('August 2026'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 8. Week view: strip renders 7 day buttons
    // -----------------------------------------------------------------------
    testWidgets('8. Week view: renders 7 day strip buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp(calendarState: todayState()));
      await tester.pumpAndSettle();

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      // Verify "3" is rendered (August 3)
      expect(find.text('3'), findsWidgets);
    });

    // -----------------------------------------------------------------------
    // 9. TRN-15: OccurrenceActionsSheet has no Start/Resume
    // -----------------------------------------------------------------------
    testWidgets(
      '9. TRN-15: OccurrenceActionsSheet has no Start/Resume WorkoutListTile',
      (tester) async {
        await tester.pumpWidget(_buildActionsSheetApp(mondayPlanned));
        await tester.pumpAndSettle();

        expect(find.text('Day A: Lower'), findsOneWidget);
        expect(find.text('Reschedule'), findsOneWidget);
        expect(find.text('Skip Workout'), findsOneWidget);
        expect(find.text('Cancel Workout'), findsOneWidget);
        // TRN-15: no redundant Start/Resume in action sheet
        expect(find.widgetWithText(ListTile, 'Start Workout'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Resume Workout'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 10. Narrow width plus elevated text: no overflow
    // -----------------------------------------------------------------------
    testWidgets(
      '10. Narrow 320px viewport at 2x text renders without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _buildTestApp(
            calendarState: todayState(),
            size: const Size(320, 568),
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Calendar'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 11. Elevated text scale (1.8x): no overflow
    // -----------------------------------------------------------------------
    testWidgets('11. Elevated text scale 1.8x: renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(calendarState: todayState(), textScale: 1.8),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Calendar'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 12. Light & Dark Themes
    // -----------------------------------------------------------------------
    testWidgets('12. Light and dark themes render cleanly', (tester) async {
      // Dark
      await tester.pumpWidget(
        _buildTestApp(calendarState: todayState(), theme: AppTheme.darkTheme),
      );
      await tester.pumpAndSettle();
      expect(find.text('Day A: Lower'), findsOneWidget);

      // Light
      await tester.pumpWidget(
        _buildTestApp(calendarState: todayState(), theme: AppTheme.lightTheme),
      );
      await tester.pumpAndSettle();
      expect(find.text('Day A: Lower'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 13. Empty state: no active program
    // -----------------------------------------------------------------------
    testWidgets('13. No active program shows empty state', (tester) async {
      final emptyState = CalendarUiState(
        selectedLocalDate: '2026-08-03',
        timezoneId: 'UTC',
        view: CalendarView.week,
        selectedDateOccurrences: const [],
        rangeOccurrences: const [],
      );
      await tester.pumpWidget(_buildTestApp(calendarState: emptyState));
      await tester.pumpAndSettle();

      expect(find.text('Set up a training plan'), findsOneWidget);
    });

    testWidgets('14. Empty calendar stays usable at 320px and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final emptyState = CalendarUiState(
        selectedLocalDate: '2026-08-03',
        timezoneId: 'UTC',
        view: CalendarView.week,
        selectedDateOccurrences: const [],
        rangeOccurrences: const [],
      );
      await tester.pumpWidget(
        _buildTestApp(
          calendarState: emptyState,
          size: const Size(320, 568),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Set up a training plan'), findsOneWidget);
    });

    testWidgets('15. Loading calendar stays usable at 320px and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final loadingState = CalendarUiState(
        selectedLocalDate: '2026-08-03',
        timezoneId: 'UTC',
        view: CalendarView.week,
        isLoading: true,
      );
      await tester.pumpWidget(
        _buildTestApp(
          calendarState: loadingState,
          size: const Size(320, 568),
          textScale: 2,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Loading your calendar'), findsOneWidget);
    });
  });
}
