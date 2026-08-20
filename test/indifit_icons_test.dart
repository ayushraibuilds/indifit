import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/indifit_icons.dart';

void main() {
  group('IndiFitIcons', () {
    test('exposes typed navigation pairs with complete selected states', () {
      const pairs = <IndiFitNavigationIconPair>[
        IndiFitIcons.today,
        IndiFitIcons.training,
        IndiFitIcons.food,
        IndiFitIcons.progress,
      ];

      expect(pairs, hasLength(4));
      for (final pair in pairs) {
        expect(pair.unselected, isA<IconData>());
        expect(pair.selected, isA<IconData>());
        expect(pair.unselected, isNot(pair.selected));
      }
    });

    test('navigation pairs preserve the current product icon treatment', () {
      expect(IndiFitIcons.today.unselected, Icons.today_outlined);
      expect(IndiFitIcons.today.selected, Icons.today_rounded);
      expect(IndiFitIcons.training.unselected, Icons.fitness_center_outlined);
      expect(IndiFitIcons.training.selected, Icons.fitness_center_rounded);
      expect(IndiFitIcons.food.unselected, Icons.restaurant_outlined);
      expect(IndiFitIcons.food.selected, Icons.restaurant_rounded);
      expect(IndiFitIcons.progress.unselected, Icons.auto_graph_outlined);
      expect(IndiFitIcons.progress.selected, Icons.auto_graph_rounded);
    });

    test('exposes only concrete typed Material concepts', () {
      const icons = <IconData>[
        IndiFitIcons.add,
        IndiFitIcons.edit,
        IndiFitIcons.delete,
        IndiFitIcons.search,
        IndiFitIcons.close,
        IndiFitIcons.back,
        IndiFitIcons.more,
        IndiFitIcons.settings,
        IndiFitIcons.workout,
        IndiFitIcons.exercise,
        IndiFitIcons.timer,
        IndiFitIcons.calendar,
        IndiFitIcons.history,
        IndiFitIcons.replace,
        IndiFitIcons.equipment,
        IndiFitIcons.plateCalculator,
        IndiFitIcons.meal,
        IndiFitIcons.calories,
        IndiFitIcons.hydration,
        IndiFitIcons.trend,
        IndiFitIcons.bodyWeight,
        IndiFitIcons.achievement,
      ];

      expect(icons, hasLength(22));
      for (final icon in icons) {
        expect(icon, isA<IconData>());
      }
    });

    test('keeps visually distinct concepts distinct where it matters', () {
      expect(IndiFitIcons.workout, isNot(IndiFitIcons.exercise));
      expect(IndiFitIcons.meal, isNot(IndiFitIcons.food.selected));
      expect(IndiFitIcons.calories, isNot(IndiFitIcons.hydration));
      expect(IndiFitIcons.trend, isNot(IndiFitIcons.bodyWeight));
      expect(IndiFitIcons.achievement, isNot(IndiFitIcons.trend));
    });

    test('keeps facade access statically typed', () {
      const IconData action = IndiFitIcons.add;
      const IndiFitNavigationIconPair navigation = IndiFitIcons.today;

      expect(action, isA<IconData>());
      expect(navigation, isA<IndiFitNavigationIconPair>());
    });
  });
}
