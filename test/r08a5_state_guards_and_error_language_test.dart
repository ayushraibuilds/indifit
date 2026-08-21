import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/presentation/product_failure_presentation.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_lifecycle_repository.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/training_next_action_resolver.dart';
import 'package:indifit/data/repositories/workout_execution_compatibility_adapter.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/training/training_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 21, 8);
  late AppDatabase db;
  late LocalScheduleDateService dates;
  late ProgramRepository programs;
  late ProgramActivationCoordinator activation;
  late CalendarOccurrenceReadItem todayOccurrenceItem;
  late CalendarOccurrenceReadItem inProgressOccurrenceItem;
  late CalendarOccurrenceReadItem completedOccurrenceItem;
  late CalendarOccurrenceReadItem partiallyCompletedOccurrenceItem;
  late WorkoutDraft matchingDraftRow;
  late WorkoutDraft competingDraftRow;

  setUp(() async {
    db = AppDatabase.memory();
    dates = LocalScheduleDateService(nowUtc: () => now);
    programs = ProgramRepository(db);
    activation = ProgramActivationCoordinator(
      db,
      dates: dates,
      nowUtc: () => now,
    );
    await db.into(db.exercises).insert(
      ExercisesCompanion.insert(
        stableId: const Value('bench-press'),
        name: 'Bench Press',
        muscleGroups: 'Chest',
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        formCues: 'Retract scapulae',
        commonMistakes: 'Elbows flared',
      ),
    );

    final programId = await programs.createProgram(
      name: 'PPL Program',
      blocks: [
        ProgramBlockInput(
          name: 'Block 1',
          ordinal: 0,
          weeks: [
            ProgramWeekInput(
              name: 'Week 1',
              ordinalInBlock: 0,
              programWeekOrdinal: 0,
              templates: [
                SessionTemplateInput(
                  name: 'Chest Day',
                  ordinal: 0,
                  plannedWeekday: DateTime.friday,
                  prescriptions: const [
                    ExercisePrescriptionInput(
                      exerciseId: 'bench-press',
                      exerciseNameSnapshot: 'Bench Press',
                      plannedSets: 3,
                      repsRange: '8-12',
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
    final versionId = (await programs.getVersionsForProgram(programId)).single.id;
    await activation.activate(
      ActivateProgramVersionCommand(
        programVersionId: versionId,
        commandId: 'activate::$versionId',
        activationLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      ),
    );

    final reader = CalendarReadRepository(db, dates: dates);
    final snapshot = await reader.readSnapshot(
      startLocalDate: '2026-08-21',
      endLocalDate: '2026-08-21',
      timezoneId: 'UTC',
    );
    todayOccurrenceItem = snapshot.rangeOccurrences.first;

    inProgressOccurrenceItem = CalendarOccurrenceReadItem(
      occurrence: todayOccurrenceItem.occurrence.copyWith(
        status: 'inProgress',
      ),
      template: todayOccurrenceItem.template,
      week: todayOccurrenceItem.week,
      block: todayOccurrenceItem.block,
      version: todayOccurrenceItem.version,
      program: todayOccurrenceItem.program,
      prescriptions: todayOccurrenceItem.prescriptions,
      isOverdue: false,
      isDeload: false,
      isNextRequired: false,
    );

    completedOccurrenceItem = CalendarOccurrenceReadItem(
      occurrence: todayOccurrenceItem.occurrence.copyWith(status: 'completed'),
      template: todayOccurrenceItem.template,
      week: todayOccurrenceItem.week,
      block: todayOccurrenceItem.block,
      version: todayOccurrenceItem.version,
      program: todayOccurrenceItem.program,
      prescriptions: todayOccurrenceItem.prescriptions,
      isOverdue: false,
      isDeload: false,
      isNextRequired: false,
    );
    partiallyCompletedOccurrenceItem = CalendarOccurrenceReadItem(
      occurrence: todayOccurrenceItem.occurrence.copyWith(
        status: 'partiallyCompleted',
      ),
      template: todayOccurrenceItem.template,
      week: todayOccurrenceItem.week,
      block: todayOccurrenceItem.block,
      version: todayOccurrenceItem.version,
      program: todayOccurrenceItem.program,
      prescriptions: todayOccurrenceItem.prescriptions,
      isOverdue: false,
      isDeload: false,
      isNextRequired: false,
    );

    matchingDraftRow = await db.into(db.workoutDrafts).insertReturning(
      WorkoutDraftsCompanion.insert(
        routineName: 'Chest Day',
        currentExerciseIndex: 0,
        currentSetIndex: 0,
        elapsedSeconds: 120,
        loggedSetsJson: '[]',
        updatedAt: Value(now),
        scheduledOccurrenceId: Value(todayOccurrenceItem.occurrence.id),
        activityType: const Value('strength'),
        executionStateJson: Value(jsonEncode({
          'snapshotId': 'snap-matching',
          'snapshotVersion': 1,
          'activityType': 'strength',
          'routineName': 'Chest Day',
          'elapsedSeconds': 120,
          'currentExerciseOrdinal': 0,
          'currentSetOrdinal': 0,
          'groups': [],
          'performedExercises': [],
        })),
      ),
    );

    competingDraftRow = await db.into(db.workoutDrafts).insertReturning(
      WorkoutDraftsCompanion.insert(
        routineName: 'Quick Workout',
        currentExerciseIndex: 0,
        currentSetIndex: 0,
        elapsedSeconds: 60,
        loggedSetsJson: '[]',
        updatedAt: Value(now),
        scheduledOccurrenceId: const Value(null),
        activityType: const Value('strength'),
        executionStateJson: Value(jsonEncode({
          'snapshotId': 'snap-competing',
          'snapshotVersion': 1,
          'activityType': 'strength',
          'routineName': 'Quick Workout',
          'elapsedSeconds': 60,
          'currentExerciseOrdinal': 0,
          'currentSetOrdinal': 0,
          'groups': [],
          'performedExercises': [],
        })),
      ),
    );
  });

  tearDown(() => db.close());

  group('R08A.5 Guard Ordering & State Precedence', () {
    test('canLaunchTrainingOccurrence allows planned, rescheduled, and inProgress only', () async {
      final reader = CalendarReadRepository(db, dates: dates);
      final item = todayOccurrenceItem;

      expect(canLaunchTrainingOccurrence(item), isTrue);

      // In progress
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(item.occurrence.id))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('inProgress')),
      );
      final inProgressSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      expect(canLaunchTrainingOccurrence(inProgressSnap.rangeOccurrences.first), isTrue);

      // Completed
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(item.occurrence.id))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('completed')),
      );
      final completedSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      expect(canLaunchTrainingOccurrence(completedSnap.rangeOccurrences.first), isFalse);

      // Partially completed
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(item.occurrence.id))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('partiallyCompleted')),
      );
      final partialSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      expect(canLaunchTrainingOccurrence(partialSnap.rangeOccurrences.first), isFalse);

      // Skipped
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(item.occurrence.id))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('skipped')),
      );
      final skippedSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      expect(canLaunchTrainingOccurrence(skippedSnap.rangeOccurrences.first), isFalse);
    });

    test('selectTrainingTodayWorkout prioritizes inProgress > planned > completed', () async {
      expect(selectTrainingTodayWorkout([todayOccurrenceItem], '2026-08-21')?.occurrence.id, todayOccurrenceItem.occurrence.id);
    });

    test('TodayWorkoutPresentation correctly maps completed vs inProgress vs rest', () async {
      final reader = CalendarReadRepository(db, dates: dates);

      // Planned
      final plannedSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      final plannedPres = TodayWorkoutPresentation.from(
        TodayDomainRead.available(plannedSnap),
        loading: false,
      );
      expect(plannedPres.status, 'Planned for today');
      expect(plannedPres.canStart, isTrue);

      // In progress
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(todayOccurrenceItem.occurrence.id))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('inProgress')),
      );
      final inProgressSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      final inProgressPres = TodayWorkoutPresentation.from(
        TodayDomainRead.available(inProgressSnap),
        loading: false,
      );
      expect(inProgressPres.status, 'In progress');
      expect(inProgressPres.isInProgress, isTrue);
      expect(inProgressPres.canStart, isTrue);

      // Completed
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(todayOccurrenceItem.occurrence.id))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('completed')),
      );
      final completedSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      final completedPres = TodayWorkoutPresentation.from(
        TodayDomainRead.available(completedSnap),
        loading: false,
      );
      expect(completedPres.status, 'Completed today');
      expect(completedPres.canStart, isFalse);

      // Rest day (date with no workout)
      final restSnap = await reader.readSnapshot(
        startLocalDate: '2026-08-22',
        endLocalDate: '2026-08-22',
        timezoneId: 'UTC',
      );
      final restPres = TodayWorkoutPresentation.from(
        TodayDomainRead.available(restSnap),
        loading: false,
      );
      expect(restPres.title, 'Nothing planned today');
      expect(restPres.state, TodayPresentationState.empty);
    });

    test('shared resolver treats an in-progress row without a draft as recovery, not Start', () async {
      final reader = CalendarReadRepository(db, dates: dates);
      await (db.update(db.scheduledSessionOccurrences)
            ..where((t) => t.id.equals(todayOccurrenceItem.occurrence.id)))
          .write(
            const ScheduledSessionOccurrencesCompanion(
              status: Value('inProgress'),
            ),
          );
      final snapshot = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );

      final resolution = resolveTrainingNextAction(
        snapshot: snapshot,
        localDate: '2026-08-21',
        activeDraft: null,
      );

      expect(resolution.currentOccurrence?.occurrence.id, todayOccurrenceItem.occurrence.id);
      expect(resolution.todayOccurrence?.occurrence.status, 'inProgress');
      expect(resolution.hasResumableDraft, isFalse);
    });

    test('terminal occurrence plus lingering draft is fail-closed and still blocks Start', () async {
      await (db.update(db.scheduledSessionOccurrences)
            ..where((t) => t.id.equals(todayOccurrenceItem.occurrence.id)))
          .write(
            const ScheduledSessionOccurrencesCompanion(
              status: Value('completed'),
            ),
          );
      final snapshot = await CalendarReadRepository(db, dates: dates).readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      final resolution = resolveTrainingNextAction(
        snapshot: snapshot,
        localDate: '2026-08-21',
        activeDraft: matchingDraftRow,
      );

      expect(resolution.hasActiveDraft, isTrue);
      expect(resolution.activeDraft, isNull);
      expect(resolution.currentOccurrence, isNull);
      expect(resolution.todayOccurrence, isNull);
      expect(resolution.todayCompletedOccurrence?.occurrence.status, 'completed');
    });

    test('unknown active-draft read exposes no scheduled action', () async {
      final snapshot = await CalendarReadRepository(db, dates: dates).readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      final resolution = resolveTrainingNextAction(
        snapshot: snapshot,
        localDate: '2026-08-21',
        activeDraftReadAvailable: false,
      );

      expect(resolution.activeDraftReadAvailable, isFalse);
      expect(resolution.todayOccurrence, isNull);
      expect(resolution.nextOccurrence, isNull);
    });
  });

  group('R08A.5 ProductFailurePresentation & Error Language', () {
    test('ProductFailurePresentation maps known typed exceptions to safe copy', () {
      final finalizationError = const ScheduledWorkoutFinalizationException(
        'Database write constraint failed',
      );
      final finalizationPres = ProductFailurePresentation.fromError(
        finalizationError,
      );
      expect(finalizationPres.message, 'Your workout could not be saved. Try again.');
      expect(finalizationPres.message.contains('Database'), isFalse);
      expect(finalizationPres.message.contains('constraint'), isFalse);

      final recoveryError = const ScheduledWorkoutRecoveryException(
        'Draft snapshot json missing key',
      );
      final recoveryPres = ProductFailurePresentation.fromError(recoveryError);
      expect(
        recoveryPres.message,
        'This workout needs to be reopened before you can continue.',
      );
      expect(recoveryPres.message.contains('snapshot'), isFalse);

      final b02RecoveryError = const B02StrengthExecutionRecoveryException(
        'B02 group ordinal mismatch in Drift table',
      );
      final b02RecoveryPres = ProductFailurePresentation.fromError(b02RecoveryError);
      expect(
        b02RecoveryPres.message,
        'This workout needs to be reopened before you can continue.',
      );
      expect(b02RecoveryPres.message.contains('B02'), isFalse);
      expect(b02RecoveryPres.message.contains('Drift'), isFalse);

      final activationError = const ActivationRejectedException(
        'Resolve the existing workout draft before activating a program.',
      );
      final activationPres = ProductFailurePresentation.fromError(activationError);
      expect(
        activationPres.message,
        'Finish or discard your active workout before starting another.',
      );
      expect(activationPres.message.contains('ActivationRejectedException'), isFalse);
    });

    test('failure presentation keeps lifecycle distinctions without exposing reasons', () {
      expect(
        ProductFailurePresentation.fromError(const NoActivePlanException()).message,
        'No workout plan is currently active.',
      );
      expect(
        ProductFailurePresentation.fromError(
          const PlanEndBlockedException('draftId=42; SQLite transaction is open'),
        ).message,
        'Resolve your active workout before ending this plan.',
      );
      expect(
        ProductFailurePresentation.fromError(
          const B02StrengthExecutionFinalizationException(
            'Drift constraint failed for uuid=abc',
          ),
        ).message,
        'Your workout could not be saved. Try again.',
      );
      expect(
        ProductFailurePresentation.fromError(
          const ActivationRejectedException(
            'A published version cannot be activated again; create a replacement draft.',
          ),
        ).message,
        'This plan is already published. Create a new draft to make changes.',
      );
      expect(
        ProductFailurePresentation.fromError(
          const ActivationRejectedException(
            'Resolve the existing workout draft before activating a program.',
          ),
        ).canRetry,
        isFalse,
      );
      expect(
        ProductFailurePresentation.fromError(
          const ScheduledWorkoutFinalizationException('temporary write failure'),
        ).canRetry,
        isTrue,
      );
      expect(
        ProductFailurePresentation.fromCode('workout_already_completed').canRetry,
        isFalse,
      );
    });

    test('ProductFailurePresentation error codes produce safe, truthful messages without tech jargon', () {
      final forbiddenTerms = [
        'b01', 'b02', 'b04', 'b05', 'uuid', 'drift', 'sqlite', 'database',
        'repository', 'provider', 'controller', 'null', 'exception', 'stack',
        'payload', 'manifest', 'invariant',
      ];

      final codes = [
        'timeout',
        'offline',
        'invalid_input',
        'profile_unavailable',
        'constraint_operation_failed',
        'food_log_unavailable',
        'partial_confirmation_required',
        'stale_recipe_version',
        'invalid_amount',
        'recipe_not_found',
        'workout_save_failed',
        'workout_recovery_needed',
        'workout_already_completed',
        'workout_in_progress_conflict',
        'no_active_plan',
        'plan_activation_rejected',
        'plan_lifecycle_blocked',
        'b04_settings_load_failed',
        'playlist_unavailable',
        'backup_export_failed',
        'backup_inspection_failed',
      ];

      for (final code in codes) {
        final presentation = ProductFailurePresentation.fromCode(code);
        final messageLower = presentation.message.toLowerCase();
        final titleLower = presentation.title.toLowerCase();

        for (final term in forbiddenTerms) {
          expect(
            messageLower.contains(term),
            isFalse,
            reason: 'Code $code message contains forbidden term "$term": "${presentation.message}"',
          );
          expect(
            titleLower.contains(term),
            isFalse,
            reason: 'Code $code title contains forbidden term "$term": "${presentation.title}"',
          );
        }
      }
    });

    test('WorkoutContextualLauncher error strings do not leak internal component IDs', () {
      final safeStartMsg = 'Workout could not be started. Try again.';
      final safeActivityMsg = 'This activity uses its own activity flow and cannot be opened here.';

      expect(safeStartMsg.contains('B02'), isFalse);
      expect(safeStartMsg.contains('legacy'), isFalse);
      expect(safeActivityMsg.contains('legacy'), isFalse);
      expect(safeActivityMsg.contains('B02'), isFalse);
    });
  });

  group('R08A.5 Training UI Widget Precedence & Language', () {
    testWidgets('Today card renders "Resume workout" when today\'s scheduled workout is active', (tester) async {
      final landingSnapshot = TrainingLandingSnapshot(
        localDate: '2026-08-21',
        timezoneId: 'UTC',
        todayWorkout: inProgressOccurrenceItem,
        upcoming: const [],
        recentSessions: const [],
        activeProgramName: 'PPL Program',
        activeDraft: matchingDraftRow,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => landingSnapshot,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: TrainingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Active workout banner at top should be present
      expect(find.text('WORKOUT IN PROGRESS'), findsOneWidget);
      expect(find.text('Resume Chest Day'), findsOneWidget);

      // Today card should say "Resume workout", NOT "Resume your saved workout before starting today's plan"
      expect(find.text('Resume your saved workout before starting today’s plan.'), findsNothing);
      expect(find.text('Resume workout'), findsOneWidget);
    });

    testWidgets('Today card renders blocking guidance when competing active draft exists', (tester) async {
      final landingSnapshot = TrainingLandingSnapshot(
        localDate: '2026-08-21',
        timezoneId: 'UTC',
        todayWorkout: todayOccurrenceItem,
        upcoming: const [],
        recentSessions: const [],
        activeProgramName: 'PPL Program',
        activeDraft: competingDraftRow,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => landingSnapshot,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: TrainingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top banner shows Quick Workout
      expect(find.text('WORKOUT IN PROGRESS'), findsOneWidget);
      expect(find.text('Resume Quick Workout'), findsOneWidget);

      // Today card shows blocking guidance
      expect(
        find.text('Resume your saved workout before starting today’s plan.'),
        findsOneWidget,
      );
      // Start button for today's workout must NOT be present while competing draft is open
      expect(find.text('Start workout'), findsNothing);
    });

    testWidgets('Today card renders "Workout complete for today." on completed workout', (tester) async {
      final landingSnapshot = TrainingLandingSnapshot(
        localDate: '2026-08-21',
        timezoneId: 'UTC',
        todayWorkout: completedOccurrenceItem,
        upcoming: const [],
        recentSessions: const [],
        activeProgramName: 'PPL Program',
        activeDraft: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => landingSnapshot,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: TrainingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout complete for today.'), findsOneWidget);
      expect(find.text('Start workout'), findsNothing);
      expect(find.text('Resume workout'), findsNothing);
    });

    testWidgets('Today card distinguishes partial completion from full completion', (tester) async {
      final landingSnapshot = TrainingLandingSnapshot(
        localDate: '2026-08-21',
        timezoneId: 'UTC',
        todayWorkout: partiallyCompletedOccurrenceItem,
        upcoming: const [],
        recentSessions: const [],
        activeProgramName: 'PPL Program',
        activeDraft: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingLandingSnapshotProvider.overrideWith(
              (ref) async => landingSnapshot,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: TrainingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout partially completed.'), findsOneWidget);
      expect(find.text('Workout complete for today.'), findsNothing);
      expect(find.text('Start workout'), findsNothing);
      expect(find.text('Resume workout'), findsNothing);
    });
  });
}
