import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/onboarding/widgets/onboarding_ruler_picker.dart';
import 'package:indifit/features/onboarding/widgets/onboarding_target_reveal.dart';
import 'package:indifit/features/onboarding/widgets/onboarding_welcome.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => IndiFitHaptics.debugHandler = null);

  group('ruler picker', () {
    Widget ruler(
      TextEditingController controller, {
      List<String>? changes,
      double textScale = 1,
    }) => MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [B05SemanticColors.dark],
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OnboardingRulerPicker(
                controller: controller,
                label: 'Current weight',
                unit: 'kg',
                min: 25,
                max: 350,
                step: 0.5,
                majorEvery: 10,
                onChanged: (value) => changes?.add(value),
              ),
            ),
          ),
        ),
      ),
    );

    double painted(WidgetTester tester) => tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(OnboardingRulerPicker),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is OnboardingRulerPainter,
            ),
          ),
        )
        .painter
        .let((p) => (p! as OnboardingRulerPainter).value);

    testWidgets('dragging left raises the value one step per tick, '
        'with one selection haptic per step', (tester) async {
      final controller = TextEditingController(text: '70');
      addTearDown(controller.dispose);
      final changes = <String>[];
      final haptics = <IndiFitHapticType>[];
      IndiFitHaptics.debugHandler = haptics.add;
      await tester.pumpWidget(ruler(controller, changes: changes));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(OnboardingRulerPicker)),
      );
      // Past the touch slop, so the drag is accepted.
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      final afterSlop = double.parse(controller.text);
      expect(afterSlop, greaterThan(70));

      await gesture.moveBy(const Offset(-OnboardingRulerPicker.tickSpacing, 0));
      await tester.pump();
      expect(double.parse(controller.text), afterSlop + 0.5);

      await gesture.moveBy(
        const Offset(OnboardingRulerPicker.tickSpacing * 2, 0),
      );
      await tester.pump();
      expect(double.parse(controller.text), afterSlop - 0.5);
      await gesture.up();
      await tester.pump();

      expect(changes, isNotEmpty);
      expect(changes.last, controller.text);
      expect(haptics, hasLength(changes.length));
      expect(haptics.toSet(), {IndiFitHapticType.selection});
    });

    testWidgets('stays inside its range', (tester) async {
      final controller = TextEditingController(text: '349.5');
      addTearDown(controller.dispose);
      await tester.pumpWidget(ruler(controller));

      await tester.drag(
        find.byType(OnboardingRulerPicker),
        const Offset(-200, 0),
      );
      await tester.pump();
      expect(controller.text, '350');
    });

    testWidgets('follows typed values', (tester) async {
      final controller = TextEditingController(text: '70');
      addTearDown(controller.dispose);
      await tester.pumpWidget(ruler(controller));
      expect(painted(tester), 70);

      controller.text = '82.5';
      await tester.pump();
      expect(painted(tester), 82.5);
    });

    testWidgets('screen readers adjust it as a slider', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: '70');
      addTearDown(controller.dispose);
      await tester.pumpWidget(ruler(controller));

      final node = find.semantics.byLabel('Current weight ruler');
      expect(
        tester.getSemantics(
          find.byKey(const Key('onboarding_ruler_Current weight')),
        ),
        matchesSemantics(
          label: 'Current weight ruler',
          value: '70 kg',
          increasedValue: '70.5 kg',
          decreasedValue: '69.5 kg',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.performAction(node, SemanticsAction.decrease);
      await tester.pump();
      expect(controller.text, '69.5');
      semantics.dispose();
    });

    testWidgets('arrow keys step it once it has focus', (tester) async {
      final controller = TextEditingController(text: '70');
      addTearDown(controller.dispose);
      await tester.pumpWidget(ruler(controller));
      await tester.drag(find.byType(OnboardingRulerPicker), Offset.zero);
      Focus.of(
        tester.element(
          find.descendant(
            of: find.byType(OnboardingRulerPicker),
            matching: find.byType(GestureDetector),
          ),
        ),
      ).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.text, '70.5');
    });

    testWidgets('lays out at 320 pt and 2x text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: '70');
      addTearDown(controller.dispose);
      await tester.pumpWidget(ruler(controller, textScale: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('target reveal', () {
    Widget reveal({required bool animate, bool reduceMotion = false}) =>
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [B05SemanticColors.dark],
          ),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: OnboardingTargetReveal(
                    calories: 2150,
                    calorieRangeLabel: '2,050–2,250 kcal',
                    proteinG: 120,
                    carbsG: 250,
                    fatG: 70,
                    waterMl: 2500,
                    animate: animate,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('builds, then fills the ring and counts up to the target', (
      tester,
    ) async {
      await tester.pumpWidget(reveal(animate: true));
      expect(
        find.byKey(const Key('onboarding_target_building')),
        findsOneWidget,
      );
      expect(find.text('2,150'), findsNothing);

      await tester.pump(OnboardingTargetReveal.buildingDuration);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const Key('onboarding_target_building')), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('2,150'), findsOneWidget);
      expect(find.text('120 g'), findsOneWidget);
      expect(find.text('250 g'), findsOneWidget);
      expect(find.text('70 g'), findsOneWidget);
    });

    testWidgets('Reduce Motion shows the final target on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(reveal(animate: true, reduceMotion: true));
      expect(find.byKey(const Key('onboarding_target_building')), findsNothing);
      expect(find.text('2,150'), findsOneWidget);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a settled reveal does not animate', (tester) async {
      await tester.pumpWidget(reveal(animate: false));
      expect(find.text('2,150'), findsOneWidget);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('screen readers hear the final values at once', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(reveal(animate: true));
      expect(
        find.bySemanticsLabel(RegExp(r'^Starting daily target: 2150 kilo')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      semantics.dispose();
    });
  });

  group('onboarding step 5', () {
    late AppDatabase database;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase.memory();
    });

    Future<void> moveToReview(WidgetTester tester) async {
      Future<void> tap(String text) async {
        final finder = find.text(text);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap('Next Step');
      await tap('Male');
      await tap('Next Step');
      await tap('Next Step');
      await tap('Review setup');
    }

    testWidgets('has no Skip, plays the reveal once, and keeps the recap', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Skip for now'), findsOneWidget);

      await moveToReview(tester);
      expect(find.text('5 of 5'), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
      expect(find.byKey(const Key('onboarding_target_reveal')), findsOneWidget);
      expect(find.text('Personalized for you'), findsOneWidget);
      expect(find.text('Finish setup'), findsOneWidget);

      // Back to step 4 and forward again: the ring is already settled.
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Skip for now'), findsOneWidget);
      await tester.tap(find.text('Review setup'));
      await tester.pump();
      expect(find.byKey(const Key('onboarding_target_building')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    });
  });

  group('welcome', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase.memory());

    Future<void> pumpOnboarding(
      WidgetTester tester, {
      bool showWelcome = true,
      Map<String, Object> prefs = const {},
      bool reduceMotion = false,
      double width = 390,
      double textScale = 1,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: const [B05SemanticColors.dark],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: OnboardingScreen(showWelcome: showWelcome),
          ),
        ),
      );
      // The draft restore.
      await tester.pump();
      await tester.pump();
    }

    Future<void> tearDownApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    }

    IndiFitMarkPainter mark(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('onboarding_welcome_mark')),
                )
                .painter!
            as IndiFitMarkPainter;

    bool settled(IndiFitMarkPainter p) => [
      p.bottomBar,
      p.topBar,
      p.centreLeaf,
      p.leftLeaf,
      p.rightLeaf,
    ].every((v) => v == 1);

    testWidgets('a fresh setup opens on the welcome, the mark assembles, '
        'and Get started goes to step 1', (tester) async {
      await pumpOnboarding(tester);
      expect(find.byKey(const Key('onboarding_welcome')), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
      expect(find.text('1 of 5'), findsNothing);
      expect(mark(tester).leftLeaf, 0);

      await tester.pump(OnboardingWelcome.duration * 0.5);
      final mid = mark(tester);
      expect(mid.bottomBar, 1);
      expect(mid.rightLeaf, lessThan(1));

      await tester.pumpAndSettle();
      expect(settled(mark(tester)), isTrue);
      expect(find.bySemanticsLabel('IndiFit logo'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding_welcome')), findsNothing);
      expect(find.text('1 of 5'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });

    testWidgets('tapping the screen jumps to the end', (tester) async {
      await pumpOnboarding(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(settled(mark(tester)), isFalse);
      await tester.tap(find.byKey(const Key('onboarding_welcome_mark')));
      await tester.pump();
      expect(settled(mark(tester)), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
      await tearDownApp(tester);
    });

    testWidgets('Reduce Motion shows the finished mark on the first frame', (
      tester,
    ) async {
      await pumpOnboarding(tester, reduceMotion: true);
      expect(settled(mark(tester)), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.tap(find.text('Get started'));
      await tester.pump();
      expect(find.text('1 of 5'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('a restored draft goes straight back to its step', (
      tester,
    ) async {
      await pumpOnboarding(
        tester,
        prefs: {AppPreferenceKeys.onboardingDraftPage: 1},
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding_welcome')), findsNothing);
      expect(find.text('2 of 5'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('setup opened from elsewhere skips the welcome', (
      tester,
    ) async {
      await pumpOnboarding(tester, showWelcome: false);
      expect(find.byKey(const Key('onboarding_welcome')), findsNothing);
      expect(find.text('1 of 5'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('lays out at 320 pt and 2x text', (tester) async {
      await pumpOnboarding(tester, width: 320, textScale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Get started'), findsOneWidget);
      await tearDownApp(tester);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
