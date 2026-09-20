import 'package:flutter/material.dart';

import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';

/// Range selector toggle between 7-Day Week and 28-Day 4-Week Block.
class PeriodComparisonSelector extends StatelessWidget {
  const PeriodComparisonSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
    this.inProgressText,
  });

  final PeriodComparisonRange selectedRange;
  final ValueChanged<PeriodComparisonRange> onRangeChanged;
  final String? inProgressText;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _RangeSegmentButton(
                label: 'This Week',
                sublabel: 'vs Last Week',
                isSelected: selectedRange == PeriodComparisonRange.week,
                onTap: () => onRangeChanged(PeriodComparisonRange.week),
              ),
            ),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: _RangeSegmentButton(
                label: 'Last 4 Weeks',
                sublabel: 'vs Prior 4 Weeks',
                isSelected: selectedRange == PeriodComparisonRange.fourWeeks,
                onTap: () => onRangeChanged(PeriodComparisonRange.fourWeeks),
              ),
            ),
          ],
        ),
        if (inProgressText != null) ...[
          const SizedBox(height: B05Layout.space4),
          Row(
            children: [
              Icon(
                Icons.timelapse_rounded,
                size: B05Layout.iconSmall,
                color: colors.textSecondary,
              ),
              const SizedBox(width: B05Layout.space4),
              Text(
                inProgressText!,
                style: B05Typography.caption(context).copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RangeSegmentButton extends StatelessWidget {
  const _RangeSegmentButton({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label $sublabel',
      child: Material(
        color: isSelected
            ? primary.withValues(alpha: 0.12)
            : colors.inset,
        shape: RoundedRectangleBorder(
          borderRadius: b05Radius(B05SurfaceRadius.medium),
          side: BorderSide(
            color: isSelected ? primary : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: b05Radius(B05SurfaceRadius.medium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: B05Layout.space8,
              horizontal: B05Layout.space8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: B05Typography.body(context).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? primary : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: B05Typography.caption(context).copyWith(
                    color: isSelected
                        ? primary.withValues(alpha: 0.85)
                        : colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
