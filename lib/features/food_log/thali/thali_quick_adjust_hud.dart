import 'package:flutter/material.dart';

import '../../../core/nutrition_thali.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/typed_quantities.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Docked quick adjustment heads-up-display (HUD) rendered when a dish
/// (katori or staple) is selected on the circular Thali plate.
class ThaliQuickAdjustHud extends StatelessWidget {
  final NutritionThaliItem item;
  final NutritionThaliItemPreview? preview;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onReplace;
  final VoidCallback onClose;

  const ThaliQuickAdjustHud({
    super.key,
    required this.item,
    this.preview,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onReplace,
    required this.onClose,
  });

  String _formatQuantity(Quantity quantity) {
    final amount = quantity.amount.toString();
    final unit = switch (quantity.unit) {
      QuantityUnit.gram => 'g',
      QuantityUnit.milligram => 'mg',
      QuantityUnit.kilogram => 'kg',
      QuantityUnit.millilitre => 'ml',
      QuantityUnit.litre => 'L',
      QuantityUnit.piece => 'pc',
      QuantityUnit.serving => 'srv',
      QuantityUnit.householdReference => item.measureId ?? 'measure',
      _ => quantity.unit.name,
    };
    return '$amount $unit';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final energy = preview?.calculation.facts['energy']?.point?.value.asDouble;
    final protein = preview?.calculation.facts['protein']?.point?.value.asDouble;
    final carbs = preview?.calculation.facts['carbohydrate']?.point?.value.asDouble;
    final fat = preview?.calculation.facts['fat']?.point?.value.asDouble;

    final energyStr = energy != null ? '${energy.round()} kcal' : '-- kcal';
    final pStr = protein != null ? '${(protein * 10).round() / 10}g' : '--';
    final cStr = carbs != null ? '${(carbs * 10).round() / 10}g' : '--';
    final fStr = fat != null ? '${(fat * 10).round() / 10}g' : '--';

    return Container(
      key: const Key('thali_quick_hud'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: B05Radii.largeRadius,
        border: Border.all(color: colors.action.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Dish name, calorie badge, and close button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.displayLabel ?? 'Dish',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          energyStr,
                          style: TextStyle(
                            color: colors.action,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'P: $pStr  C: $cStr  F: $fStr',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              B05TouchTarget(
                minWidth: B05Layout.minTouchTarget,
                minHeight: B05Layout.minTouchTarget,
                child: IconButton(
                  key: const Key('thali_quick_hud_close'),
                  icon: Icon(Icons.close_rounded, size: 20, color: colors.textDisabled),
                  onPressed: onClose,
                  tooltip: 'Deselect',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: colors.border.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 8),
          // Row 2: Quantity Controls (Decrement, Quantity text, Increment) & Action buttons
          Row(
            children: [
              // Stepper controls
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: B05Radii.largeRadius,
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    B05TouchTarget(
                      minWidth: B05Layout.minTouchTarget,
                      minHeight: B05Layout.minTouchTarget,
                      child: IconButton(
                        key: const Key('thali_quick_hud_decrement'),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        color: colors.textPrimary,
                        onPressed: onDecrement,
                        tooltip: 'Decrease portion',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _formatQuantity(item.quantity),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    B05TouchTarget(
                      minWidth: B05Layout.minTouchTarget,
                      minHeight: B05Layout.minTouchTarget,
                      child: IconButton(
                        key: const Key('thali_quick_hud_increment'),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        color: colors.textPrimary,
                        onPressed: onIncrement,
                        tooltip: 'Increase portion',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Replace button
              B05TouchTarget(
                minWidth: B05Layout.minTouchTarget,
                minHeight: B05Layout.minTouchTarget,
                child: IconButton(
                  key: const Key('thali_quick_hud_replace'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  color: colors.action,
                  onPressed: onReplace,
                  tooltip: 'Replace Dish',
                ),
              ),
              // Delete button
              B05TouchTarget(
                minWidth: B05Layout.minTouchTarget,
                minHeight: B05Layout.minTouchTarget,
                child: IconButton(
                  key: const Key('thali_quick_hud_remove'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.danger.foreground),
                  onPressed: onRemove,
                  tooltip: 'Remove Dish',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
