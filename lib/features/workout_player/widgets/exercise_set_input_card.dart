import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../data/database/app_database.dart';
import 'plate_calculator_sheet.dart';

class ExerciseSetInputCard extends StatelessWidget {
  final RoutineExercise currentExercise;
  final int currentSetIndex;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final bool isWarmUp;
  final int? selectedRpe;
  final ValueChanged<bool> onWarmUpChanged;
  final ValueChanged<int?> onRpeChanged;
  final VoidCallback onCompleteSet;

  const ExerciseSetInputCard({
    super.key,
    required this.currentExercise,
    required this.currentSetIndex,
    required this.weightController,
    required this.repsController,
    required this.isWarmUp,
    required this.selectedRpe,
    required this.onWarmUpChanged,
    required this.onRpeChanged,
    required this.onCompleteSet,
  });

  String _getExerciseFormCue(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('bench press') || name.contains('chest press')) {
      return 'Form: Scapula retracted (shoulders back and down), chest up, flat feet on floor. Lower under control to touch your mid-chest and press up.';
    } else if (name.contains('shoulder press') || name.contains('overhead press')) {
      return 'Form: Keep core tight, avoid excessive arch in lower back. Drive weight straight up, keeping elbows slightly tucked.';
    } else if (name.contains('squat')) {
      return 'Form: Hips back first, push knees outward, keep chest high, brace core. Squat to parallel or lower.';
    } else if (name.contains('deadlift')) {
      return 'Form: Hinge at hips, keep flat back, pull bar close to shins. Drive feet into the ground to lock out.';
    } else if (name.contains('lat pulldown') || name.contains('pull')) {
      return 'Form: Pull shoulders down and back, pull down to upper chest using elbows, lean back slightly.';
    } else if (name.contains('curl') || name.contains('tricep') || name.contains('lateral') || name.contains('raise')) {
      return 'Form: Pin elbows, avoid swinging, squeeze targeted arm muscles.';
    }
    return 'Form: Perform with strict form. Keep core braced, breathe out on exertion, and control the negative phase.';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set ${currentSetIndex + 1} of ${currentExercise.sets}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 20),
                      tooltip: 'Plate Calculator',
                      onPressed: () {
                        final double w = double.tryParse(weightController.text) ?? 20.0;
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => PlateCalculatorSheet(targetWeight: w),
                        );
                      },
                    ),
                    FilterChip(
                      label: const Text('Warm-up', style: TextStyle(fontSize: 11)),
                      selected: isWarmUp,
                      selectedColor: Colors.orange.withValues(alpha: 0.2),
                      checkmarkColor: Colors.orange,
                      onSelected: (val) => onWarmUpChanged(val),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Reps Target: ${currentExercise.repsRange}',
                      suffixText: 'reps',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Rate of Perceived Exertion (RPE)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [6, 7, 8, 9, 10].map((rpe) {
                  final isSelected = selectedRpe == rpe;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text('@$rpe', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textSecondary)),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      onSelected: (val) => onRpeChanged(val ? rpe : null),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _getExerciseFormCue(currentExercise.exerciseName),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onCompleteSet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Log & Complete Set', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
