import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/nutrients.dart';
import '../../../core/nutrition_legacy_read_models.dart';
import '../../../core/presentation/consumer_copy.dart';
import '../../../core/presentation/consumer_number_label.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/repositories/nutrition_target_authority.dart';
import '../../dashboard/today_consumer_presentation.dart';
import '../../dashboard/today_surface_controller.dart';
import '../food_log_surface.dart';
import '../food_search_screen.dart';
import '../meal_presentation_registry.dart';


/// Food diary widgets (PV1-ENG-05D first pass).
///
/// Extracted verbatim from `food_search_screen.dart`; unchanged.

class FoodMealDetailScreen extends ConsumerWidget {
  const FoodMealDetailScreen({
    super.key,
    required this.mealType,
    required this.selectedDate,
  });

  final String mealType;
  final DateTime selectedDate;

  DateTime get _day =>
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(foodDiaryReadModelProvider(_day));
    final records = diary.valueOrNull?.daily.records;
    final mealRecords = records
        ?.where((record) => foodDiaryMealType(record.mealCategory) == mealType)
        .toList(growable: false);
    final title = foodDiaryMealTitle(mealType);
    final total = mealRecords == null
        ? 'Loading meal total'
        : foodDiaryEnergyLabel(mealRecords);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            B05Surface(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: B05Typography.title(context)),
                        const SizedBox(height: 4),
                        Text(total, style: B05Typography.body(context)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => FoodSearchScreen(
                          mealType: mealType,
                          selectedDate: selectedDate,
                          returnToParentOnSave: true,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add food'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FoodLogEntriesPanel(
              date: selectedDate,
              mealType: mealType,
              onCanonicalItemTap: (record, item) =>
                  _openRecordActions(context, record, item),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecordActions(
    BuildContext context,
    NutritionHistoricalReadRecord record,
    NutritionHistoricalReadItem item,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          mealType: mealType,
          selectedDate: selectedDate,
          returnToParentOnSave: true,
          initialRecord: record,
          initialRecordItem: item,
        ),
      ),
    );
  }
}

class FoodDiaryPrimaryAddAction extends StatelessWidget {
  const FoodDiaryPrimaryAddAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Add food',
    hint: 'Choose a meal, then search or select food to log.',
    child: SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('food_diary_primary_add'),
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add food'),
      ),
    ),
  );
}

class FoodDiarySummary extends StatelessWidget {
  const FoodDiarySummary({super.key, 
    required this.presentation,
    required this.targetRead,
  });

  final TodayNutritionPresentation presentation;
  final TodayDomainRead<NutritionTargetsForDate?>? targetRead;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.unavailable) {
      return const SizedBox.shrink();
    }
    final calories = presentation.calories;
    final macros = presentation.macros
        .where((metric) => metric.nutrientId != 'fibre')
        .toList(growable: false);
    final hasTarget = calories?.hasTarget == true;
    final consumed = calories?.isAvailable == true
        ? '${calories!.value} ${calories.unit}'
        : '— kcal';
    final remaining = _remainingLabel(calories);
    final targetContext = _targetContextLabel(
      presentation: presentation,
      targetRead: targetRead,
      hasTarget: hasTarget,
    );
    return Semantics(
      container: true,
      label: 'Food diary nutrition summary',
      value: [
        'Consumed $consumed',
        if (remaining != null) 'Remaining $remaining',
        targetContext,
      ].join('. '),
      child: B05Surface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily nutrition', style: B05Typography.title(context)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: FoodDiarySummaryMetric(
                        label: 'Consumed',
                        value: consumed,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: FoodDiarySummaryMetric(
                        label: 'Remaining',
                        value: remaining ?? (hasTarget ? '—' : 'Not available'),
                        valueColor: remaining == null
                            ? null
                            : context.b05Colors.action,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            if (calories?.progress != null)
              LinearProgressIndicator(
                value: calories!.progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                color: context.b05Colors.action,
                backgroundColor: context.b05Colors.selected,
              )
            else if (presentation.state == TodayPresentationState.loading)
              const B05StatusMessage(
                status: B05SemanticStatus.info,
                label: 'Loading daily target',
              )
            else
              Text(targetContext, style: B05Typography.caption(context)),
            if (calories?.progress != null) ...[
              const SizedBox(height: 6),
              Text(targetContext, style: B05Typography.caption(context)),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final metric in macros)
                      SizedBox(
                        width: itemWidth,
                        child: FoodDiaryMetric(metric: metric),
                      ),
                  ],
                );
              },
            ),
            if (presentation.hasIncompleteNutrition) ...[
              const SizedBox(height: 8),
              Text(
                '${ConsumerCopy.nutritionDetailsIncomplete}; available values stay visible.',
                style: B05Typography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _remainingLabel(TodayNutritionMetricPresentation? calories) {
    if (calories?.hasTarget != true ||
        calories?.pointValue == null ||
        calories!.isRange) {
      return null;
    }
    final difference = calories.targetValue! - calories.pointValue!;
    if (difference >= 0) {
      return '${ConsumerNumberLabel.rounded(difference)} kcal';
    }
    return 'Over by ${ConsumerNumberLabel.rounded(-difference)} kcal';
  }

  String _targetContextLabel({
    required TodayNutritionPresentation presentation,
    required TodayDomainRead<NutritionTargetsForDate?>? targetRead,
    required bool hasTarget,
  }) {
    if (presentation.state == TodayPresentationState.loading) {
      return 'Daily target is loading.';
    }
    if (targetRead?.isAvailable == false) {
      return 'Daily target unavailable for this date.';
    }
    if (!hasTarget) return 'No daily target for this date.';
    return '${ConsumerNumberLabel.rounded(presentation.calories!.targetValue!)} kcal daily target.';
  }
}

class FoodDiarySummaryMetric extends StatelessWidget {
  const FoodDiarySummaryMetric({super.key, 
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: B05Typography.caption(context)),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: B05Typography.title(context).copyWith(color: valueColor),
      ),
    ],
  );
}

