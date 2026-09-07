import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/exercise_display_muscles.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_previous_performance_models.dart';
import 'package:indifit/data/repositories/b02_previous_performance_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/b07_exercise_context_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/media/b05_exercise_visual_registry.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';
import 'package:indifit/features/workout_player/widgets/b02_compact_set_table.dart';
import 'package:indifit/features/workout_player/widgets/plate_calculator_sheet.dart';

void main() {
  void setTestViewport(WidgetTester tester, {Size size = const Size(1080, 1920)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('PV1-PROD-05: isBarbellPlateCalculatorSupported Predicate Contract', () {
    test('Typed exclusion: returns false for any bodyweight loadBasis', () {
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Barbell Squat', // even if barbell in name
          loadBasis: B02LoadBasis.bodyweight,
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Pull-up',
          loadBasis: B02LoadBasis.bodyweight,
        ),
        isFalse,
      );
    });

    test('Blocklist evaluated first: non-barbell equipment returns false', () {
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Incline Dumbbell Bench Press',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Cable Chest Fly',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Seated Cable Row',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Machine Chest Press',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Resistance Band Pull-Apart',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Kettlebell Swing',
        ),
        isFalse,
      );
    });

    test('Blocklist evaluated first: non-barbell exercise families return false', () {
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Lat Pulldown',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Pull-ups',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Chin-ups',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Chest Dips',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Push-ups',
        ),
        isFalse,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Plank',
        ),
        isFalse,
      );
    });

    test('Allowlist evaluated second: explicit barbell exercises return true', () {
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Flat Barbell Bench Press',
          loadBasis: B02LoadBasis.totalExternal,
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Barbell Squat',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Barbell Deadlift',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Bent Over Barbell Row',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Overhead Barbell Press',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Standing Barbell Curl',
        ),
        isTrue,
      );
    });

    test('Allowlist evaluated second: canonical lifts omitting barbell return true', () {
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Romanian Deadlift (RDL)',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Back Squat',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Front Squat',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Overhead Press',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Hip Thrust',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Clean and Jerk',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Snatch',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Pendlay Row',
        ),
        isTrue,
      );
    });

    test('Documented default: unrecognized non-blocklisted names default-show', () {
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Floor Press',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: 'Strict Press',
        ),
        isTrue,
      );
      expect(
        isBarbellPlateCalculatorSupported(
          exerciseName: '',
        ),
        isTrue,
      );
    });
  });

  group('PV1-PROD-05: PlateCalculatorView Apply Contract', () {
    testWidgets('Does not render Apply button when onApplyWeight is null', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: PlateCalculatorView(
              initialTargetWeight: 80,
              isEditable: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apply to set'), findsNothing);
    });

    testWidgets('Renders Apply button and invokes callback with target weight', (tester) async {
      setTestViewport(tester);
      double? appliedValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: PlateCalculatorView(
              initialTargetWeight: 80,
              isEditable: true,
              onApplyWeight: (weight) {
                appliedValue = weight;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apply to set'), findsOneWidget);

      await tester.tap(find.text('Apply to set'));
      await tester.pumpAndSettle();

      expect(appliedValue, 80.0);
    });

    testWidgets('Invokes callback with updated weight after user edits target', (tester) async {
      setTestViewport(tester);
      double? appliedValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: PlateCalculatorView(
              initialTargetWeight: 60,
              isEditable: true,
              onApplyWeight: (weight) {
                appliedValue = weight;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '92.5');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply to set'));
      await tester.pumpAndSettle();

      expect(appliedValue, 92.5);
    });
  });

  group('PV1-PROD-05: PlateCalculatorSheet Single-Delivery', () {
    testWidgets('PlateCalculatorSheet pops and delivers weight via callback', (tester) async {
      setTestViewport(tester);
      double? deliveredWeight;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<double>(
                    context: context,
                    builder: (_) => PlateCalculatorSheet(
                      targetWeight: 100,
                      onApplyWeight: (weight) {
                        deliveredWeight = weight;
                      },
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Apply to set'), findsOneWidget);

      await tester.tap(find.text('Apply to set'));
      await tester.pumpAndSettle();

      expect(find.byType(PlateCalculatorSheet), findsNothing);
      expect(deliveredWeight, 100.0);
    });

    testWidgets('PlateCalculatorSheet.show delivers weight via future when onApplyWeight omitted', (tester) async {
      setTestViewport(tester);
      double? futureResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  futureResult = await PlateCalculatorSheet.show(
                    context: context,
                    initialWeight: 70,
                  );
                },
                child: const Text('Open Show Helper'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Show Helper'));
      await tester.pumpAndSettle();

      expect(find.text('Apply to set'), findsOneWidget);

      await tester.tap(find.text('Apply to set'));
      await tester.pumpAndSettle();

      expect(futureResult, 70.0);
    });
  });

  group('PV1-PROD-05: Compact Set Table Integration', () {
    const testSlot = B02StrengthExecutionSlot(
      id: 'slot_bench',
      groupId: null,
      groupType: null,
      groupLabel: null,
      groupOrdinal: null,
      roundOrdinal: null,
      memberOrdinal: null,
      prescriptionId: 'rx_1',
      exerciseId: 'ex_bench',
      exerciseNameSnapshot: 'Flat Barbell Bench Press',
      plannedSets: 3,
      targetRepsMin: 8,
      targetRepsMax: 10,
      targetRpe: 8,
      targetLoadKg: 80.0,
      targetLoadBasis: B02LoadBasis.totalExternal,
      effortMode: B02EffortMode.standard,
      endedAtFailure: false,
    );

    testWidgets('Renders plate calculator icon button when onOpenPlateCalculator provided', (tester) async {
      setTestViewport(tester);
      var opened = false;
      final loadCtrl = TextEditingController(text: '80');
      final repsCtrl = TextEditingController(text: '8');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: B02CompactSetTable(
                slot: testSlot,
                loggedSets: const [],
                isPlannedMode: true,
                isBusy: false,
                currentSet: 1,
                loadController: loadCtrl,
                repsController: repsCtrl,
                rpe: null,
                isWarmup: false,
                loadLabel: 'Weight (kg)',
                onRpeChanged: (_) {},
                onWarmupChanged: (_) {},
                onEdit: (_) {},
                onDelete: (_) {},
                moreContent: null,
                onOpenPlateCalculator: () => opened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calcButton = find.byTooltip('Plate calculator');
      expect(calcButton, findsOneWidget);

      await tester.tap(calcButton);
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets('Does not render plate calculator icon button when onOpenPlateCalculator is null', (tester) async {
      setTestViewport(tester);
      final loadCtrl = TextEditingController(text: '80');
      final repsCtrl = TextEditingController(text: '8');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: B02CompactSetTable(
                slot: testSlot,
                loggedSets: const [],
                isPlannedMode: true,
                isBusy: false,
                currentSet: 1,
                loadController: loadCtrl,
                repsController: repsCtrl,
                rpe: null,
                isWarmup: false,
                loadLabel: 'Weight (kg)',
                onRpeChanged: (_) {},
                onWarmupChanged: (_) {},
                onEdit: (_) {},
                onDelete: (_) {},
                moreContent: null,
                onOpenPlateCalculator: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Plate calculator'), findsNothing);
    });
  });

  group('PV1-PROD-05: Prefill Chain Pinning', () {
    test('Entered load takes precedence over planned and actual load', () {
      final weight = B02StrengthPlayerScreen.resolvePlateCalculatorPrefillWeight(
        inputText: '95',
        actualLoadKg: 70.0,
        plannedLoadKg: 80.0,
      );
      expect(weight, 95.0);
    });

    test('Actual load takes precedence over planned load when input empty', () {
      final weight = B02StrengthPlayerScreen.resolvePlateCalculatorPrefillWeight(
        inputText: '',
        actualLoadKg: 70.0,
        plannedLoadKg: 80.0,
      );
      expect(weight, 70.0);
    });

    test('Planned load takes precedence over default 20kg when input and actual empty', () {
      final weight = B02StrengthPlayerScreen.resolvePlateCalculatorPrefillWeight(
        inputText: '',
        actualLoadKg: null,
        plannedLoadKg: 80.0,
      );
      expect(weight, 80.0);
    });

    test('Default 20kg is used when input, actual, and planned load are absent or 0', () {
      expect(
        B02StrengthPlayerScreen.resolvePlateCalculatorPrefillWeight(
          inputText: '',
          actualLoadKg: null,
          plannedLoadKg: null,
        ),
        20.0,
      );
      expect(
        B02StrengthPlayerScreen.resolvePlateCalculatorPrefillWeight(
          inputText: '0',
          actualLoadKg: 0,
          plannedLoadKg: 0,
        ),
        20.0,
      );
    });
  });

  group('PV1-PROD-05: Responsive & A11y Certification', () {
    testWidgets('PlateCalculatorSheet renders cleanly at 320pt with 2x text without overflow', (tester) async {
      setTestViewport(tester, size: const Size(320, 800));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: PlateCalculatorSheet(
                targetWeight: 140,
                isEditable: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Plate Calculator'), findsOneWidget);
      expect(find.text('LOADING PER SIDE'), findsOneWidget);
    });

    testWidgets('Barbell visual exposes accessible Semantics summary label', (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: PlateCalculatorSheet(
              targetWeight: 140,
              isEditable: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final visualSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.startsWith('Barbell loading diagram:') ?? false),
      );
      expect(visualSemantics, findsOneWidget);
    });
  });

  group('PV1-PROD-05: Player Screen Tap-Through Integration', () {
    Future<void> settlePlayer(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('Overflow menu ListTile opens plate calculator and applies load', (tester) async {
      setTestViewport(tester);
      final db = AppDatabase.memory();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(db.close());
      });
      final executions = StrengthExecutionRepository(
        db: db,
        calendarRepo: CalendarRepository(db),
        nowUtc: () => DateTime.utc(2026, 8, 13, 8),
      );
      final launch = (await tester.runAsync(() async {
        await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            stableId: const Value('r07c-bench'),
            name: 'Bench press',
            muscleGroups: 'Chest,Triceps',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace your feet',
            commonMistakes: 'Bouncing',
          ),
        );
        return _launchPlannedPlayer(executions);
      }))!;

      await _pumpPlayerScreen(tester, launch, executions, db);

      // Tap exercise actions icon
      final actionBtn = find.byTooltip('Exercise actions');
      expect(actionBtn, findsOneWidget);
      await tester.tap(actionBtn);
      await settlePlayer(tester);

      // Overflow menu displays plate calculator ListTile
      final plateTile = find.widgetWithText(ListTile, 'Plate calculator');
      expect(plateTile, findsOneWidget);

      await tester.tap(plateTile);
      await settlePlayer(tester);

      // Plate calculator sheet is open
      expect(find.text('Plate Calculator'), findsOneWidget);
      expect(find.text('LOADING PER SIDE'), findsOneWidget);

      // Tap 'Apply to set'
      final applyBtn = find.text('Apply to set');
      expect(applyBtn, findsOneWidget);
      await tester.tap(applyBtn);
      await settlePlayer(tester);

      // Plate calculator sheet is dismissed and weight is applied to load input
      expect(find.text('Plate Calculator'), findsNothing);
      final loadInputs = find.byType(EditableText);
      expect(tester.widget<EditableText>(loadInputs.at(0)).controller.text, '60');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Edit set modal suffix icon opens plate calculator and applies load', (tester) async {
      setTestViewport(tester);
      final db = AppDatabase.memory();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(db.close());
      });
      final executions = StrengthExecutionRepository(
        db: db,
        calendarRepo: CalendarRepository(db),
        nowUtc: () => DateTime.utc(2026, 8, 13, 8),
      );
      final launch = (await tester.runAsync(() async {
        await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            stableId: const Value('r07c-bench'),
            name: 'Bench press',
            muscleGroups: 'Chest,Triceps',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace your feet',
            commonMistakes: 'Bouncing',
          ),
        );
        return _launchPlannedPlayer(executions, workingSets: 1);
      }))!;
      await _pumpPlayerScreen(tester, launch, executions, db);

      final editSetBtn = find.byTooltip('Edit set 1');
      expect(editSetBtn, findsOneWidget);
      await tester.tap(editSetBtn);
      await settlePlayer(tester);

      expect(find.text('Edit set 1'), findsOneWidget);

      final calcSuffix = find.byTooltip('Plate calculator').last;
      expect(calcSuffix, findsOneWidget);
      await tester.tap(calcSuffix);
      await settlePlayer(tester);

      expect(find.text('Plate Calculator'), findsOneWidget);
      expect(find.text('LOADING PER SIDE'), findsOneWidget);

      final applyBtn = find.text('Apply to set');
      expect(applyBtn, findsOneWidget);
      await tester.tap(applyBtn);
      await settlePlayer(tester);

      expect(find.text('Plate Calculator'), findsNothing);
      expect(find.text('Edit set 1'), findsOneWidget);

      final saveBtn = find.text('Save changes');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settlePlayer(tester);

      expect(find.text('Edit set 1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _NoHistoryPreviousPerformanceRepository
    extends B02PreviousPerformanceRepository {
  const _NoHistoryPreviousPerformanceRepository(super.database);

  @override
  Future<B02PreviousExercisePerformance> resolve(
    B02PreviousPerformanceQuery query,
  ) async => B02PreviousExercisePerformance.unavailable(
    status: B02PreviousPerformanceStatus.noHistory,
    canonicalExerciseId: query.canonicalExerciseId,
    reasonCode: 'no_history',
  );
}

class _TestB07ExerciseContextRepository extends B07ExerciseContextRepository {
  _TestB07ExerciseContextRepository(super.database);

  @override
  Future<B07ExerciseContextResult> resolve(String canonicalExerciseId) async {
    if (canonicalExerciseId != 'r07c-bench') {
      return const B07ExerciseContextResult.unavailable();
    }
    return B07ExerciseContextResult.available(
      B07ExerciseContext(
        canonicalExerciseId: 'r07c-bench',
        canonicalName: 'Bench press',
        equipment: 'Barbell',
        displayMuscles: ExerciseDisplayMuscles.fromMuscleGroups('Chest,Triceps'),
        formCues: const ['Brace your feet', 'Keep the bar path controlled'],
        commonMistakes: const ['Bouncing the bar'],
      ),
    );
  }
}

Future<B02StrengthExecutionLaunch> _launchPlannedPlayer(
  StrengthExecutionRepository executions, {
  int workingSets = 0,
}) async {
  final snapshot = jsonEncode({
    'version': 1,
    'routineName': 'Planned push',
    'groups': [
      {
        'id': 'r07c-group',
        'groupType': 'superset',
        'ordinal': 0,
        'roundCount': 1,
        'members': [
          {'exercisePrescriptionId': 'r07c-prescription', 'ordinal': 0},
        ],
      },
    ],
    'prescriptions': [
      {
        'id': 'r07c-prescription',
        'exerciseId': 'r07c-bench',
        'exerciseNameSnapshot': 'Bench press',
        'plannedSets': 3,
        'repsRange': '8-10',
        'targetLoadKg': 60.0,
        'loadBasis': 'totalExternal',
      },
    ],
  });
  final launch = await executions.startUnscheduledDraft(
    routineName: 'Planned push',
    executionSnapshotJson: snapshot,
    snapshotId: 'test-planned-player',
  );
  final prepared = await executions.prepareExecution(launch);
  var state = prepared.state;
  if (workingSets > 0) {
    final slot = (await executions.readExecutionSlots(launch)).single;
    for (var i = 0; i < workingSets; i++) {
      state = const B02StrengthExecutionDraftService().recordSet(
        state: state,
        slot: slot,
        reps: 8,
        loadKg: 60.0,
      );
    }
  }
  return B02StrengthExecutionLaunch(
    draftId: launch.draftId,
    occurrenceId: 'test-planned-occurrence',
    executionSnapshotJson: launch.executionSnapshotJson,
    state: state,
  );
}

Future<B02StrengthExecutionController> _pumpPlayerScreen(
  WidgetTester tester,
  B02StrengthExecutionLaunch launch,
  StrengthExecutionRepository executions,
  AppDatabase db,
) async {
  final controller = B02StrengthExecutionController(
    StrengthExecutionCompatibilityAdapter(executions),
    initialLaunch: launch,
  );
  await tester.runAsync(controller.loadSlots);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        b02StrengthExecutionScreenControllerProvider.overrideWith(
          (ref, _) => controller,
        ),
        b02PreviousPerformanceRepositoryProvider.overrideWithValue(
          _NoHistoryPreviousPerformanceRepository(db),
        ),
        b07ExerciseContextRepositoryProvider.overrideWithValue(
          _TestB07ExerciseContextRepository(db),
        ),
        b05ExerciseVisualRegistryProvider.overrideWith(
          (ref) async => const B05ExerciseVisualRegistry.empty(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            disableAnimations: true,
          ),
          child: B02StrengthPlayerScreen(
            launch: launch,
            nowUtc: () => DateTime.utc(2026, 8, 13, 8),
          ),
        ),
      ),
    ),
  );
  for (var pump = 0; pump < 8; pump++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump(const Duration(milliseconds: 100));
  return controller;
}
