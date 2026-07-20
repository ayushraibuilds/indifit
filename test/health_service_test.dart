import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/repositories/health_service.dart';

void main() {
  group('HealthDataSummary Tests', () {
    test('default summary has zero metrics and disconnected status', () {
      const summary = HealthDataSummary();
      expect(summary.steps, 0);
      expect(summary.activeCalories, 0.0);
      expect(summary.sleepHours, 0.0);
      expect(summary.isConnected, false);
      expect(summary.statusMessage, isNull);
    });

    test('custom summary holds correct parameters', () {
      const summary = HealthDataSummary(
        steps: 8500,
        activeCalories: 450.5,
        sleepHours: 7.5,
        isConnected: true,
      );
      expect(summary.steps, 8500);
      expect(summary.activeCalories, 450.5);
      expect(summary.sleepHours, 7.5);
      expect(summary.isConnected, true);
    });

    test('HealthService writeWorkoutSession handles uninitialized health gracefully', () async {
      final service = HealthService();
      final success = await service.writeWorkoutSession(
        title: 'Chest & Triceps',
        durationMinutes: 45,
        caloriesBurned: 320,
        startTime: DateTime.now(),
      );
      expect(success, false);
    });

    test('HealthService writeBodyWeight handles uninitialized health gracefully', () async {
      final service = HealthService();
      final success = await service.writeBodyWeight(75.5);
      expect(success, false);
    });
  });
}
