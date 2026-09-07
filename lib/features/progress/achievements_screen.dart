import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/achievement_service.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/repositories/progress_statistics_repository.dart';
import '../dashboard/dashboard_controller.dart';
import 'widgets/achievement_detail_sheet.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Achievement> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statsRepo = ref.read(progressStatisticsRepositoryProvider);
      final prefs = await SharedPreferences.getInstance();
      final streak =
          prefs.getInt('user_streak_count') ??
          ref.read(dashboardControllerProvider).streakCount;

      final achievements = await AchievementService.recordAndEvaluate(
        statsRepository: statsRepo,
        currentStreakDays: streak,
      );

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Achievements could not be loaded. Try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements & Badges'), elevation: 0),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = context.b05Colors;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colors.action),
            const SizedBox(height: B05Layout.space16),
            Text(
              'Evaluating your achievements...',
              style: B05Typography.caption(context),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(B05Layout.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: colors.danger.indicator,
                size: 48,
              ),
              const SizedBox(height: B05Layout.space16),
              Text(
                'Failed to load achievements',
                style: B05Typography.title(context),
              ),
              const SizedBox(height: B05Layout.space8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space20),
              B05ActionButton(
                onPressed: _loadData,
                icon: Icons.refresh_rounded,
                label: 'Retry',
                emphasis: B05ActionEmphasis.secondary,
              ),
            ],
          ),
        ),
      );
    }

    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;
    final allComplete =
        _achievements.isNotEmpty && unlockedCount == _achievements.length;
    final recentlyUnlocked = AchievementService.getRecentlyUnlocked(_achievements);

    return ListView(
      padding: const EdgeInsets.all(B05Layout.space16),
      children: [
        // Unlocked summary banner
        Semantics(
          container: true,
          label: allComplete
              ? 'All 9 achievements unlocked! Incredible dedication.'
              : '$unlockedCount of ${_achievements.length} achievements unlocked. Keep training and logging to earn badges.',
          child: B05Surface(
            tone: allComplete
                ? B05SurfaceTone.selected
                : B05SurfaceTone.inset,
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: allComplete ? Colors.amber : colors.action,
                  size: 36,
                ),
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allComplete
                            ? 'All 9 Badges Unlocked!'
                            : '$unlockedCount / ${_achievements.length} Unlocked',
                        style: B05Typography.title(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        allComplete
                            ? 'Incredible dedication! You have earned every milestone.'
                            : 'Keep training and logging to earn badges!',
                        style: B05Typography.caption(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: B05Layout.space16),

        // Empty state when 0 unlocked
        if (unlockedCount == 0) ...[
          B05Surface(
            tone: B05SurfaceTone.section,
            padding: const EdgeInsets.all(B05Layout.space20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(B05Layout.space12),
                  decoration: BoxDecoration(
                    color: colors.action.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 36,
                    color: colors.action,
                  ),
                ),
                const SizedBox(height: B05Layout.space12),
                Text(
                  'No Badges Unlocked Yet',
                  style: B05Typography.title(context),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(
                  'Start logging workouts, meals, and maintaining your streak to earn your first achievement badge!',
                  textAlign: TextAlign.center,
                  style: B05Typography.body(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: B05Layout.space16),
        ],

        // Recently unlocked horizontal carousel
        if (recentlyUnlocked.isNotEmpty) ...[
          Text(
            'RECENTLY UNLOCKED',
            style: B05Typography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: B05Layout.space12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              key: const Key('recently_unlocked_carousel'),
              scrollDirection: Axis.horizontal,
              itemCount: recentlyUnlocked.length,
              separatorBuilder: (_, _) => const SizedBox(width: B05Layout.space12),
              itemBuilder: (context, index) {
                final item = recentlyUnlocked[index];
                final dateStr = item.unlockedAt != null
                    ? DateFormat('d MMM yyyy').format(item.unlockedAt!.toLocal())
                    : null;
                return InkWell(
                  borderRadius: BorderRadius.circular(B05Radii.large),
                  onTap: () => showAchievementDetailSheet(
                    context,
                    achievement: item,
                  ),
                  child: B05Surface(
                    tone: B05SurfaceTone.selected,
                    radius: B05SurfaceRadius.large,
                    padding: const EdgeInsets.symmetric(
                      horizontal: B05Layout.space16,
                      vertical: B05Layout.space12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: item.color.withValues(alpha: 0.2),
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        const SizedBox(width: B05Layout.space12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: B05Typography.label(context).copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (dateStr != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                dateStr,
                                style: B05Typography.caption(context).copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: B05Layout.space16),
        ],

        Text(
          'ALL BADGES',
          style: B05Typography.caption(
            context,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(height: B05Layout.space12),

        LayoutBuilder(
          builder: (context, _) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final useSingleColumn = textScale >= 1.5;
            final childAspectRatio = useSingleColumn
                ? (1.5 / textScale).clamp(0.65, 1.15)
                : 0.68;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: useSingleColumn ? 1 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                final item = _achievements[index];
                final dateStr = item.unlockedAt != null
                    ? DateFormat('d MMM yyyy').format(item.unlockedAt!.toLocal())
                    : null;
                final semanticLabel =
                    '${item.title}: ${item.description}. '
                    '${item.isUnlocked ? 'Unlocked on ${dateStr ?? 'record'}.' : 'Locked. ${(item.progressPercentage * 100).toInt()}% progress.'}';

                return Semantics(
                  container: true,
                  label: semanticLabel,
                  child: InkWell(
                    key: Key('achievement_card_${item.id}'),
                    borderRadius: BorderRadius.circular(B05Radii.large),
                    onTap: () => showAchievementDetailSheet(
                      context,
                      achievement: item,
                    ),
                    child: B05Surface(
                      tone: item.isUnlocked
                          ? B05SurfaceTone.selected
                          : B05SurfaceTone.inset,
                      radius: B05SurfaceRadius.large,
                      padding: const EdgeInsets.all(B05Layout.space12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: item.isUnlocked
                                    ? item.color.withValues(alpha: 0.2)
                                    : colors.border.withValues(alpha: 0.4),
                                child: Icon(
                                  item.icon,
                                  color: item.isUnlocked
                                      ? item.color
                                      : colors.textDisabled,
                                  size: 24,
                                ),
                              ),
                              if (item.isUnlocked)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: colors.section,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: item.color,
                                      size: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: B05Layout.space8),
                          Text(
                            item.title,
                            style: B05Typography.label(context).copyWith(
                              color: item.isUnlocked
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: B05Typography.caption(context),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Factual Evidence proof
                          Text(
                            item.evidence,
                            style: B05Typography.caption(context).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: item.isUnlocked
                                  ? colors.textSecondary
                                  : colors.textDisabled,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dateStr != null && item.isUnlocked) ...[
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: B05Typography.caption(context).copyWith(
                                fontSize: 9,
                                color: colors.textDisabled,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: B05Layout.space8),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: item.progressPercentage,
                            ),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, animVal, _) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: animVal,
                                  backgroundColor: colors.border.withValues(
                                    alpha: 0.5,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    item.isUnlocked
                                        ? item.color
                                        : colors.textDisabled,
                                  ),
                                  minHeight: 4,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
