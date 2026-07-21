import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wave 4 Quiet Hours Logic Tests', () {
    test('isInQuietHours evaluates overnight range correctly (22:00 to 07:00)', () {
      // 10 PM (22) to 7 AM (7)
      expect(NotificationService.isInQuietHours(23, 0, 22, 7), isTrue); // 11 PM -> inside
      expect(NotificationService.isInQuietHours(2, 30, 22, 7), isTrue); // 2:30 AM -> inside
      expect(NotificationService.isInQuietHours(6, 59, 22, 7), isTrue); // 6:59 AM -> inside
      expect(NotificationService.isInQuietHours(7, 0, 22, 7), isFalse); // 7:00 AM -> outside
      expect(NotificationService.isInQuietHours(12, 0, 22, 7), isFalse); // 12:00 PM -> outside
      expect(NotificationService.isInQuietHours(21, 59, 22, 7), isFalse); // 9:59 PM -> outside
    });

    test('isInQuietHours evaluates daytime range correctly (13:00 to 17:00)', () {
      // 1 PM (13) to 5 PM (17)
      expect(NotificationService.isInQuietHours(14, 0, 13, 17), isTrue);
      expect(NotificationService.isInQuietHours(12, 0, 13, 17), isFalse);
      expect(NotificationService.isInQuietHours(18, 0, 13, 17), isFalse);
    });
  });
}
