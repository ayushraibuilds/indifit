import 'package:flutter/material.dart';

/// A foreground, container and indicator trio for a meaningful UI state.
///
/// B05 surfaces use this rather than inferring a state from an arbitrary
/// palette colour. The accompanying label remains required in the UI, so the
/// colour is never the only expression of a state.
@immutable
class B05ColorRole {
  const B05ColorRole({
    required this.foreground,
    required this.container,
    required this.indicator,
  });

  final Color foreground;
  final Color container;
  final Color indicator;

  B05ColorRole lerp(B05ColorRole other, double t) {
    return B05ColorRole(
      foreground: Color.lerp(foreground, other.foreground, t)!,
      container: Color.lerp(container, other.container, t)!,
      indicator: Color.lerp(indicator, other.indicator, t)!,
    );
  }
}

enum B05SemanticStatus { success, warning, danger, info, unavailable }

enum B05MealAccent { breakfast, lunch, dinner, snack }

enum B05MediaState { available, unavailable, invalid }

/// Semantic light and dark presentation tokens for B05-owned surfaces.
///
/// Domain data must choose an explicit state; this extension only supplies its
/// presentation. It deliberately does not contain domain calculations or
/// arbitrary user-configurable values.
@immutable
class B05SemanticColors extends ThemeExtension<B05SemanticColors> {
  const B05SemanticColors({
    required this.page,
    required this.surface,
    required this.surfaceSubtle,
    required this.section,
    required this.inset,
    required this.selected,
    required this.interactive,
    required this.navigationSurface,
    required this.navigationSelected,
    required this.navigationUnselected,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.focus,
    required this.disabled,
    required this.action,
    required this.onAction,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.unavailable,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snack,
    required this.mediaAvailable,
    required this.mediaUnavailable,
    required this.mediaInvalid,
  });

  final Color page;

  /// The neutral, single-boundary surface for a product information group.
  final Color section;

  /// A recessed area within a section, such as a metric or compact input.
  final Color inset;

  /// The tonal state for a selected product choice.
  final Color selected;

  /// The tonal state for a tappable, non-selected product row.
  final Color interactive;

  /// Navigation colors intentionally have their own contrast contract.
  final Color navigationSurface;
  final Color navigationSelected;
  final Color navigationUnselected;

  /// Backwards-compatible aliases used by earlier B05 presentation surfaces.
  final Color surface;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;
  final Color focus;
  final Color disabled;
  final Color action;
  final Color onAction;

  final B05ColorRole success;
  final B05ColorRole warning;
  final B05ColorRole danger;
  final B05ColorRole info;
  final B05ColorRole unavailable;

  final B05ColorRole breakfast;
  final B05ColorRole lunch;
  final B05ColorRole dinner;
  final B05ColorRole snack;

  final B05ColorRole mediaAvailable;
  final B05ColorRole mediaUnavailable;
  final B05ColorRole mediaInvalid;

