import 'package:flutter/material.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_thali.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import 'saved_meal_presentation.dart';
import 'saved_meals_controller.dart';

enum SavedMealDetailResult { logged, updated, deleted }

/// The composition-first surface for one persisted Saved Meal.
///
/// Persistence and logging remain owned by the parent Saved Meals flow. The
/// callbacks keep this surface from growing a second logging or deletion
/// authority while still making the exact saved composition inspectable.
class SavedMealDetailScreen extends StatefulWidget {
  final SavedMealDisplayItem meal;
  final String mealType;
  final Future<bool> Function() onQuickLog;
  final Future<bool> Function() onReviewPortions;
  final Future<bool> Function() onEdit;
  final Future<bool> Function()? onDelete;

  const SavedMealDetailScreen({
    super.key,
    required this.meal,
    required this.mealType,
    required this.onQuickLog,
    required this.onReviewPortions,
    required this.onEdit,
    this.onDelete,
  });

  @override
  State<SavedMealDetailScreen> createState() => _SavedMealDetailScreenState();
}

class _SavedMealDetailScreenState extends State<SavedMealDetailScreen> {
  var _isBusy = false;

  Future<void> _runAction(
    Future<bool> Function() action,
    SavedMealDetailResult result,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final completed = await action();
    if (!mounted) return;
    if (completed) {
      Navigator.pop(context, result);
      return;
    }
    setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final colors = context.b05Colors;
    final logEnabled = meal.isLoggable && !_isBusy;
    final targetMeal = _titleCase(widget.mealType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved meal'),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          if (widget.onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Saved meal actions',
              enabled: !_isBusy,
              onSelected: (value) {
                if (value == 'edit') {
                  _runAction(widget.onEdit, SavedMealDetailResult.updated);
                } else if (value == 'delete') {
                  _confirmDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit saved meal')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                label: '${meal.draft.name}, saved meal',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.draft.name,
                      style: B05Typography.pageTitle(context),
                    ),
                    if (meal.draft.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        meal.draft.description!,
                        style: B05Typography.body(context),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${meal.itemCount} ${meal.itemCount == 1 ? 'item' : 'items'} · Reusable meal',
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildNutritionSummary(context),
              if (meal.unavailableMessage != null) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.error_outline_rounded,
                  colors: colors.danger,
                  message: meal.unavailableMessage!,
                ),
              ] else if (meal.hasPartialNutrition) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.info_outline_rounded,
                  colors: colors.warning,
                  message: meal.requiresPartialAcknowledgement
                      ? 'Some core nutrition is incomplete. Review it before logging.'
                      : 'Some nutrition details are incomplete; unknown values stay unknown.',
                ),
              ],
              const SizedBox(height: 20),
              Text('Composition', style: B05Typography.title(context)),
              const SizedBox(height: 4),
              Text(
                'These are the foods and recipes that will be logged together. Quantities stay in their saved units.',
                style: B05Typography.body(context),
              ),
              const SizedBox(height: 10),
              _buildComposition(context),
              const SizedBox(height: 20),
              Text(
                'Log destination: $targetMeal',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack =
                      constraints.maxWidth < B05Layout.compactBreakpoint ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.25;
                  final review = OutlinedButton(
                    onPressed: logEnabled
                        ? () => _runAction(
                            widget.onReviewPortions,
                            SavedMealDetailResult.logged,
                          )
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, B05Layout.minTouchTarget),
                      foregroundColor: colors.action,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: B05Radii.mediumRadius,
                      ),
                    ),
                    child: const Text('REVIEW PORTIONS'),
                  );
                  final log = FilledButton(
                    onPressed: logEnabled
                        ? () => _runAction(
                            widget.onQuickLog,
                            SavedMealDetailResult.logged,
                          )
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, B05Layout.minTouchTarget),
                      backgroundColor: colors.action,
                      foregroundColor: colors.onAction,
                      shape: RoundedRectangleBorder(
                        borderRadius: B05Radii.mediumRadius,
                      ),
                    ),
                    child: _isBusy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onAction,
                            ),
                          )
                        : Text(
                            meal.requiresPartialAcknowledgement
                                ? 'REVIEW & LOG'
                                : 'LOG TO ${widget.mealType.toUpperCase()}',
                          ),
                  );
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [review, const SizedBox(height: 8), log],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: review),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: log),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (_isBusy || widget.onDelete == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${widget.meal.draft.name}"?'),
        content: const Text(
          'This removes the saved meal. Past diary entries stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runAction(widget.onDelete!, SavedMealDetailResult.deleted);
    }
  }

  Widget _buildNutritionSummary(BuildContext context) {
    final meal = widget.meal;
    final preview = meal.preview;
    final values = <String, String>{
      'Energy': preview == null
          ? _numberOrUnknown(meal.estimatedCalories, 'kcal', 0)
          : _factLabel(preview.aggregate.facts['energy'], 'kcal', 0),
      'Protein': preview == null
          ? _numberOrUnknown(meal.estimatedProteinG, 'g', 1)
          : _factLabel(preview.aggregate.facts['protein'], 'g', 1),
      'Carbs': preview == null
          ? 'Unknown'
          : _factLabel(preview.aggregate.facts['carbohydrate'], 'g', 1),
      'Fat': preview == null
          ? 'Unknown'
          : _factLabel(preview.aggregate.facts['fat'], 'g', 1),
    };
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.all(12),
      child: Semantics(
        container: true,
        label: values.entries
            .map((entry) => '${entry.key} ${entry.value}')
            .join(', '),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meal nutrition', style: B05Typography.label(context)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: values.entries
                  .map(
                    (entry) =>
                        _NutritionMetric(label: entry.key, value: entry.value),
                  )
                  .toList(growable: false),
            ),
            if (meal.hasPartialNutrition ||
                meal.unavailableMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Unknown nutrition is shown as unknown, not zero.',
                style: B05Typography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposition(BuildContext context) {
    final items = widget.meal.draft.items;
    if (items.isEmpty) {
      return B05Surface(
        tone: B05SurfaceTone.inset,
        padding: const EdgeInsets.all(16),
        child: Text(
          'This saved meal has no components yet.',
          style: B05Typography.body(context),
        ),
      );
    }
    return B05Surface(
      tone: B05SurfaceTone.section,
      padding: EdgeInsets.zero,
      showBorder: true,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _CompositionRow(item: items[index]),
            if (index < items.length - 1)
              Divider(height: 1, color: context.b05Colors.border),
          ],
        ],
      ),
    );
  }

  static String _numberOrUnknown(double? value, String unit, int precision) {
    if (value == null || !value.isFinite) return 'Unknown';
    final formatted = precision == 0
        ? value.round().toString()
        : value.toStringAsFixed(precision);
    return '$formatted $unit';
  }

  static String _factLabel(
    NutrientFact? fact,
    String fallbackUnit,
    int precision,
  ) {
    if (fact == null || !fact.isAvailable) return 'Unknown';
    final unit = fact.unit.symbol;
    final point = fact.point;
    if (point != null) {
      return '${point.value.format(decimalPlaces: precision)} $unit';
    }
    final lower = fact.lower?.value.format(decimalPlaces: precision);
    final upper = fact.upper?.value.format(decimalPlaces: precision);
    if (lower != null || upper != null) {
      return '${lower ?? '—'}–${upper ?? '—'} $unit';
    }
    return 'Unknown $fallbackUnit';
  }

  static String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Meal';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }
}

class _NutritionMetric extends StatelessWidget {
  final String label;
  final String value;

  const _NutritionMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: B05Typography.caption(context)),
        const SizedBox(height: 2),
        Text(value, style: B05Typography.label(context)),
      ],
    ),
  );
}

class _CompositionRow extends StatelessWidget {
  final NutritionThaliItem item;

  const _CompositionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final label = savedMealItemSemanticsLabel(item);
    return Semantics(
      container: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.source == NutritionThaliItemSource.food
                  ? Icons.restaurant_rounded
                  : Icons.menu_book_rounded,
              size: 20,
              color: colors.action,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    savedMealItemDisplayName(item),
                    style: B05Typography.label(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    savedMealItemKindLabel(item),
                    style: B05Typography.caption(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                savedMealQuantityLabel(item),
                textAlign: TextAlign.end,
                style: B05Typography.label(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final B05ColorRole colors;
  final String message;

  const _Notice({
    required this.icon,
    required this.colors,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: colors.container,
      borderRadius: B05Radii.mediumRadius,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.indicator, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: B05Typography.body(context))),
      ],
    ),
  );
}
