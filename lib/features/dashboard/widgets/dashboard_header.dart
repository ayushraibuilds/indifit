import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/daypart_greeting.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class DashboardHeader extends StatelessWidget {
  final int streakCount;
  final String? userName;

  const DashboardHeader({super.key, required this.streakCount, this.userName});

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final localNow = DateTime.now();
    final name = (userName != null && userName!.trim().isNotEmpty)
        ? userName!.trim()
        : 'Champ';

    return Row(
      children: [
        // Greeting Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${daypartGreeting(localNow)}, $name',
                style: B05Typography.title(context).copyWith(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                daypartSubtitle(localNow),
                style: B05Typography.caption(context).copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Streak Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.warning.container,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.warning.indicator.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: colors.warning.indicator,
                size: 14,
              ),
              const SizedBox(width: 2),
              Text(
                '${streakCount}d',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.warning.indicator,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: B05Layout.space4),

        // Direct Settings Button
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: colors.textSecondary,
            size: 20,
          ),
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}
