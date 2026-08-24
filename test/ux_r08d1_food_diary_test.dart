import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/nutrition_target_authority.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('diary exposes remaining calories from the date-scoped target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_foodDiaryApp(targets: _targetRead(2100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('0 kcal'), findsOneWidget);
    expect(find.text('2,100 kcal'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('2,100 kcal daily target.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('diary keeps target absence explicit instead of showing zero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _foodDiaryApp(
        targets: const TodayDomainRead<NutritionTargetsForDate?>.available(
          null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Daily target unavailable for this date.'), findsNothing);
    expect(find.text('No daily target for this date.'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('diary fails closed when the target read is unavailable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _foodDiaryApp(
        targets: const TodayDomainRead<NutritionTargetsForDate?>.unavailable(
          'target unavailable',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Daily target unavailable for this date.'),
      findsOneWidget,
    );
    expect(find.text('Not available'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('empty diary keeps meal hierarchy and one dominant add action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_foodDiaryApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Meals'), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsNWidgets(4));
    expect(
      find.byKey(const ValueKey('food_diary_primary_add')),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Add food'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Food tools'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Food tools'), findsOneWidget);
    expect(find.text('Search foods'), findsOneWidget);
    expect(find.text('Saved meals'), findsOneWidget);
    expect(find.text('Saved recipes'), findsOneWidget);
  });

  testWidgets(
    'diary remains scrollable at narrow width and elevated text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_foodDiaryApp(textScale: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey('food_diary_primary_add')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('diary action semantics remain available in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_foodDiaryApp(theme: AppTheme.darkTheme));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('food_diary_primary_add')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Add food'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Widget _foodDiaryApp({
  TodayDomainRead<NutritionTargetsForDate?>? targets,
  double textScale = 1,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      foodDiaryReadModelProvider.overrideWith((ref, date) async {
        final registry = NutrientRegistry.fromAssetFileSync(
          'assets/data/nutrient_registry.json',
        );
        final totals = NutrientAggregationService.aggregate(
          registry: registry,
          contributions: const <NutrientContribution>[],
          requestedNutrientIds: registry.definitions
              .map((definition) => definition.id)
              .toSet(),
        );
        return FoodDiaryReadModel(
          daily: NutritionDailyReadModel(
            userId: 'r08d1-test-user',
            localDate: _dateKey(date),
            records: const [],
            recordIds: const [],
            totals: totals,
            sourceCounts: const {},
            issues: const [],
          ),
          targets: targets ?? _targetRead(null),
        );
      }),
      canonicalRecentFoodsProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: FoodDiaryScreen(
        selectedDate: DateTime(2026, 8, 13),
        today: DateTime(2026, 8, 13),
      ),
    ),
  );
}

TodayDomainRead<NutritionTargetsForDate?> _targetRead(int? calories) {
  if (calories == null) {
    return const TodayDomainRead<NutritionTargetsForDate?>.available(null);
  }
  return TodayDomainRead.available(
    NutritionTargetsForDate(
      localDate: '2026-08-13',
      timezoneId: 'Asia/Kolkata',
      goalVersion: NutritionGoalVersionReadModel(
        id: 'r08d1-target',
        userId: 'r08d1-test-user',
        versionNumber: 1,
        goalType: NutritionGoalType.maintenance,
        source: NutritionGoalSource.userSet,
        calorieTargetKcal: calories,
        proteinTargetG: 140,
        carbsTargetG: 220,
        fatTargetG: 65,
        policyVersion: null,
        calculationVersion: null,
        algorithmVersion: null,
        effectiveFromLocalDate: '2026-08-13',
        effectiveToLocalDate: null,
        timezoneId: 'Asia/Kolkata',
        supersedesGoalVersionId: null,
        evidenceFingerprint: null,
        exactResultNumerator: null,
        exactResultDenominator: null,
        normalizedMaintenanceKcal: null,
        createdAtUtc: DateTime.utc(2026, 8, 13),
      ),
    ),
  );
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
