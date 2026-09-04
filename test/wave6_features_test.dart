import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Wave 6 — CrashReportingService Security & Privacy Tests', () {
    test('CrashReportingService respects toggle state', () async {
      await CrashReportingService.setEnabled(false);
      expect(CrashReportingService.isEnabled, isFalse);

      await CrashReportingService.setEnabled(true);
      expect(CrashReportingService.isEnabled, isTrue);
    });

    test('CrashReportingService records exception without throwing', () {
      expect(
        () => CrashReportingService.captureException(
          Exception('Test Wave 6 Exception'),
          StackTrace.current,
          context: 'Wave6TestContext',
        ),
        returnsNormally,
      );
    });
  });
}
