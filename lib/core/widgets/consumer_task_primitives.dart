import 'package:flutter/material.dart';

import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

/// Shared shell for focused consumer tasks.
///
/// The shell keeps the content scrollable when the keyboard or large text
/// reduces the available viewport, while reserving a stable bottom action
/// area for the task's primary completion action.
class ConsumerTaskScaffold extends StatelessWidget {
  const ConsumerTaskScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.primaryAction,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.maxContentWidth = 640,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? primaryAction;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContentWidth),
      child: Padding(
        padding: padding,
        child: scrollable
            ? SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: body,
              )
            : body,
      ),
    );

    return Scaffold(
      appBar: appBar,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: appBar == null,
        bottom: false,
        child: AnimatedPadding(
          duration: B05MotionPolicy.transitionDuration(context),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: Column(
            children: [
              Expanded(
                child: Align(alignment: Alignment.topCenter, child: content),
              ),
              if (primaryAction != null)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: SizedBox(
                      width: double.infinity,
                      child: primaryAction,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A calm, one-surface empty state for consumer product screens.
///
/// It deliberately accepts display-ready copy so implementation state and
/// domain identifiers cannot leak into ordinary UI.
class ProductEmptyState extends StatelessWidget {
  const ProductEmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.checklist_rounded,
    this.action,
    this.actionLabel,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    assert(
      action == null || actionLabel != null,
      'ProductEmptyState actions need a label.',
    );
    return Semantics(
      container: true,
      label: '$title. $message',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final surface = B05Surface(
            subtle: true,
            showBorder: false,
            padding: const EdgeInsets.all(B05Layout.space20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: B05Layout.iconLarge,
                  color: context.b05Colors.action,
                ),
                const SizedBox(height: B05Layout.space12),
                Text(title, style: B05Typography.title(context)),
                const SizedBox(height: B05Layout.space4),
                Text(message, style: B05Typography.body(context)),
                if (action != null && actionLabel != null) ...[
                  const SizedBox(height: B05Layout.space16),
                  B05ActionButton(
                    label: actionLabel!,
                    icon: actionIcon,
                    onPressed: action,
                  ),
                ],
              ],
            ),
          );
          final sizedSurface = constraints.maxWidth.isFinite
              ? SizedBox(width: constraints.maxWidth, child: surface)
              : surface;
          final tappableSurface = action == null
              ? sizedSurface
              : Semantics(
                  container: true,
                  button: true,
                  label: '$title. $message',
                  hint: actionLabel == null
                      ? 'Double tap to continue.'
                      : 'Double tap to $actionLabel.',
                  enabled: true,
                  onTap: action,
                  child: GestureDetector(onTap: action, child: sizedSurface),
                );
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (constraints.maxHeight.isFinite && textScale >= 1.6) {
            return SingleChildScrollView(child: tappableSurface);
          }
          return tappableSurface;
        },
      ),
    );
  }
}

/// Compact, inline status treatment for loading and recoverable task states.
class ConsumerStatusRow extends StatelessWidget {
  const ConsumerStatusRow({
    required this.label,
    super.key,
    this.detail,
    this.loading = false,
    this.onRetry,
    this.error = false,
  });

  final String label;
  final String? detail;
  final bool loading;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (loading && !B05MotionPolicy.reduceMotion(context))
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.action,
            ),
          )
        else if (loading)
          Icon(
            Icons.hourglass_top_rounded,
            size: B05Layout.iconMedium,
            color: colors.action,
          )
        else
          Icon(
            error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: B05Layout.iconMedium,
            color: error ? colors.danger.indicator : colors.action,
          ),
        const SizedBox(width: B05Layout.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: B05Typography.label(context)),
              if (detail != null)
                Text(detail!, style: B05Typography.body(context)),
            ],
          ),
        ),
        if (onRetry != null)
          B05IconAction(
            icon: Icons.refresh_rounded,
            label: 'Retry',
            hint: 'Try again.',
            onPressed: onRetry,
          ),
      ],
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      value: detail,
      child: B05Surface(
        subtle: true,
        showBorder: false,
        padding: const EdgeInsets.symmetric(
          horizontal: B05Layout.space12,
          vertical: B05Layout.space8,
        ),
        child: content,
      ),
    );
  }
}

/// Reflows a task's primary and secondary actions on small screens or large
/// text. It keeps the first action visually dominant without horizontal
/// overflow.
class TaskActionGroup extends StatelessWidget {
  const TaskActionGroup({required this.primary, super.key, this.secondary});

  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return B05ActionGroup(
      children: [
        primary,
        ...?secondary == null ? null : <Widget>[secondary!],
      ],
    );
  }
}
