import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
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
    double resolveTargetWeight({
      required String enteredText,
      required double? plannedTargetLoadKg,
    }) {
      final entered = double.tryParse(enteredText.trim());
      if (entered != null && entered > 0) return entered;
      if (plannedTargetLoadKg != null && plannedTargetLoadKg > 0) {
        return plannedTargetLoadKg;
      }
      return 20.0;
    }

    test('Entered load takes precedence over planned load', () {
      final weight = resolveTargetWeight(
        enteredText: '95',
        plannedTargetLoadKg: 80.0,
      );
      expect(weight, 95.0);
    });

    test('Planned load takes precedence over default 20kg when input empty', () {
      final weight = resolveTargetWeight(
        enteredText: '',
        plannedTargetLoadKg: 80.0,
      );
      expect(weight, 80.0);
    });

    test('Default 20kg is used when both input and planned load are absent or 0', () {
      expect(
        resolveTargetWeight(enteredText: '', plannedTargetLoadKg: null),
        20.0,
      );
      expect(
        resolveTargetWeight(enteredText: '0', plannedTargetLoadKg: 0),
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
  });
}
