import 'package:flutter/material.dart';

import '../../../core/nutrition_thali.dart';
import '../../../core/theme/colors.dart';
import '../../../core/typed_quantities.dart';

class ThaliItemCard extends StatelessWidget {
  final NutritionThaliItem item;
  final NutritionThaliItemPreview? preview;
  final int index;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  const ThaliItemCard({
    super.key,
    required this.item,
    this.preview,
    required this.index,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
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
    final energyVal = preview?.calculation.facts['energy']?.point?.value.asDouble;
    final proteinVal = preview?.calculation.facts['protein']?.point?.value.asDouble;
    final carbsVal = preview?.calculation.facts['carbohydrate']?.point?.value.asDouble;
    final fatVal = preview?.calculation.facts['fat']?.point?.value.asDouble;

    final caloriesStr = energyVal != null ? '${energyVal.round()} kcal' : null;
    final macrosStr = (proteinVal != null && carbsVal != null && fatVal != null)
        ? 'P: ${(proteinVal * 10).round() / 10}g  C: ${(carbsVal * 10).round() / 10}g  F: ${(fatVal * 10).round() / 10}g'
        : null;

    return Container(
      key: Key('thali_item_${item.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.displayLabel ?? 'Meal Item',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatQuantity(item.quantity),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (caloriesStr != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          caloriesStr,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (macrosStr != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      macrosStr,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Portion steppers
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('thali_item_decrement_${item.id}'),
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  color: AppColors.textSecondary,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  onPressed: onDecrement,
                  tooltip: 'Decrease portion',
                ),
                IconButton(
                  key: Key('thali_item_increment_${item.id}'),
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  color: AppColors.primary,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  onPressed: onIncrement,
                  tooltip: 'Increase portion',
                ),
                IconButton(
                  key: Key('thali_item_delete_${item.id}'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.danger,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                  tooltip: 'Remove item',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
