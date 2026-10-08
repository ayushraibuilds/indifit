import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_previous_performance_models.dart';
import 'package:indifit/data/repositories/b02_previous_performance_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/b07_exercise_context_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';

/// V5 (PREMIUM_REDESIGN_PLAN § 7.1–7.2): the rest takeover and the player
/// beats. Rest timing and intents are covered by the existing rest tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StrengthExecutionRepository executions;

  setUp(() async {
    db = AppDatabase.memory();
    executions = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
      nowUtc: () => DateTime.utc(2026, 8, 13, 8),
    );
    for (final (id, name) in const [
      ('v5-leg-press', 'Leg Press'),
      ('v5-row', 'Seated Row'),
    ]) {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: Value(id),
              name: name,
              muscleGroups: 'Legs',
              equipment: 'Machine',
              difficulty: 'Beginner',
              formCues: '',
              commonMistakes: '',
            ),
          );
    }
  });

  tearDown(() => db.close());

  group('rest takeover', () {
    testWidgets('Log set opens the takeover with what comes next', (
      tester,
    ) async {
      final launch = (await tester.runAsync(() => _launchPlanned(executions)))!;
      await _pumpPlayer(tester, launch, executions, db);

      await _logSet(tester, reps: '8');

      expect(find.bySemanticsLabel('Rest in progress'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Leg Press · Set 2 of 3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StickyRestBar),
          matching: find.text('60 kg × 8'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Hide rest timer'), findsOneWidget);
      // Thumb-sized controls.
      for (final label in const ['−15', '+30', 'Skip']) {
        final size = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          ),
        );
        expect(size.height, greaterThanOrEqualTo(56), reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('touching the set list folds it; tapping the time opens it', (
      tester,
    ) async {
      final launch = (await tester.runAsync(() => _launchPlanned(executions)))!;
      await _pumpPlayer(tester, launch, executions, db);
      await _logSet(tester, reps: '8');
      expect(find.bySemanticsLabel('Rest in progress'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -40));
      await _settle(tester);
      expect(find.bySemanticsLabel('Rest in progress'), findsNothing);
      expect(find.text('Up next'), findsNothing);
      // The bar keeps every control.
      expect(find.text('−15').hitTestable(), findsOneWidget);
      expect(find.text('+30').hitTestable(), findsOneWidget);
      expect(find.text('Skip').hitTestable(), findsOneWidget);

      await tester.tap(find.text('Rest'));
      await _settle(tester);
      expect(find.bySemanticsLabel('Rest in progress'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide rest timer'));
      await _settle(tester);
      expect(find.bySemanticsLabel('Rest in progress'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('+30 and Skip work from the takeover', (tester) async {
      final launch = (await tester.runAsync(() => _launchPlanned(executions)))!;
      await _pumpPlayer(tester, launch, executions, db);
      await _logSet(tester, reps: '8');
      final before = (await tester.runAsync(
        () => executions.readDraft(launch.draftId),
      ))!.state.restPeriods.single.selectedSeconds!;

      await tester.tap(find.text('+30'));
      await _settle(tester);
      var rest = (await tester.runAsync(
        () => executions.readDraft(launch.draftId),
      ))!.state.restPeriods.single;
      expect(rest.selectedSeconds, before + 30);
      expect(find.bySemanticsLabel('Rest in progress'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await _settle(tester);
      rest = (await tester.runAsync(
        () => executions.readDraft(launch.draftId),
      ))!.state.restPeriods.single;
      expect(rest.endedAtUtc, isNotNull);
      expect(find.bySemanticsLabel('Rest in progress'), findsNothing);
      expect(find.text('Rest done'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text keeps the compact bar', (tester) async {
      final launch = (await tester.runAsync(() => _launchPlanned(executions)))!;
      await _pumpPlayer(tester, launch, executions, db, textScale: 2);
      await _logSet(tester, reps: '8');

      expect(find.bySemanticsLabel('Rest in progress'), findsNothing);
      expect(find.text('Skip').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduce Motion: no size animation and no rest-done beat', (
      tester,
    ) async {
      final launch = (await tester.runAsync(
        () => _launchPlanned(executions, restSeconds: 1),
      ))!;
      await _pumpPlayer(tester, launch, executions, db, reduceMotion: true);
      await _logSet(tester, reps: '8');

      expect(find.bySemanticsLabel('Rest in progress'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);

      await _waitForRestEnd(tester, launch, executions);
      expect(find.byType(RestDoneBeat), findsNothing);
      expect(find.bySemanticsLabel('Rest in progress'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rest that runs out pulses once, then goes', (tester) async {
      final launch = (await tester.runAsync(
        () => _launchPlanned(executions, restSeconds: 1),
      ))!;
      await _pumpPlayer(tester, launch, executions, db);
      await _logSet(tester, reps: '8');

      await _waitForRestEnd(tester, launch, executions);
      expect(find.text('Rest done'), findsOneWidget);
      expect(find.text('Leg Press · Set 2 of 3'), findsOneWidget);

      // The first frame starts the beat's clock.
      await tester.pump();
      await tester.pump(B02PlayerBeats.restDone + _frame);
      await tester.pump();
      expect(find.byType(RestDoneBeat), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('exercise done beat', () {
    testWidgets('the last planned set shows the beat, then the next exercise', (
      tester,
    ) async {
      final launch = (await tester.runAsync(
        () => _launchPlanned(executions, loggedSets: 2),
      ))!;
      await _pumpPlayer(tester, launch, executions, db);
      expect(find.text('Leg Press'), findsWidgets);

      await _logSet(tester, reps: '8');
      expect(find.text('Leg Press done'), findsOneWidget);
      expect(find.text('3 × 8 · 60 kg'), findsOneWidget);
      expect(find.text('Log set'), findsNothing);

      await tester.pump(B02PlayerBeats.exerciseDone + _frame);
      await _settle(tester);
      expect(find.text('Leg Press done'), findsNothing);
      expect(find.text('Set 1 · 40 kg × 10–12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the beat moves on at once', (tester) async {
      final launch = (await tester.runAsync(
        () => _launchPlanned(executions, loggedSets: 2),
      ))!;
      await _pumpPlayer(tester, launch, executions, db);
      await _logSet(tester, reps: '8');
      expect(find.text('Leg Press done'), findsOneWidget);

      // One frame for the shared-axis slide to settle.
      await tester.pump(_frame);
      await tester.tap(find.text('Leg Press done'));
      // The beat slides out with the shared-axis transition.
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester);
      expect(find.text('Leg Press done'), findsNothing);
      expect(find.text('Set 1 · 40 kg × 10–12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduce Motion goes straight to the next exercise', (
      tester,
    ) async {
      final launch = (await tester.runAsync(
        () => _launchPlanned(executions, loggedSets: 2),
      ))!;
      await _pumpPlayer(tester, launch, executions, db, reduceMotion: true);
      await _logSet(tester, reps: '8');

      expect(find.byType(ExerciseDoneBeat), findsNothing);
      expect(find.text('Set 1 · 40 kg × 10–12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a middle set shows no beat', (tester) async {
      final launch = (await tester.runAsync(
        () => _launchPlanned(executions, loggedSets: 1),
      ))!;
      await _pumpPlayer(tester, launch, executions, db);
      await _logSet(tester, reps: '8');

      expect(find.byType(ExerciseDoneBeat), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('b02ExerciseDoneSummary', () {
    B02PerformedSet set(
      int ordinal, {
      int? reps,
      double? load,
      B02LoadBasis? basis = B02LoadBasis.totalExternal,
      B02SetRole role = B02SetRole.working,
    }) => B02PerformedSet(
      id: 'set-$ordinal',
      performedExerciseId: 'performed:a',
      ordinal: ordinal,
      role: role,
      actualReps: reps,
      actualLoadKg: load,
      actualLoadBasis: basis,
    );

    test('same reps and load', () {
      expect(
        b02ExerciseDoneSummary([
          set(0, reps: 8, load: 60),
          set(1, reps: 8, load: 60),
          set(2, reps: 8, load: 60),
        ]),
        '3 × 8 · 60 kg',
      );
    });

    test('mixed reps and loads', () {
      expect(
        b02ExerciseDoneSummary([
          set(0, reps: 10, load: 60),
          set(1, reps: 8, load: 62.5),
        ]),
        '2 sets · 18 reps · up to 62.5 kg',
      );
    });

    test('warm-ups are left out; bodyweight says so', () {
      expect(
        b02ExerciseDoneSummary([
          set(0, reps: 5, load: 20, role: B02SetRole.warmup),
          set(1, reps: 12, basis: B02LoadBasis.bodyweight),
          set(2, reps: 12, basis: B02LoadBasis.bodyweight),
        ]),
        '2 × 12 · Bodyweight',
      );
    });

    test('unknown load is not shown as zero', () {
      expect(
        b02ExerciseDoneSummary([set(0, reps: 8), set(1, reps: 8)]),
        '2 × 8',
      );
      expect(b02ExerciseDoneSummary(const []), isNull);
    });
  });
}

const _frame = Duration(milliseconds: 16);

Future<void> _logSet(WidgetTester tester, {required String reps}) async {
  await tester.scrollUntilVisible(
    find.text('Log set'),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(find.byType(TextFormField).at(1), reps);
  await tester.ensureVisible(find.text('Log set'));
  await tester.pump();
  await tester.tap(find.text('Log set'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var pump = 0; pump < 6; pump++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// The rest bar ends a rest from the real clock, so wait in real time.
Future<void> _waitForRestEnd(
  WidgetTester tester,
  B02StrengthExecutionLaunch launch,
  StrengthExecutionRepository executions,
) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump(const Duration(seconds: 1));
    final saved = await tester.runAsync(
      () => executions.readDraft(launch.draftId),
    );
    if (saved!.state.restPeriods.every((rest) => rest.endedAtUtc != null)) {
      await tester.pump();
      return;
    }
  }
  fail('The rest did not end.');
}

Future<void> _pumpPlayer(
  WidgetTester tester,
  B02StrengthExecutionLaunch launch,
  StrengthExecutionRepository executions,
  AppDatabase database, {
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final controller = B02StrengthExecutionController(
    StrengthExecutionCompatibilityAdapter(executions),
    initialLaunch: launch,
  );
  await tester.runAsync(controller.loadSlots);
  final theme = AppTheme.darkTheme;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        b02StrengthExecutionScreenControllerProvider.overrideWith(
          (ref, _) => controller,
        ),
        b02PreviousPerformanceRepositoryProvider.overrideWithValue(
          _NoHistory(database),
        ),
        b07ExerciseContextProvider.overrideWith(
          (ref, id) async => const B07ExerciseContextResult.unavailable(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: B02StrengthPlayerScreen(
            launch: launch,
            nowUtc: () => DateTime.utc(2026, 8, 13, 8),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

class _NoHistory extends B02PreviousPerformanceRepository {
  const _NoHistory(super.database);

  @override
  Future<B02PreviousExercisePerformance> resolve(
    B02PreviousPerformanceQuery query,
  ) async => B02PreviousExercisePerformance.unavailable(
    status: B02PreviousPerformanceStatus.noHistory,
    canonicalExerciseId: query.canonicalExerciseId,
    reasonCode: 'no_history',
  );
}

Future<B02StrengthExecutionLaunch> _launchPlanned(
  StrengthExecutionRepository executions, {
  int loggedSets = 0,
  int restSeconds = 90,
}) async {
  final snapshot = jsonEncode({
    'version': 1,
    'routineName': 'Full Body C',
    'groups': const [],
    'prescriptions': [
      {
        'id': 'v5-p-leg-press',
        'exerciseId': 'v5-leg-press',
        'exerciseNameSnapshot': 'Leg Press',
        'plannedSets': 3,
        'repsRange': '8-12',
        'targetLoadKg': 60,
        'loadBasis': 'totalExternal',
        'restSeconds': restSeconds,
      },
      {
        'id': 'v5-p-row',
        'exerciseId': 'v5-row',
        'exerciseNameSnapshot': 'Seated Row',
        'plannedSets': 3,
        'repsRange': '10-12',
        'targetLoadKg': 40,
        'loadBasis': 'totalExternal',
        'restSeconds': restSeconds,
      },
    ],
  });
  final draft = await executions.startUnscheduledDraft(
    routineName: 'Full Body C',
    executionSnapshotJson: snapshot,
    snapshotId: 'v5-planned-player',
  );
  final prepared = await executions.prepareExecution(draft);
  var launch = B02StrengthExecutionLaunch(
    draftId: draft.draftId,
    occurrenceId: 'v5-planned-occurrence',
    executionSnapshotJson: draft.executionSnapshotJson,
    state: prepared.state,
  );
  if (loggedSets == 0) return launch;
  final slot = (await executions.readExecutionSlots(launch)).first;
  var state = launch.state;
  for (var index = 0; index < loggedSets; index++) {
    state = const B02StrengthExecutionDraftService().recordSet(
      state: state,
      slot: slot,
      reps: 8,
      loadKg: 60,
      actualLoadBasis: B02LoadBasis.totalExternal,
    );
  }
  await executions.saveDraft(draftId: launch.draftId, state: state);
  launch = launch.copyWith(state: state);
  return launch;
}
