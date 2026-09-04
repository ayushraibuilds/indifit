import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/settings/widgets/settings_reminder_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 8 Critical UI Widget Tests', () {

    testWidgets('SettingsReminderToggle responds to switch toggle', (
      WidgetTester tester,
    ) async {
      bool toggleValue = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: SettingsReminderToggle(
                  icon: Icons.alarm,
                  iconColor: Colors.blue,
                  title: 'Workout Reminder',
                  subtitle: 'Daily morning prompt',
                  value: toggleValue,
                  onChanged: (val) {
                    setState(() {
                      toggleValue = val;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Workout Reminder'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(toggleValue, true);
    });
  });
}
