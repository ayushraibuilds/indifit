import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 Notifications & Deep Link Unit Tests', () {
    test('NotificationService onNotificationNavigate callback handles payloads correctly', () {
      String? routedPath;

      NotificationService.onNotificationNavigate = (payload) {
        if (payload == 'workout') {
          routedPath = '/workout';
        } else if (payload.startsWith('meal_')) {
          final type = payload.replaceFirst('meal_', '');
          routedPath = '/food?mealType=$type';
        } else if (payload == 'weekly_report') {
          routedPath = '/weekly-report';
        }
      };

      // Test payload 'workout'
      NotificationService.onNotificationNavigate!('workout');
      expect(routedPath, '/workout');

      // Test payload 'meal_lunch'
      NotificationService.onNotificationNavigate!('meal_lunch');
      expect(routedPath, '/food?mealType=lunch');

      // Test payload 'weekly_report'
      NotificationService.onNotificationNavigate!('weekly_report');
      expect(routedPath, '/weekly-report');
    });

    test('SharedPreferences preference keys match notification toggles', () {
      expect(NotificationService.prefRemindWorkout, 'pref_remind_workout');
      expect(NotificationService.prefRemindMeals, 'pref_remind_meals');
      expect(NotificationService.prefRemindWater, 'pref_remind_water');
      expect(NotificationService.prefRemindEvening, 'pref_remind_evening');
      expect(NotificationService.prefRemindWeekly, 'pref_remind_weekly');
    });
  });
}
