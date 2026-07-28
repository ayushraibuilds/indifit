import 'package:flutter/material.dart';
import 'colors.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color streakOrange;
  final Color infoBlue;
  final Color fiberTeal;
  final Color achievementGold;
  final Color achievementSilver;
  final Color achievementBronze;
  final Color cardBackground;
  final Color border;
  final Color textMuted;

  const AppColorsExtension({
    required this.streakOrange,
    required this.infoBlue,
    required this.fiberTeal,
    required this.achievementGold,
    required this.achievementSilver,
    required this.achievementBronze,
    required this.cardBackground,
    required this.border,
    required this.textMuted,
  });

  static const dark = AppColorsExtension(
    streakOrange: AppColors.streakOrange,
    infoBlue: AppColors.infoBlue,
    fiberTeal: AppColors.fiberTeal,
    achievementGold: AppColors.achievementGold,
    achievementSilver: AppColors.achievementSilver,
    achievementBronze: AppColors.achievementBronze,
    cardBackground: AppColors.cardBackground,
    border: AppColors.border,
    textMuted: AppColors.textMuted,
  );

  static const light = AppColorsExtension(
    streakOrange: Color(0xFFEA580C),
    infoBlue: Color(0xFF2563EB),
    fiberTeal: Color(0xFF0D9488),
    achievementGold: Color(0xFFD97706),
    achievementSilver: Color(0xFF64748B),
    achievementBronze: Color(0xFFB45309),
    cardBackground: Colors.white,
    border: Color(0xFFE2E8F0),
    textMuted: Color(0xFF64748B),
  );

  @override
  AppColorsExtension copyWith({
    Color? streakOrange,
    Color? infoBlue,
    Color? fiberTeal,
    Color? achievementGold,
    Color? achievementSilver,
    Color? achievementBronze,
    Color? cardBackground,
    Color? border,
    Color? textMuted,
  }) {
    return AppColorsExtension(
      streakOrange: streakOrange ?? this.streakOrange,
      infoBlue: infoBlue ?? this.infoBlue,
      fiberTeal: fiberTeal ?? this.fiberTeal,
      achievementGold: achievementGold ?? this.achievementGold,
      achievementSilver: achievementSilver ?? this.achievementSilver,
      achievementBronze: achievementBronze ?? this.achievementBronze,
      cardBackground: cardBackground ?? this.cardBackground,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppColorsExtension lerp(
    ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      streakOrange: Color.lerp(streakOrange, other.streakOrange, t)!,
      infoBlue: Color.lerp(infoBlue, other.infoBlue, t)!,
      fiberTeal: Color.lerp(fiberTeal, other.fiberTeal, t)!,
      achievementGold: Color.lerp(achievementGold, other.achievementGold, t)!,
      achievementSilver:
          Color.lerp(achievementSilver, other.achievementSilver, t)!,
      achievementBronze:
          Color.lerp(achievementBronze, other.achievementBronze, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

extension AppColorsExtensionContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>() ?? AppColorsExtension.dark;
}
