import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/education/b05_education_content.dart';
import 'package:indifit/features/onboarding/b05_adaptive_onboarding.dart';
import 'package:indifit/features/onboarding/widgets/onboarding_step_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('B05 adaptive onboarding mapping', () {
    test('maps every declared goal to only packaged lesson IDs', () {
      for (final goal in const [
        'lose',
        'maintain',
        'gain',
        'weight_loss',
        'hypertrophy',
        'strength',
      ]) {
        final ids = B05GoalLessonMapping.lessonIdsFor(goal);
        expect(ids, isNotEmpty, reason: goal);
        expect(
          ids,
          everyElement(
            isIn(
              b05BundledEducationRegistry.lessons.map(
                (lesson) => lesson.contentId,
              ),
            ),
          ),
        );
      }
      expect(B05GoalLessonMapping.lessonIdsFor('unrecognized'), isEmpty);
      expect(
        B05AdaptiveOnboardingPlan.fromGoal(
          selectedGoal: 'strength',
        ).lessons.map((lesson) => lesson.contentId),
        ['rpe', 'progressive_overload', 'recovery'],
      );
    });
  });

  group('B05 adaptive onboarding controller', () {
    late AppDatabase database;
    late B05EducationProgressRepository repository;

    setUp(() {
      database = AppDatabase.memory();
      repository = B05EducationProgressRepository(database: database);
    });

    tearDown(() => database.close());

    test('resumes at the first incomplete goal lesson', () async {
      await repository.complete(
        userId: 'local-user',
        lesson: b05BundledEducationRegistry.lessons.firstWhere(
          (lesson) => lesson.contentId == 'rpe',
        ),
      );
      final controller = B05AdaptiveOnboardingController(
        repository: repository,
        registry: b05BundledEducationRegistry,
        userId: 'local-user',
        selectedGoal: 'strength',
      );

      await controller.load();

      expect(controller.state.status, B05AdaptiveOnboardingStatus.ready);
      expect(controller.state.lessons.first.lesson.lesson.contentId, 'rpe');
      expect(controller.state.lessons.first.isCompleted, isTrue);
      expect(controller.state.currentLessonIndex, 1);

      await controller.complete('progressive_overload');
      expect(controller.state.lessons[1].isCompleted, isTrue);
      expect(controller.state.currentLessonIndex, 2);
    });

    test('revisit reopens completed content without a duplicate row', () async {
      final lesson = b05BundledEducationRegistry.lessons.first;
      await repository.complete(userId: 'local-user', lesson: lesson);
      final controller = B05AdaptiveOnboardingController(
        repository: repository,
        registry: b05BundledEducationRegistry,
        userId: 'local-user',
        selectedGoal: 'maintain',
      );

      await controller.load();
      await controller.revisit(lesson.contentId);

      expect(controller.state.lessons.first.isCompleted, isFalse);
      expect(await repository.readAll(userId: 'local-user'), hasLength(1));
    });
  });

  test('routine draft store restores bounded fields and clears them', () async {
    final longInjuryNote = List.filled(600, 'x').join();
    SharedPreferences.setMockInitialValues({
      'onboarding_draft_routine_step': 99,
      'onboarding_draft_routine_goal': 'strength',
      'onboarding_draft_routine_equipment': 'full_gym',
      'onboarding_draft_routine_days': 5,
      'onboarding_draft_routine_experience': 'advanced',
      'onboarding_draft_routine_injuries': longInjuryNote,
    });
    const store = B05OnboardingDraftStore();

    final restored = await store.readRoutineDraft();
    expect(restored, isNotNull);
    expect(restored!.currentStep, 4);
    expect(restored.selectedGoal, 'strength');
    expect(restored.selectedEquipment, 'gym');
    expect(restored.daysPerWeek, 5);
    expect(restored.injuries, hasLength(512));

    await store.clearRoutineDraft();
    expect(await store.readRoutineDraft(), isNull);
  });

  test('profile draft restores only bounded, recognized values', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_draft_page': 99,
      'onboarding_draft_sex': 'unspecified',
      'onboarding_draft_name': List.filled(140, 'n').join(),
      'onboarding_draft_age': List.filled(30, '9').join(),
      'onboarding_draft_activity': 'adaptive',
      'onboarding_draft_goal': 'coach-inferred',
      'onboarding_draft_diet': 'unknown',
    });
    const store = B05OnboardingDraftStore();

    final restored = await store.readProfileDraft();

    expect(restored, isNotNull);
    expect(restored!.currentPage, 7);
    expect(restored.sex, isNull);
    expect(restored.name, hasLength(100));
    expect(restored.age, hasLength(16));
    expect(restored.activityLevel, 'moderate');
    expect(restored.goal, 'maintain');
    expect(restored.dietPreference, 'veg');
  });

  test(
    'profile draft save removes a stale sex answer and can be cleared',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_draft_page': 1,
        'onboarding_draft_sex': 'male',
      });
      const store = B05OnboardingDraftStore();

      await store.saveProfileDraft(
        const B05ProfileOnboardingDraft(
          currentPage: 6,
          sex: null,
          name: '  Priya  ',
          age: '31',
          height: '165',
          weight: '62',
          activityLevel: 'light',
          goal: 'lose',
          targetWeight: '58',
          dietPreference: 'vegan',
        ),
      );

      final restored = await store.readProfileDraft();
      expect(restored!.currentPage, 6);
      expect(restored.sex, isNull);
      expect(restored.name, 'Priya');
      expect(restored.goal, 'lose');

      await store.clearProfileDraft();
      expect(await store.readProfileDraft(), isNull);
    },
  );

  test(
    'skipping profile setup records no fabricated profile targets',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_draft_page': 3,
        'onboarding_draft_age': '25',
        'onboarding_draft_goal': 'maintain',
      });
      const store = B05OnboardingDraftStore();

      await store.markProfileOnboardingSkipped();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getBool('onboarding_completed'), isTrue);
      expect(prefs.getBool('onboarding_skipped'), isTrue);
      expect(prefs.containsKey('user_age'), isFalse);
      expect(prefs.containsKey('calorie_goal'), isFalse);
      expect(prefs.containsKey('protein_goal'), isFalse);
      expect(prefs.containsKey('carbs_goal'), isFalse);
      expect(prefs.containsKey('fat_goal'), isFalse);
      expect(await store.readProfileDraft(), isNull);
    },
  );

  testWidgets('onboarding choice semantics and reduced motion remain usable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var tapped = false;
    try {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: OnboardingSelectionCard(
                title: 'Male',
                icon: Icons.male,
                selected: true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Male')),
        matchesSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          label: 'Male',
          hint: 'Select Male.',
        ),
      );
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .duration,
        Duration.zero,
      );

      await tester.tap(find.byType(OnboardingSelectionCard));
      expect(tapped, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('goal lesson path exposes semantic non-gesture actions', (
    tester,
  ) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final controller = B05AdaptiveOnboardingController(
      repository: B05EducationProgressRepository(database: database),
      registry: b05BundledEducationRegistry,
      userId: 'local-user',
      selectedGoal: 'strength',
    );
    await tester.runAsync(controller.load);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b05AdaptiveOnboardingControllerProvider(
              'strength',
            ).overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: B05AdaptiveLessonPath(selectedGoal: 'strength'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Learn for your strength goal'), findsOneWidget);
      expect(find.text('Mark lesson complete'), findsNWidgets(3));
      expect(find.bySemanticsLabel('RPE').first, findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
