import 'package:flutter/material.dart';

import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

/// The one IndiFit feedback surface: every success and Undo toast (TF-1,
/// UR-42). A raised card with a 1 pt action-colour edge, so it reads as a
/// message over the page rather than another card on it.
///
/// Text wraps to more lines at large sizes instead of truncating.
class IndiFitFeedbackCard extends StatelessWidget {
  const IndiFitFeedbackCard({
    required this.message,
    super.key,
    this.leading,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String message;

  /// Art or an icon at the start, such as the meal's chip.
  final Widget? leading;

  /// A second, quieter line, such as the day's change after a log. It may
  /// arrive after the card shows; the card grows when it does.
  final Future<String?>? detail;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final textTheme = Theme.of(context).textTheme;
    final detail = this.detail;
    return DecoratedBox(
      key: const ValueKey('indifit_feedback_card'),
      decoration: ShapeDecoration(
        shape: B05Radii.shape(
          B05Radii.cardRadius,
          side: BorderSide(color: colors.action),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.raised, colors.raisedEnd],
        ),
        shadows: [
          BoxShadow(
            color: colors.raisedShadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space12,
          B05Layout.space8,
          B05Layout.space12,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: B05Layout.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail != null)
                    FutureBuilder<String?>(
                      future: detail,
                      builder: (context, snapshot) {
                        final line = snapshot.data;
                        if (line == null || line.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            line,
                            key: const ValueKey('indifit_feedback_detail'),
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colors.action,
                  minimumSize: B05Layout.minimumTouchTarget,
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              )
            else
              const SizedBox(width: B05Layout.space8),
          ],
        ),
      ),
    );
  }
}

SnackBar _feedbackSnackBar({
  required Widget content,
  required Duration duration,
}) => SnackBar(
  behavior: SnackBarBehavior.floating,
  margin: const EdgeInsets.fromLTRB(
    B05Layout.space16,
    0,
    B05Layout.space16,
    B05Layout.space12,
  ),
  padding: EdgeInsets.zero,
  elevation: 0,
  backgroundColor: Colors.transparent,
  duration: duration,
  persist: false,
  content: content,
);

/// Quiet, compact feedback for ordinary successful actions.
SnackBar indiFitSuccessSnackBar(
  String message, {
  BuildContext? context,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) => _feedbackSnackBar(
  duration: duration,
  content: Builder(
    builder: (context) => IndiFitFeedbackCard(
      message: message,
      actionLabel: action?.label,
      onAction: action == null
          ? null
          : () {
              ScaffoldMessenger.maybeOf(
                context,
              )?.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
              action.onPressed();
            },
    ),
  ),
);

void dismissIndiFitFeedback(BuildContext context) =>
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();

ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _show(
  BuildContext context,
  SnackBar snackBar,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.clearSnackBars();
  // Reduce Motion: the card appears and leaves without sliding or fading.
  final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return messenger.showSnackBar(
    snackBar,
    snackBarAnimationStyle: still ? AnimationStyle.noAnimation : null,
  );
}

/// Clears any active/queued feedback and shows a finite, theme-consistent success SnackBar.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
showIndiFitSuccessFeedback(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) => _show(
  context,
  indiFitSuccessSnackBar(
    message,
    context: context,
    duration: duration,
    action: action,
  ),
);

/// Clears any active/queued feedback and shows a finite, theme-consistent undo SnackBar.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
showIndiFitUndoFeedback(
  BuildContext context, {
  required String message,
  required Duration duration,
  required VoidCallback onUndo,
  Widget? leading,
  Future<String?>? detail,
}) => _show(
  context,
  indiFitUndoSnackBar(
    context,
    message: message,
    duration: duration,
    onUndo: onUndo,
    leading: leading,
    detail: detail,
  ),
);

/// Short-lived reversible feedback that stays visually inside the current
/// task instead of reading like a persistent page-level alert.
SnackBar indiFitUndoSnackBar(
  BuildContext context, {
  required String message,
  required Duration duration,
  required VoidCallback onUndo,
  Widget? leading,
  Future<String?>? detail,
}) => _feedbackSnackBar(
  duration: duration,
  // Undo is a bounded affordance here: the card still times out.
  content: Builder(
    builder: (context) => IndiFitFeedbackCard(
      message: message,
      leading: leading,
      detail: detail,
      actionLabel: 'Undo',
      onAction: () {
        ScaffoldMessenger.maybeOf(
          context,
        )?.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
        onUndo();
      },
    ),
  ),
);
