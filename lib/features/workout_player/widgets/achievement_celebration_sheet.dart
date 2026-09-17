import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/services/achievement_service.dart';
import '../../../core/services/modal_queue_coordinator.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../progress/achievements_screen.dart';

/// Non-blocking bottom sheet presented after workout completion when one or
/// more milestones were unlocked during the session.
class AchievementCelebrationSheet extends StatefulWidget {
  final List<Achievement> achievements;
  final VoidCallback? onDismiss;

  const AchievementCelebrationSheet({
    super.key,
    required this.achievements,
    this.onDismiss,
  });

  @override
  State<AchievementCelebrationSheet> createState() =>
      _AchievementCelebrationSheetState();
}

class _AchievementCelebrationSheetState
    extends State<AchievementCelebrationSheet> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Announce to screen readers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.achievements.isEmpty) return;
      final titles = widget.achievements.map((a) => a.title).join(', ');
      final message = widget.achievements.length == 1
          ? 'Milestone unlocked: $titles!'
          : '${widget.achievements.length} milestones unlocked: $titles!';
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final isMulti = widget.achievements.length > 1;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return ConfettiOverlay(
      child: SafeArea(
        key: const Key('achievement_celebration_sheet'),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space20,
          B05Layout.space16,
          B05Layout.space20,
          B05Layout.space20,
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
              const SizedBox(height: B05Layout.space16),

              // Header celebration title
              Text(
                isMulti
                    ? '${widget.achievements.length} Milestones Reached!'
                    : 'Milestone Reached!',
                style: B05Typography.pageTitle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: B05Layout.space4),
              Text(
                'Honest progress, backed by your verified training data.',
                style: B05Typography.caption(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: B05Layout.space20),

              // Cards
              if (!isMulti)
                _buildAchievementCard(context, widget.achievements.first)
              else ...[
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    itemCount: widget.achievements.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildAchievementCard(
                          context,
                          widget.achievements[index],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: B05Layout.space12),
                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.achievements.length, (idx) {
                    final isSelected = idx == _currentIndex;
                    return AnimatedContainer(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isSelected ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? colors.action : colors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: B05Layout.space24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: B05ActionButton(
                      key: const Key('achievement_celebration_view_all'),
                      label: 'View Badges',
                      icon: Icons.emoji_events_rounded,
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AchievementsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: B05Layout.space12),
                  Expanded(
                    child: B05ActionButton(
                      key: const Key('achievement_celebration_done'),
                      label: 'Done',
                      icon: Icons.check_rounded,
                      emphasis: B05ActionEmphasis.primary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDismiss?.call();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildAchievementCard(BuildContext context, Achievement achievement) {
    final colors = context.b05Colors;
    final dateStr = achievement.unlockedAt != null
        ? DateFormat('d MMM yyyy').format(achievement.unlockedAt!.toLocal())
        : null;

    return B05Surface(
      tone: B05SurfaceTone.section,
      radius: B05SurfaceRadius.large,
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge Icon
          Container(
            padding: const EdgeInsets.all(B05Layout.space16),
            decoration: BoxDecoration(
              color: achievement.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: achievement.color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              achievement.icon,
              size: 40,
              color: achievement.color,
            ),
          ),
          const SizedBox(height: B05Layout.space12),

          // Title
          Text(
            achievement.title,
            style: B05Typography.title(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: B05Layout.space4),

          // Description
          Text(
            achievement.description,
            style: B05Typography.body(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: B05Layout.space12),

          // Factual Evidence & Date Box
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: B05Layout.space12,
              vertical: B05Layout.space8,
            ),
            decoration: BoxDecoration(
              color: colors.inset,
              borderRadius: BorderRadius.circular(B05Radii.medium),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: colors.success.indicator,
                    ),
                    const SizedBox(width: B05Layout.space4),
                    Flexible(
                      child: Text(
                        achievement.evidence,
                        style: B05Typography.caption(context).copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (dateStr != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Unlocked on $dateStr',
                    style: B05Typography.caption(context).copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAchievementCelebrationSheet(
  BuildContext context, {
  required List<Achievement> achievements,
  VoidCallback? onDismiss,
}) {
  if (achievements.isEmpty) return Future.value();
  return ModalQueueCoordinator.instance.enqueueModal<void>(
    context: context,
    showModal: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.b05Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(B05Radii.large),
        ),
      ),
      builder: (ctx) => AchievementCelebrationSheet(
        achievements: achievements,
        onDismiss: onDismiss,
      ),
    ),
  );
}
