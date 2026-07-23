import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/food_repository.dart';
import '../../food_log/ai_meal_logger_screen.dart';
import '../../food_log/food_search_screen.dart';
import '../../food_log/meal_templates_screen.dart';
import '../../food_log/thali_builder_screen.dart';
import '../../food_log/widgets/edit_food_log_sheet.dart';
import '../dashboard_controller.dart';

class DashboardMealSection extends ConsumerWidget {
  final List<FoodLog> logs;
  final DateTime? selectedDate;

  const DashboardMealSection({
    super.key,
    required this.logs,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MEALS TODAY',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        _MealCard(title: 'Breakfast', type: 'breakfast', allLogs: logs, selectedDate: selectedDate ?? DateTime.now()),
        const SizedBox(height: 8),
        _MealCard(title: 'Lunch', type: 'lunch', allLogs: logs, selectedDate: selectedDate ?? DateTime.now()),
        const SizedBox(height: 8),
        _MealCard(title: 'Dinner', type: 'dinner', allLogs: logs, selectedDate: selectedDate ?? DateTime.now()),
        const SizedBox(height: 8),
        _MealCard(title: 'Snacks', type: 'snack', allLogs: logs, selectedDate: selectedDate ?? DateTime.now()),
      ],
    );
  }
}

class _MealCard extends ConsumerWidget {
  final String title;
  final String type;
  final List<FoodLog> allLogs;
  final DateTime selectedDate;

  const _MealCard({
    required this.title,
    required this.type,
    required this.allLogs,
    required this.selectedDate,
  });

  void _showAddMealSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log Food Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<FoodLog>>(
                future: ref.read(foodRepositoryProvider).getLastLoggedMeal(type),
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
                          if (context.mounted) {
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Re-logged recent $title items!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.history_toggle_off_rounded, size: 16),
                        label: Text('Repeat ${recent.length} recent item${recent.length > 1 ? 's' : ''}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
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
                leading: const Icon(Icons.search_rounded, color: AppColors.primary),
                title: const Text('Search Food Database', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Search common Indian items & scan barcodes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FoodSearchScreen(mealType: type)),
                  );
                },
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.bookmark_outline_rounded, color: AppColors.warning),
                title: const Text('Meal Templates', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('One-tap log your usual multi-item meals'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MealTemplatesScreen(mealType: type),
                    ),
                  );
                },
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded, color: AppColors.success),
                title: const Text('Thali Builder (Multi-item)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Compose a custom plate with running macros'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ThaliBuilderScreen(mealType: type)),
                  );
                },
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.psychology_rounded, color: AppColors.success),
                title: const Text('AI Meal Estimator', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Estimate calories & macros from photos or text'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AiMealLoggerScreen(mealType: type)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAsTemplate(BuildContext context, WidgetRef ref, List<FoodLog> mealLogs) async {
    final controller = TextEditingController(
      text: 'My $title',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Save as meal template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Template name',
            hintText: 'e.g. Office $title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await ref.read(foodRepositoryProvider).saveMealTemplate(
            name: name,
            defaultMealType: type,
            items: mealLogs,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved template “$name”'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save template: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _copyMeal(BuildContext context, WidgetRef ref, List<FoodLog> mealLogs) async {
    // Prefer group id when all items share one; otherwise save+log via synthetic group.
    final groupIds = mealLogs
        .map((l) => l.mealGroupId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    // 1. Pick target date
    final targetDate = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final today = DateTime.now();
        final tomorrow = today.add(const Duration(days: 1));
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Copy to target date…',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.today_rounded, color: AppColors.primary),
                title: const Text('Today'),
                onTap: () => Navigator.pop(ctx, today),
              ),
              ListTile(
                leading: const Icon(Icons.next_plan_rounded, color: AppColors.success),
                title: const Text('Tomorrow'),
                onTap: () => Navigator.pop(ctx, tomorrow),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary),
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
    final targetType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = <String, String>{
          'breakfast': 'Breakfast',
          'lunch': 'Lunch',
          'dinner': 'Dinner',
          'snack': 'Snacks',
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Copy to meal…',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ...options.entries.map(
                (e) => ListTile(
                  title: Text(e.value),
                  trailing: e.key == type && targetDate.day == DateTime.now().day
                      ? const Text('(same)', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
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
      await repo.logFromMealTemplate(templateId: tempId, mealType: targetType, loggedAt: targetDate);
      await repo.deleteMealTemplate(tempId);
    }

    if (!context.mounted) return;
    final dateStr = targetDate.day == DateTime.now().day
        ? 'Today'
        : targetDate.day == DateTime.now().add(const Duration(days: 1)).day
            ? 'Tomorrow'
            : '${targetDate.day}/${targetDate.month}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $title → $targetType ($dateStr)'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealLogs = allLogs.where((l) => l.mealType == type).toList();
    int totalCals = mealLogs.fold(0, (sum, item) => sum + item.calories);

    Color accentColor = AppColors.primary;
    IconData mealIcon = Icons.restaurant_rounded;
    if (type == 'breakfast') {
      accentColor = Colors.amber;
      mealIcon = Icons.wb_sunny_outlined;
    } else if (type == 'lunch') {
      accentColor = Colors.green;
      mealIcon = Icons.wb_twilight_rounded;
    } else if (type == 'dinner') {
      accentColor = Colors.indigoAccent;
      mealIcon = Icons.nightlight_round;
    } else if (type == 'snack') {
      accentColor = Colors.deepOrangeAccent;
      mealIcon = Icons.cookie_outlined;
    }

    return Card(
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(mealIcon, color: accentColor, size: 18),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('$totalCals kcal', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        subtitle: Text(
          mealLogs.isEmpty ? 'Tap plus to log item' : '${mealLogs.length} items logged',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: () => _showAddMealSheet(context, ref),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          if (mealLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                children: [
                  const Text('No food logged yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                              builder: (_) => MealTemplatesScreen(mealType: type),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bookmark_outline_rounded, size: 14),
                        label: const Text('Templates', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      FutureBuilder<List<FoodLog>>(
                        future: ref.read(foodRepositoryProvider).getLastLoggedMeal(type),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final lastMeal = snapshot.data!;
                            final cals = lastMeal.fold(0, (sum, item) => sum + item.calories);
                            return TextButton.icon(
                              onPressed: () async {
                                await ref.read(dashboardControllerProvider.notifier).repeatLastMeal(type, lastMeal);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Repeated last $type!')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.history_rounded, size: 14),
                              label: Text('Repeat Last ($cals kcal)', style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            const Divider(color: AppColors.border, height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveAsTemplate(context, ref, mealLogs),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: const Text('Save as template', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyMeal(context, ref, mealLogs),
                    icon: const Icon(Icons.copy_all_outlined, size: 16),
                    label: const Text('Copy meal', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LoggedItemRow extends ConsumerWidget {
  final FoodLog log;

  const _LoggedItemRow({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('food_log_${log.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 22),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Delete Entry?'),
            content: Text('Are you sure you want to remove "${log.name}" from your logged meal?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
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
                  Text(log.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(
                    '${log.servingLogged} logged • ${log.calories} kcal',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: EditFoodLogSheet(
                      log: log,
                      onSave: ({
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
