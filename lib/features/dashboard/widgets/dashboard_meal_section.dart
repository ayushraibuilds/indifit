import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrients.dart';
import '../../../core/nutrition_legacy_read_models.dart';
import '../../../core/presentation/consumer_copy.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../core/widgets/indi_fit_feedback.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/food_repository.dart';
import '../../food_log/canonical_food_delete.dart';
import '../../food_log/food_search_screen.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../../food_log/save_logged_meal_as_reusable_meal_helper.dart';
import '../../food_log/saved_meals_screen.dart';
import '../../food_log/saved_recipe_log_screen.dart';
import '../../food_log/thali_builder_screen.dart';
import '../../food_log/widgets/edit_food_log_sheet.dart';
import '../dashboard_controller.dart';

class DashboardMealSection extends ConsumerWidget {
  final List<FoodLog> logs;
  final DateTime? selectedDate;
  final NutritionDailyReadModel? unifiedDay;

  const DashboardMealSection({
    super.key,
    required this.logs,
    this.selectedDate,
    this.unifiedDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEALS TODAY',
          style: B05Typography.caption(context).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _MealCard(
          title: 'Breakfast',
          type: 'breakfast',
          allLogs: logs,
          selectedDate: selectedDate ?? DateTime.now(),
          unifiedDay: unifiedDay,
        ),
        const SizedBox(height: 8),
        _MealCard(
          title: 'Lunch',
          type: 'lunch',
          allLogs: logs,
          selectedDate: selectedDate ?? DateTime.now(),
          unifiedDay: unifiedDay,
        ),
        const SizedBox(height: 8),
        _MealCard(
          title: 'Dinner',
          type: 'dinner',
          allLogs: logs,
          selectedDate: selectedDate ?? DateTime.now(),
          unifiedDay: unifiedDay,
        ),
        const SizedBox(height: 8),
        _MealCard(
          title: 'Snacks',
          type: 'snack',
          allLogs: logs,
          selectedDate: selectedDate ?? DateTime.now(),
          unifiedDay: unifiedDay,
        ),
      ],
    );
  }
}

class _MealCard extends ConsumerWidget {
  final String title;
  final String type;
  final List<FoodLog> allLogs;
  final DateTime selectedDate;
  final NutritionDailyReadModel? unifiedDay;

  const _MealCard({
    required this.title,
    required this.type,
    required this.allLogs,
    required this.selectedDate,
    required this.unifiedDay,
  });

