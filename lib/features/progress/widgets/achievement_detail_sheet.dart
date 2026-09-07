import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/services/achievement_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class AchievementDetailSheet extends StatelessWidget {
  final Achievement achievement;

  const AchievementDetailSheet({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final dateStr = achievement.unlockedAt != null
        ? DateFormat('d MMM yyyy').format(achievement.unlockedAt!.toLocal())
        : null;

    final progression = _calculateProgression(achievement);
    final basis = _getBasisDisclosure(achievement.id);

    return SafeArea(
      key: const Key('achievement_detail_sheet'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space20,
          B05Layout.space16,
          B05Layout.space20,
          B05Layout.space24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: B05Layout.space20),

              // Vector icon in colored tier circle
              Container(
                padding: const EdgeInsets.all(B05Layout.space20),
                decoration: BoxDecoration(
                  color: achievement.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: achievement.color.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  achievement.icon,
                  size: 48,
                  color: achievement.color,
                ),
              ),
              const SizedBox(height: B05Layout.space16),

              // Title
              Text(
                achievement.title,
                style: B05Typography.pageTitle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: B05Layout.space4),

              // Description
              Text(
                achievement.description,
                style: B05Typography.body(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: B05Layout.space20),

              // Factual Evidence & Date Box
              B05Surface(
                tone: B05SurfaceTone.inset,
                radius: B05SurfaceRadius.medium,
                padding: const EdgeInsets.all(B05Layout.space16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          achievement.isUnlocked
                              ? Icons.verified_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: achievement.isUnlocked
                              ? colors.success.indicator
                              : colors.textDisabled,
                        ),
                        const SizedBox(width: B05Layout.space8),
                        Expanded(
                          child: Text(
                            achievement.isUnlocked
                                ? 'How this was unlocked: ${achievement.evidence}'
                                : 'Current progress: ${achievement.evidence}',
                            style: B05Typography.body(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateStr != null) ...[
                      const SizedBox(height: B05Layout.space8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Unlocked on $dateStr',
                          style: B05Typography.caption(context).copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: B05Layout.space16),

              // Tier Progression ("X to go" math)
              if (progression != null) ...[
                B05Surface(
                  tone: B05SurfaceTone.section,
                  radius: B05SurfaceRadius.medium,
                  padding: const EdgeInsets.all(B05Layout.space16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 20,
                        color: colors.action,
                      ),
                      const SizedBox(width: B05Layout.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tier Progression',
                              style: B05Typography.label(context).copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              progression,
                              style: B05Typography.caption(context).copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: B05Layout.space16),
              ],

              // Basis Disclosure
              B05Surface(
                tone: B05SurfaceTone.inset,
                radius: B05SurfaceRadius.medium,
                padding: const EdgeInsets.all(B05Layout.space12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: colors.textDisabled,
                    ),
                    const SizedBox(width: B05Layout.space8),
                    Expanded(
                      child: Text(
                        basis,
                        style: B05Typography.caption(context).copyWith(
                          color: colors.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: B05Layout.space20),

              // Close action
              B05ActionButton(
                key: const Key('achievement_detail_close'),
                label: 'Done',
                icon: Icons.check_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calculates exact "X to go" math for tiered progression chains.
  static String? _calculateProgression(Achievement a) {
    switch (a.id) {
      // Volume chain: 1,000 -> 5,000 -> 10,000 kg
      case 'volume_1000':
        final remaining = (5000.0 - a.currentProgress).clamp(0.0, double.infinity);
        if (remaining == 0) return 'Next tier: Heavy Mover (5,000 kg) achieved!';
        return '${AchievementService.formatAmount(remaining)} kg to Heavy Mover (5,000 kg)';
      case 'volume_5000':
        final remaining = (10000.0 - a.currentProgress).clamp(0.0, double.infinity);
        if (remaining == 0) return 'Next tier: Titan Legend (10,000 kg) achieved!';
        return '${AchievementService.formatAmount(remaining)} kg to Titan Legend (10,000 kg)';
      case 'volume_10000':
        return a.isUnlocked
            ? 'Top tier reached! Maximum volume milestone achieved.'
            : '${AchievementService.formatAmount((10000.0 - a.currentProgress).clamp(0.0, double.infinity))} kg to Titan Legend';

      // Streaks chain: 7 -> 30 days
      case 'streak_7':
        final remaining = (30 - a.currentProgress.toInt()).clamp(0, 30);
        if (remaining == 0) return 'Next tier: Iron Discipline (30 days) achieved!';
        return '$remaining days to Iron Discipline (30 days)';
      case 'streak_30':
        return a.isUnlocked
            ? 'Top tier reached! 30-day streak milestone achieved.'
            : '${(30 - a.currentProgress.toInt()).clamp(0, 30)} days to Iron Discipline';

      // Meals chain: 10 -> 50 meals
      case 'meals_10':
        final remaining = (50 - a.currentProgress.toInt()).clamp(0, 50);
        if (remaining == 0) return 'Next tier: Macro Master (50 meals) achieved!';
        return '$remaining meals to Macro Master (50 meals)';
      case 'meals_50':
        return a.isUnlocked
            ? 'Top tier reached! 50 logged meals milestone achieved.'
            : '${(50 - a.currentProgress.toInt()).clamp(0, 50)} meals to Macro Master';

      // Single tier
      case 'first_workout':
        return a.isUnlocked
            ? 'Single tier milestone achieved.'
            : 'Complete 1 workout session to earn this badge.';
      case 'first_thali':
        return a.isUnlocked
            ? 'Single tier milestone achieved.'
            : 'Log 1 Indian Thali meal to earn this badge.';
      default:
        return null;
    }
  }

  static String _getBasisDisclosure(String id) {
    if (id.startsWith('volume_') || id == 'first_workout') {
      return 'Basis: Verified completed workout sessions and sets in local SQLite database. No synthetic or estimated PRs.';
    } else if (id.startsWith('streak_')) {
      return 'Basis: Consecutive calendar days with logged workouts or meals. Verified from local database history.';
    } else {
      return 'Basis: Food entries logged in your local food diary. Verified from local SQLite database.';
    }
  }
}

Future<void> showAchievementDetailSheet(
  BuildContext context, {
  required Achievement achievement,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.b05Colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(B05Radii.large),
      ),
    ),
    builder: (ctx) => AchievementDetailSheet(achievement: achievement),
  );
}
