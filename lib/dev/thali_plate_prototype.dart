// Prototype for the steel thali (PREMIUM_REDESIGN_PLAN § 6.1). Not part of
// the app: run it on its own with
//   flutter run -t lib/dev/thali_plate_prototype.dart
// Sample dishes are fixed examples, not real logs.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/b05_semantic_colors.dart';
import '../core/widgets/b05_accessibility_primitives.dart';
import '../features/food_log/thali/steel_thali_art.dart';
import '../features/food_log/thali/thali_plate_layout.dart';

void main() => runApp(const _PrototypeApp());

class _PrototypeApp extends StatefulWidget {
  const _PrototypeApp();

  @override
  State<_PrototypeApp> createState() => _PrototypeAppState();
}

class _PrototypeAppState extends State<_PrototypeApp> {
  var _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: _PrototypePages(
        dark: _dark,
        onToggle: () => setState(() => _dark = !_dark),
      ),
    );
  }
}

typedef _Dish = ({ThaliDishCategory? category, double fill, int kcal});

class _Scenario {
  const _Scenario({
    required this.title,
    required this.centre,
    required this.dishes,
    required this.split,
    this.overflow = 0,
    this.width,
  });

  final String title;
  final List<({bool rice, int pieces, int kcal})> centre;
  final List<_Dish> dishes;
  final ThaliMacroSplit split;
  final int overflow;
  final double? width;
}

final _classic = _Scenario(
  title: 'North Indian classic (example)',
  centre: const [
    (rice: false, pieces: 2, kcal: 240),
    (rice: true, pieces: 1, kcal: 205),
  ],
  dishes: const [
    (category: ThaliDishCategory.dal, fill: 1.0, kcal: 180),
    (category: ThaliDishCategory.sabzi, fill: 0.8, kcal: 120),
    (category: ThaliDishCategory.curry, fill: 1.0, kcal: 290),
    (category: ThaliDishCategory.curd, fill: 0.5, kcal: 60),
    (category: ThaliDishCategory.sweet, fill: 0.6, kcal: 150),
  ],
  split: ThaliMacroSplit.fromGrams(protein: 42, carbs: 160, fat: 38),
);

final _scenarios = [
  const _Scenario(
    title: 'Empty plate',
    centre: [],
    dishes: [],
    split: ThaliMacroSplit.none,
  ),
  _classic,
  _Scenario(
    title: '8 dishes (overflow)',
    centre: const [(rice: true, pieces: 1, kcal: 205)],
    dishes: const [
      (category: ThaliDishCategory.dal, fill: 1.0, kcal: 180),
      (category: ThaliDishCategory.sabzi, fill: 0.8, kcal: 120),
      (category: ThaliDishCategory.curry, fill: 1.0, kcal: 290),
      (category: ThaliDishCategory.curd, fill: 0.5, kcal: 60),
      (category: ThaliDishCategory.side, fill: 0.7, kcal: 40),
    ],
    overflow: 2,
    split: ThaliMacroSplit.fromGrams(protein: 38, carbs: 150, fat: 30),
  ),
  _Scenario(
    title: '320 pt wide (iPhone SE)',
    centre: _classic.centre,
    dishes: _classic.dishes,
    split: _classic.split,
    width: 320,
  ),
];

class _PrototypePages extends StatelessWidget {
  const _PrototypePages({required this.dark, required this.onToggle});

  final bool dark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return PageView(
      children: [
        for (final scenario in _scenarios)
          Scaffold(
            appBar: AppBar(
              title: Text(scenario.title),
              actions: [
                IconButton(
                  tooltip: 'Switch theme',
                  onPressed: onToggle,
                  icon: Icon(
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: scenario.width ?? double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: B05Surface(
                    tone: B05SurfaceTone.raised,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final diameter = math.min(
                          constraints.maxWidth - 32,
                          340.0,
                        );
                        return Align(
                          heightFactor: 1,
                          child: _PrototypePlate(
                            scenario: scenario,
                            diameter: diameter,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PrototypePlate extends StatelessWidget {
  const _PrototypePlate({required this.scenario, required this.diameter});

  final _Scenario scenario;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final tones = SteelTones.of(context);
    final colors = context.b05Colors;
    final katori = (diameter * 0.25).clamp(48.0, 76.0);
    final orbit = diameter * 0.32;
    final centre = diameter * 0.36;

    final slots = <Widget Function(double size)>[
      for (final dish in scenario.dishes)
        (size) => _Katori(tones: tones, dish: dish, size: size),
      if (scenario.overflow > 0)
        (size) => _EmptyBowl(
          tones: tones,
          size: size,
          child: Text(
            '+${scenario.overflow}',
            style: B05Typography.label(context),
          ),
        )
      else if (scenario.dishes.length < 6)
        (size) => _EmptyBowl(
          tones: tones,
          size: size,
          child: Icon(Icons.add_rounded, color: colors.action),
        ),
    ];

    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SteelPlatePainter(
                tones: tones,
                colors: colors,
                split: scenario.split,
              ),
            ),
          ),
          Positioned(
            left: (diameter - centre) / 2,
            top: (diameter - centre) / 2,
            width: centre,
            height: centre,
            child: _Centre(tones: tones, staples: scenario.centre),
          ),
          for (var i = 0; i < slots.length; i++)
            Positioned(
              left:
                  diameter / 2 +
                  orbit *
                      math.cos(-math.pi / 2 + i * 2 * math.pi / slots.length) -
                  katori / 2,
              top:
                  diameter / 2 +
                  orbit *
                      math.sin(-math.pi / 2 + i * 2 * math.pi / slots.length) -
                  katori / 2,
              width: katori,
              height: katori,
              child: slots[i](katori),
            ),
        ],
      ),
    );
  }
}

class _Katori extends StatelessWidget {
  const _Katori({required this.tones, required this.dish, required this.size});

  final SteelTones tones;
  final _Dish dish;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: SteelKatoriPainter(
              tones: tones,
              category: dish.category,
              fill: dish.fill,
            ),
          ),
        ),
        Positioned(
          bottom: size * 0.08,
          child: _KcalChip(kcal: dish.kcal),
        ),
      ],
    );
  }
}

class _EmptyBowl extends StatelessWidget {
  const _EmptyBowl({
    required this.tones,
    required this.size,
    required this.child,
  });

  final SteelTones tones;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: SteelKatoriPainter(tones: tones, category: null, fill: 0),
          ),
        ),
        child,
      ],
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.tones, required this.staples});

  final SteelTones tones;
  final List<({bool rice, int pieces, int kcal})> staples;

  @override
  Widget build(BuildContext context) {
    if (staples.isEmpty) return const SizedBox.shrink();
    Widget staple(({bool rice, int pieces, int kcal}) s) => Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: s.rice
                ? RiceMoundPainter(tones: tones)
                : RotiStackPainter(tones: tones, pieces: s.pieces),
          ),
        ),
        Positioned(bottom: 2, child: _KcalChip(kcal: s.kcal)),
      ],
    );
    if (staples.length == 1) return staple(staples.single);
    return Row(
      children: [
        for (final s in staples.take(2))
          Expanded(child: AspectRatio(aspectRatio: 1, child: staple(s))),
      ],
    );
  }
}

class _KcalChip extends StatelessWidget {
  const _KcalChip({required this.kcal});

  final int kcal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          '$kcal',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
