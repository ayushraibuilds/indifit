import 'package:flutter/material.dart';

import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

/// Quiet, compact feedback for ordinary successful actions.
SnackBar indiFitSuccessSnackBar(String message) =>
    SnackBar(behavior: SnackBarBehavior.floating, content: Text(message));

void dismissIndiFitFeedback(BuildContext context) =>
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();

/// Short-lived reversible feedback that stays visually inside the current
/// task instead of reading like a persistent page-level alert.
SnackBar indiFitUndoSnackBar(
  BuildContext context, {
  required String message,
  required Duration duration,
  required VoidCallback onUndo,
}) {
  final colors = context.b05Colors;
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(B05Layout.space16),
    shape: const RoundedRectangleBorder(borderRadius: B05Radii.mediumRadius),
    backgroundColor: colors.section,
    content: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
    ),
    duration: duration,
    action: SnackBarAction(
      label: 'Undo',
      textColor: colors.action,
      onPressed: onUndo,
    ),
  );
}
