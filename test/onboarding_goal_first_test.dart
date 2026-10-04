import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/widgets/consumer_task_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MediaQuery.fromView(
        view: tester.view,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Map<String, Object> _v2Draft(int page) => {
  'onboarding_draft_page': page,
  'onboarding_draft_flow_version': 2,
  'onboarding_draft_sex': 'female',
  'onboarding_draft_age': '31',
  'onboarding_draft_height': '165',
  'onboarding_draft_weight': '62',
  'onboarding_draft_goal': 'gain',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the goal is the first question, then the body fields', (
    tester,
  ) async {
    await _pumpOnboarding(tester);

    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.text('What is your main goal?'), findsOneWidget);
    expect(find.text('A bit about you'), findsNothing);

    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.text('A bit about you'), findsOneWidget);

    // The About checks still apply on About: sex is required.
    await tester.tap(find.text('Next Step'));
    await tester.pump();
    expect(find.text('Choose an option above to continue.'), findsOneWidget);
    expect(find.text('A bit about you'), findsOneWidget);
  });

  testWidgets('a v2 draft saved on About resumes on About', (tester) async {
    await _pumpOnboarding(tester, prefs: _v2Draft(0));

    expect(find.text('A bit about you'), findsOneWidget);
    expect(find.text('2 of 5'), findsOneWidget);
  });

  testWidgets('a v2 draft saved on Goal resumes on Goal', (tester) async {
    await _pumpOnboarding(tester, prefs: _v2Draft(1));

    expect(find.text('What is your main goal?'), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
  });

  testWidgets('a v2 draft on Activity keeps its place', (tester) async {
    await _pumpOnboarding(tester, prefs: _v2Draft(2));

    expect(find.text('How do you move most days?'), findsOneWidget);
    expect(find.text('3 of 5'), findsOneWidget);
  });

  testWidgets('the keyboard opening on About keeps the About page', (
    tester,
  ) async {
    await _pumpOnboarding(tester);
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('A bit about you'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.text('A bit about you'), findsOneWidget);
    expect(find.text('What is your main goal?'), findsNothing);
  });

  testWidgets('ConsumerTaskScaffold keeps its body when the keyboard opens', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MediaQuery.fromView(
        view: tester.view,
        child: MaterialApp(
          home: ConsumerTaskScaffold(
            scrollable: false,
            hidePrimaryActionWhenKeyboardVisible: true,
            primaryAction: const Text('Continue'),
            body: PageView(
              controller: controller,
              children: const [Text('first'), Text('second')],
            ),
          ),
        ),
      ),
    );
    controller.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });
}
