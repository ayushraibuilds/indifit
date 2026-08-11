import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/custom_food_editor_screen.dart';
import 'package:indifit/features/profile/profile_screen.dart';
import 'package:indifit/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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
    expect(find.text('Save Custom Food'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(ListTile, 'Goal'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Goal')),
      findsOneWidget,
    );
    expect(find.text('Goals'), findsOneWidget);

    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await tester.pumpAndSettle();
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
}
