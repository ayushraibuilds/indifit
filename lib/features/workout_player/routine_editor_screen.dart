import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/workout_repository.dart';

class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key});

  @override
  ConsumerState<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final TextEditingController _routineNameController = TextEditingController();
  final List<String> _days = ['Push (Chest/Shoulders/Triceps)', 'Pull (Back/Biceps)', 'Legs (Quads/Hamstrings)'];

  @override
  void dispose() {
    _routineNameController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    final name = _routineNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name.')),
      );
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    final routineDaysData = <RoutineDayWithExercises>[];
    for (int i = 0; i < _days.length; i++) {
      routineDaysData.add(
        RoutineDayWithExercises(
          dayName: _days[i],
          dayOfWeek: i + 1,
          isRestDay: false,
          exercises: [
            RoutineExerciseInput(name: 'Push Up / Bench Press', sets: 3, repsRange: '8-12'),
          ],
        ),
      );
    }

    await repo.saveRoutine(
      name: name,
      goal: 'hypertrophy',
      notes: 'Custom manual routine split',
      days: routineDaysData,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom routine saved!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Routine Builder'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _routineNameController,
              decoration: const InputDecoration(
                labelText: 'Routine Split Name (e.g. PPL 3-Day Split)',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TRAINING DAYS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: () {
                    setState(() {
                      _days.add('Custom Day ${_days.length + 1}');
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(_days[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () {
                          setState(() {
                            _days.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _saveRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Custom Routine', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
