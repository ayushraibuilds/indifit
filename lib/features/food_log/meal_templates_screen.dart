import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/repositories/food_repository.dart';

final mealTemplatesProvider =
    FutureProvider.autoDispose<List<MealTemplateWithItems>>((ref) async {
      final repo = ref.watch(foodRepositoryProvider);
      return await repo.getMealTemplates();
    });

class MealTemplatesScreen extends ConsumerStatefulWidget {
  final String? initialMealType;
  final String? mealType;
  final DateTime? targetDate;
  final bool legacyReadOnly;

  const MealTemplatesScreen({
    super.key,
    this.initialMealType,
    this.mealType,
    this.targetDate,
    this.legacyReadOnly = false,
  });

  String? get resolvedMealType => initialMealType ?? mealType;

  @override
  ConsumerState<MealTemplatesScreen> createState() =>
      _MealTemplatesScreenState();
}

class _MealTemplatesScreenState extends ConsumerState<MealTemplatesScreen> {
  bool _isLogging = false;

  Future<void> _handleLogTemplate(MealTemplateWithItems template) async {
    setState(() => _isLogging = true);
    final repo = ref.read(foodRepositoryProvider);
    final mealType =
        widget.resolvedMealType ?? template.template.defaultMealType;
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
            backgroundColor: context.b05Colors.success.indicator,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLogging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved meal could not be logged. Try again.'),
            backgroundColor: context.b05Colors.danger.indicator,
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
          title: const Text(
            'Create Saved Meal',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Saved Meal Name (e.g. Daily Lunch)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: mealType,
                  decoration: const InputDecoration(
                    labelText: 'Default Meal Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'breakfast',
                      child: Text('Breakfast'),
                    ),
                    DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                    DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                    DropdownMenuItem(value: 'snack', child: Text('Snack')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => mealType = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'First Item Quick Entry:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameItemCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: calCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Calories',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: pCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.b05Colors.action,
                foregroundColor: context.b05Colors.onAction,
              ),
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
              child: const Text('Save Saved Meal'),
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
        title: Text(
          widget.legacyReadOnly ? 'Older saved meals' : 'My saved meals',
        ),
        actions: widget.legacyReadOnly
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _showCreateTemplateDialog,
                ),
              ],
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            final colors = context.b05Colors;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_outline_rounded,
                      size: 64,
                      color: colors.textDisabled,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.legacyReadOnly
                          ? 'No older saved meals'
                          : 'No saved meals',
                      style: B05Typography.title(
                        context,
                      ).copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.legacyReadOnly
                          ? 'These older saved meals are read-only. New saved meals appear in Saved meals.'
                          : 'Save your usual breakfast, lunch, or meal combinations for 1-tap logging.',
                      textAlign: TextAlign.center,
                      style: B05Typography.caption(
                        context,
                      ).copyWith(fontSize: 13),
                    ),
                    if (!widget.legacyReadOnly) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showCreateTemplateDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create saved meal'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.action,
                          foregroundColor: colors.onAction,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = templates[index];
              final colors = context.b05Colors;
              return B05Surface(
                radius: B05SurfaceRadius.large,
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
                                style: B05Typography.title(
                                  context,
                                ).copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.template.defaultMealType.toUpperCase()} • ${item.totalCalories} kcal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.action,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (!widget.legacyReadOnly)
                            IconButton(
                              tooltip: 'Delete ${item.template.name}',
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: colors.danger.indicator,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _handleDeleteTemplate(item.template.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.items
                            .map(
                              (it) => Chip(
                                label: Text(
                                  '${it.name} (${it.calories} kcal)',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isLogging
                            ? null
                            : () => _handleLogTemplate(item),
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: Text(
                          'Log ${item.template.name} (${item.totalCalories} kcal)',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.action,
                          foregroundColor: colors.onAction,
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ConsumerStatusRow(label: 'Loading saved meals', loading: true),
        ),
        error: (_, _) => const Center(
          child: Text('Saved meals are unavailable. Try again later.'),
        ),
      ),
    );
  }
}
