import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/food_repository.dart';

final mealTemplatesProvider = FutureProvider.autoDispose<List<MealTemplateWithItems>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  return await repo.getMealTemplates();
});

class MealTemplatesScreen extends ConsumerStatefulWidget {
  final String? initialMealType;
  final String? mealType;
  final DateTime? targetDate;

  const MealTemplatesScreen({
    super.key,
    this.initialMealType,
    this.mealType,
    this.targetDate,
  });

  String? get resolvedMealType => initialMealType ?? mealType;

  @override
  ConsumerState<MealTemplatesScreen> createState() => _MealTemplatesScreenState();
}

class _MealTemplatesScreenState extends ConsumerState<MealTemplatesScreen> {
  bool _isLogging = false;

  Future<void> _handleLogTemplate(MealTemplateWithItems template) async {
    setState(() => _isLogging = true);
    final repo = ref.read(foodRepositoryProvider);
    final mealType = widget.resolvedMealType ?? template.template.defaultMealType;
    final date = widget.targetDate ?? DateTime.now();


    try {
      await repo.logMealTemplate(
        templateId: template.template.id,
        targetMealType: mealType,
        targetDate: date,
      );

      if (mounted) {
        setState(() => _isLogging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged "${template.template.name}" as $mealType!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLogging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log template: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteTemplate(int id) async {
    final repo = ref.read(foodRepositoryProvider);
    await repo.deleteMealTemplate(id);
    ref.invalidate(mealTemplatesProvider);
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    String mealType = widget.initialMealType ?? 'breakfast';

    // Sample item inputs
    final nameItemCtrl = TextEditingController(text: 'Roti / Rice');
    final calCtrl = TextEditingController(text: '200');
    final pCtrl = TextEditingController(text: '6');
    final cCtrl = TextEditingController(text: '40');
    final fCtrl = TextEditingController(text: '2');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Create Meal Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Template Name (e.g. Daily Lunch)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: mealType,
                  decoration: const InputDecoration(
                    labelText: 'Default Meal Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                    DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                    DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                    DropdownMenuItem(value: 'snack', child: Text('Snack')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => mealType = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text('First Item Quick Entry:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameItemCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name', isDense: true),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Calories', isDense: true), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: pCtrl, decoration: const InputDecoration(labelText: 'Protein (g)', isDense: true), keyboardType: TextInputType.number)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final repo = ref.read(foodRepositoryProvider);
                await repo.createMealTemplate(
                  name: nameController.text.trim(),
                  defaultMealType: mealType,
                  items: [
                    MealTemplateItemInput(
                      name: nameItemCtrl.text.trim(),
                      calories: int.tryParse(calCtrl.text) ?? 200,
                      proteinG: double.tryParse(pCtrl.text) ?? 6.0,
                      carbsG: double.tryParse(cCtrl.text) ?? 40.0,
                      fatG: double.tryParse(fCtrl.text) ?? 2.0,
                      servingLogged: 1.0,
                      servingUnit: 'katori',
                    ),
                  ],
                );
                ref.invalidate(mealTemplatesProvider);
                if (context.mounted) Navigator.pop(dlgCtx);
              },
              child: const Text('Save Template'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(mealTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meal Templates'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showCreateTemplateDialog,
          ),
        ],
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark_outline_rounded, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No Saved Meal Templates',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Save your usual breakfast, lunch, or thali combinations for 1-tap logging.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showCreateTemplateDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Meal Template'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = templates[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.template.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.template.defaultMealType.toUpperCase()} • ${item.totalCalories} kcal',
                                style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                            onPressed: () => _handleDeleteTemplate(item.template.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.items.map((it) => Chip(
                          label: Text('${it.name} (${it.calories} kcal)', style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isLogging ? null : () => _handleLogTemplate(item),
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: Text('Log ${item.template.name} (${item.totalCalories} kcal)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
