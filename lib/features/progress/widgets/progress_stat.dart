import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// How large a [ProgressStat] reads. [hero] leads a section card; [compact]
/// sits in a tile or a column of three.
enum ProgressStatSize { hero, compact }

/// Which way a [ProgressStatDelta] points. Down is neutral, not a warning:
/// less volume or a lower weight is not bad on its own.
enum ProgressTrend { up, down, flat }

/// The one number style on Progress (V9): a tabular value, a smaller unit on
/// the same baseline, an optional change chip and a detail line.
///
/// The value and unit render as one [Text.rich], so the plain text stays
/// "70.0 kg" for screen readers and finders.
class ProgressStat extends StatelessWidget {
  const ProgressStat({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.detail,
    this.delta,
    this.size = ProgressStatSize.hero,
  });

  /// Splits "70.0 kg" or "3 training days" into a leading number and its
  /// unit. Text that does not start with a number stays whole.
  factory ProgressStat.split(
    String text, {
    Key? key,
    String? label,
    String? detail,
    ProgressStatDelta? delta,
    ProgressStatSize size = ProgressStatSize.hero,
  }) {
    final match = _leadingNumber.firstMatch(text);
    return ProgressStat(
      key: key,
      value: match?.group(1) ?? text,
      unit: match?.group(2),
      label: label,
      detail: detail,
      delta: delta,
      size: size,
    );
  }

  static final _leadingNumber = RegExp(r'^([+\-−]?[\d.,/]+)\s+(.+)$');

  final String value;
  final String? unit;
  final String? label;
  final String? detail;
  final ProgressStatDelta? delta;
  final ProgressStatSize size;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final hero = size == ProgressStatSize.hero;
    final valueStyle = hero
        ? B05Typography.metric(context)
        : B05Typography.number(
            context,
            size: 20,
          ).copyWith(fontWeight: FontWeight.w800);
    final unitStyle =
        (hero ? B05Typography.title(context) : B05Typography.label(context))
            .copyWith(color: colors.textSecondary, fontWeight: FontWeight.w600);
    final number = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value, style: valueStyle),
          if (unit != null) TextSpan(text: ' $unit', style: unitStyle),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: B05Typography.sectionLabel(context),
          ),
          const SizedBox(height: B05Layout.space4),
        ],
        if (delta == null)
          number
        else
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space4,
            children: [number, delta!],
          ),
        if (detail != null) ...[
          SizedBox(height: hero ? 2 : B05Layout.space4),
          Text(
            detail!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: hero
                ? B05Typography.body(context)
                : B05Typography.caption(context),
          ),
        ],
      ],
    );
  }
}

/// A small change chip: "+12%", "−0.4 kg", "Same". The sign carries the
/// direction; up is the success colour, down and flat stay neutral.
class ProgressStatDelta extends StatelessWidget {
  const ProgressStatDelta({
    super.key,
    required this.text,
    required this.trend,
    this.neutral = false,
  });

  final String text;
  final ProgressTrend trend;

  /// Keeps up neutral too, for a change that is good or bad depending on
  /// the goal (body weight).
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final (background, foreground) = switch (trend) {
      ProgressTrend.up when !neutral => (
        colors.success.container,
        colors.success.foreground,
      ),
      ProgressTrend.up || ProgressTrend.down => (
        colors.textSecondary.withValues(alpha: 0.12),
        colors.textPrimary,
      ),
      ProgressTrend.flat => (colors.inset, colors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: B05Typography.caption(context).copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
