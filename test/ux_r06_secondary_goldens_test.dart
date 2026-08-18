import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConstraintDefinition, NutritionUserConstraint;
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/features/education/b05_education_content.dart';
import 'package:indifit/features/education/learn_screen.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/profile/profile_screen.dart';
import 'package:indifit/features/settings/household_measures_controller.dart';
import 'package:indifit/features/settings/household_measures_screen.dart';
import 'package:indifit/features/settings/nutrition_constraints_controller.dart';
import 'package:indifit/features/settings/nutrition_constraints_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

late AppDatabase _r6GoldenDatabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    _r6GoldenDatabase = AppDatabase.memory();
  });

  tearDownAll(() => _r6GoldenDatabase.close());

  testWidgets('onboarding About you dark golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_onboarding_about_dark.png',
      theme: AppTheme.darkTheme,
      child: const OnboardingScreen(),
    );
  });

  testWidgets('onboarding Goal dark golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_onboarding_goal_dark.png',
      theme: AppTheme.darkTheme,
      child: const OnboardingScreen(),
      prepare: _moveToGoal,
    );
  });

  testWidgets('onboarding Nutrition dark golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_onboarding_nutrition_dark.png',
      theme: AppTheme.darkTheme,
      child: const OnboardingScreen(),
      prepare: _moveToNutrition,
    );
  });

  testWidgets('onboarding skip affordance dark golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_onboarding_skip_dark.png',
      theme: AppTheme.darkTheme,
      child: const OnboardingScreen(),
    );
  });

  testWidgets('profile root light golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_profile_light.png',
      theme: AppTheme.lightTheme,
      child: const ProfileScreen(),
    );
  });

  testWidgets('dietary needs light golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_dietary_needs_light.png',
      theme: AppTheme.lightTheme,
      child: const NutritionConstraintsScreen(),
      extraOverrides: [_constraintControllerOverride()],
    );
  });

  testWidgets('household measures dark golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_household_measures_dark.png',
      theme: AppTheme.darkTheme,
      child: const HouseholdMeasuresScreen(),
      extraOverrides: [_householdControllerOverride()],
    );
  });

  testWidgets('learn list dark golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_learn_list_dark.png',
      theme: AppTheme.darkTheme,
      child: const LearnScreen(),
      extraOverrides: [_educationControllerOverride()],
    );
  });

  testWidgets('lesson detail dark golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_lesson_detail_dark.png',
      theme: AppTheme.darkTheme,
      child: const LearnLessonScreen(contentId: 'rpe'),
      extraOverrides: [_educationControllerOverride()],
    );
  });

  testWidgets('onboarding compact 2x golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_onboarding_compact_2x.png',
      theme: AppTheme.darkTheme,
      size: const Size(320, 568),
      textScale: 2,
      child: const OnboardingScreen(),
    );
  });

  testWidgets('profile light representative golden', (tester) async {
    await _expectGolden(
      tester,
      fileName: 'ux_r06_profile_light_representative.png',
      theme: AppTheme.lightTheme,
      child: const ProfileScreen(),
    );
  });
}

Future<void> _expectGolden(
  WidgetTester tester, {
  required String fileName,
  required ThemeData theme,
  required Widget child,
  Size size = const Size(390, 844),
  double textScale = 1,
  Future<void> Function(WidgetTester tester)? prepare,
  List<Override> extraOverrides = const [],
}) async {
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(_r6GoldenDatabase),
        userProfileProvider.overrideWith((ref) => _GoldenProfileNotifier()),
        ...extraOverrides,
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(theme: theme, home: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  if (prepare != null) {
    await prepare(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
  await expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile('goldens/$fileName'),
  );
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _moveToGoal(WidgetTester tester) async {
  await tester.tap(find.text('Male'));
  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();
}

Future<void> _moveToNutrition(WidgetTester tester) async {
  await _moveToGoal(tester);
  await tester.tap(find.text('Maintain'));
  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();
}

Override _constraintControllerOverride() {
  return nutritionConstraintManagementControllerProvider.overrideWith(
    (ref) => _GoldenConstraintController(_r6GoldenDatabase),
  );
}

Override _householdControllerOverride() {
  return householdMeasuresControllerProvider(
    kLocalNutritionUserScopeId,
  ).overrideWith((ref) => _GoldenHouseholdController(_r6GoldenDatabase));
}

Override _educationControllerOverride() {
  return b05EducationLessonsControllerProvider.overrideWith(
    (ref) => _GoldenEducationController(_r6GoldenDatabase),
  );
}

class _GoldenConstraintRepository extends NutritionConstraintRepository {
  _GoldenConstraintRepository(AppDatabase database) : super(database: database);

  @override
  Future<List<NutritionConstraintDefinition>> listTaxonomy() async =>
      NutritionConstraintTaxonomy.definitions;

  @override
  Future<List<NutritionUserConstraint>> listAllConstraints({
    required String userId,
  }) async => const [];
}

class _GoldenProfileNotifier extends UserProfileNotifier {
  _GoldenProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2200,
      proteinGoal: 140,
      carbsGoal: 250,
      fatGoal: 70,
      currentWeight: 80,
      userHeight: 180,
      userName: 'Ayush',
      userSex: 'male',
      userAge: 30,
      userActivityLevel: 'moderate',
      userGoal: 'gain',
      dietPreference: 'non-veg',
    );
  }

  @override
  Future<void> loadProfile() async {}
}

class _GoldenConstraintController
    extends NutritionConstraintManagementController {
  _GoldenConstraintController(AppDatabase database)
    : super(
        repository: _GoldenConstraintRepository(database),
        userId: 'golden-user',
      ) {
    state = NutritionConstraintManagementState(
      status: NutritionConstraintManagementStatus.empty,
      definitions: NutritionConstraintTaxonomy.definitions,
    );
  }

  @override
  Future<void> load() async {}
}

class _GoldenHouseholdController extends HouseholdMeasuresController {
  _GoldenHouseholdController(AppDatabase database)
    : super(
        repository: NutritionHouseholdMeasureRepository(db: database),
        userId: kLocalNutritionUserScopeId,
      ) {
    state = const HouseholdMeasuresState(status: HouseholdMeasuresStatus.empty);
  }

  @override
  Future<void> load() async {}
}

class _GoldenEducationController extends B05EducationLessonsController {
  _GoldenEducationController(AppDatabase database)
    : super(
        repository: B05EducationProgressRepository(database: database),
        registry: b05BundledEducationRegistry,
        userId: kLocalNutritionUserScopeId,
      ) {
    final now = DateTime.utc(2026, 8, 10);
    state = B05EducationLessonsState(
      status: B05EducationLessonsStatus.ready,
      lessons: [
        for (final lesson in kB05BundledEducationLessons)
          B05EducationLessonProgress(
            lesson: lesson,
            progress: B05EducationProgress(
              contentId: lesson.contentId,
              contentVersion: lesson.version,
              state: B05EducationProgressState.notStarted,
              updatedAtUtc: now,
            ),
            previousVersion: null,
          ),
      ],
    );
  }

  @override
  Future<void> load() async {}
}
