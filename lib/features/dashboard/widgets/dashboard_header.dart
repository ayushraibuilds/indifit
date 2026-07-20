import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';

class DashboardHeader extends StatelessWidget {
  final int streakCount;

  const DashboardHeader({
    super.key,
    required this.streakCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Greeting Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Namaste, Champ',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              const Text(
                'Crush your goals today!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Streak Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 14),
              const SizedBox(width: 2),
              Text(
                '${streakCount}d',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),

        // Actions Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          onSelected: (val) {
            if (val == 'planner') {
              context.push('/meal-planner');
            } else if (val == 'settings') {
              context.push('/settings');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'planner',
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('AI Meal Planner'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
