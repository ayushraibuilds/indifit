import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WaterNotifier Unit Tests', () {
    test('WaterState holds default water intake values', () {
      final state = WaterState(
        waterLogged: 4,
        waterGoal: 10,
        lastLoggedDate: '2026-07-20',
        glassSize: 250,
      );

      expect(state.waterLogged, 4);
      expect(state.waterGoal, 10);
      expect(state.glassSize, 250);
    });

    test('WaterNotifier logWater updates count', () async {
      final notifier = WaterNotifier();
      await notifier.loadState();
      await notifier.logWater(2);
      expect(notifier.state.waterLogged, 2);
    });
  });
}
