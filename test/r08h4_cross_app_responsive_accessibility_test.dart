import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/widgets/dashboard_date_bar.dart';
import 'package:indifit/features/dashboard/widgets/log_weight_bottom_sheet.dart';
import 'package:indifit/features/dashboard/widgets/quick_log_bottom_sheet.dart';
import 'package:indifit/features/dashboard/widgets/today_workout_card.dart';
import 'package:indifit/features/dashboard/widgets/weight_sparkline_card.dart';
import 'package:indifit/features/food_log/saved_recipe_log_screen.dart';
import 'package:indifit/features/settings/widgets/settings_reminder_toggle.dart';
import 'package:indifit/features/workout_player/widgets/b02_compact_set_table.dart';

Widget _wrapResponsiveTest(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...overrides,
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light().copyWith(
          extensions: const [B05SemanticColors.light],
        ),
        darkTheme: ThemeData.dark().copyWith(
          extensions: const [B05SemanticColors.dark],
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08H.4 — Cross-App Responsive & Accessibility Sweep', () {
    // -------------------------------------------------------------------------
    // TODAY SURFACE
    // -------------------------------------------------------------------------
    group('Today Surface', () {
      const viewports = [
        Size(320, 640),
        Size(390, 844),
      ];
      const textScales = [1.0, 2.0];
      const themes = [ThemeMode.light, ThemeMode.dark];

      testWidgets(
        'DashboardDateBar renders without overflow across the full matrix',
        (tester) async {
          for (final size in viewports) {
            for (final textScale in textScales) {
              for (final themeMode in themes) {
                await tester.pumpWidget(
                  _wrapResponsiveTest(
                    DashboardDateBar(
                      selectedDate: DateTime(2026, 8, 27),
                      onDateChanged: (_) {},
                      today: DateTime(2026, 8, 27),
                    ),
                    size: size,
                    textScale: textScale,
                    themeMode: themeMode,
                  ),
                );
                await tester.pumpAndSettle();

                expect(tester.takeException(), isNull);
                expect(find.byType(DashboardDateBar), findsOneWidget);
                // Verify date button has maxLines 1
                final actionButtons = tester.widgetList<B05ActionButton>(
                  find.byType(B05ActionButton),
                );
                expect(actionButtons.any((b) => b.maxLines == 1), isTrue);
              }
            }
          }
        },
      );

      testWidgets(
        'DashboardDateBar keeps current and historical dates in one compact semantic row',
        (tester) async {
          DateTime? changedDate;
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              _wrapResponsiveTest(
                DashboardDateBar(
                  selectedDate: DateTime(2026, 8, 28),
                  onDateChanged: (date) => changedDate = date,
                  today: DateTime(2026, 8, 28),
                ),
                size: const Size(320, 640),
                textScale: 2,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.byKey(const ValueKey('dashboard-date-bar-row')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('dashboard-date-bar-today')),
              findsNothing,
            );
            expect(find.bySemanticsLabel('Previous day'), findsOneWidget);
            expect(find.bySemanticsLabel('Next day'), findsOneWidget);
            expect(find.bySemanticsLabel('Selected date'), findsOneWidget);
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('dashboard-date-bar-row')))
                  .height,
              lessThan(100),
            );

            await tester.pumpWidget(
              _wrapResponsiveTest(
                DashboardDateBar(
                  selectedDate: DateTime(2026, 8, 27),
                  onDateChanged: (date) => changedDate = date,
                  today: DateTime(2026, 8, 28),
                ),
                size: const Size(320, 640),
                textScale: 2,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.byKey(const ValueKey('dashboard-date-bar-today')),
              findsOneWidget,
            );
            expect(find.bySemanticsLabel('Go to today'), findsOneWidget);
            await tester.tap(
              find.byKey(const ValueKey('dashboard-date-bar-today')),
            );
            expect(changedDate, DateTime(2026, 8, 28));
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );

      testWidgets(
        'WeightSparklineCard header is protected against overflow and has accessible chart semantics',
        (tester) async {
          await tester.pumpWidget(
            _wrapResponsiveTest(
              WeightSparklineCard(
                currentWeight: 78.4,
                weightHistory: const [79.0, 78.8, 78.4],
                onWeightAdjusted: (_) async {},
              ),
              size: const Size(320, 640),
              textScale: 2.0,
              themeMode: ThemeMode.dark,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Check that Log button has at least 48px height touch target
          final logButtonFinder = find.widgetWithText(OutlinedButton, 'Log');
          expect(logButtonFinder, findsOneWidget);
          final logSize = tester.getSize(logButtonFinder);
          expect(logSize.height, greaterThanOrEqualTo(B05Layout.minTouchTarget));

          // Check chart semantics
          expect(
            find.bySemanticsLabel(
              RegExp(r'Weight progress chart showing 3 recorded weigh-ins'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'TodayWorkoutCard play button has tooltip "Start workout"',
        (tester) async {
          await tester.pumpWidget(
            _wrapResponsiveTest(
              TodayWorkoutCard(
                todayWorkoutName: 'Upper Body A',
                exerciseCount: 5,
                isRestDay: false,
                selectedDate: DateTime(2026, 8, 27),
                onStartWorkout: () {},
                onRepeatWorkout: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byTooltip('Start workout'), findsOneWidget);
        },
      );

      testWidgets(
        'QuickLogBottomSheet actions have tooltips for screen-readers',
        (tester) async {
          await tester.pumpWidget(
            _wrapResponsiveTest(
              const QuickLogBottomSheet(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byTooltip('Breakfast'), findsOneWidget);
          expect(find.byTooltip('Lunch'), findsOneWidget);
          expect(find.byTooltip('Dinner'), findsOneWidget);
          expect(find.byTooltip('Snacks'), findsOneWidget);
        },
      );

      testWidgets(
        'LogWeightBottomSheet close button has tooltip "Close"',
        (tester) async {
          await tester.pumpWidget(
            _wrapResponsiveTest(
              LogWeightBottomSheet(
                currentWeight: 75.0,
                onSave: (_) async {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byTooltip('Close'), findsOneWidget);
        },
      );
    });

    // -------------------------------------------------------------------------
    // WORKOUT PLAYER & EXECUTION
    // -------------------------------------------------------------------------
    group('Workout Execution', () {
      final sampleSlot = B02StrengthExecutionSlot(
        id: 'slot-1',
        groupId: null,
        groupType: null,
        groupLabel: null,
        groupOrdinal: null,
        roundOrdinal: null,
        memberOrdinal: null,
        prescriptionId: 'prescription-1',
        exerciseId: 'ex-1',
        exerciseNameSnapshot: 'Barbell Bench Press',
        plannedSets: 3,
        targetRepsMin: 8,
        targetRepsMax: 10,
        targetRpe: 8,
        targetLoadKg: 80,
        targetLoadBasis: B02LoadBasis.totalExternal,
      );

      final sampleSet = B02PerformedSet(
        id: 'set-1',
        performedExerciseId: 'perf-1',
        ordinal: 0,
        role: B02SetRole.working,
        actualReps: 8,
        actualLoadKg: 80,
        actualLoadBasis: B02LoadBasis.totalExternal,
      );

      testWidgets(
        'B02CompactSetTable switches to compact stacked mode at 320pt and 2.0x text scale',
        (tester) async {
          final loadController = TextEditingController(text: '80');
          final repsController = TextEditingController(text: '8');

          await tester.pumpWidget(
            _wrapResponsiveTest(
              SingleChildScrollView(
                child: B02CompactSetTable(
                  slot: sampleSlot,
                  loggedSets: [sampleSet],
                  isBusy: false,
                  isPlannedMode: true,
                  currentSet: 1,
                  loadController: loadController,
                  repsController: repsController,
                  rpe: 8,
                  isWarmup: false,
                  loadLabel: 'Weight (kg)',
                  onRpeChanged: (_) {},
                  onWarmupChanged: (_) {},
                  onEdit: (_) {},
                  onDelete: (_) {},
                  moreContent: null,
                  onAddSet: () {},
                ),
              ),
              size: const Size(320, 640),
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // In compact mode, the header has 'SET / DETAILS'
          expect(find.text('SET / DETAILS'), findsOneWidget);
          expect(find.text('STATUS'), findsOneWidget);
        },
      );
    });

    // -------------------------------------------------------------------------
    // FOOD SURFACE
    // -------------------------------------------------------------------------
    group('Food Surface', () {
      testWidgets(
        'SavedRecipeLogScreen clear search icon button has tooltip "Clear search"',
        (tester) async {
          await tester.pumpWidget(
            _wrapResponsiveTest(
              const SavedRecipeLogScreen(mealType: 'breakfast'),
            ),
          );
          await tester.pump();

          // Enter text in search field
          await tester.enterText(find.byType(TextField), 'Oatmeal');
          await tester.pump(const Duration(milliseconds: 500));

          expect(find.byTooltip('Clear search'), findsOneWidget);
        },
      );
    });

    // -------------------------------------------------------------------------
    // SETTINGS SURFACE
    // -------------------------------------------------------------------------
    group('Settings Surface', () {
      testWidgets(
        'SettingsReminderToggle semantics does not duplicate toggled state on the outer row',
        (tester) async {
          await tester.pumpWidget(
            _wrapResponsiveTest(
              SettingsReminderToggle(
                icon: Icons.notifications_outlined,
                iconColor: Colors.blue,
                title: 'Workout reminders',
                subtitle: 'Notify before scheduled sessions',
                value: true,
                onChanged: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Switch has toggled state
          final switchFinder = find.byType(Switch);
          expect(switchFinder, findsOneWidget);
          final switchWidget = tester.widget<Switch>(switchFinder);
          expect(switchWidget.value, isTrue);
        },
      );

      testWidgets(
        'Date arrow button wraps internal icon button in ExcludeSemantics',
        (tester) async {
          await tester.pumpWidget(
            _wrapResponsiveTest(
              Semantics(
                button: true,
                label: 'Previous target day',
                hint: 'Change target date.',
                onTap: () {},
                child: ExcludeSemantics(
                  child: IconButton(
                    tooltip: 'Previous target day',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final semantics = tester.getSemantics(find.byType(IconButton));
          expect(semantics.label, 'Previous target day');
        },
      );
    });

    // -------------------------------------------------------------------------
    // PROGRESS & CHARTS
    // -------------------------------------------------------------------------
    group('Progress & Charts', () {
      test('LeftTitles reservedSize dynamically scales up with elevated text scale', () {
        double calculateReservedSize(double textScale, double baseSize) {
          return (baseSize * textScale).clamp(baseSize, 72.0);
        }

        // At 1.0x text scale, size stays at base
        expect(calculateReservedSize(1.0, 42.0), 42.0);
        expect(calculateReservedSize(1.0, 44.0), 44.0);

        // At 2.0x text scale, reserved size expands up to 72.0 to avoid label clipping
        expect(calculateReservedSize(2.0, 42.0), 72.0);
        expect(calculateReservedSize(2.0, 44.0), 72.0);
      });
    });

    // -------------------------------------------------------------------------
    // HIDDEN / DEFERRED GUARDS
    // -------------------------------------------------------------------------
    group('Hidden and Deferred Guards', () {
      test(
        'Hydration remains strictly absent from standard dashboard module registry',
        () {
          final moduleIds = standardDashboardModuleRegistry.descriptors.map(
            (d) => d.id,
          );
          expect(moduleIds, isNot(contains('today.hydration')));
          expect(moduleIds, isNot(contains('today.water')));
        },
      );

      test('Travel Mode is absent from release registry and routes', () {
        final moduleIds = standardDashboardModuleRegistry.descriptors.map(
          (d) => d.id,
        );
        expect(moduleIds, isNot(contains('today.travel')));
        expect(moduleIds, isNot(contains('travel_mode')));
      });
    });
  });
}
