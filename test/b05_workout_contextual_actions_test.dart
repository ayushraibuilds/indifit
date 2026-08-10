import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/calendar/workout_contextual_action_controller.dart';
import 'package:indifit/features/calendar/workout_contextual_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'skip suppresses repeated pending input and supports valid undo',
    () async {
      final gateway = _FakeGateway(_occurrence());
      final controller = WorkoutOccurrenceActionController(
        gateway: gateway,
        occurrenceId: 'occ-1',
        nowUtc: () => DateTime.utc(2026, 8, 7, 12),
      );

      final gate = Completer<void>();
      gateway.skipGate = gate;
      final first = controller.skip(SkipDisposition.keepPending);
      final duplicate = controller.skip(SkipDisposition.advance);
      expect(controller.state.status, WorkoutOccurrenceActionStatus.pending);
      gate.complete();
      await Future.wait([first, duplicate]);

      expect(gateway.skipCalls, 1);
      expect(controller.state.status, WorkoutOccurrenceActionStatus.success);
      expect(controller.state.undoOffer, isNotNull);

      await controller.undo();
      expect(gateway.restoreCalls, 1);
      expect(gateway.occurrence?.status, OccurrenceStatus.planned.dbValue);
      expect(controller.state.message, 'Workout restored to the plan.');
    },
  );

  test('undo expires and downstream transition becomes unavailable', () async {
    var now = DateTime.utc(2026, 8, 7, 12);
    final gateway = _FakeGateway(_occurrence());
    final controller = WorkoutOccurrenceActionController(
      gateway: gateway,
      occurrenceId: 'occ-1',
      nowUtc: () => now,
      undoWindow: const Duration(seconds: 2),
    );

    await controller.skip(SkipDisposition.advance);
    now = now.add(const Duration(seconds: 3));
    await controller.undo();
    expect(controller.state.status, WorkoutOccurrenceActionStatus.ready);
    expect(gateway.restoreCalls, 0);

    // A new skip creates a new undo offer; the fake mirrors the next planned
    // occurrence while the restore path below simulates a downstream event.
    gateway.occurrence = _occurrence();
    await controller.skip(SkipDisposition.advance);
    gateway.restoreError = const InvalidOccurrenceTransitionException(
      'A later workout has started.',
    );
    await controller.undo();
    expect(controller.state.status, WorkoutOccurrenceActionStatus.unavailable);
    expect(controller.state.message, contains('A later workout has started'));
  });

  test('failure exposes retry and retry reuses the B01 action path', () async {
    final gateway = _FakeGateway(_occurrence())
      ..skipError = StateError('offline');
    final controller = WorkoutOccurrenceActionController(
      gateway: gateway,
      occurrenceId: 'occ-1',
    );

    await controller.skip(SkipDisposition.keepPending);
    expect(controller.state.status, WorkoutOccurrenceActionStatus.failure);
    gateway.skipError = null;
    await controller.retry();
    expect(controller.state.status, WorkoutOccurrenceActionStatus.success);
    expect(gateway.skipCalls, 2);
  });

  testWidgets('contextual workout row has swipe and non-swipe alternatives', (
    tester,
  ) async {
    final gateway = _FakeGateway(_occurrence());
    final item = _item(gateway.occurrence!);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutOccurrenceActionGatewayProvider.overrideWithValue(gateway),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkoutContextualActions(
                  item: item,
                  onOpenDetails: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Start workout'), findsOneWidget);
    expect(find.bySemanticsLabel('Skip workout'), findsOneWidget);
    // The normal playlist entry is intentionally omitted when no approved
    // provider is registered; this prevents a dead-end setup route.
    expect(find.bySemanticsLabel('Playlist launcher'), findsNothing);
    expect(
      tester.getSize(find.bySemanticsLabel('Start workout')).height,
      greaterThanOrEqualTo(48),
    );

    // A left swipe is handled contextually but never dismisses the row. The
    // confirmation dialog is the accessible equivalent of the gesture.
    final surface = find.byType(Dismissible);
    await tester.fling(surface, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Skip workout?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byType(WorkoutContextualActions), findsOneWidget);
  });
}

