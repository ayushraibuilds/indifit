import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/user_profile_provider.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2 Architecture & Persistence Tests', () {
    test('AppRouter config contains expected route paths', () {
      final container = ProviderContainer();
      final router = container.read(appRouterProvider);

      final routePaths = router.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(routePaths, contains('/'));
      expect(routePaths, contains('/onboarding'));
      expect(routePaths, contains('/workout'));
      expect(routePaths, contains('/food'));
      expect(routePaths, contains('/settings'));
      expect(routePaths, contains('/health-hub'));
      expect(routePaths, contains('/meal-planner'));
      expect(routePaths, contains('/achievements'));
      container.dispose();
    });

    test('Drift UserProfiles table supports CRUD and profile provider syncing', () async {
      final db = AppDatabase.memory();

      final notifier = UserProfileNotifier(db);

      expect(notifier.state.calorieGoal, 2000);

      await notifier.updateGoals(
        calorieGoal: 2400,
        proteinGoal: 160.0,
      );

      expect(notifier.state.calorieGoal, 2400);
      expect(notifier.state.proteinGoal, 160.0);

      final profiles = await db.select(db.userProfiles).get();
      expect(profiles.isNotEmpty, true);
      expect(profiles.first.calorieGoal, 2400);

      await db.close();
    });
  });
}
