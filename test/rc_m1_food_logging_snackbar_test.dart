import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/indi_fit_feedback.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  testWidgets('Undo feedback appears and auto-dismisses after its window', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showIndiFitUndoFeedback(
      context,
      message: 'Added Roti to breakfast',
      duration: const Duration(seconds: 4),
      onUndo: () {},
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Added Roti to breakfast'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.persist, isFalse);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('rapid Undo feedback replaces the prior operation', (
    tester,
  ) async {
    late BuildContext context;
    var firstUndoCount = 0;
    var secondUndoCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showIndiFitUndoFeedback(
      context,
      message: 'Added Dal to lunch',
      duration: const Duration(seconds: 4),
      onUndo: () => firstUndoCount++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    showIndiFitUndoFeedback(
      context,
      message: 'Added Paneer to lunch',
      duration: const Duration(seconds: 4),
      onUndo: () => secondUndoCount++,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Added Dal to lunch'), findsNothing);
    expect(find.text('Added Paneer to lunch'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(firstUndoCount, 0);
    expect(secondUndoCount, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('feedback remains readable with the search keyboard open', (
    tester,
  ) async {
    late BuildContext context;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (builderContext) {
              context = builderContext;
              return TextField(focusNode: focusNode);
            },
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    showIndiFitUndoFeedback(
      context,
      message: 'Added Poha to dinner',
      duration: const Duration(seconds: 4),
      onUndo: () {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Added Poha to dinner'), findsOneWidget);
    expect(focusNode.hasFocus, isTrue);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'feedback does not leak as a persistent snackbar after navigation',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (builderContext) {
                context = builderContext;
                return const Text('Food search');
              },
            ),
          ),
        ),
      );

      showIndiFitUndoFeedback(
        context,
        message: 'Added Chole to lunch',
        duration: const Duration(seconds: 4),
        onUndo: () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Added Chole to lunch'), findsOneWidget);

      final navigation = Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Unrelated screen')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unrelated screen'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsNothing);
      Navigator.of(context).pop();
      await navigation;
    },
  );
}
