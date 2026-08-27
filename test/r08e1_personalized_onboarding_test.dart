import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/utils/tdee_calculator.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('review payoff reflects answers and offers focused adjustments', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final database = await _pumpDatabase(tester);
    await tester.pumpWidget(_onboardingApp(database));
    await tester.pump(const Duration(milliseconds: 250));

    await _moveToReview(
      tester,
      goal: 'Gain / build muscle',
      activity: 'Very Active',
      diet: 'Vegan',
    );

    expect(find.text('Here’s your starting setup'), findsOneWidget);
    expect(find.text('Personalized for you'), findsOneWidget);
    expect(find.text('Build muscle'), findsOneWidget);
    expect(find.text('Very active'), findsOneWidget);
    expect(find.text('Vegan'), findsOneWidget);
    expect(find.text('Starting daily target'), findsOneWidget);
    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('Adjust'), findsNWidgets(4));
    expect(find.text('Hi'), findsNothing);
    expect(find.textContaining('perfect plan'), findsNothing);
    expect(find.textContaining('optimize everything'), findsNothing);

    final goalAdjust = find.text('Adjust').at(1);
    await tester.ensureVisible(goalAdjust);
    await tester.tap(goalAdjust);
    await tester.pumpAndSettle();
    expect(find.text('What is your main goal?'), findsOneWidget);
    expect(find.text('2 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finish persists the reviewed profile and canonical target values',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final database = await _pumpDatabase(tester);
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
          overrides: [
            databaseProvider.overrideWithValue(database),
            userProfileProvider.overrideWith((ref) => _TestProfileNotifier()),
            workoutRepositoryProvider.overrideWithValue(
              _TestWorkoutRepository(database),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(find.byType(TextField).at(0), 'Maya');
      await tester.enterText(find.byType(TextField).at(1), '31');
      await tester.enterText(find.byType(TextField).at(2), '165');
      await tester.enterText(find.byType(TextField).at(3), '62');
      await _moveToReview(
        tester,
        sex: 'Female',
        goal: 'Gain / build muscle',
        activity: 'Very Active',
        diet: 'Non-Vegetarian',
      );

      final beforeFinish = await SharedPreferences.getInstance();
      expect(beforeFinish.containsKey('onboarding_completed'), isFalse);
      expect(beforeFinish.containsKey('calorie_goal'), isFalse);
      expect(find.text('Finish setup'), findsOneWidget);

      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      expect(find.text('Today shell'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), 'Maya');
      expect(prefs.getString('user_sex'), 'female');
      expect(prefs.getInt('user_age'), 31);
      expect(prefs.getDouble('user_height'), 165);
      expect(prefs.getDouble('current_weight'), 62);
      expect(prefs.getString('user_goal'), 'gain');
      expect(prefs.getString('user_activity_level'), 'active');
      expect(prefs.getString('user_diet_preference'), 'non-veg');
      expect(prefs.getBool('onboarding_completed'), isTrue);

      final bmr = TdeeCalculator.calculateBmr(
        weightKg: 62,
        heightCm: 165,
        ageYears: 31,
        gender: Gender.female,
      );
      final tdee = TdeeCalculator.calculateTdee(
        bmr: bmr,
        activityLevel: ActivityLevel.veryActive,
      );
      final macros = TdeeCalculator.calculateMacros(
        tdee: tdee,
        goal: FitnessGoal.muscleGain,
        weightKg: 62,
      );
      expect(prefs.getInt('calorie_goal'), macros.calories);
      expect(prefs.getDouble('protein_goal'), macros.proteinG);
      expect(prefs.getDouble('carbs_goal'), macros.carbsG);
      expect(prefs.getDouble('fat_goal'), macros.fatG);

      expect(tester.takeException(), isNull);
    },
  );

  test(
    'profile bridge persists preference targets into canonical storage',
    () async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'Maya',
        'user_age': 31,
        'user_height': 165.0,
        'current_weight': 62.0,
        'user_sex': 'female',
        'user_activity_level': 'active',
        'user_goal': 'gain',
        'user_diet_preference': 'non-veg',
        'calorie_goal': 2603,
        'protein_goal': 124.0,
        'carbs_goal': 364.1,
        'fat_goal': 72.3,
      });
      final database = AppDatabase.memory();
      final notifier = UserProfileNotifier(
        database,
        LocalTimezoneService(read: () async => 'Asia/Kolkata'),
      );
      addTearDown(() async {
        notifier.dispose();
        await database.close();
      });

      await notifier.loadProfile();

      final profiles = await database.select(database.userProfiles).get();
      final goals = await database.select(database.nutritionGoalVersions).get();
      expect(profiles, hasLength(1));
      expect(goals, hasLength(1));
      expect(profiles.single.name, 'Maya');
      expect(goals.single.userId, profiles.single.id.toString());
      expect(goals.single.calorieTargetKcal, 2603);
      expect(goals.single.proteinTargetG, 124);
      expect(goals.single.carbsTargetG, 364.1);
      expect(goals.single.fatTargetG, 72.3);
    },
  );

  testWidgets(
    'finishing a Settings setup reset updates the existing canonical target',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});
      final database = await _pumpDatabase(tester);
      await tester.runAsync(() async {
        final profileId = await database
            .into(database.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                name: const Value('Existing user'),
                age: const Value(30),
                height: const Value(180),
                weight: const Value(80),
                sex: const Value('male'),
                activityLevel: const Value('moderate'),
                goal: const Value('maintain'),
                dietPreference: const Value('veg'),
                calorieGoal: const Value(2100),
                proteinGoal: const Value(140),
                carbsGoal: const Value(220),
                fatGoal: const Value(65),
              ),
            );
        await database
            .into(database.nutritionGoalVersions)
            .insert(
              NutritionGoalVersionsCompanion.insert(
                id: 'existing-canonical-goal',
                userId: '$profileId',
                versionNumber: 1,
                goalType: NutritionGoalType.maintenance.stableId,
                targetSource: NutritionGoalSource.userSet.stableId,
                calorieTargetKcal: const Value(2100),
                proteinTargetG: const Value(140),
                carbsTargetG: const Value(220),
                fatTargetG: const Value(65),
                effectiveFromLocalDate: '2000-01-01',
                timezoneId: 'UTC',
              ),
            );
      });
      final profileNotifier = _ExistingProfileNotifier(database);

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
          overrides: [
            databaseProvider.overrideWithValue(database),
            userProfileProvider.overrideWith((ref) => profileNotifier),
            workoutRepositoryProvider.overrideWithValue(
              _TestWorkoutRepository(database),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await _moveToReview(tester, goal: 'Gain / build muscle');
      await tester.tap(find.text('Finish setup'));
      await tester.pump();
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Today shell').evaluate().isNotEmpty) break;
      }

      expect(find.text('Today shell'), findsOneWidget);
      final versions = await tester.runAsync(
        () => database.select(database.nutritionGoalVersions).get(),
      );
      expect(versions, isNotNull);
      final persistedVersions = versions!;
      persistedVersions.sort(
        (left, right) => left.versionNumber.compareTo(right.versionNumber),
      );
      expect(persistedVersions, hasLength(2));
      expect(persistedVersions.last.goalType, NutritionGoalType.gain.stableId);
      expect(
        persistedVersions.last.targetSource,
        NutritionGoalSource.userSet.stableId,
      );
      expect(persistedVersions.last.calorieTargetKcal, isNot(2100));
    },
  );

  testWidgets('persistence failure stays recoverable and never completes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final database = await _pumpDatabase(tester);
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
        overrides: [
          databaseProvider.overrideWithValue(database),
          userProfileProvider.overrideWith((ref) => _TestProfileNotifier()),
          workoutRepositoryProvider.overrideWithValue(
            _FailingWorkoutRepository(database),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await _moveToReview(tester);
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(find.text('Today shell'), findsNothing);
    expect(find.text('Setup could not be completed'), findsOneWidget);
    expect(find.text('Retry setup'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isNot(true));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'payoff remains usable at compact width and elevated text scale',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      final database = await _pumpDatabase(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const MaterialApp(home: OnboardingScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await _moveToReview(tester);
      expect(find.text('Starting daily target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<AppDatabase> _pumpDatabase(WidgetTester tester) async {
  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });
  return database;
}

Widget _onboardingApp(AppDatabase database) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: const MaterialApp(home: OnboardingScreen()),
  );
}

Future<void> _moveToReview(
  WidgetTester tester, {
  String sex = 'Male',
  String goal = 'Maintain',
  String activity = 'Moderately Active',
  String diet = 'Vegetarian',
}) async {
  await _tapVisible(tester, sex);
  await _tapVisible(tester, 'Next Step');
  await _tapVisible(tester, goal);
  await _tapVisible(tester, 'Next Step');
  await _tapVisible(tester, activity);
  await _tapVisible(tester, 'Next Step');
  await _tapVisible(tester, diet);
  await _tapVisible(tester, 'Review setup');
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _TestProfileNotifier extends UserProfileNotifier {
  _TestProfileNotifier() : super();

  @override
  Future<void> loadProfile() async {}
}

class _ExistingProfileNotifier extends UserProfileNotifier {
  _ExistingProfileNotifier(AppDatabase database)
    : super(database, LocalTimezoneService(read: () async => 'UTC')) {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2100,
      proteinGoal: 140,
      carbsGoal: 220,
      fatGoal: 65,
      currentWeight: 80,
      userHeight: 180,
      userName: 'Existing user',
      userSex: 'male',
      userAge: 30,
      userActivityLevel: 'moderate',
      userGoal: 'maintain',
      dietPreference: 'veg',
    );
  }

  @override
  Future<void> loadProfile() async {}
}

class _TestWorkoutRepository extends WorkoutRepository {
  _TestWorkoutRepository(super.database);

  @override
  Future<int> logBodyMeasurement({
    double? weight,
    double? waist,
    double? chest,
    double? arms,
  }) async => 1;
}

class _FailingWorkoutRepository extends WorkoutRepository {
  _FailingWorkoutRepository(super.database);

  @override
  Future<int> logBodyMeasurement({
    double? weight,
    double? waist,
    double? chest,
    double? arms,
  }) async {
    throw StateError('test persistence failure');
  }
}
