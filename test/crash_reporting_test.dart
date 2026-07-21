import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indifit/core/services/crash_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashReportingService Privacy & Toggle Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        CrashReportingService.prefCrashReportingEnabled: true,
      });
    });

    test('CrashReportingService respects user preference toggle', () async {
      expect(CrashReportingService.isEnabled, isTrue);

      await CrashReportingService.setEnabled(false);
      expect(CrashReportingService.isEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(CrashReportingService.prefCrashReportingEnabled), isFalse);
    });

    test('CrashReportingService captures exception without throwing error', () {
      expect(
        () => CrashReportingService.captureException(
          FormatException('Test crash exception'),
          StackTrace.current,
          context: 'UnitTestContext',
        ),
        returnsNormally,
      );
    });
  });
}
