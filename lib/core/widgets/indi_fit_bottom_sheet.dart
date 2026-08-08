import 'package:flutter/material.dart';

/// The shared opaque, keyboard-aware surface for product bottom sheets.
class IndiFitBottomSheet extends StatelessWidget {
  const IndiFitBottomSheet({
    required this.child,
    super.key,
    this.maxHeightFactor = 1.0,
    this.showHandle = true,
  });

  final Widget child;
  final double maxHeightFactor;
  final bool showHandle;

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
    final colors = Theme.of(context).colorScheme;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: colors.surface,
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                            color: colors.onSurface.withValues(alpha: 0.35),
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
    );
  }
}

Future<T?> showIndiFitBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double maxHeightFactor = 1.0,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    useSafeArea: false,
    builder: (sheetContext) => IndiFitBottomSheet(
      maxHeightFactor: maxHeightFactor,
      child: builder(sheetContext),
    ),
  );
}
