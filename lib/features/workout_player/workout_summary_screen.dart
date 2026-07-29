import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  final String routineName;
  final int elapsedSeconds;
  final List<WorkoutSetsCompanion> loggedSets;

  const WorkoutSummaryScreen({
    super.key,
    required this.routineName,
    required this.elapsedSeconds,
    required this.loggedSets,
  });

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  bool _isSaving = false;

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _calculateTotalVolume() {
    double total = 0;
    for (final set in widget.loggedSets) {
      final double weight = set.weight.value;
      final int reps = set.reps.value;
      total += weight * reps;
    }
    return total;
  }

  int _calculateCaloriesBurned() {
    // Basic estimation: approx 6.5 kcal burned per minute of active workout
    final minutes = widget.elapsedSeconds / 60.0;
    return (minutes * 6.5).round();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.logSession(
        name: widget.routineName,
        volume: _calculateTotalVolume(),
        durationSeconds: widget.elapsedSeconds,
        calories: _calculateCaloriesBurned(),
        sets: widget.loggedSets,
      );

      // Delete active draft ONLY AFTER durable session logging succeeds
      await repo.deleteActiveDraft();

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context); // Exit summary and return to split view
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save session: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalVolume = _calculateTotalVolume();
    final int calories = _calculateCaloriesBurned();
    final String durationText = _formatDuration(widget.elapsedSeconds);

    // Group sets by exercise name for summary listing
    final Map<String, List<WorkoutSetsCompanion>> grouped = {};
    for (final set in widget.loggedSets) {
      final name = set.exerciseName.value;
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(set);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        automaticallyImplyLeading: false, // Don't allow backing out to player
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Celebration Emoji Header
                    const Center(
                      child: Text('🏆', style: TextStyle(fontSize: 64)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Workout Crushed!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.routineName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Metrics Grid (Volume, Duration, Calories)
                    Row(
                      children: [
                        _buildMetricCard(
                          context,
                          'Total Volume',
                          '${totalVolume.round()} kg',
                          Icons.fitness_center_rounded,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          context,
                          'Duration',
                          durationText,
                          Icons.timer_outlined,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          context,
                          'Active Burn',
                          '$calories kcal',
                          Icons.local_fire_department_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Completed Exercises Section Header
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'EXERCISES COMPLETED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Exercises sets summary rows
                    ...grouped.entries.map((entry) {
                      final exName = entry.key;
                      final sets = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: sets.map((s) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      'Set ${s.setNumber.value}: ${s.weight.value}kg x ${s.reps.value}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Share Summary Button
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      final text =
                          'Crushed my workout today! 🏋️\n'
                          'Routine: ${widget.routineName}\n'
                          'Volume Lifted: ${totalVolume.round()} kg\n'
                          'Duration: $durationText\n'
                          'Burned: $calories kcal\n'
                          'Logged with IndiFit App ⚡';
                      Share.share(text);
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text(
                'Share Workout Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Save Workout Button with Multi-Tap Guard
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Workout & Exit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
