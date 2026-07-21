import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';

/// Browse saved multi-item meals and log them in one tap.
class MealTemplatesScreen extends ConsumerWidget {
  final String mealType;

  const MealTemplatesScreen({super.key, required this.mealType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(foodRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Meal Templates · ${mealType.toUpperCase()}'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: StreamBuilder<List<MealTemplate>>(
        stream: repo.watchMealTemplates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final templates = snapshot.data ?? const [];
          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border_rounded,
                        size: 48, color: AppColors.textMuted.withValues(alpha: 0.8)),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved meals yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Log a meal on the dashboard, then tap “Save as template” to reuse it later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplateCard(
                template: template,
                mealType: mealType,
              );
            },
          );
        },
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  final MealTemplate template;
  final String mealType;

  const _TemplateCard({
    required this.template,
    required this.mealType,
  });

  Future<void> _logTemplate(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(foodRepositoryProvider);
    await repo.logFromMealTemplate(
      templateId: template.id,
      mealType: mealType,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged “${template.name}” to $mealType'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete template?'),
        content: Text('Remove “${template.name}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(foodRepositoryProvider).deleteMealTemplate(template.id);
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: template.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Template name',
            hintText: 'e.g. Office lunch',
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
    if (newName != null && newName.isNotEmpty) {
      await ref.read(foodRepositoryProvider).renameMealTemplate(template.id, newName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(foodRepositoryProvider);

    return FutureBuilder<List<MealTemplateItem>>(
      future: repo.getMealTemplateItems(template.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <MealTemplateItem>[];
        final cals = items.fold<int>(0, (s, i) => s + i.calories);
        final protein = items.fold<double>(0, (s, i) => s + i.proteinG);

        return Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _logTemplate(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${items.length} item${items.length == 1 ? '' : 's'}'
                              ' · default ${template.defaultMealType}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'rename') _rename(context, ref);
                          if (value == 'delete') _confirmDelete(context, ref);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      items.map((i) => i.name).take(4).join(' · ') +
                          (items.length > 4 ? ' · …' : ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MacroChip(label: '$cals kcal', color: AppColors.primary),
                      const SizedBox(width: 8),
                      _MacroChip(
                        label: 'P ${protein.toStringAsFixed(0)}g',
                        color: AppColors.success,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _logTemplate(context, ref),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Log'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MacroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
