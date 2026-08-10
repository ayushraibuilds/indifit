import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/presentation/diet_preference_presentation.dart';
import 'package:indifit/core/presentation/secondary_presentation.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConstraintDefinition, NutritionUserConstraint;
import 'package:indifit/features/dashboard/main_navigation_scaffold.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/profile/profile_screen.dart';
import 'package:indifit/features/settings/unit_preference.dart';
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

  test('unit presentation round-trips without rewriting canonical values', () {
    const kilograms = 80.0;
    const centimetres = 180.0;
    final pounds = UnitPreferencePresentation.weightForDisplay(
      kilograms,
      UnitPreferenceNotifier.imperial,
    );
    final inches = UnitPreferencePresentation.heightForDisplay(
      centimetres,
      UnitPreferenceNotifier.imperial,
    );

    expect(pounds, closeTo(176.3698, 0.0001));
    expect(inches, closeTo(70.8661, 0.0001));
    expect(
      UnitPreferencePresentation.weightForStorage(
        pounds,
        UnitPreferenceNotifier.imperial,
      ),
      closeTo(kilograms, 0.0000001),
    );
    expect(
      UnitPreferencePresentation.heightForStorage(
        inches,
        UnitPreferenceNotifier.imperial,
      ),
      closeTo(centimetres, 0.0000001),
    );
    const roundedUserEntry = 176.4;
    final storedFromRoundedEntry = UnitPreferencePresentation.weightForStorage(
      roundedUserEntry,
      UnitPreferenceNotifier.imperial,
    );
    expect(storedFromRoundedEntry, closeTo(kilograms, 0.02));
    expect(
      UnitPreferencePresentation.weightForDisplay(
        storedFromRoundedEntry,
        UnitPreferenceNotifier.imperial,
      ),
      closeTo(roundedUserEntry, 0.0000001),
    );
  });

  test('display unit preference survives backup serialization', () async {
    SharedPreferences.setMockInitialValues({
      UnitPreferenceNotifier.key: UnitPreferenceNotifier.imperial,
    });
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final prefs = await SharedPreferences.getInstance();
    final backup = await BackupData.createFromDatabase(database, prefs);

    expect(
      backup.userPreferences[UnitPreferenceNotifier.key],
      UnitPreferenceNotifier.imperial,
    );
  });

  test(
    'a skipped user can choose a diet without fabricating a profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'onboarding_skipped': true,
      });
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final notifier = UserProfileNotifier(database);
      addTearDown(notifier.dispose);
      await notifier.loadProfile();

      await notifier.updateDietPreference('non-veg');

      expect(await database.select(database.userProfiles).get(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_diet_preference'), 'non-veg');
      expect(prefs.containsKey('user_age'), isFalse);
      expect(prefs.containsKey('calorie_goal'), isFalse);
      expect(notifier.state.hasProfile, isFalse);
    },
  );

  test(
    'restored skipped state ignores legacy placeholder profile facts',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'onboarding_skipped': true,
        'user_age': 25,
        'user_sex': 'male',
        'current_weight': 74.5,
        'calorie_goal': 2000,
      });
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final notifier = UserProfileNotifier(database);
      addTearDown(notifier.dispose);

      await notifier.loadProfile();

      expect(notifier.state.isLoaded, isTrue);
      expect(notifier.state.hasProfile, isFalse);
      expect(await database.select(database.userProfiles).get(), isEmpty);
    },
  );

  testWidgets('skipped Profile does not render fabricated default facts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'onboarding_skipped': true,
    });
    final database = await pumpDatabase(tester);
    final notifier = _R6ProfileNotifier(
      const UserProfileState(
        isLoaded: true,
        hasProfile: false,
        calorieGoal: 2000,
        proteinGoal: 120,
        carbsGoal: 230,
        fatGoal: 65,
        currentWeight: 74.5,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          userProfileProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Complete your profile when you’re ready'),
      findsOneWidget,
    );
    expect(find.text('Age (years)'), findsNothing);
    expect(find.text('25'), findsNothing);
  });

  testWidgets('Profile presents canonical measurements in Imperial units', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'user_age': 30,
      'user_height': 180.0,
      'current_weight': 80.0,
      'user_sex': 'female',
      UnitPreferenceNotifier.key: UnitPreferenceNotifier.imperial,
    });
    final database = await pumpDatabase(tester);
    final profileNotifier = _R6ProfileNotifier(
      const UserProfileState(
        isLoaded: true,
        hasProfile: true,
        calorieGoal: 2000,
        proteinGoal: 120,
        carbsGoal: 230,
        fatGoal: 65,
        currentWeight: 80,
        userHeight: 180,
        userSex: 'female',
        userAge: 30,
      ),
    );
    final unitNotifier = UnitPreferenceNotifier();
    await unitNotifier.setUnits(UnitPreferenceNotifier.imperial);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          userProfileProvider.overrideWith((ref) => profileNotifier),
          unitPreferenceProvider.overrideWith((ref) => unitNotifier),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    final height = fields.singleWhere(
      (field) => field.decoration?.labelText == 'Height',
    );
    final weight = fields.singleWhere(
      (field) => field.decoration?.labelText == 'Weight',
    );
    expect(height.decoration?.suffixText, 'in');
    expect(weight.decoration?.suffixText, 'lb');
    expect(double.parse(height.controller!.text), closeTo(70.9, 0.05));
    expect(double.parse(weight.controller!.text), closeTo(176.4, 0.05));
    expect(profileNotifier.state.userHeight, 180.0);
    expect(profileNotifier.state.currentWeight, 80.0);
  });

  test('Food deep links resolve into the indexed app shell', () {
    final destination = foodRouteDestination(
      mealType: 'dinner',
      date: '2026-08-09',
    );

    expect(destination, isA<MainNavigationScaffold>());
    expect(destination.initialIndex, 2);
    expect(destination.foodMealType, 'dinner');
    expect(destination.foodSelectedDate, DateTime(2026, 8, 9));
    expect(parseFoodRouteMealType('snack'), 'snacks');
    expect(parseFoodRouteMealType('unsupported'), 'breakfast');
  });

  testWidgets('all onboarding stages remain reachable at 320pt and 2x text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    final database = await pumpDatabase(tester);

    await tester.pumpWidget(
      appWithDatabase(
        database: database,
        child: MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Male'));
    await tester.pump();
    await tester.tap(find.text('Male'));
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('What is your main goal?'), findsOneWidget);
    await tester.ensureVisible(find.text('Maintain'));
    await tester.pump();
    await tester.tap(find.text('Maintain'));
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('How do you move most days?'), findsOneWidget);
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('How do you like to eat?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _R6ProfileNotifier extends UserProfileNotifier {
  _R6ProfileNotifier(UserProfileState initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> loadProfile() async {}
}
