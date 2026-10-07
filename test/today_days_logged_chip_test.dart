import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/dashboard/widgets/today_module_widgets.dart';

/// PR-M (TP-5): Today keeps the daily chip, labelled "days logged". Training
/// uses the weekly goal instead.
void main() {
  group('Today chip', () {
    Future<void> pumpChip(WidgetTester tester, int count) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(child: StreakChip(count: count)),
        ),
      ),
    );

    testWidgets('reads "days logged", not a streak', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChip(tester, 4);
      expect(find.text('4 days logged'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^4 days logged in a row')),
        findsOneWidget,
      );
      expect(find.textContaining('streak'), findsNothing);

      await pumpChip(tester, 1);
      expect(find.text('1 day logged'), findsOneWidget);
      semantics.dispose();
    });
  });
}
