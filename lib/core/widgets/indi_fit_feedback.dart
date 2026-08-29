import 'package:flutter/material.dart';

import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

/// Quiet, compact feedback for ordinary successful actions.
SnackBar indiFitSuccessSnackBar(
  String message, {
  BuildContext? context,
  Duration duration = const Duration(seconds: 3),
}) {
  if (context != null) {
    final colors = context.b05Colors;
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(B05Layout.space16),
      shape: const RoundedRectangleBorder(borderRadius: B05Radii.mediumRadius),
      backgroundColor: colors.section,
      duration: duration,
      content: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
      ),
    );
  }
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: duration,
    content: Text(message),
  );
}

void dismissIndiFitFeedback(BuildContext context) =>
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();

/// Clears any active/queued feedback and shows a finite, theme-consistent success SnackBar.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
showIndiFitSuccessFeedback(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.clearSnackBars();
  return messenger.showSnackBar(
    indiFitSuccessSnackBar(message, context: context, duration: duration),
  );
}

/// Clears any active/queued feedback and shows a finite, theme-consistent undo SnackBar.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
showIndiFitUndoFeedback(
  BuildContext context, {
  required String message,
  required Duration duration,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.clearSnackBars();
  return messenger.showSnackBar(
    indiFitUndoSnackBar(
      context,
      message: message,
      duration: duration,
      onUndo: onUndo,
    ),
  );
}

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
