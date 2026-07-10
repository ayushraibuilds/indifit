import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import 'exercise_history_screen.dart';

class ExerciseDetailsSheet extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailsSheet({super.key, required this.exercise});

  Future<void> _launchYouTube() async {
    if (exercise.youtubeId == null) return;
    
    final url = Uri.parse('https://www.youtube.com/watch?v=${exercise.youtubeId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> muscles = exercise.muscleGroups.split(',');
    final List<String> cues = exercise.formCues.split('\n');
    final List<String> mistakes = exercise.commonMistakes.split('\n');

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Exercise Name & Difficulty
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGlow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    exercise.difficulty,
                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),

            // Muscle Groups & Equipment Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...muscles.map((m) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(m, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('🔧 ${exercise.equipment}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                )
              ],
            ),
            const Divider(color: AppColors.border, height: 32),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close sheet first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExerciseHistoryScreen(exerciseName: exercise.name),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_rounded),
              label: const Text('View 1RM Trend & Plate Calc'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // YouTube Video Link
            if (exercise.youtubeId != null) ...[
              const Text('INSTRUCTION VIDEO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _launchYouTube,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage('https://img.youtube.com/vi/${exercise.youtubeId}/0.jpg'),
                      fit: BoxFit.cover,
                      opacity: 0.65,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 64,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Form Cues List
            const Text('FORM CUES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0)),
            const SizedBox(height: 10),
            ...cues.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.key + 1}. ', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      )
                    ],
                  ),
                )),
            const SizedBox(height: 24),

            // Common Mistakes List
            const Text('COMMON MISTAKES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger, letterSpacing: 1.0)),
            const SizedBox(height: 10),
            ...mistakes.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m,
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      )
                    ],
                  ),
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
