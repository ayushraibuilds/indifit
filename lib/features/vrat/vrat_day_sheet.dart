import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import 'vrat_days.dart';

/// Marks or unmarks [day] as a vrat / festival day, or a range of days
/// (Navratri). [onChanged] runs after a change, e.g. to recount the streak.
Future<void> showVratDaySheet(
  BuildContext context, {
  required DateTime day,
  VoidCallback? onChanged,
}) => showIndiFitBottomSheet<void>(
  context: context,
  semanticLabel: 'Vrat / festival day',
  builder: (_) => VratDaySheet(day: day, onChanged: onChanged),
);

class VratDaySheet extends ConsumerWidget {
  const VratDaySheet({super.key, required this.day, this.onChanged});

  final DateTime day;
  final VoidCallback? onChanged;

  static const explainer =
      "A vrat day doesn't break your streak or add to it. Your targets stay "
      'the same, and search and the thali suggest vrat foods.';

  Future<void> _pickRange(
    BuildContext context,
    VratDaysController controller, {
    required bool mark,
  }) async {
    final navigator = Navigator.of(context);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(day.year + 1, day.month, day.day),
      initialDateRange: DateTimeRange(
        start: day,
        end: DateTime(day.year, day.month, day.day + 8),
      ),
      helpText: mark ? 'Mark vrat days' : 'Unmark vrat days',
    );
    if (range == null) return;
    await (mark
        ? controller.mark(range.start, range.end)
        : controller.unmark(range.start, range.end));
    onChanged?.call();
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final controller = ref.read(vratDaysProvider.notifier);
    final days = ref.watch(vratDaysProvider);
    final marked = days.contains(VratDays.civilDate(day));
    final label = DateFormat('EEEE d MMMM').format(day);

    Future<void> toggle() async {
      final navigator = Navigator.of(context);
      await (marked ? controller.unmark(day) : controller.mark(day));
      onChanged?.call();
      if (navigator.mounted) navigator.pop();
    }

    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('vrat-day-sheet'),
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space8,
          B05Layout.space16,
          B05Layout.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vrat / festival day', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space4),
            Text(
              explainer,
              style: B05Typography.body(
                context,
              ).copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: B05Layout.space8),
            ListTile(
              key: const ValueKey('vrat-toggle-day'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                marked ? Icons.event_busy_outlined : Icons.event_available,
              ),
              title: Text(
                marked ? 'Unmark $label' : 'Mark $label as a vrat day',
              ),
              onTap: () => unawaited(toggle()),
            ),
            ListTile(
              key: const ValueKey('vrat-mark-range'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('Mark several days, like Navratri'),
              onTap: () =>
                  unawaited(_pickRange(context, controller, mark: true)),
            ),
            if (days.isNotEmpty)
              ListTile(
                key: const ValueKey('vrat-unmark-range'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('Unmark several days'),
                onTap: () =>
                    unawaited(_pickRange(context, controller, mark: false)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "Vrat day" chip on Today for a marked day.
class VratDayChip extends StatelessWidget {
  const VratDayChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Semantics(
      button: onTap != null,
      label: 'Vrat day',
      hint: onTap == null ? null : 'Change vrat days',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.action.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa_outlined, size: 14, color: colors.action),
              const SizedBox(width: 4),
              Text(
                'Vrat day',
                style: B05Typography.caption(
                  context,
                ).copyWith(color: colors.action, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
