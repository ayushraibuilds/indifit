import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/health_provider.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/di/theme_provider.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/media/b05_playlist_launcher.dart';
import 'package:indifit/features/profile/profile_screen.dart';
import 'package:indifit/features/settings/health_sync_hub_screen.dart';
import 'package:indifit/features/settings/nutrition_targets_hub_screen.dart';
import 'package:indifit/features/settings/settings_screen.dart';
import 'package:indifit/features/settings/unit_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets('Settings landing uses the consumer hierarchy and exclusions', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _expectSettingsSection(tester, 'Goals & targets', [
      'Fitness goal',
      'Nutrition targets',
      'Coaching',
    ]);
    await _expectSettingsSection(tester, 'Food preferences', [
      'Dietary needs',
      'Measuring at home',
      'Regional food preferences',
    ]);
    await _expectSettingsSection(tester, 'Training preferences', [
      'Training preferences',
      'Equipment profiles',
    ]);
    await _expectSettingsSection(tester, 'Health & integrations', [
      'Health integration',
    ]);
    await _expectSettingsSection(tester, 'Notifications', [
      'Notifications & reminders',
    ]);
    await _expectSettingsSection(tester, 'App preferences', [
      'Appearance',
      'Units',
      'Customize Today',
    ]);
    await _expectSettingsSection(tester, 'Data & privacy', [
      'Manage your data',
    ]);
    await _expectSettingsSection(tester, 'Account', ['Personal details']);
    await _expectSettingsSection(tester, 'Learn', ['Learn']);

    for (final obsoleteLabel in [
      'PROFILE',
      'CONNECTIONS',
      'ADVANCED',
      'Nutrition preferences',
      'Food library',
      'Data and backup',
      'Goals & adaptive coaching',
      'Workout playlist',
    ]) {
      expect(find.text(obsoleteLabel), findsNothing, reason: obsoleteLabel);
    }

    expect(find.textContaining('Hydration'), findsNothing);
    expect(find.textContaining('Water'), findsNothing);
    expect(find.textContaining('Travel'), findsNothing);
    expect(find.textContaining('Coming soon'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings rows keep their existing canonical destinations', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Fitness goal'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('Nutrition targets row opens the existing target hub', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Nutrition targets'));
    await tester.pumpAndSettle();
    expect(find.byType(NutritionTargetsHubScreen), findsOneWidget);
  });

  testWidgets('Health integration row opens the existing health owner', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _scrollToSettingsText(
      tester,
      find.widgetWithText(ListTile, 'Health integration'),
    );
    await tester.pumpAndSettle();
    final healthTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Health integration'),
    );
    healthTile.onTap!();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byType(HealthSyncHubScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings remains usable at narrow width and large text', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      size: const Size(320, 568),
      textScale: 2,
      theme: AppTheme.darkTheme,
    );

    final semanticsHandle = tester.ensureSemantics();
    try {
      final targetRow = find.bySemanticsLabel(
        'Nutrition targets, Calories and macros for each day',
      );
      expect(targetRow, findsOneWidget);
      expect(
        tester
            .getSemantics(targetRow)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.drag(find.byType(Scrollable), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('Settings landing representative light state', (tester) async {
    await _pumpSettings(tester);

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/ux_r08g1_settings_landing_light.png'),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
}) async {
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;

  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(database.close());
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        userProfileProvider.overrideWith((ref) => _TestProfileNotifier()),
        healthStateProvider.overrideWith((ref) => _TestHealthNotifier()),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        unitPreferenceProvider.overrideWith((ref) => UnitPreferenceNotifier()),
        b05PlaylistProviderRegistryProvider.overrideWithValue(
          B05PlaylistProviderRegistry(const []),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          home: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}

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

class _TestHealthNotifier extends HealthStateNotifier {
  _TestHealthNotifier() : super(HealthService()) {
    state = const HealthState(status: HealthStatus.notRequested);
  }

  @override
  Future<void> loadHealthData() async {}

  @override
  Future<void> refresh() async {}
}

Future<void> _expectSettingsSection(
  WidgetTester tester,
  String heading,
  List<String> rows,
) async {
  await _scrollToSettingsText(tester, find.text(heading));
  expect(find.text(heading), findsWidgets);
  for (final row in rows) {
    final rowFinder = find.widgetWithText(ListTile, row);
    await _scrollToSettingsText(tester, rowFinder);
    expect(rowFinder, findsOneWidget);
  }
}

Future<void> _scrollToSettingsText(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable);
  for (var attempt = 0; attempt < 24; attempt++) {
    if (target.evaluate().isNotEmpty) {
      final firstTarget = target.first;
      await tester.ensureVisible(firstTarget);
      await tester.pump();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Could not find Settings content after scrolling: $target');
}
