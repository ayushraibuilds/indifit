import 'package:flutter/material.dart';

/// Reflows a group of related fields before labels or controls can overflow.
///
/// The breakpoint is intentionally a layout concern, not a screen-specific
/// width constant. Large text also stacks the group even on wider phones.
class IndiFitResponsiveFieldGroup extends StatelessWidget {
  const IndiFitResponsiveFieldGroup({
    required this.children,
    super.key,
    this.spacing = 12,
    this.breakpoint = 420,
    this.textScaleBreakpoint = 1.4,
  });

  final List<Widget> children;
  final double spacing;
  final double breakpoint;
  final double textScaleBreakpoint;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // AlertDialog measures its content intrinsically. A LayoutBuilder below
    // that boundary throws before the dialog can render, so use the usable
    // viewport width instead. The small inset allowance matches the common
    // screen and dialog padding used by this primitive's callers.
    final usableWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      0.0,
      double.infinity,
    );
    final shouldStack =
        usableWidth < breakpoint || textScale >= textScaleBreakpoint;
    if (shouldStack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index < children.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}
