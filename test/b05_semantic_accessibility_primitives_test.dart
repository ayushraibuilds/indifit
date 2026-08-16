import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {});

  group('B05 semantic colors', () {
    test('light and dark themes register all semantic state tokens', () {
      final light = AppTheme.lightTheme.extension<B05SemanticColors>();
      final dark = AppTheme.darkTheme.extension<B05SemanticColors>();

      expect(light, isNotNull);
      expect(dark, isNotNull);
      expect(light!.page, isNot(dark!.page));
      expect(light.status(B05SemanticStatus.success).foreground, isNotNull);
      expect(light.meal(B05MealAccent.breakfast).indicator, isNotNull);
      expect(light.media(B05MediaState.invalid).container, isNotNull);
      expect(dark.status(B05SemanticStatus.unavailable).indicator, isNotNull);
    });

    test(
      'semantic text and action tokens retain contrast and state distinction',
      () {
        for (final colors in [
          B05SemanticColors.light,
          B05SemanticColors.dark,
        ]) {
          expect(
            _contrast(colors.textPrimary, colors.page),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(colors.onAction, colors.action),
            greaterThanOrEqualTo(4.5),
          );
          expect(colors.success.indicator, isNot(colors.warning.indicator));
          expect(colors.warning.indicator, isNot(colors.danger.indicator));
          expect(
            colors.mediaAvailable.indicator,
            isNot(colors.mediaInvalid.indicator),
          );
        }
      },
    );

    test('the B05 radius scale is limited to 8, 10 and 12 pixels', () {
      expect(B05Radii.small, 8);
      expect(B05Radii.medium, 10);
      expect(B05Radii.large, 12);
    });

    testWidgets(
      'system theme resolves dark semantic tokens from platform brightness',
      (tester) async {
        late B05SemanticColors colors;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(platformBrightness: Brightness.dark),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.system,
              home: Builder(
                builder: (context) {
                  colors = context.b05Colors;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(colors.page, B05SemanticColors.dark.page);
      },
    );
  });

  group('B05 accessibility primitives', () {
    testWidgets('typography helpers resolve semantic text tokens', (
      tester,
    ) async {
      late TextStyle title;
      late TextStyle body;
      late TextStyle label;
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) {
              title = B05Typography.title(context);
              body = B05Typography.body(context);
              label = B05Typography.label(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(title.color, B05SemanticColors.light.textPrimary);
      expect(body.color, B05SemanticColors.light.textSecondary);
      expect(label.color, B05SemanticColors.light.textPrimary);
    });

    testWidgets('status includes a non-colour semantic state, value and hint', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _app(
            child: const B05StatusMessage(
              status: B05SemanticStatus.unavailable,
              label: 'Exercise media is unavailable',
              value: 'Still instructions are available',
              hint: 'Try again after media is installed',
            ),
          ),
        );

        expect(
          find.bySemanticsLabel('Unavailable: Exercise media is unavailable'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      'action buttons expose selected, disabled and semantic labels',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _app(
              child: const Column(
                children: [
                  B05ActionButton(
                    label: 'Save layout',
                    hint: 'Persists your dashboard order',
                    selected: true,
                    onPressed: _noOp,
                  ),
                  B05ActionButton(label: 'Unavailable action', onPressed: null),
                ],
              ),
            ),
          );

          expect(find.bySemanticsLabel('Save layout'), findsOneWidget);
          expect(find.bySemanticsLabel('Unavailable action'), findsOneWidget);
          expect(
            tester.getSemantics(find.bySemanticsLabel('Save layout')),
            matchesSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasSelectedState: true,
              isSelected: true,
              hasTapAction: true,
              label: 'Save layout',
              hint: 'Persists your dashboard order',
            ),
          );
          expect(
            tester.getSemantics(find.bySemanticsLabel('Unavailable action')),
            matchesSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasSelectedState: true,
            ),
          );
          expect(find.byType(FilledButton), findsNWidgets(2));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'actions reflow on compact screens and 2x text without clipping',
      (tester) async {
        await tester.pumpWidget(
          _app(
            mediaQuery: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: const SizedBox(
              width: 320,
              child: B05ActionGroup(
                children: [
                  B05ActionButton(
                    label: 'Open workout details',
                    onPressed: _noOp,
                  ),
                  B05ActionButton(
                    label: 'Choose another action',
                    emphasis: B05ActionEmphasis.secondary,
                    onPressed: _noOp,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Open workout details'), findsOneWidget);
        expect(find.text('Choose another action'), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('action primitives meet the shared minimum touch target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const Row(
            children: [
              B05ActionButton(label: 'Save', onPressed: _noOp),
              B05IconAction(
                icon: Icons.more_horiz,
                label: 'More actions',
                onPressed: _noOp,
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(B05TouchTarget).first).height,
        greaterThanOrEqualTo(B05Layout.minTouchTarget),
      );
      expect(
        tester.getSize(find.byType(B05TouchTarget).last).width,
        greaterThanOrEqualTo(B05Layout.minTouchTarget),
      );
    });

    testWidgets('focus traversal reaches ordered action controls by keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const B05ActionGroup(
            children: [
              B05ActionButton(
                label: 'Second in visual order',
                focusOrder: 2,
                onPressed: _noOp,
              ),
              B05ActionButton(
                label: 'First in keyboard order',
                focusOrder: 1,
                onPressed: _noOp,
              ),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final focusContext = FocusManager.instance.primaryFocus?.context;
      final order = focusContext
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      expect(order, isNotNull);
      expect((order!.order as NumericFocusOrder).order, 1);
      await tester.pump();
      final focusBorders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.border)
          .whereType<Border>()
          .map((border) => border.top.color);
      expect(focusBorders, contains(B05SemanticColors.light.focus));
    });

    testWidgets(
      'reduced motion uses a still alternative and disables autoplay',
      (tester) async {
        late bool allowsAutoplay;
        await tester.pumpWidget(
          _app(
            mediaQuery: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                allowsAutoplay = B05MotionPolicy.allowsAutoplay(context);
                return const B05MotionContent(
                  animatedChild: Text('Animated clip'),
                  reducedMotionChild: Text('Still form checklist'),
                );
              },
            ),
          ),
        );

        expect(allowsAutoplay, isFalse);
        expect(find.text('Still form checklist'), findsOneWidget);
        expect(find.text('Animated clip'), findsNothing);
        expect(find.byType(AnimatedSwitcher), findsNothing);
      },
    );
  });

  test('B05-owned production files do not directly use AppColors', () {
    final b05Files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              file.path.split(Platform.pathSeparator).last.startsWith('b05_'),
        );

    expect(b05Files, isNotEmpty);
    for (final file in b05Files) {
      expect(
        file.readAsStringSync(),
        isNot(contains('AppColors.')),
        reason: '${file.path} must use semantic tokens instead of AppColors.',
      );
    }
  });
}

Widget _app({required Widget child, MediaQueryData? mediaQuery}) {
  return MediaQuery(
    data: mediaQuery ?? const MediaQueryData(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void _noOp() {}