  void _showAddMealSheet(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    showIndiFitBottomSheet(
      context: context,
      semanticLabel: 'Log Food Item',
      builder: (sheetCtx) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 12.0,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ConsumerCopy.logFoodAction,
                style: B05Typography.title(sheetCtx).copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<FoodLog>>(
                future: ref
                    .read(foodRepositoryProvider)
                    .getLastLoggedMeal(type),
                builder: (context, snapshot) {
                  final recent = snapshot.data ?? [];
                  if (recent.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final repo = ref.read(foodRepositoryProvider);
                          for (final item in recent) {
                            await repo.logFoodEntry(
                              name: item.name,
                              calories: item.calories,
                              proteinG: item.proteinG,
                              carbsG: item.carbsG,
                              fatG: item.fatG,
                              servingLogged: item.servingLogged,
                              servingUnit: item.servingUnit,
                              mealType: type,
                              foodItemId: item.foodItemId,
                            );
                          }
                          await HapticFeedback.selectionClick();
                          if (context.mounted) {
                            Navigator.pop(sheetCtx);
                            showIndiFitSuccessFeedback(
                              context,
                              'Logged recent $title items',
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.history_toggle_off_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'Repeat ${recent.length} recent item${recent.length > 1 ? 's' : ''}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.action,
                          side: BorderSide(color: colors.action),
                          minimumSize: const Size.fromHeight(36),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.search_rounded,
                  color: colors.action,
                ),
                title: const Text(
                  'Search foods',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Search common Indian items & scan barcodes',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FoodSearchScreen(
                        mealType: type,
                        selectedDate: selectedDate,
                      ),
                    ),
                  );
                },
              ),
              Divider(color: colors.border),
              ListTile(
                leading: Icon(
                  Icons.bookmark_outline_rounded,
                  color: colors.warning.indicator,
                ),
                title: const Text(
                  'Saved meals',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('One-tap log your usual multi-item meals'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavedMealsScreen(
                        mealType: type,
                        selectedDate: selectedDate,
                      ),
                    ),
                  );
                },
              ),
              Divider(color: colors.border),
              ListTile(
                leading: Icon(
                  Icons.menu_book_rounded,
                  color: colors.action,
                ),
                title: const Text(
                  'Recipes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Add or create a prepared recipe with yield & servings',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavedRecipeLogScreen(
                        mealType: type,
                        selectedDate: selectedDate,
                      ),
                    ),
                  );
                },
              ),
              Divider(color: colors.border),
              ListTile(
                leading: Icon(
                  Icons.restaurant_menu_rounded,
                  color: colors.success.indicator,
                ),
                title: const Text(
                  'Build a meal',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Compose a custom meal with running nutrition',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ThaliBuilderScreen(mealType: type),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAsReusableMeal(
    BuildContext context,
    WidgetRef ref,
    List<NutritionHistoricalReadItem> snapshotItems, {
    required int legacyItemCount,
  }) async {
    await SaveLoggedMealHelper.saveLoggedMealAsReusable(
      context: context,
      ref: ref,
      mealCategory: type,
      snapshotItems: snapshotItems,
      legacyItemCount: legacyItemCount,
    );
  }

  Future<void> _copyMeal(
    BuildContext context,
    WidgetRef ref,
    List<FoodLog> mealLogs,
  ) async {
    // Prefer group id when all items share one; otherwise save+log via synthetic group.
    final groupIds = mealLogs
        .map((l) => l.mealGroupId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final colors = context.b05Colors;

    // 1. Pick target date
    final targetDate = await showIndiFitBottomSheet<DateTime>(
      context: context,
      semanticLabel: 'Copy to target date',
      builder: (ctx) {
        final today = DateTime.now();
        final tomorrow = today.add(const Duration(days: 1));
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Copy to target date…',
                    style: B05Typography.title(ctx).copyWith(fontSize: 16),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.today_rounded,
                  color: colors.action,
                ),
                title: const Text('Today'),
                onTap: () => Navigator.pop(ctx, today),
              ),
              ListTile(
                leading: Icon(
                  Icons.next_plan_rounded,
                  color: colors.success.indicator,
                ),
                title: const Text('Tomorrow'),
                onTap: () => Navigator.pop(ctx, tomorrow),
              ),
              ListTile(
                leading: Icon(
                  Icons.calendar_month_rounded,
                  color: colors.textSecondary,
                ),
                title: const Text('Pick custom date…'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: today,
                    firstDate: today.subtract(const Duration(days: 30)),
                    lastDate: today.add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    if (ctx.mounted) Navigator.pop(ctx, picked);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (targetDate == null) return;

    // 2. Pick target meal type
    if (!context.mounted) return;
    final targetType = await showIndiFitBottomSheet<String>(
      context: context,
      semanticLabel: 'Copy to meal',
      builder: (ctx) {
        final options = <String, String>{
          'breakfast': 'Breakfast',
          'lunch': 'Lunch',
          'dinner': 'Dinner',
          'snack': 'Snacks',
        };
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Copy to meal…',
                    style: B05Typography.title(ctx).copyWith(fontSize: 16),
                  ),
                ),
              ),
              ...options.entries.map(
                (e) => ListTile(
                  title: Text(e.value),
                  trailing:
                      e.key == type && targetDate.day == DateTime.now().day
                      ? Text(
                          '(same)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textDisabled,
                          ),
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, e.key),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (targetType == null) return;

    final repo = ref.read(foodRepositoryProvider);

    if (groupIds.length == 1) {
      await repo.copyMealGroup(
        groupId: groupIds.first,
        targetDate: targetDate,
        targetMealType: targetType,
      );
    } else {
      // Fallback: re-log each item as a fresh group under the target meal.
      final tempId = await repo.saveMealTemplate(
        name: '_copy_tmp_${targetDate.millisecondsSinceEpoch}',
        defaultMealType: targetType,
        items: mealLogs,
      );
      await repo.logFromMealTemplate(
        templateId: tempId,
        mealType: targetType,
        loggedAt: targetDate,
      );
      await repo.deleteMealTemplate(tempId);
    }

    if (!context.mounted) return;
    final dateStr = targetDate.day == DateTime.now().day
        ? 'Today'
        : targetDate.day == DateTime.now().add(const Duration(days: 1)).day
        ? 'Tomorrow'
        : '${targetDate.day}/${targetDate.month}';
    showIndiFitSuccessFeedback(
      context,
      'Copied $title → $targetType ($dateStr)',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealLogs = allLogs.where((l) => l.mealType == type).toList();
    final canonicalRecords = unifiedDay?.records
        .where((record) => !record.isLegacy && record.mealCategory == type)
        .toList(growable: false);
    final canonicalMealItems = <NutritionHistoricalReadItem>[
      for (final record in canonicalRecords ?? const []) ...record.items,
    ];
    var canonicalCalories = 0.0;
    var canonicalEnergyLower = 0.0;
    var canonicalEnergyUpper = 0.0;
    var canonicalEnergyUnknown = false;
    var canonicalEnergyRange = false;
    for (final record in canonicalRecords ?? const []) {
      final fact = record.totals.facts['energy'];
      if (fact == null || !fact.isAvailable) {
        canonicalEnergyUnknown = true;
        continue;
      }
      final lower = fact.lower?.value.asDouble ?? fact.point?.value.asDouble;
      final upper = fact.upper?.value.asDouble ?? fact.point?.value.asDouble;
      if (lower == null || upper == null) {
        canonicalEnergyUnknown = true;
        continue;
      }
      canonicalEnergyLower += lower;
      canonicalEnergyUpper += upper;
      canonicalCalories += fact.point?.value.asDouble ?? 0;
      canonicalEnergyRange = canonicalEnergyRange || lower != upper;
    }
    final totalCals =
        mealLogs.fold(0, (sum, item) => sum + item.calories) +
        canonicalCalories.round();
    final legacyCalories = mealLogs.fold(0, (sum, item) => sum + item.calories);
    final energyLabel = canonicalEnergyUnknown
        ? 'Calories not available'
        : canonicalEnergyRange
        ? '${(legacyCalories + canonicalEnergyLower).round()}–${(legacyCalories + canonicalEnergyUpper).round()} kcal'
        : '$totalCals kcal';

    final presentation = foodMealPresentationFor(type);
    final mealAccent = context.b05Colors.meal(
      presentation.accent ?? B05MealAccent.snack,
    );
    final accentColor = mealAccent.indicator;
    final containerColor = mealAccent.container;
    final mealIcon = presentation.icon;

    return Card(
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: containerColor,
            shape: BoxShape.circle,
          ),
          child: Icon(mealIcon, color: accentColor, size: 18),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              presentation.label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              energyLabel,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        subtitle: Text(
          mealLogs.isEmpty && (canonicalRecords?.isEmpty ?? true)
              ? 'Tap plus to log item'
              : '${mealLogs.length + (canonicalRecords?.length ?? 0)} items logged',
          style: B05Typography.caption(context).copyWith(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.add_circle_outline, color: context.b05Colors.action),
          onPressed: () => _showAddMealSheet(context, ref),
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        children: [
          if (mealLogs.isEmpty && (canonicalRecords?.isEmpty ?? true))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                children: [
                  Text(
                    'No food logged yet.',
                    style: TextStyle(color: context.b05Colors.textDisabled, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavedMealsScreen(mealType: type),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.bookmark_outline_rounded,
                          size: 14,
                        ),
                        label: const Text(
                          'Saved meals',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: context.b05Colors.warning.indicator,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      FutureBuilder<List<FoodLog>>(
                        future: ref
                            .read(foodRepositoryProvider)
                            .getLastLoggedMeal(type),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final lastMeal = snapshot.data!;
                            final cals = lastMeal.fold(
                              0,
                              (sum, item) => sum + item.calories,
                            );
                            return TextButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(dashboardControllerProvider.notifier)
                                    .repeatLastMeal(type, lastMeal);
                                if (context.mounted) {
                                  showIndiFitSuccessFeedback(
                                    context,
                                    'Repeated last $type!',
                                  );
                                }
                              },
                              icon: const Icon(Icons.history_rounded, size: 14),
                              label: Text(
                                'Repeat last ($cals kcal)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: context.b05Colors.action,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            ...mealLogs.map((log) => _LoggedItemRow(log: log)),
            ...?canonicalRecords?.expand((record) {
              final items = record.items
                  .where(
                    (candidate) =>
                        candidate.originSourceType == 'direct_food' &&
                        candidate.foodId != null,
                  )
                  .toList(growable: false);
              if (items.isEmpty) {
                return [_CanonicalItemRow(record: record)];
              }
              return items.map(
                (item) => _CanonicalItemRow(
                  record: record,
                  item: item,
                  onDelete: () => showCanonicalFoodItemDelete(
                    context: context,
                    ref: ref,
                    record: record,
                    item: item,
                  ),
                ),
              );
            }),
            Divider(color: context.b05Colors.border, height: 20),
            Row(
              children: [
                if (canonicalMealItems.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveAsReusableMeal(
                        context,
                        ref,
                        canonicalMealItems,
                        legacyItemCount: mealLogs.length,
                      ),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                      label: const Text(
                        'Save meal',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.b05Colors.action,
                        side: BorderSide(color: context.b05Colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyMeal(context, ref, mealLogs),
                    icon: const Icon(Icons.copy_all_outlined, size: 16),
                    label: const Text(
                      'Copy meal',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.b05Colors.textSecondary,
                      side: BorderSide(color: context.b05Colors.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            if (mealLogs.isNotEmpty && canonicalMealItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Older entries stay unchanged. Choose them again when creating a new saved meal.',
                  style: B05Typography.caption(context).copyWith(fontSize: 11),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CanonicalItemRow extends StatelessWidget {
  final NutritionHistoricalReadRecord record;
  final NutritionHistoricalReadItem? item;
  final Future<bool> Function()? onDelete;

  const _CanonicalItemRow({required this.record, this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final displayedItem = item ?? record.items.firstOrNull;
    final energy = item?.facts['energy'] ?? record.totals.facts['energy'];
    final isRecipe = displayedItem?.recipeVersionId != null;
    final quantity = displayedItem?.quantity.quantity;
    final amount = quantity == null
        ? null
        : '${quantity.amount} ${quantity.definition.displayLabel}';
    final energyText = energy?.point == null
        ? 'Calories not available'
        : '${energy!.point!.value.format(decimalPlaces: 0)} kcal';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.selected,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.action.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            isRecipe ? Icons.menu_book_rounded : Icons.restaurant_rounded,
            color: colors.action,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayedItem?.displayLabel ?? record.displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    isRecipe ? 'Saved recipe' : 'Food item',
                    ?amount,
                    energyText,
                  ].join(' • '),
                  style: B05Typography.caption(context).copyWith(fontSize: 11),
                ),
                if (record.completeness.state !=
                    NutrientCompletenessState.complete)
                  Text(
                    _completenessLabel(record.completeness.state),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.warning.indicator,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (onDelete == null)
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: colors.textDisabled,
            )
          else
            IconButton(
              tooltip:
                  'Delete ${displayedItem?.displayLabel ?? record.displayLabel}',
              visualDensity: VisualDensity.compact,
              onPressed: () => onDelete!(),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
            ),
        ],
      ),
    );
  }

  String _completenessLabel(NutrientCompletenessState state) => switch (state) {
    NutrientCompletenessState.partial => 'Some nutrition details unavailable',
    NutrientCompletenessState.unknown => 'Nutrition details unavailable',
    NutrientCompletenessState.notApplicable => 'Nutrition details not needed',
    NutrientCompletenessState.invalid => 'Nutrition details need review',
    NutrientCompletenessState.complete => 'Nutrition details complete',
  };
}

class _LoggedItemRow extends ConsumerWidget {
  final FoodLog log;

  const _LoggedItemRow({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    return Dismissible(
      key: ValueKey('food_log_${log.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.danger.container,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.delete_sweep_rounded,
          color: colors.danger.indicator,
          size: 22,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: dialogCtx.b05Colors.section,
            title: const Text('Delete food entry?'),
            content: Text('Remove "${log.name}" from this logged meal?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: dialogCtx.b05Colors.danger.container,
                  foregroundColor: dialogCtx.b05Colors.danger.foreground,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final repo = ref.read(foodRepositoryProvider);
        await repo.deleteLogEntry(log.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${log.servingLogged} logged • ${log.calories} kcal',
                    style: B05Typography.caption(context).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.action,
                    size: 18,
                  ),
                  tooltip: 'Edit entry',
                  onPressed: () {
                    showIndiFitBottomSheet(
                      context: context,
                      semanticLabel: 'Edit food log',
                      builder: (sheetCtx) => EditFoodLogSheet(
                        log: log,
                        onSave:
                            ({
                              required int id,
                              required String name,
                              required int calories,
                              required double proteinG,
                              required double carbsG,
                              required double fatG,
                              required double servingLogged,
                            }) async {
                              final repo = ref.read(foodRepositoryProvider);
                              await repo.updateFoodLog(
                                id: id,
                                name: name,
                                calories: calories,
                                proteinG: proteinG,
                                carbsG: carbsG,
                                fatG: fatG,
                                servingLogged: servingLogged,
                              );
                            },
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.danger.indicator,
                    size: 18,
                  ),
                  tooltip: 'Delete entry',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: dialogCtx.b05Colors.section,
                        title: const Text('Delete food entry?'),
                        content: Text(
                          'Remove "${log.name}" from this logged meal?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  dialogCtx.b05Colors.danger.container,
                              foregroundColor:
                                  dialogCtx.b05Colors.danger.foreground,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await HapticFeedback.mediumImpact();
                      final repo = ref.read(foodRepositoryProvider);
                      await repo.deleteLogEntry(log.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
