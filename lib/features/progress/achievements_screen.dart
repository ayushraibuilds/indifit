import 'package:flutter/material.dart';
import '../../core/services/achievement_service.dart';
import '../../core/theme/colors.dart';

class AchievementsScreen extends StatelessWidget {
  final int completedWorkoutsCount;
  final int currentStreakDays;
  final double totalVolumeKg;
  final int totalLoggedMealsCount;

  const AchievementsScreen({
    super.key,
    this.completedWorkoutsCount = 5,
    this.currentStreakDays = 4,
    this.totalVolumeKg = 850.0,
    this.totalLoggedMealsCount = 12,
  });

  @override
  Widget build(BuildContext context) {
    final achievements = AchievementService.evaluateAchievements(
      completedWorkoutsCount: completedWorkoutsCount,
      currentStreakDays: currentStreakDays,
      totalVolumeKg: totalVolumeKg,
      totalLoggedMealsCount: totalLoggedMealsCount,
    );

    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements & Badges'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unlocked summary banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 36),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount / ${achievements.length} Unlocked',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Keep training and logging to earn badges!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ALL BADGES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final item = achievements[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: item.isUnlocked ? AppColors.surface : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.isUnlocked ? item.color.withOpacity(0.4) : AppColors.border,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: item.isUnlocked ? item.color.withOpacity(0.15) : AppColors.border,
                          child: Icon(
                            item.icon,
                            color: item.isUnlocked ? item.color : AppColors.textMuted,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: item.isUnlocked ? Colors.white : AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progressPercentage,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item.isUnlocked ? item.color : AppColors.textMuted,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
