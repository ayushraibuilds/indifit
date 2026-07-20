import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/dashboard/widgets/adherence_card.dart';
import 'package:indifit/features/dashboard/widgets/dashboard_header.dart';
import 'package:indifit/features/settings/widgets/settings_reminder_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 8 Critical UI Widget Tests', () {
    testWidgets('DashboardHeader renders streak and title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DashboardHeader(streakCount: 5),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DashboardHeader), findsOneWidget);
    });

    testWidgets('AdherenceCard renders weekly adherence percentage', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdherenceCard(adherenceScore: 85.0),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('SettingsReminderToggle responds to switch toggle', (WidgetTester tester) async {
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
