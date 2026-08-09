import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/presentation/diet_preference_presentation.dart';
import 'package:indifit/core/presentation/secondary_presentation.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConstraintDefinition, NutritionUserConstraint;
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<AppDatabase> pumpDatabase(WidgetTester tester) async {
    final database = AppDatabase.memory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    });
    return database;
  }

  Widget appWithDatabase({
    required AppDatabase database,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('onboarding is a short four-stage flow without lessons', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final database = await pumpDatabase(tester);

    await tester.pumpWidget(
      appWithDatabase(database: database, child: const OnboardingScreen()),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.text('Welcome to IndiFit!'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('Understanding RPE'), findsNothing);
    expect(find.textContaining('lesson'), findsNothing);
    expect(find.text('What is your main goal?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip enters the shell without fabricating profile or targets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final database = await pumpDatabase(tester);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Today shell')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Today shell'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_skipped'), isTrue);
    expect(prefs.getBool('onboarding_completed'), isTrue);
    expect(prefs.containsKey('user_age'), isFalse);
    expect(prefs.containsKey('user_target_weight'), isFalse);
    expect(prefs.containsKey('calorie_goal'), isFalse);
    expect(prefs.containsKey('adaptive_consent'), isFalse);
  });

  testWidgets('legacy onboarding pages resume inside the short flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_draft_page': 6,
      'onboarding_draft_sex': 'female',
      'onboarding_draft_age': '31',
      'onboarding_draft_height': '165',
      'onboarding_draft_weight': '62',
      'onboarding_draft_goal': 'gain',
      'onboarding_draft_diet': 'non-veg',
    });
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final database = await pumpDatabase(tester);

    await tester.pumpWidget(
      appWithDatabase(database: database, child: const OnboardingScreen()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('What is your main goal?'), findsOneWidget);
    expect(find.text('2 of 4'), findsOneWidget);
    expect(find.text('What is your target weight?'), findsNothing);
    expect(find.text('Understanding RPE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'onboarding remains usable across the compact accessibility matrix',
    (tester) async {
      addTearDown(tester.view.reset);
      final database = AppDatabase.memory();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await database.close();
      });
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(430, 932),
      ]) {
        for (final scale in const [1.0, 1.5, 2.0]) {
          for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
            SharedPreferences.setMockInitialValues({});
            await tester.pumpWidget(
              ProviderScope(
                overrides: [databaseProvider.overrideWithValue(database)],
                child: MaterialApp(
                  theme: theme,
                  home: MediaQuery(
                    data: MediaQueryData.fromView(
                      tester.view,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: const OnboardingScreen(),
                  ),
                ),
              ),
            );
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pump(const Duration(milliseconds: 120));
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  test('dietary aliases stay at the presentation boundary', () {
    expect(
      DietPreferencePresentation.normalizeForOnboarding('non-veg'),
      'non-veg',
    );
    expect(
      DietPreferencePresentation.normalizeForOnboarding('non_veg'),
      'non-veg',
    );
    expect(
      DietPreferencePresentation.uiValueFor('non-veg'),
      DietPreferencePresentation.uiValueFor('non_veg'),
    );
    final allergy = NutritionConstraintPresentation.fromDomain(
      NutritionUserConstraint(
        id: 'allergy-1',
        userId: 'local-user',
        definitionId: 'nutrition-constraint-type-allergy',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'peanut',
        ),
        strictness: NutritionConstraintStrictness.avoid,
        crossContact: true,
        effectiveFrom: DateTime.utc(2026, 8, 10),
        source: NutritionConstraintSource.userEntered,
      ),
    );
    final preference = NutritionConstraintPresentation.fromDomain(
      NutritionUserConstraint(
        id: 'preference-1',
        userId: 'local-user',
        definitionId: 'nutrition-constraint-type-ethical-preference',
        type: NutritionConstraintType.ethicalPreference,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.ingredient,
          id: 'mushroom',
        ),
        strictness: NutritionConstraintStrictness.warn,
        effectiveFrom: DateTime.utc(2026, 8, 10),
        source: NutritionConstraintSource.userEntered,
      ),
    );
    expect(allergy.detail, isNot(preference.detail));
    expect(allergy.crossContact, isTrue);
    expect(allergy.handling, 'Avoid');
    expect(preference.handling, 'Warn me');
  });
}
