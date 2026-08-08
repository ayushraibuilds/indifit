import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/legacy_workout_compatibility_adapter.dart';
import 'plate_calculator_sheet.dart';

class ExerciseSetInputCard extends StatelessWidget {
  final RoutineExercise currentExercise;
  final int currentSetIndex;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController durationController;
  final TextEditingController distanceController;
  final TextEditingController inclineController;
  final LegacyExerciseExecutionMetadata executionMetadata;
  final bool isWarmUp;
  final String selectedSetType;
  final int? selectedRpe;
  final ValueChanged<bool> onWarmUpChanged;
  final ValueChanged<String> onSetTypeChanged;
  final ValueChanged<int?> onRpeChanged;
  final VoidCallback onCompleteSet;

  const ExerciseSetInputCard({
    super.key,
    required this.currentExercise,
    required this.currentSetIndex,
    required this.weightController,
    required this.repsController,
    required this.durationController,
    required this.distanceController,
    required this.inclineController,
    required this.executionMetadata,
    required this.isWarmUp,
    required this.selectedSetType,
    required this.selectedRpe,
    required this.onWarmUpChanged,
    required this.onSetTypeChanged,
    required this.onRpeChanged,
    required this.onCompleteSet,
  });

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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.calculate_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  tooltip: 'Plate Calculator',
                  onPressed: () {
                    final double w =
                        double.tryParse(weightController.text) ?? 20.0;
                    showIndiFitBottomSheet<void>(
                      context: context,
                      builder: (context) =>
                          PlateCalculatorSheet(targetWeight: w),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
            if (executionMetadata.isCardio) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        suffixText: 'sec',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: distanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Distance',
                        suffixText: 'km',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: inclineController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Incline',
                        suffixText: '%',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Set Type',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      {'id': 'working', 'label': 'Working'},
                      {'id': 'warmup', 'label': 'Warm-up'},
                      {'id': 'dropset', 'label': 'Drop Set'},
                      {'id': 'amrap', 'label': 'AMRAP'},
                      {'id': 'failure', 'label': 'Failure'},
                    ].map((type) {
                      final isSelected = selectedSetType == type['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            type['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          onSelected: (val) {
                            if (val) onSetTypeChanged(type['id']!);
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rate of Perceived Exertion (RPE)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [6, 7, 8, 9, 10].map((rpe) {
                  final isSelected = selectedRpe == rpe;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      label: Text(
                        '@$rpe',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
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
                executionMetadata.formCue,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onCompleteSet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Log & Complete Set',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
