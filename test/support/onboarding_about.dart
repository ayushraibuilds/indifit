import 'package:flutter_test/flutter_test.dart';

/// The About step starts empty (UR-25): taps each "Use …" so the usual
/// 25 years, 170 cm and 70 kg are set, as someone accepting them would.
Future<void> useOnboardingAboutDefaults(WidgetTester tester) async {
  for (final label in const ['Use 25 years', 'Use 170 cm', 'Use 70 kg']) {
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) continue;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}
