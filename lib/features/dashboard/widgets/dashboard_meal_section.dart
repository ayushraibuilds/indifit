import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/food_repository.dart';
import '../../food_log/ai_meal_logger_screen.dart';
import '../../food_log/food_search_screen.dart';
import '../../food_log/widgets/edit_food_log_sheet.dart';
import '../dashboard_controller.dart';

class DashboardMealSection extends ConsumerWidget {
  final List<FoodLog> logs;

  const DashboardMealSection({super.key, required this.logs});

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
        _MealCard(title: 'Breakfast', type: 'breakfast', allLogs: logs),
        const SizedBox(height: 8),
        _MealCard(title: 'Lunch', type: 'lunch', allLogs: logs),
        const SizedBox(height: 8),
        _MealCard(title: 'Dinner', type: 'dinner', allLogs: logs),
        const SizedBox(height: 8),
        _MealCard(title: 'Snacks', type: 'snack', allLogs: logs),
      ],
    );
  }
}

class _MealCard extends ConsumerWidget {
  final String title;
  final String type;
  final List<FoodLog> allLogs;

  const _MealCard({
    required this.title,
    required this.type,
    required this.allLogs,
  });

  void _showAddMealSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
              const SizedBox(height: 16),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealLogs = allLogs.where((l) => l.mealType == type).toList();
    int totalCals = mealLogs.fold(0, (sum, item) => sum + item.calories);

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('$totalCals kcal', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        subtitle: Text(
          mealLogs.isEmpty ? 'Tap plus to log item' : '${mealLogs.length} items logged',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: () => _showAddMealSheet(context),
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
            )
          else
            ...mealLogs.map((log) => _LoggedItemRow(log: log)),
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
    return Padding(
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
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
            onPressed: () async {
              final repo = ref.read(foodRepositoryProvider);
              await repo.deleteLogEntry(log.id);
            },
          ),
        ],
      ),
    );
  }
}
