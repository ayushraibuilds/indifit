import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/user_profile_provider.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/features/settings/data_management_sub_screen.dart';
import 'package:indifit/features/settings/household_measures_screen.dart';
import 'package:indifit/features/settings/notification_settings_screen.dart';
import 'package:indifit/features/settings/regional_food_packs_screen.dart';
import 'package:indifit/features/settings/settings_screen.dart';
import 'package:indifit/features/settings/water_settings_sub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestProfileNotifier extends UserProfileNotifier {
  _TestProfileNotifier() : super() {
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

Widget _wrapWithScope(Widget child, {ThemeMode themeMode = ThemeMode.light, double textScale = 1.0, Size size = const Size(390, 844)}) {
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => _TestProfileNotifier()),
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
        home: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'app_theme_mode': 'system',
      'unit_preference': 'metric',
    });
  });

  group('R08G.8 Visual & Responsive Polish', () {
    testWidgets('Settings landing renders without overflow on narrow width (320pt)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithScope(
          const SettingsScreen(),
          size: const Size(320, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings landing renders without overflow at 2.0x text scale in dark mode', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithScope(
          const SettingsScreen(),
          themeMode: ThemeMode.dark,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sub-screens render cleanly at narrow 320pt and 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Data Management
      await tester.pumpWidget(
        _wrapWithScope(
          const DataManagementSubScreen(),
          size: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Notifications
      await tester.pumpWidget(
        _wrapWithScope(
          const NotificationSettingsScreen(),
          size: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Water Settings
      await tester.pumpWidget(
        _wrapWithScope(
          const WaterSettingsSubScreen(),
          size: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Household measures
      await tester.pumpWidget(
        _wrapWithScope(
          const HouseholdMeasuresScreen(),
          size: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Regional food packs
      await tester.pumpWidget(
        _wrapWithScope(
          const RegionalFoodPacksScreen(),
          size: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  group('R08G.8 Accessibility Semantics & Interaction Targets', () {
    testWidgets('Settings landing provides accessible semantics labels for all rows', (tester) async {
      await tester.pumpWidget(_wrapWithScope(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Verify Semantics labels on navigation rows
      expect(
        find.bySemanticsLabel(RegExp('Goal & targets', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.bySemanticsLabel(RegExp('Dietary needs & preferences', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.bySemanticsLabel(RegExp('Health integration', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.bySemanticsLabel(RegExp('Notifications & reminders', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('Theme and Unit bottom sheets open and have accessible option selection', (tester) async {
      await tester.pumpWidget(_wrapWithScope(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll to Appearance row and tap it
      final appearanceFinder = find.widgetWithText(ListTile, 'Appearance');
      await tester.ensureVisible(appearanceFinder);
      await tester.pumpAndSettle();
      final tile = tester.widget<ListTile>(appearanceFinder);
      tile.onTap!();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(RadioListTile<ThemeMode>, 'System'), findsOneWidget);
      expect(find.widgetWithText(RadioListTile<ThemeMode>, 'Light'), findsOneWidget);
      expect(find.widgetWithText(RadioListTile<ThemeMode>, 'Dark'), findsOneWidget);

      // Tap Light option
      await tester.tap(find.widgetWithText(RadioListTile<ThemeMode>, 'Light'));
      await tester.pumpAndSettle();

      // Bottom sheet closed
      expect(find.widgetWithText(RadioListTile<ThemeMode>, 'System'), findsNothing);
    });
  });
}
