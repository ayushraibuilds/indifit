import 'package:flutter/material.dart';

import '../../../core/nutrition_consumption_snapshots.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// One food logged during this visit to search (UR-13).
class LoggedSearchItem {
  const LoggedSearchItem({required this.snapshot, required this.label});

  final NutritionConsumptionSnapshot snapshot;

  /// What was logged, as the confirmation said it: "1 katori Poha".
  final String label;

  /// The logged energy, rounded; null when the food has no energy value.
  int? get kcal {
    final energy = snapshot.totals.facts['energy']?.point?.value.asDouble;
    return energy?.round();
  }
}

/// "Lunch · 3 items · 540 kcal · Done" at the foot of search (UR-13).
/// Tapping the summary reviews the items, each with Undo; Done leaves.
class FoodSearchMealBar extends StatelessWidget {
  const FoodSearchMealBar({
    super.key,
    required this.mealLabel,
    required this.items,
    required this.onReview,
    required this.onDone,
  });

  final String mealLabel;
  final List<LoggedSearchItem> items;
  final VoidCallback onReview;
  final VoidCallback onDone;

  static String summary(String mealLabel, List<LoggedSearchItem> items) {
    final count = items.length;
    final kcal = items.fold<int>(0, (sum, item) => sum + (item.kcal ?? 0));
    return '$mealLabel · $count item${count == 1 ? '' : 's'} · $kcal kcal';
  }

  @override
  Widget build(BuildContext context) {
    final text = summary(mealLabel, items);
    return SafeArea(
      top: false,
      child: B05Surface(
        key: const ValueKey('food_search_meal_bar'),
        radius: B05SurfaceRadius.small,
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: '$text. Review what you added',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onReview,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: context.b05Colors.action,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            text,
                            style: B05Typography.label(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_less_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('food_search_meal_bar_done'),
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The items added this visit, each with Undo (UR-13).
Future<void> showLoggedSearchItems(
  BuildContext context, {
  required String mealLabel,
  required List<LoggedSearchItem> Function() items,
  required Future<void> Function(LoggedSearchItem item) onUndo,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => StatefulBuilder(
    builder: (sheetContext, setSheetState) {
      final current = items();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                FoodSearchMealBar.summary(mealLabel, current),
                style: B05Typography.title(sheetContext),
              ),
              const SizedBox(height: 8),
              if (current.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nothing added this time.',
                    style: B05Typography.body(sheetContext),
                  ),
                ),
              for (final item in current)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  subtitle: item.kcal == null
                      ? null
                      : Text('${item.kcal} kcal'),
                  trailing: TextButton(
                    key: ValueKey('meal_bar_undo_${item.snapshot.id}'),
                    onPressed: () async {
                      await onUndo(item);
                      setSheetState(() {});
                    },
                    child: const Text('Undo'),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  ),
);
