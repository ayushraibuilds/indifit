import 'package:figma_squircle/figma_squircle.dart';
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
///
/// Corners are continuous (squircle) with [smoothing]. Roles: [chip] for
/// chips and small tags, [control] for buttons and inputs, [row] for list
/// rows and insets, [card] for sections, [sheet] for sheet and dialog tops.
abstract final class B05Radii {
  static const double chip = 12;
  static const double control = 14;
  static const double row = 16;
  static const double card = 22;
  static const double sheet = 28;
  static const double pill = 999;
  static const double smoothing = 0.6;

  static const SmoothBorderRadius chipRadius = SmoothBorderRadius.all(
    SmoothRadius(cornerRadius: chip, cornerSmoothing: smoothing),
  );
  static const SmoothBorderRadius controlRadius = SmoothBorderRadius.all(
    SmoothRadius(cornerRadius: control, cornerSmoothing: smoothing),
  );
  static const SmoothBorderRadius rowRadius = SmoothBorderRadius.all(
    SmoothRadius(cornerRadius: row, cornerSmoothing: smoothing),
  );
  static const SmoothBorderRadius cardRadius = SmoothBorderRadius.all(
    SmoothRadius(cornerRadius: card, cornerSmoothing: smoothing),
  );
  static const SmoothBorderRadius sheetTopRadius = SmoothBorderRadius.vertical(
    top: SmoothRadius(cornerRadius: sheet, cornerSmoothing: smoothing),
  );

  /// Earlier names, kept for one release while call sites move to the roles
  /// above. They now resolve to the role scale, not 8/10/12.
  static const double small = chip;
  static const double medium = control;
  static const double large = row;
  static const SmoothBorderRadius smallRadius = chipRadius;
  static const SmoothBorderRadius mediumRadius = controlRadius;
  static const SmoothBorderRadius largeRadius = rowRadius;

  static SmoothRectangleBorder shape(
    SmoothBorderRadius radius, {
    BorderSide side = BorderSide.none,
  }) => SmoothRectangleBorder(borderRadius: radius, side: side);
}

enum B05SurfaceRadius { small, medium, large, card }

SmoothBorderRadius b05Radius(B05SurfaceRadius radius) {
  return switch (radius) {
    B05SurfaceRadius.small => B05Radii.chipRadius,
    B05SurfaceRadius.medium => B05Radii.controlRadius,
    B05SurfaceRadius.large => B05Radii.rowRadius,
    B05SurfaceRadius.card => B05Radii.cardRadius,
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
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Timers, counters, kcal and weights. Tabular figures keep digits from
  /// shifting as values change.
  static TextStyle number(BuildContext context, {double? size}) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
      color: context.b05Colors.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: size,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// The one section-header style: sentence case, never ALL CAPS.
  static TextStyle sectionLabel(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
      color: context.b05Colors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.3,
    );
  }
}

/// The small semantic surface scale used across consumer screens.
///
/// A section should normally be the only boundary around an information
/// group. Insets, selected choices and interactive rows rely on tonal
/// contrast instead of adding another card border.
///
/// [raised] is for the one hero card on a screen (Today nutrition, the
/// workout summary, the thali plate panel).
enum B05SurfaceTone { section, raised, inset, selected, interactive }

/// A restrained semantic surface. It avoids a card-on-card visual hierarchy.
///
/// Depth comes from tone, not borders: sections get a top highlight in dark
/// mode and a soft shadow in light mode; raised cards add a gradient and a
/// deeper shadow. Sections default to [B05Radii.card], everything else to
/// [B05Radii.row].
class B05Surface extends StatelessWidget {
  const B05Surface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(B05Layout.space16),
    this.radius,
    this.tone = B05SurfaceTone.section,
    this.subtle = false,
    this.showBorder = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final B05SurfaceRadius? radius;
  final B05SurfaceTone tone;

  /// Retained for earlier callers; new code should choose [tone].
  final bool subtle;

  /// Adds a decorative [B05SemanticColors.borderSubtle] edge.
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final resolvedTone = subtle ? B05SurfaceTone.inset : tone;
    final elevated =
        resolvedTone == B05SurfaceTone.section ||
        resolvedTone == B05SurfaceTone.raised;
    final shape = B05Radii.shape(
      radius != null
          ? b05Radius(radius!)
          : elevated
          ? B05Radii.cardRadius
          : B05Radii.rowRadius,
      side: showBorder
          ? BorderSide(color: colors.borderSubtle)
          : BorderSide.none,
    );
    final decoration = switch (resolvedTone) {
      B05SurfaceTone.raised => ShapeDecoration(
        shape: shape,
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
      B05SurfaceTone.section => ShapeDecoration(
        shape: shape,
        color: colors.section,
        shadows: colors.sectionShadow.a == 0
            ? null
            : [
                BoxShadow(
                  color: colors.sectionShadow,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      B05SurfaceTone.inset => ShapeDecoration(
        shape: shape,
        color: colors.inset,
      ),
      B05SurfaceTone.selected => ShapeDecoration(
        shape: shape,
        color: colors.selected,
      ),
      B05SurfaceTone.interactive => ShapeDecoration(
        shape: shape,
        color: colors.interactive,
      ),
    };
    final content = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );
    if (!elevated || colors.sectionHighlight.a == 0) return content;
    return CustomPaint(
      foregroundPainter: _B05TopHighlightPainter(
        shape: shape,
        color: colors.sectionHighlight,
      ),
      child: content,
    );
  }
}

/// A one-pixel light along the top edge that fades out down the sides, so a
/// dark section reads as lit from above rather than outlined.
class _B05TopHighlightPainter extends CustomPainter {
  const _B05TopHighlightPainter({required this.shape, required this.color});

  final ShapeBorder shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final fade = (B05Radii.card * 1.5).clamp(1.0, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, fade));
    canvas.drawPath(shape.getOuterPath(rect), paint);
  }

  @override
  bool shouldRepaint(_B05TopHighlightPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape;
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
        decoration: ShapeDecoration(
          shape: B05Radii.shape(
            b05Radius(widget.radius),
            side: BorderSide(
              color: _hasFocus ? colors.focus : Colors.transparent,
              width: 2,
            ),
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
        backgroundColor: colors.actionFill,
        disabledBackgroundColor: colors.disabled,
        foregroundColor: colors.onAction,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        shape: B05Radii.shape(B05Radii.controlRadius),
      ),
      B05ActionEmphasis.secondary => OutlinedButton.styleFrom(
        foregroundColor: colors.action,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        side: BorderSide(color: colors.controlBorder),
        shape: B05Radii.shape(B05Radii.controlRadius),
      ),
      B05ActionEmphasis.tertiary => TextButton.styleFrom(
        foregroundColor: colors.action,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space8),
        shape: B05Radii.shape(B05Radii.chipRadius),
      ),
      B05ActionEmphasis.danger => FilledButton.styleFrom(
        backgroundColor: colors.danger.container,
        foregroundColor: colors.danger.foreground,
        disabledBackgroundColor: colors.disabled,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: B05Layout.minimumTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        shape: B05Radii.shape(B05Radii.controlRadius),
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

  Widget _labelWidget() => Text(label, maxLines: maxLines, overflow: overflow);

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
      B05ActionEmphasis.primary ||
      B05ActionEmphasis.danger => FilledButton.icon(
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
