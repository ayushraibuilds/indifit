import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/dashboard/widgets/today_header_widgets.dart';

/// PR-M (TP-5): Today keeps the daily chip, read as "days logged". Training
/// uses the weekly goal instead. T1: a 3D flame and the count in the header.
void main() {
  group('Today chip', () {
    Future<void> pumpChip(
      WidgetTester tester,
      int count, {
      bool loaded = true,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: TodayStreakChip(count: count, loaded: loaded),
          ),
        ),
      ),
    );

    testWidgets('reads "days logged", not a streak', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChip(tester, 4);
      expect(find.text('4'), findsOneWidget);
      expect(find.bySemanticsLabel('4 days logged in a row'), findsOneWidget);
      expect(find.textContaining('streak'), findsNothing);

      await pumpChip(tester, 1);
      expect(find.bySemanticsLabel('1 day logged in a row'), findsOneWidget);

      await pumpChip(tester, 0);
      expect(
        find.bySemanticsLabel('No days logged in a row yet'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('keeps one size for 1–2 digits and before it loads', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpChip(tester, 5, loaded: false);
      final hidden = tester.getSize(find.byType(TodayStreakChip));
      expect(find.bySemanticsLabel(RegExp('logged')), findsNothing);
      await pumpChip(tester, 5);
      expect(tester.getSize(find.byType(TodayStreakChip)), hidden);
      await pumpChip(tester, 12);
      expect(tester.getSize(find.byType(TodayStreakChip)), hidden);
      semantics.dispose();
    });
  });
}
