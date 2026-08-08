import 'package:flutter/material.dart';

import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

/// The shared opaque, keyboard-aware surface for product bottom sheets.
class IndiFitBottomSheet extends StatelessWidget {
  const IndiFitBottomSheet({
    required this.child,
    super.key,
    this.maxHeightFactor = 1.0,
    this.showHandle = true,
    this.semanticLabel = 'Bottom sheet',
  });

  final Widget child;
  final double maxHeightFactor;
  final bool showHandle;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom)
            .clamp(0.0, mediaQuery.size.height)
            .toDouble();
    final maxHeight = (availableHeight * maxHeightFactor)
        .clamp(0.0, availableHeight)
        .toDouble();
    final colors = context.b05Colors;

    return AnimatedPadding(
      duration: B05MotionPolicy.transitionDuration(context),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Semantics(
          container: true,
          label: semanticLabel,
          child: Material(
            color: colors.section,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showHandle)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: ExcludeSemantics(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.textDisabled.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    Flexible(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showIndiFitBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double maxHeightFactor = 1.0,
  String semanticLabel = 'Bottom sheet',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    useSafeArea: false,
    requestFocus: true,
    builder: (sheetContext) => IndiFitBottomSheet(
      maxHeightFactor: maxHeightFactor,
      semanticLabel: semanticLabel,
      child: builder(sheetContext),
    ),
  );
}
