import 'package:flutter/material.dart';

import '../presentation/product_failure_presentation.dart';
import '../theme/b05_semantic_colors.dart';

/// Shared spacing, icon and target sizes for B05-owned presentation.
abstract final class B05Layout {
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  static const double compactBreakpoint = 360;
  static const double iconSmall = 18;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const double minTouchTarget = 48;
  static const Size minimumTouchTarget = Size.square(minTouchTarget);
}

/// The only corner-radius values used by B05 presentation primitives.
abstract final class B05Radii {
  static const double small = 8;
  static const double medium = 10;
  static const double large = 12;

  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
}

enum B05SurfaceRadius { small, medium, large }

BorderRadius b05Radius(B05SurfaceRadius radius) {
  return switch (radius) {
    B05SurfaceRadius.small => B05Radii.smallRadius,
    B05SurfaceRadius.medium => B05Radii.mediumRadius,
    B05SurfaceRadius.large => B05Radii.largeRadius,
  };
}

/// Typography helpers that retain the active app text scale and semantic ink.
abstract final class B05Typography {
  static TextStyle pageTitle(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall!.copyWith(
      color: context.b05Colors.textPrimary,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle title(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
      color: context.b05Colors.textPrimary,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle body(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: context.b05Colors.textSecondary);
  }

  static TextStyle label(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge!.copyWith(
      color: context.b05Colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle caption(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: context.b05Colors.textSecondary);
  }

  static TextStyle metric(BuildContext context) {
    return Theme.of(context).textTheme.displaySmall!.copyWith(
      color: context.b05Colors.textPrimary,
      fontWeight: FontWeight.w700,
    );
  }
}

/// The small semantic surface scale used across consumer screens.
///
/// A section should normally be the only boundary around an information
/// group. Insets, selected choices and interactive rows rely on tonal
/// contrast instead of adding another card border.
enum B05SurfaceTone { section, inset, selected, interactive }

/// A restrained semantic surface. It avoids a card-on-card visual hierarchy.
class B05Surface extends StatelessWidget {
  const B05Surface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(B05Layout.space16),
    this.radius = B05SurfaceRadius.medium,
    this.tone = B05SurfaceTone.section,
    this.subtle = false,
    this.showBorder = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final B05SurfaceRadius radius;
  final B05SurfaceTone tone;

  /// Retained for earlier callers; new code should choose [tone].
  final bool subtle;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final resolvedTone = subtle ? B05SurfaceTone.inset : tone;
    final background = switch (resolvedTone) {
      B05SurfaceTone.section => colors.section,
      B05SurfaceTone.inset => colors.inset,
      B05SurfaceTone.selected => colors.selected,
      B05SurfaceTone.interactive => colors.interactive,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: b05Radius(radius),
        border: showBorder ? Border.all(color: colors.border) : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Gives B05 actions an explicit 48 px minimum target without changing their
/// visual layout when their contents naturally grow larger.
class B05TouchTarget extends StatelessWidget {
  const B05TouchTarget({
    required this.child,
    super.key,
    this.minWidth = B05Layout.minTouchTarget,
    this.minHeight = B05Layout.minTouchTarget,
  });

  final Widget child;
  final double minWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
      child: child,
    );
  }
}

/// Draws a persistent-layout focus ring from the B05 semantic focus token.
///
/// The ring reserves its border space while unfocused, avoiding motion or
/// layout shifts when keyboard focus changes.
class B05FocusRing extends StatefulWidget {
  const B05FocusRing({
    required this.child,
    super.key,
    this.radius = B05SurfaceRadius.medium,
  });

  final Widget child;
  final B05SurfaceRadius radius;

  @override
  State<B05FocusRing> createState() => _B05FocusRingState();
}

class _B05FocusRingState extends State<B05FocusRing> {
  var _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Focus(
      canRequestFocus: false,
      onFocusChange: (hasFocus) {
        if (_hasFocus != hasFocus) {
          setState(() => _hasFocus = hasFocus);
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: b05Radius(widget.radius),
          border: Border.all(
            color: _hasFocus ? colors.focus : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

enum B05ActionEmphasis { primary, secondary, tertiary, danger }

/// A labelled action with a semantic hint, focus order and shared touch target.
class B05ActionButton extends StatelessWidget {
  const B05ActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.hint,
    this.icon,
    this.emphasis = B05ActionEmphasis.primary,
    this.selected = false,
    this.focusOrder,
    this.maxLines,
    this.overflow,
  });

  final String label;
  final String? hint;
  final IconData? icon;
  final VoidCallback? onPressed;
  final B05ActionEmphasis emphasis;
  final bool selected;
  final double? focusOrder;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final style = switch (emphasis) {
      B05ActionEmphasis.primary => FilledButton.styleFrom(
        backgroundColor: colors.action,
        disabledBackgroundColor: colors.disabled,
        foregroundColor: colors.onAction,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        shape: RoundedRectangleBorder(borderRadius: B05Radii.mediumRadius),
      ),
      B05ActionEmphasis.secondary => OutlinedButton.styleFrom(
        foregroundColor: colors.action,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: B05Radii.mediumRadius),
      ),
      B05ActionEmphasis.tertiary => TextButton.styleFrom(
        foregroundColor: colors.action,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space8),
        shape: RoundedRectangleBorder(borderRadius: B05Radii.smallRadius),
      ),
      B05ActionEmphasis.danger => FilledButton.styleFrom(
        backgroundColor: colors.danger.container,
        foregroundColor: colors.danger.foreground,
        disabledBackgroundColor: colors.disabled,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        shape: RoundedRectangleBorder(borderRadius: B05Radii.mediumRadius),
      ),
    };
    final button = B05TouchTarget(
      child: B05FocusRing(
        child: Tooltip(
          message: hint ?? label,
          excludeFromSemantics: true,
          child: Semantics(
            container: true,
            label: label,
            hint: hint,
            button: true,
            enabled: onPressed != null,
            selected: selected,
            onTap: onPressed,
            child: ExcludeSemantics(
              child: icon == null ? _button(style) : _iconButton(style),
            ),
          ),
        ),
      ),
    );
    return focusOrder == null
        ? button
        : FocusTraversalOrder(
            order: NumericFocusOrder(focusOrder!),
            child: button,
          );
  }

  Widget _labelWidget() => Text(
        label,
        maxLines: maxLines,
        overflow: overflow,
      );

  Widget _button(ButtonStyle style) {
    return switch (emphasis) {
      B05ActionEmphasis.primary || B05ActionEmphasis.danger => FilledButton(
        onPressed: onPressed,
        style: style,
        child: _labelWidget(),
      ),
      B05ActionEmphasis.secondary => OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: _labelWidget(),
      ),
      B05ActionEmphasis.tertiary => TextButton(
        onPressed: onPressed,
        style: style,
        child: _labelWidget(),
      ),
    };
  }

  Widget _iconButton(ButtonStyle style) {
    return switch (emphasis) {
      B05ActionEmphasis.primary || B05ActionEmphasis.danger => FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: B05Layout.iconMedium),
        label: _labelWidget(),
      ),
      B05ActionEmphasis.secondary => OutlinedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: B05Layout.iconMedium),
        label: _labelWidget(),
      ),
      B05ActionEmphasis.tertiary => TextButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: B05Layout.iconMedium),
        label: _labelWidget(),
      ),
    };
  }
}