void _noop() {}

ScheduledSessionOccurrence _occurrence({String status = 'planned'}) =>
    ScheduledSessionOccurrence(
      id: 'occ-1',
      programVersionId: 'version-1',
      sessionTemplateId: 'template-1',
      programBlockOrdinal: 0,
      programWeekOrdinal: 0,
      sessionOrdinal: 0,
      repeatOrdinal: 0,
      originalLocalDate: '2026-08-07',
      originalTimezoneId: 'UTC',
      effectiveLocalDate: '2026-08-07',
      effectiveTimezoneId: 'UTC',
      status: status,
      progressionDisposition: 'pending',
      createdAtUtc: DateTime.utc(2026, 8, 1),
    );

CalendarOccurrenceReadItem _item(ScheduledSessionOccurrence occurrence) {
  final created = DateTime.utc(2026, 8, 1);
  return CalendarOccurrenceReadItem(
    occurrence: occurrence,
    template: SessionTemplate(
      id: 'template-1',
      programWeekId: 'week-1',
      ordinal: 0,
      name: 'Full body session',
      plannedWeekday: DateTime.friday,
      activityType: 'legacy',
      defaultRestSeconds: null,
    ),
    week: const ProgramWeek(
      id: 'week-1',
      programVersionId: 'version-1',
      programBlockId: 'block-1',
      ordinalInBlock: 0,
      programWeekOrdinal: 0,
      isDeload: false,
    ),
    block: const ProgramBlock(
      id: 'block-1',
      programVersionId: 'version-1',
      ordinal: 0,
      name: 'Block 1',
    ),
    version: ProgramVersion(
      id: 'version-1',
      programId: 'program-1',
      versionNumber: 1,
      status: 'published',
      origin: 'authoring',
      createdAtUtc: created,
    ),
    program: Program(id: 'program-1', name: 'Program', createdAtUtc: created),
    prescriptions: const [],
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}

class _FakeGateway implements WorkoutOccurrenceActionGateway {
  _FakeGateway(this.occurrence);

  ScheduledSessionOccurrence? occurrence;
  Completer<void>? skipGate;
  Object? skipError;
  Object? restoreError;
  var skipCalls = 0;
  var restoreCalls = 0;

  @override
  Future<ScheduledSessionOccurrence?> getOccurrence(
    String occurrenceId,
  ) async => occurrence;

  @override
  Future<OccurrenceMutationResult> skip(SkipOccurrenceCommand command) async {
    skipCalls++;
    final gate = skipGate;
    if (gate != null) {
      await gate.future;
      skipGate = null;
    }
    final error = skipError;
    if (error != null) throw error;
    occurrence = occurrence?.copyWith(status: OccurrenceStatus.skipped.dbValue);
    return _result(command.occurrenceId, 'skipped');
  }

  @override
  Future<OccurrenceMutationResult> restore(
    RestoreOccurrenceCommand command,
  ) async {
    restoreCalls++;
    final error = restoreError;
    if (error != null) throw error;
    occurrence = occurrence?.copyWith(status: OccurrenceStatus.planned.dbValue);
    return _result(command.occurrenceId, 'planned');
  }

  OccurrenceMutationResult _result(String occurrenceId, String toStatus) {
    final event = OccurrenceEvent(
      id: 'event-$restoreCalls-$skipCalls',
      occurrenceId: occurrenceId,
      commandId: 'command-$restoreCalls-$skipCalls',
      eventType: toStatus,
      fromStatus: null,
      toStatus: toStatus,
      occurredAtUtc: DateTime.utc(2026, 8, 7),
    );
    return OccurrenceMutationResult(
      occurrence: occurrence!,
      event: event,
      wasIdempotent: false,
    );
  }
}
