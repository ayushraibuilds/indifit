import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/settings/regional_food_packs_screen.dart';
import 'package:indifit/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings groups supported food preferences together', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => _FakeProfileNotifier()),
          healthServiceProvider.overrideWithValue(_FakeHealthService()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('FOOD & NUTRITION'), findsOneWidget);
    expect(find.text('Dietary needs & preferences'), findsOneWidget);
    expect(find.text('Household measures'), findsOneWidget);
    expect(find.text('Regional foods'), findsOneWidget);
    expect(find.text('Food library'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'regional food choices use existing search controls at large text',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final repository = _FakeRegionalFoodRepository(
        database,
        initial: {'gujarati': true},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [foodRepositoryProvider.overrideWithValue(repository)],
          child: MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const RegionalFoodPacksScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Regional foods'), findsNWidgets(2));
      expect(
        find.textContaining('do not change nutrition values'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Gujarati Pack'), 300);
      expect(find.text('Included in food search'), findsOneWidget);
      expect(find.text('Not included in food search'), findsWidgets);
      expect(find.byType(Switch), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('regional update failure keeps the previous choice visible', (
    tester,
  ) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final repository = _FakeRegionalFoodRepository(
      database,
      initial: {'gujarati': true},
    )..failNextUpdate = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [foodRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RegionalFoodPacksScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Gujarati Pack'), 240);

    final gujaratiSurface = find.ancestor(
      of: find.text('Gujarati Pack'),
      matching: find.byType(B05Surface),
    );
    final gujaratiSwitch = find.descendant(
      of: gujaratiSurface,
      matching: find.byType(Switch),
    );
    expect(gujaratiSwitch, findsOneWidget);
    expect(tester.widget<Switch>(gujaratiSwitch).value, isTrue);

    await tester.tap(gujaratiSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(gujaratiSwitch).value, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    expect(
      find.textContaining('Could not update this food pack'),
      findsOneWidget,
    );
    expect(repository.removed, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRegionalFoodRepository extends FoodRepository {
  _FakeRegionalFoodRepository(super.database, {Map<String, bool>? initial})
    : _loaded = {...?initial};

  final Map<String, bool> _loaded;
  final List<String> imported = [];
  final List<String> removed = [];
  bool failNextUpdate = false;

  @override
  Future<bool> isRegionalPackLoaded(String packId) async =>
      _loaded[packId] ?? false;

  @override
  Future<void> importRegionalPack({
    required String packId,
    required String assetPath,
  }) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw StateError('regional pack unavailable');
    }
    imported.add(packId);
    _loaded[packId] = true;
  }

  @override
  Future<void> removeRegionalPack(String packId) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw StateError('regional pack unavailable');
    }
    removed.add(packId);
    _loaded[packId] = false;
  }
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

class _FakeHealthService extends HealthService {
  @override
  Future<HealthDataSummary> fetchTodayHealthData() async =>
      const HealthDataSummary();
}
