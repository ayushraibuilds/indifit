import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:indifit/core/widgets/confetti_overlay.dart';
import 'package:flutter/material.dart';

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

  group('Wave 6 — ConfettiOverlay Widget Tests', () {
    testWidgets('ConfettiOverlay renders child widget correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfettiOverlay(
              isPlaying: false,
              child: Text('Dashboard Content'),
            ),
          ),
        ),
      );

      expect(find.text('Dashboard Content'), findsOneWidget);
    });

    testWidgets('ConfettiOverlay responds when isPlaying becomes true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfettiOverlay(
              isPlaying: true,
              child: Text('Celebration Active'),
            ),
          ),
        ),
      );

      expect(find.text('Celebration Active'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
