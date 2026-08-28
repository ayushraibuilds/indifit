import 'package:flutter/material.dart';

/// A typed pair for navigation destinations that have selected and
/// unselected Material treatments.
///
/// This class contains visual symbols only. The consuming button or
/// navigation widget remains responsible for its semantic label, tooltip,
/// and any visible text.
class IndiFitNavigationIconPair {
  const IndiFitNavigationIconPair({
    required this.unselected,
    required this.selected,
  });

  final IconData unselected;
  final IconData selected;
}

/// The small semantic icon vocabulary for new R08 foundation components.
///
/// This is deliberately a compile-time, Material-first facade. It is
/// forward-only: existing screens should keep their current icon choices
/// until their owning R08 wave explicitly migrates them.
///
/// Icons are visual symbols, not accessible names. Callers must continue to
/// provide semantic labels, tooltips, and visible text where appropriate.
abstract final class IndiFitIcons {
  // Navigation: Today / Training / Food / Progress.
  static const today = IndiFitNavigationIconPair(
    unselected: Icons.today_outlined,
    selected: Icons.today_rounded,
  );

  static const training = IndiFitNavigationIconPair(
    unselected: Icons.fitness_center_outlined,
    selected: Icons.fitness_center_rounded,
  );

  static const food = IndiFitNavigationIconPair(
    unselected: Icons.restaurant_outlined,
    selected: Icons.restaurant_rounded,
  );

  static const progress = IndiFitNavigationIconPair(
    unselected: Icons.trending_up_outlined,
    selected: Icons.trending_up_rounded,
  );

  // Common actions.
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData settings = Icons.settings_outlined;

  // Training.
  static const IconData workout = Icons.fitness_center_rounded;
  static const IconData exercise = Icons.directions_run_rounded;
  static const IconData timer = Icons.timer_outlined;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData replace = Icons.swap_horiz_rounded;
  static const IconData equipment = Icons.fitness_center_outlined;
  static const IconData plateCalculator = Icons.calculate_outlined;

  // Food concepts with a clear existing Material representation. Macro
  // nutrient-specific glyphs are intentionally deferred rather than using a
  // misleading generic symbol.
  static const IconData meal = Icons.restaurant_menu_rounded;
  static const IconData calories = Icons.local_fire_department_rounded;
  static const IconData hydration = Icons.water_drop_rounded;

  // Progress.
  static const IconData trend = Icons.trending_up_rounded;
  static const IconData bodyWeight = Icons.monitor_weight_outlined;
  static const IconData achievement = Icons.emoji_events_rounded;
}