  static const dark = B05SemanticColors(
    page: Color(0xFF060A12),
    section: Color(0xFF0F172A),
    inset: Color(0xFF162033),
    selected: Color(0xFF103B31),
    interactive: Color(0xFF172235),
    navigationSurface: Color(0xFF0B1220),
    navigationSelected: Color(0xFF34D399),
    navigationUnselected: Color(0xFF94A3B8),
    surface: Color(0xFF0F172A),
    surfaceSubtle: Color(0xFF162033),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFCBD5E1),
    textDisabled: Color(0xFF94A3B8),
    border: Color(0x66FFFFFF),
    focus: Color(0xFF5EEAD4),
    disabled: Color(0xFF334155),
    action: Color(0xFF087F5B),
    onAction: Color(0xFFFFFFFF),
    success: B05ColorRole(
      foreground: Color(0xFF6EE7B7),
      container: Color(0xFF063A2B),
      indicator: Color(0xFF34D399),
    ),
    warning: B05ColorRole(
      foreground: Color(0xFFFCD34D),
      container: Color(0xFF4A2600),
      indicator: Color(0xFFFBBF24),
    ),
    danger: B05ColorRole(
      foreground: Color(0xFFFCA5A5),
      container: Color(0xFF4C1117),
      indicator: Color(0xFFF87171),
    ),
    info: B05ColorRole(
      foreground: Color(0xFF93C5FD),
      container: Color(0xFF0B2950),
      indicator: Color(0xFF60A5FA),
    ),
    unavailable: B05ColorRole(
      foreground: Color(0xFFCBD5E1),
      container: Color(0xFF1E293B),
      indicator: Color(0xFF94A3B8),
    ),
    breakfast: B05ColorRole(
      foreground: Color(0xFFFED7AA),
      container: Color(0xFF4A2600),
      indicator: Color(0xFFFB923C),
    ),
    lunch: B05ColorRole(
      foreground: Color(0xFFBBF7D0),
      container: Color(0xFF063A2B),
      indicator: Color(0xFF4ADE80),
    ),
    dinner: B05ColorRole(
      foreground: Color(0xFFC4B5FD),
      container: Color(0xFF2E1065),
      indicator: Color(0xFFA78BFA),
    ),
    snack: B05ColorRole(
      foreground: Color(0xFFFDE68A),
      container: Color(0xFF422006),
      indicator: Color(0xFFFACC15),
    ),
    mediaAvailable: B05ColorRole(
      foreground: Color(0xFF6EE7B7),
      container: Color(0xFF063A2B),
      indicator: Color(0xFF34D399),
    ),
    mediaUnavailable: B05ColorRole(
      foreground: Color(0xFFCBD5E1),
      container: Color(0xFF1E293B),
      indicator: Color(0xFF94A3B8),
    ),
    mediaInvalid: B05ColorRole(
      foreground: Color(0xFFFCA5A5),
      container: Color(0xFF4C1117),
      indicator: Color(0xFFF87171),
    ),
  );

  static const light = B05SemanticColors(
    page: Color(0xFFF8FAFC),
    section: Color(0xFFFFFFFF),
    inset: Color(0xFFF1F5F9),
    selected: Color(0xFFD1FAE5),
    interactive: Color(0xFFECFDF5),
    navigationSurface: Color(0xFFFFFFFF),
    navigationSelected: Color(0xFF0F766E),
    navigationUnselected: Color(0xFF475569),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textDisabled: Color(0xFF64748B),
    border: Color(0xFFCBD5E1),
    focus: Color(0xFF0F766E),
    disabled: Color(0xFFE2E8F0),
    action: Color(0xFF0F766E),
    onAction: Color(0xFFFFFFFF),
    success: B05ColorRole(
      foreground: Color(0xFF065F46),
      container: Color(0xFFD1FAE5),
      indicator: Color(0xFF047857),
    ),
    warning: B05ColorRole(
      foreground: Color(0xFF92400E),
      container: Color(0xFFFEF3C7),
      indicator: Color(0xFFB45309),
    ),
    danger: B05ColorRole(
      foreground: Color(0xFF991B1B),
      container: Color(0xFFFEE2E2),
      indicator: Color(0xFFDC2626),
    ),
    info: B05ColorRole(
      foreground: Color(0xFF1E40AF),
      container: Color(0xFFDBEAFE),
      indicator: Color(0xFF2563EB),
    ),
    unavailable: B05ColorRole(
      foreground: Color(0xFF334155),
      container: Color(0xFFE2E8F0),
      indicator: Color(0xFF475569),
    ),
    breakfast: B05ColorRole(
      foreground: Color(0xFF9A3412),
      container: Color(0xFFFFEDD5),
      indicator: Color(0xFFEA580C),
    ),
    lunch: B05ColorRole(
      foreground: Color(0xFF166534),
      container: Color(0xFFDCFCE7),
      indicator: Color(0xFF16A34A),
    ),
    dinner: B05ColorRole(
      foreground: Color(0xFF5B21B6),
      container: Color(0xFFEDE9FE),
      indicator: Color(0xFF7C3AED),
    ),
    snack: B05ColorRole(
      foreground: Color(0xFF854D0E),
      container: Color(0xFFFEF9C3),
      indicator: Color(0xFFCA8A04),
    ),
    mediaAvailable: B05ColorRole(
      foreground: Color(0xFF065F46),
      container: Color(0xFFD1FAE5),
      indicator: Color(0xFF047857),
    ),
    mediaUnavailable: B05ColorRole(
      foreground: Color(0xFF334155),
      container: Color(0xFFE2E8F0),
      indicator: Color(0xFF475569),
    ),
    mediaInvalid: B05ColorRole(
      foreground: Color(0xFF991B1B),
      container: Color(0xFFFEE2E2),
      indicator: Color(0xFFDC2626),
    ),
  );

  B05ColorRole status(B05SemanticStatus status) {
    return switch (status) {
      B05SemanticStatus.success => success,
      B05SemanticStatus.warning => warning,
      B05SemanticStatus.danger => danger,
      B05SemanticStatus.info => info,
      B05SemanticStatus.unavailable => unavailable,
    };
  }

  B05ColorRole meal(B05MealAccent meal) {
    return switch (meal) {
      B05MealAccent.breakfast => breakfast,
      B05MealAccent.lunch => lunch,
      B05MealAccent.dinner => dinner,
      B05MealAccent.snack => snack,
    };
  }

  B05ColorRole media(B05MediaState state) {
    return switch (state) {
      B05MediaState.available => mediaAvailable,
      B05MediaState.unavailable => mediaUnavailable,
      B05MediaState.invalid => mediaInvalid,
    };
  }

  @override
  B05SemanticColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceSubtle,
    Color? section,
    Color? inset,
    Color? selected,
    Color? interactive,
    Color? navigationSurface,
    Color? navigationSelected,
    Color? navigationUnselected,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
    Color? focus,
    Color? disabled,
    Color? action,
    Color? onAction,
    B05ColorRole? success,
    B05ColorRole? warning,
    B05ColorRole? danger,
    B05ColorRole? info,
    B05ColorRole? unavailable,
    B05ColorRole? breakfast,
    B05ColorRole? lunch,
    B05ColorRole? dinner,
    B05ColorRole? snack,
    B05ColorRole? mediaAvailable,
    B05ColorRole? mediaUnavailable,
    B05ColorRole? mediaInvalid,
  }) {
    return B05SemanticColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      section: section ?? this.section,
      inset: inset ?? this.inset,
      selected: selected ?? this.selected,
      interactive: interactive ?? this.interactive,
      navigationSurface: navigationSurface ?? this.navigationSurface,
      navigationSelected: navigationSelected ?? this.navigationSelected,
      navigationUnselected: navigationUnselected ?? this.navigationUnselected,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      focus: focus ?? this.focus,
      disabled: disabled ?? this.disabled,
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      unavailable: unavailable ?? this.unavailable,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      snack: snack ?? this.snack,
      mediaAvailable: mediaAvailable ?? this.mediaAvailable,
      mediaUnavailable: mediaUnavailable ?? this.mediaUnavailable,
      mediaInvalid: mediaInvalid ?? this.mediaInvalid,
    );
  }

  @override
  B05SemanticColors lerp(ThemeExtension<B05SemanticColors>? other, double t) {
    if (other is! B05SemanticColors) return this;
    return B05SemanticColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      section: Color.lerp(section, other.section, t)!,
      inset: Color.lerp(inset, other.inset, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      interactive: Color.lerp(interactive, other.interactive, t)!,
      navigationSurface: Color.lerp(
        navigationSurface,
        other.navigationSurface,
        t,
      )!,
      navigationSelected: Color.lerp(
        navigationSelected,
        other.navigationSelected,
        t,
      )!,
      navigationUnselected: Color.lerp(
        navigationUnselected,
        other.navigationUnselected,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      success: success.lerp(other.success, t),
      warning: warning.lerp(other.warning, t),
      danger: danger.lerp(other.danger, t),
      info: info.lerp(other.info, t),
      unavailable: unavailable.lerp(other.unavailable, t),
      breakfast: breakfast.lerp(other.breakfast, t),
      lunch: lunch.lerp(other.lunch, t),
      dinner: dinner.lerp(other.dinner, t),
      snack: snack.lerp(other.snack, t),
      mediaAvailable: mediaAvailable.lerp(other.mediaAvailable, t),
      mediaUnavailable: mediaUnavailable.lerp(other.mediaUnavailable, t),
      mediaInvalid: mediaInvalid.lerp(other.mediaInvalid, t),
    );
  }
}

extension B05SemanticColorsContext on BuildContext {
  B05SemanticColors get b05Colors {
    final theme = Theme.of(this);
    return theme.extension<B05SemanticColors>() ??
        (theme.brightness == Brightness.light
            ? B05SemanticColors.light
            : B05SemanticColors.dark);
  }
}