/// An icon-only action that always has a discoverable spoken label and hint.
class B05IconAction extends StatelessWidget {
  const B05IconAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.hint,
    this.focusOrder,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final double? focusOrder;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final action = B05TouchTarget(
      child: B05FocusRing(
        child: Tooltip(
          message: hint ?? label,
          excludeFromSemantics: true,
          child: Semantics(
            container: true,
            label: label,
            hint: hint,
            button: true,
            enabled: onPressed != null,
            onTap: onPressed,
            child: ExcludeSemantics(
              child: IconButton(
                onPressed: onPressed,
                tooltip: label,
                icon: Icon(icon, size: B05Layout.iconMedium),
                color: colors.action,
                disabledColor: colors.textDisabled,
                constraints: const BoxConstraints.tightFor(
                  width: B05Layout.minTouchTarget,
                  height: B05Layout.minTouchTarget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return focusOrder == null
        ? action
        : FocusTraversalOrder(
            order: NumericFocusOrder(focusOrder!),
            child: action,
          );
  }
}

/// Reflows a group of actions when a phone is narrow or text is enlarged.
class B05ActionGroup extends StatelessWidget {
  const B05ActionGroup({
    required this.children,
    super.key,
    this.spacing = B05Layout.space8,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < B05Layout.compactBreakpoint ||
              textScale >= 1.6;
          if (stacked) {
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
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: children,
          );
        },
      ),
    );
  }
}

/// A labelled status treatment, so visual state is never communicated by
/// colour alone.
class B05StatusMessage extends StatelessWidget {
  const B05StatusMessage({
    required this.status,
    required this.label,
    super.key,
    this.value,
    this.hint,
  });

  final B05SemanticStatus status;
  final String label;
  final String? value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final role = context.b05Colors.status(status);
    final semanticLabel = '${_spokenStatus(status)}: $label';
    return Semantics(
      container: true,
      label: semanticLabel,
      value: value,
      hint: hint,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: role.container,
            borderRadius: B05Radii.smallRadius,
            border: Border(left: BorderSide(color: role.indicator, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space4,
              children: [
                Icon(_statusIcon(status), color: role.indicator),
                Text(
                  label,
                  style: B05Typography.label(
                    context,
                  ).copyWith(color: role.foreground),
                ),
                if (value != null)
                  Text(
                    value!,
                    style: B05Typography.body(
                      context,
                    ).copyWith(color: role.foreground),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _spokenStatus(B05SemanticStatus status) {
    return switch (status) {
      B05SemanticStatus.success => 'Success',
      B05SemanticStatus.warning => 'Warning',
      B05SemanticStatus.danger => 'Error',
      B05SemanticStatus.info => 'Information',
      B05SemanticStatus.unavailable => 'Unavailable',
    };
  }

  static IconData _statusIcon(B05SemanticStatus status) {
    return switch (status) {
      B05SemanticStatus.success => Icons.check_circle_outline,
      B05SemanticStatus.warning => Icons.warning_amber_outlined,
      B05SemanticStatus.danger => Icons.error_outline,
      B05SemanticStatus.info => Icons.info_outline,
      B05SemanticStatus.unavailable => Icons.do_not_disturb_alt_outlined,
    };
  }
}

/// Production-safe failure treatment shared by consumer screens. It accepts a
/// mapped presentation value and therefore never renders an exception string.
class ProductFailureCard extends StatelessWidget {
  const ProductFailureCard({
    required this.failure,
    super.key,
    this.onRetry,
    this.onBack,
  });

  final ProductFailurePresentation failure;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(failure.title, style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space8),
          Text(failure.message, style: B05Typography.body(context)),
          if (failure.supportReference != null) ...[
            const SizedBox(height: B05Layout.space8),
            Text(
              'Reference ${failure.supportReference}',
              style: B05Typography.body(context),
            ),
          ],
          if (onRetry != null || onBack != null) ...[
            const SizedBox(height: B05Layout.space12),
            B05ActionGroup(
              children: [
                if (onRetry != null && failure.canRetry)
                  B05ActionButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  ),
                if (onBack != null)
                  B05ActionButton(
                    label: 'Go back',
                    emphasis: B05ActionEmphasis.secondary,
                    onPressed: onBack,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Platform accessibility policy used by every B05 nonessential animation.
abstract final class B05MotionPolicy {
  /// Standard duration for interactive transitions (e.g. selection, fades).
  static const Duration fastDuration = Duration(milliseconds: 160);

  /// Default duration for state changes (e.g. nutrition values, sheet transitions).
  static const Duration standardDuration = Duration(milliseconds: 240);

  /// Deliberate completion duration for milestone moments (e.g. workout completion).
  static const Duration completionDuration = Duration(milliseconds: 360);

  /// Standard motion curve for smooth deceleration without elastic bounce.
  static const Curve standardCurve = Curves.easeOutCubic;

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static bool allowsAutoplay(BuildContext context) => !reduceMotion(context);

  static Duration transitionDuration(
    BuildContext context, {
    Duration standard = standardDuration,
  }) {
    return reduceMotion(context) ? Duration.zero : standard;
  }
}

/// Chooses a still/text alternative when the platform requests reduced motion.
///
/// The primitive intentionally requires a fallback rather than silently
/// removing content. It does not start media playback; media surfaces must use
/// [B05MotionPolicy.allowsAutoplay] before requesting autoplay.
class B05MotionContent extends StatelessWidget {
  const B05MotionContent({
    required this.animatedChild,
    required this.reducedMotionChild,
    super.key,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget animatedChild;
  final Widget reducedMotionChild;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (B05MotionPolicy.reduceMotion(context)) {
      return TickerMode(enabled: false, child: reducedMotionChild);
    }
    return AnimatedSwitcher(duration: duration, child: animatedChild);
  }
}
