import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/dashboard/dashboard_controller.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'support/indifit_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Refactored Controllers Unit Tests', () {
    setUp(() {
      setIndiFitTestPreferences({
        'water_goal': 10,
        'water_glass_size': 300,
        'current_weight': 72.0,
        'calorie_goal': 2200,
      });
    });

    test('SettingsController loads preferences accurately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(settingsControllerProvider.notifier);
      await controller.loadPreferences();

      final state = container.read(settingsControllerProvider);
      expect(state.waterGoal, 10);
      expect(state.glassSize, 300);
      expect(state.loading, false);
    });

    test('SettingsController updates offline mode and water goals', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(settingsControllerProvider.notifier);
      await controller.toggleOfflineOnly(true);
      expect(container.read(settingsControllerProvider).offlineOnly, true);
    });

    test(
      'DashboardController loads state and updates date selection',
      () async {
        final container = ProviderContainer(
          overrides: [
            dashboardControllerProvider.overrideWith(
              (ref) => DashboardController(ref, loadOnInit: false),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(dashboardControllerProvider.notifier);
        final newDate = DateTime(2026, 7, 21);
        controller.setSelectedDate(newDate);

        final state = container.read(dashboardControllerProvider);
        expect(state.selectedDate, newDate);
      },
    );

    test('DashboardController ignores a load started after disposal', () async {
      final container = ProviderContainer(
        overrides: [
          dashboardControllerProvider.overrideWith(
            (ref) => DashboardController(ref, loadOnInit: false),
          ),
        ],
      );
      final controller = container.read(dashboardControllerProvider.notifier);
      container.dispose();

      await expectLater(controller.loadStateData(), completes);
    });
  });
}
