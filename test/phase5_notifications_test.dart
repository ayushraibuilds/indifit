import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 Notifications & Deep Link Unit Tests', () {
    test(
      'NotificationService onNotificationNavigate callback handles payloads correctly',
      () {
        expect(
          NotificationService.destinationForPayload('workout'),
          '/training',
        );
        expect(
          NotificationService.destinationForPayload('meal_lunch'),
          '/food?mealType=lunch',
        );
        expect(
          NotificationService.destinationForPayload('weekly_report'),
          '/progress',
        );
        expect(NotificationService.destinationForPayload('unknown'), isNull);
      },
    );

    test('SharedPreferences preference keys match notification toggles', () {
      expect(NotificationService.prefRemindWorkout, 'pref_remind_workout');
      expect(NotificationService.prefRemindMeals, 'pref_remind_meals');
      expect(NotificationService.prefRemindWater, 'pref_remind_water');
      expect(NotificationService.prefRemindEvening, 'pref_remind_evening');
      expect(NotificationService.prefRemindWeekly, 'pref_remind_weekly');
    });
  });
}
