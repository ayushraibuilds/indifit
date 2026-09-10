import 'package:flutter/material.dart';

import '../../../core/nutrition_thali.dart';
import '../../../core/theme/colors.dart';

class ThaliNutritionSummaryBar extends StatelessWidget {
  final NutritionThaliPreview? preview;
  final bool isLoading;
  final bool hasItems;
  final VoidCallback onLogThali;
  final VoidCallback onSaveTemplate;

  const ThaliNutritionSummaryBar({
    super.key,
    this.preview,
    this.isLoading = false,
    required this.hasItems,
    required this.onLogThali,
    required this.onSaveTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final facts = preview?.aggregate.facts;
    final energy = facts?['energy']?.point?.value.asDouble;
    final protein = facts?['protein']?.point?.value.asDouble;
    final carbs = facts?['carbohydrate']?.point?.value.asDouble;
    final fat = facts?['fat']?.point?.value.asDouble;
    final fiber = facts?['fiber']?.point?.value.asDouble;

    final isPartial = preview?.isPartial ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPartial)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Some items have partial nutrient data',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Calories Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOTAL NUTRITION',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      key: const Key('thali_summary_calories'),
                      energy != null ? '${energy.round()} kcal' : '-- kcal',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Macros Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MacroBadge(
                    label: 'P',
                    value: protein != null
                        ? '${(protein * 10).round() / 10}g'
                        : '--',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _MacroBadge(
                    label: 'C',
                    value: carbs != null
                        ? '${(carbs * 10).round() / 10}g'
                        : '--',
                    color: AppColors.streakOrange,
                  ),
                  const SizedBox(width: 8),
                  _MacroBadge(
                    label: 'F',
                    value: fat != null ? '${(fat * 10).round() / 10}g' : '--',
                    color: AppColors.infoBlue,
                  ),
                  if (fiber != null) ...[
                    const SizedBox(width: 8),
                    _MacroBadge(
                      label: 'Fb',
                      value: '${(fiber * 10).round() / 10}g',
                      color: AppColors.fiberTeal,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('thali_save_template_button'),
                onPressed: hasItems && !isLoading ? onSaveTemplate : null,
                icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                label: const Text('Save Template'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('thali_log_meal_button'),
                  onPressed: hasItems && !isLoading ? onLogThali : null,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Text(
                    isLoading ? 'Logging...' : 'Log Thali',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.surface,
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
