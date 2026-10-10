import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  testWidgets(
    'onboarding fields use form actions and keep the page CTA out of the keyboard area',
    (tester) async {
      final database = await _pumpOnboarding(tester);
      addTearDown(database.close);

      final name = _field('Name');
      final age = _field('Age');
      final height = _field('Height');
      final weight = _field('Current weight');
      expect(
        tester.widget<TextField>(_field('Name')).textInputAction,
        TextInputAction.next,
      );
      expect(
        tester.widget<TextField>(age).textInputAction,
        TextInputAction.next,
      );
      expect(
        tester.widget<TextField>(height).textInputAction,
        TextInputAction.next,
      );
      expect(
        tester.widget<TextField>(weight).textInputAction,
        TextInputAction.done,
      );

      await tester.tap(name);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus,
        same(_focusNode(tester, name)),
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(name);
      await tester.tap(name);
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      expect(find.bySemanticsLabel('Next Step'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(_focusNode(tester, age)));
      expect(find.text('A bit about you'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus,
        same(_focusNode(tester, height)),
      );
      expect(find.text('A bit about you'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus,
        same(_focusNode(tester, weight)),
      );
      expect(
        tester.getRect(weight).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height - 300),
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_focusedEditableFields(tester), isEmpty);

      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('Next Step'), findsOneWidget);
      expect(find.text('A bit about you'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the lower onboarding measurement stays reachable above a compact keyboard at 2x text',
    (tester) async {
      final database = await _pumpOnboarding(
        tester,
        size: const Size(320, 568),
        textScale: 2,
      );
      addTearDown(database.close);

      final age = _field('Age');
      final weight = _field('Current weight');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(age);
      await tester.tap(age);
      await tester.pump();

      const keyboardInset = 240.0;
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.getRect(age).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height - keyboardInset),
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(
        FocusManager.instance.primaryFocus,
        same(_focusNode(tester, weight)),
      );
      expect(
        tester.getRect(weight).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height - keyboardInset),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard Next never advances onboarding, but page CTA does', (
    tester,
  ) async {
    final database = await _pumpOnboarding(tester);
    addTearDown(database.close);

    final age = _field('Age');
    await tester.tap(age);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(find.text('A bit about you'), findsOneWidget);
    expect(find.text('What is your main goal?'), findsNothing);

    await _tapVisible(tester, 'Male');
    await _tapVisible(tester, 'Next Step');
    await tester.pumpAndSettle();
    expect(find.text('How do you move most days?'), findsOneWidget);
    expect(find.text('A bit about you'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid onboarding measurements remain validated and values survive back',
    (tester) async {
      final database = await _pumpOnboarding(tester);
      addTearDown(database.close);

      final name = _field('Name');
      final age = _field('Age');
      final height = _field('Height');
      final weight = _field('Current weight');
      await tester.enterText(name, 'Priya');
      await tester.enterText(age, '9');
      await tester.pump();
      expect(find.text('Enter age between 10 and 120.'), findsOneWidget);

      await tester.tap(find.text('Next Step'));
      await tester.pump();
      expect(find.text('A bit about you'), findsOneWidget);
      expect(find.text('What is your main goal?'), findsNothing);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pump();

      await tester.ensureVisible(age);
      await tester.enterText(age, '31');
      await tester.pump();
      await tester.ensureVisible(height);
      await tester.enterText(height, '165');
      await tester.pump();
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '62');
      await tester.pump();
      await _tapVisible(tester, 'Male');
      await _tapVisible(tester, 'Next Step');
      await tester.pumpAndSettle();
      final back = find.byTooltip('Back');
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(find.text('A bit about you'), findsOneWidget);
      expect(tester.widget<TextField>(name).controller!.text, 'Priya');
      expect(tester.widget<TextField>(age).controller!.text, '31');
      expect(tester.widget<TextField>(height).controller!.text, '165');
      expect(tester.widget<TextField>(weight).controller!.text, '62');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onboarding remains free of compact large-text overflow', (
    tester,
  ) async {
    final database = registerTestDatabaseScope().create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.reset();
    });

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      for (final scale in [1.0, 2.0]) {
        setIndiFitTestPreferences({});
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MediaQuery(
              data: MediaQueryData.fromView(
                tester.view,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: MaterialApp(theme: theme, home: const OnboardingScreen()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('What is your main goal?'), findsOneWidget);
        expect(find.text('Skip for now'), findsOneWidget);
        expect(find.text('Next Step'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'steppers, rulers and height converter adjust inputs accurately',
    (tester) async {
      final database = await _pumpOnboarding(tester);
      addTearDown(database.close);

      final ageField = _field('Age');
      final weightField = _field('Current weight');

      // Default age is 25
      expect(tester.widget<TextField>(ageField).controller!.text, '25');
      // Tap increase age stepper
      await tester.tap(find.bySemanticsLabel('Increase Age'));
      await tester.pump();
      expect(tester.widget<TextField>(ageField).controller!.text, '26');

      // Tap decrease age stepper
      await tester.tap(find.bySemanticsLabel('Decrease Age'));
      await tester.pump();
      expect(tester.widget<TextField>(ageField).controller!.text, '25');

      // Default weight is 70
      expect(tester.widget<TextField>(weightField).controller!.text, '70');
      // Weight moves on the ruler (V8): one step up is 0.5 kg.
      final semantics = tester.ensureSemantics();
      final weightRuler = find.byKey(
        const Key('onboarding_ruler_Current weight'),
      );
      await tester.ensureVisible(weightRuler);
      tester.semantics.performAction(
        find.semantics.byLabel('Current weight ruler'),
        SemanticsAction.increase,
      );
      await tester.pump();
      expect(tester.widget<TextField>(weightField).controller!.text, '70.5');
      semantics.dispose();

      // Toggle height to ft/in
      expect(find.text('ft/in'), findsOneWidget);
      await tester.tap(find.text('ft/in'));
      await tester.pumpAndSettle();

      // Now in ft/in mode, should show ft and in labels and cm toggle
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('ft'), findsOneWidget);
      expect(find.text('in'), findsOneWidget);

      // Toggle back to cm
      await tester.tap(find.text('cm'));
      await tester.pumpAndSettle();
      expect(find.text('ft/in'), findsOneWidget);
    },
  );
}

Finder _field(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

FocusNode _focusNode(WidgetTester tester, Finder field) {
  return tester.widget<TextField>(field).focusNode!;
}

Iterable<Element> _focusedEditableFields(WidgetTester tester) {
  return find.byType(EditableText).evaluate().where((element) {
    return Focus.maybeOf(element)?.hasPrimaryFocus ?? false;
  });
}

Future<AppDatabase> _pumpOnboarding(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  setIndiFitTestPreferences({});
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final database = registerTestDatabaseScope().create();
  final app = MaterialApp(
    theme: AppTheme.lightTheme,
    home: const OnboardingScreen(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MediaQuery.fromView(
        view: tester.view,
        child: Builder(
          builder: (context) {
            final mediaQueryData = MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale));
            return MediaQuery(data: mediaQueryData, child: app);
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
  // The goal comes first; these tests cover the body fields after it.
  await tester.tap(find.text('Next Step'));
  await tester.pumpAndSettle();
  return database;
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