class FoodDiaryMetric extends StatelessWidget {
  const FoodDiaryMetric({super.key, required this.metric});

  final TodayNutritionMetricPresentation metric;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(metric.label, style: B05Typography.caption(context)),
      const SizedBox(height: 2),
      Text(
        '${metric.value} ${metric.unit}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: B05Typography.label(context),
      ),
    ],
  );
}

class FoodDiaryMealRow extends StatelessWidget {
  const FoodDiaryMealRow({super.key, 
    required this.type,
    required this.label,
    required this.records,
    required this.onOpen,
    required this.onAdd,
    this.isLoading = false,
  });

  final String type;
  final String label;
  final List<NutritionHistoricalReadRecord> records;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final accent = context.b05Colors.meal(
      foodMealPresentationFor(type).accent ?? B05MealAccent.snack,
    );
    final labels = records
        .expand((record) => record.items)
        .map((item) => item.displayLabel)
        .whereType<String>()
        .where((label) => label.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    final preview = isLoading
        ? 'Loading logged food'
        : records.isEmpty
        ? 'Nothing logged yet'
        : labels.isEmpty
        ? '${records.length} logged'
        : labels.join(' · ');
    return Semantics(
      container: true,
      button: true,
      label: '$label. ${foodDiaryEnergyLabel(records)}. $preview',
      hint: 'Open $label details or use the add button.',
      child: InkWell(
        onTap: onOpen,
        borderRadius: B05Radii.smallRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.container,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    foodMealPresentationFor(type).icon,
                    size: 18,
                    color: accent.indicator,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: B05Typography.label(context)),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              Text(
                foodDiaryEnergyLabel(records),
                style: B05Typography.caption(context).copyWith(
                  color: accent.indicator,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              B05IconAction(
                icon: Icons.add_circle_outline_rounded,
                label: 'Add $label',
                hint: 'Log food to $label.',
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FoodDiaryShortcut extends StatelessWidget {
  const FoodDiaryShortcut({super.key, 
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    hint: detail,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: context.b05Colors.action),
      title: Text(title, style: B05Typography.label(context)),
      subtitle: Text(detail, style: B05Typography.caption(context)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

String foodDiaryMealType(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'snacks' ? 'snack' : normalized;
}

String foodDiaryMealTitle(String value) {
  final normalized = foodDiaryMealType(value);
  final presentation = MealPresentationRegistry.forStableId(normalized);
  if (presentation.isKnown) {
    return presentation.label;
  }
  return switch (normalized) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'snack' => 'Snacks',
    _ => 'Meal',
  };
}

String foodDiaryEnergyLabel(Iterable<NutritionHistoricalReadRecord> records) {
  final facts = [for (final record in records) record.totals.facts['energy']];
  if (facts.isEmpty || facts.any((fact) => fact == null || !fact.isAvailable)) {
    return '— kcal';
  }
  final available = facts.cast<NutrientFact>();
  if (available.any((fact) => fact.point == null)) return '— kcal';
  final total = available.fold<double>(
    0,
    (sum, fact) => sum + fact.point!.value.asDouble,
  );
  return '${total.round()} kcal';
}
