import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/indi_fit_bottom_sheet.dart';
import 'package:indifit/core/widgets/indi_fit_feedback.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/dashboard/dashboard_controller.dart';
import 'package:indifit/features/food_log/custom_food_editor_screen.dart';
import 'package:indifit/features/profile/profile_screen.dart';
import 'package:indifit/features/settings/settings_screen.dart';
import 'package:indifit/features/workout_player/widgets/manual_log_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // R07F-0: Outfit is bundled; no runtime font fetching configuration.

  test('ordinary success feedback is compact and semantically concise', () {
    final snackBar = indiFitSuccessSnackBar('✓ Workout logged');

    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, isNull);
    expect((snackBar.content as Text).data, '✓ Workout logged');
  });

  testWidgets(
    'skip feedback is themed, floating, and cleared before workout navigation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const _FeedbackNavigationHarness(),
        ),
      );

      await tester.tap(find.text('Skip workout'));
      await tester.pump();
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, B05SemanticColors.dark.section);
      expect(find.text('Workout skipped.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Open workout player'));
      await tester.pumpAndSettle();
      expect(find.text('Review Workout'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Workout skipped.'), findsNothing);
    },
  );

  testWidgets('Custom Food remains readable in light mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final database = AppDatabase.memory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          foodRepositoryProvider.overrideWithValue(FoodRepository(database)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomFoodEditorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Custom Food'), findsOneWidget);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Serving'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('Save custom food'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CustomFoodEditorScreen),
      matchesGoldenFile('goldens/ux_r07a_custom_food_light.png'),
    );
  });

  testWidgets('Settings rows open focused Profile editors', (tester) async {
    SharedPreferences.setMockInitialValues({
      'user_age': 32,
      'user_height': 175.0,
      'current_weight': 72.0,
      'user_sex': 'male',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => _FakeProfileNotifier()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSettingsTo(
      tester,
      find.widgetWithText(ListTile, 'Personal details'),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Personal details'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Personal details'),
      ),
      findsOneWidget,
    );
    expect(find.text('Goals'), findsNothing);

    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await tester.pumpAndSettle();
    await _scrollSettingsToTop(tester);
    await _scrollSettingsTo(
      tester,
      find.widgetWithText(ListTile, 'Fitness goal'),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Fitness goal'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Goal')),
      findsOneWidget,
    );
    expect(find.text('Goals'), findsOneWidget);

    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await tester.pumpAndSettle();
    await _scrollSettingsToTop(tester);
    await _scrollSettingsTo(
      tester,
      find.widgetWithText(ListTile, 'Training preferences'),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Training preferences'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Training preferences'),
      ),
      findsOneWidget,
    );
    expect(find.text('Goals'), findsNothing);
  });

  testWidgets('focused Goal save does not submit unrelated profile fields', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'user_age': 32,
      'user_height': 175.0,
      'current_weight': 72.0,
      'user_sex': 'male',
    });
    final profile = _FakeProfileNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => profile),
          dashboardControllerProvider.overrideWith(
            (ref) => _NoopDashboardController(ref),
          ),
        ],
        child: const MaterialApp(
          home: ProfileScreen(focus: ProfileEditorFocus.goal),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      ).read(userProfileProvider.notifier),
      same(profile),
    );

    await tester.tap(find.text('Maintain and feel strong'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build muscle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep current targets'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(profile.lastUpdate, isNotNull);
    expect(profile.lastUpdate!['goal'], 'gain');
    for (final field in const [
      'name',
      'age',
      'height',
      'weight',
      'sex',
      'activityLevel',
      'dietPreference',
      'equipmentAccess',
      'injuriesLimitations',
    ]) {
      expect(profile.lastUpdate![field], isNull, reason: field);
    }
  });

  testWidgets(
    'manual workout honors top, bottom, and keyboard safe-area insets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final database = AppDatabase.memory();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.reset();
        await database.close();
      });
      const topInset = 59.0;
      const bottomInset = 34.0;
      const keyboardInset = 280.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
                viewPadding: EdgeInsets.only(
                  top: topInset,
                  bottom: bottomInset,
                ),
                viewInsets: EdgeInsets.only(bottom: keyboardInset),
              ),
              child: Scaffold(
                body: IndiFitBottomSheet(
                  showHandle: false,
                  child: ManualLogSheet(selectedDate: DateTime(2026, 8, 9)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Log Completed Workout')).dy,
        greaterThanOrEqualTo(topInset),
      );
      expect(
        tester.getTopRight(find.byTooltip('Close')).dy,
        greaterThanOrEqualTo(topInset),
      );
      expect(
        tester.getBottomRight(find.text('Save Workout Session')).dy,
        lessThanOrEqualTo(844 - keyboardInset - bottomInset),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual workout presenter preserves real modal route insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final database = AppDatabase.memory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.reset();
      await database.close();
    });
    const topInset = 59.0;
    const bottomInset = 34.0;
    const keyboardInset = 280.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
            viewPadding: EdgeInsets.only(top: topInset, bottom: bottomInset),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => showIndiFitBottomSheet<void>(
                    context: context,
                    semanticLabel: 'Log completed workout',
                    builder: (_) =>
                        ManualLogSheet(selectedDate: DateTime(2026, 8, 9)),
                  ),
                  child: const Text('Open manual workout'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open manual workout'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Log completed workout'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Log Completed Workout')).dy,
      greaterThanOrEqualTo(topInset),
    );
    expect(
      tester.getTopRight(find.byTooltip('Close')).dy,
      greaterThanOrEqualTo(topInset),
    );
    expect(
      tester.getBottomRight(find.text('Save Workout Session')).dy,
      lessThanOrEqualTo(844 - keyboardInset - bottomInset),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FeedbackNavigationHarness extends StatelessWidget {
  const _FeedbackNavigationHarness();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                indiFitUndoSnackBar(
                  context,
                  message: 'Workout skipped.',
                  duration: const Duration(seconds: 30),
                  onUndo: () {},
                ),
              );
            },
            child: const Text('Skip workout'),
          ),
          FilledButton(
            onPressed: () {
              dismissIndiFitFeedback(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Review Workout')),
                  ),
                ),
              );
            },
            child: const Text('Open workout player'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _scrollSettingsTo(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable);
  for (var attempt = 0; attempt < 24; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pump();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Could not find Settings content after scrolling: $target');
}

Future<void> _scrollSettingsToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable), const Offset(0, 3000));
  await tester.pump(const Duration(milliseconds: 50));
}

