import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/presentation/diet_preference_presentation.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/indi_fit_bottom_sheet.dart';
import 'package:indifit/core/widgets/responsive_form_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/onboarding/b05_adaptive_onboarding.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/workout_player/widgets/manual_log_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('UX wave 1 diet preference presentation', () {
    test('maps aliases to one UI value without rewriting source identity', () {
      expect(DietPreferencePresentation.uiValueFor('veg'), 'veg');
      expect(DietPreferencePresentation.uiValueFor('vegan'), 'vegan');
      expect(DietPreferencePresentation.uiValueFor('non-veg'), 'non_veg');
      expect(DietPreferencePresentation.uiValueFor('non_veg'), 'non_veg');
      expect(DietPreferencePresentation.uiValueFor('unknown'), isNull);
      expect(DietPreferencePresentation.uiValueFor(null), isNull);
      expect(B05OnboardingDraftStore.normalizeDiet('non_veg'), 'non-veg');

      final duplicateSources = ['non-veg', 'non_veg', 'non-veg'];
      expect(
        duplicateSources.map(DietPreferencePresentation.uiValueFor).toSet(),
        {'non_veg'},
      );

      final uiValues = DietPreferencePresentation.options
          .map((option) => option.uiValue)
          .toList();
      expect(uiValues.toSet(), hasLength(uiValues.length));
      expect(
        DietPreferencePresentation.persistedValueFor(
          originalValue: 'non_veg',
          uiValue: 'non_veg',
        ),
        'non_veg',
      );
      expect(
        DietPreferencePresentation.persistedValueFor(
          originalValue: 'veg',
          uiValue: 'non_veg',
          userChanged: true,
        ),
        'non-veg',
      );
      expect(
        DietPreferencePresentation.persistedValueFor(
          originalValue: 'legacy-unknown',
          uiValue: 'veg',
        ),
        'legacy-unknown',
      );
    });

    testWidgets('dropdown is safe for every legacy, unknown, and null value', (
      tester,
    ) async {
      for (final rawValue in <String?>[
        'veg',
        'vegan',
        'non-veg',
        'non_veg',
        'unknown',
        null,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DietPreferenceDropdown(
                persistedValue: rawValue,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'diet value $rawValue must not assert',
        );
      }
    });
  });

  testWidgets('responsive field groups avoid overflow at release sizes', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IndiFitResponsiveFieldGroup(
                    children: [
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Target Weight (kg)',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: 'standard',
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'standard',
                            child: Text(
                              '20 kg (Standard Olympic Barbell)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '$width width at $scale text scale must not overflow',
        );
      }
    }
  });

  testWidgets('bottom sheet remains opaque and keyboard-aware', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showIndiFitBottomSheet<void>(
                  context: context,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: TextField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                  ),
                ),
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.byType(IndiFitBottomSheet), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual workout logging preserves editable set state', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final repository = _FakeWorkoutRepository(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          workoutRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ManualLogSheet(selectedDate: DateTime(2026, 8, 8)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap to add exercises to this log'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Set 1'), findsOneWidget);
    final firstSetWeight = find.byType(TextField).at(2);
    await tester.enterText(firstSetWeight, '55');
    await tester.pump();
    expect(tester.widget<TextField>(firstSetWeight).controller?.text, '55');

    await tester.tap(find.text('Add Set'));
    await tester.pump();
    expect(find.text('Set 4'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
      '55',
    );

    await tester.tap(find.byTooltip('Remove set 4'));
    await tester.pump();
    expect(find.text('Set 4'), findsNothing);
    await tester.tap(find.byTooltip('Remove Bench Press'));
    await tester.pump();
    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('Tap to add exercises to this log'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding dismisses stale focus before validation/transition', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase.memory();
    addTearDown(database.close);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Select your biological sex:'), findsOneWidget);
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Priya');
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.tap(find.text('Next Step'));
    await tester.pump();
    final focusedEditable = find.byType(EditableText).evaluate().where((
      element,
    ) {
      return Focus.maybeOf(element)?.hasPrimaryFocus ?? false;
    });
    expect(focusedEditable, isEmpty);
    expect(find.text('Select your biological sex:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation themes provide explicit light and dark states', (
    tester,
  ) async {
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today_rounded),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center_rounded),
                  label: 'Workouts',
                ),
              ],
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(theme.navigationBarTheme.backgroundColor, isNotNull);
      expect(theme.navigationBarTheme.iconTheme, isNotNull);
      expect(theme.navigationBarTheme.labelTextStyle, isNotNull);
    }
  });
}

class _FakeWorkoutRepository extends WorkoutRepository {
  _FakeWorkoutRepository(super.database);

  @override
  Future<List<Exercise>> searchExercises(String query) async {
    return [
      const Exercise(
        id: 1,
        stableId: 'exercise-bench-v1',
        name: 'Bench Press',
        muscleGroups: 'Chest',
        equipment: 'Barbell',
        difficulty: 'Beginner',
        formCues: 'Keep wrists stacked.',
        commonMistakes: 'Bouncing the bar.',
        isCustom: false,
      ),
    ];
  }
}