class _FakeProfileNotifier extends UserProfileNotifier {
  _FakeProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2000,
      proteinGoal: 120,
      carbsGoal: 230,
      fatGoal: 65,
      currentWeight: 72,
      userHeight: 175,
      userName: 'Test user',
    );
  }

  @override
  Future<void> loadProfile() async {}

  Map<String, Object?>? lastUpdate;

  @override
  Future<void> updateProfile({
    String? name,
    int? age,
    double? height,
    double? weight,
    String? sex,
    String? activityLevel,
    String? goal,
    String? dietPreference,
    int? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    String? equipmentAccess,
    String? injuriesLimitations,
  }) async {
    lastUpdate = {
      'name': name,
      'age': age,
      'height': height,
      'weight': weight,
      'sex': sex,
      'activityLevel': activityLevel,
      'goal': goal,
      'dietPreference': dietPreference,
      'calorieGoal': calorieGoal,
      'proteinGoal': proteinGoal,
      'carbsGoal': carbsGoal,
      'fatGoal': fatGoal,
      'equipmentAccess': equipmentAccess,
      'injuriesLimitations': injuriesLimitations,
    };
  }
}

class _NoopDashboardController extends DashboardController {
  _NoopDashboardController(super.ref) : super(loadOnInit: false);

  @override
  Future<void> loadStateData() async {}
}
