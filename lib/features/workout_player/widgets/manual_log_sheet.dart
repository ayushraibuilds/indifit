import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/workout_repository.dart';

class ManualLogSheet extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final String? initialWorkoutName;

  const ManualLogSheet({
    super.key,
    required this.selectedDate,
    this.initialWorkoutName,
  });

  @override
  ConsumerState<ManualLogSheet> createState() => _ManualLogSheetState();
}

class _ManualLogSheetState extends ConsumerState<ManualLogSheet> {
  late TextEditingController _nameController;
  late TextEditingController _durationController;
  final List<_ManualExerciseInput> _exercises = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialWorkoutName ?? 'Completed Workout');
    _durationController = TextEditingController(text: '45');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _addExercise() async {
    final repo = ref.read(workoutRepositoryProvider);
    final allExercises = await repo.searchExercises('');
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = allExercises.where((e) => e.name.toLowerCase().contains(query.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search exercise library...',
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final ex = filtered[i];
                        return ListTile(
                          title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${ex.muscleGroups} • ${ex.equipment}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          onTap: () {
                            setState(() {
                              _exercises.add(
                                _ManualExerciseInput(
                                  exerciseName: ex.name,
                                  sets: [
                                    _SetInput(weightKg: 40.0, reps: 10),
                                    _SetInput(weightKg: 40.0, reps: 10),
                                    _SetInput(weightKg: 40.0, reps: 10),
                                  ],
                                ),
                              );
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveLoggedSession() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a session title.')));
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one exercise.')));
      return;
    }

    final durationMins = int.tryParse(_durationController.text) ?? 45;
    final repo = ref.read(workoutRepositoryProvider);

    final setCompanions = <WorkoutSetsCompanion>[];
    double totalVol = 0.0;
    for (final ex in _exercises) {
      for (int i = 0; i < ex.sets.length; i++) {
        final s = ex.sets[i];
        totalVol += (s.weightKg * s.reps);
        setCompanions.add(
          WorkoutSetsCompanion(
            exerciseName: Value(ex.exerciseName),
            setNumber: Value(i + 1),
            reps: Value(s.reps),
            weight: Value(s.weightKg),
          ),
        );
      }
    }

    final int estCalories = (durationMins * 5.5).round();

    await repo.logSession(
      name: name,
      volume: totalVol,
      durationSeconds: durationMins * 60,
      calories: estCalories,
      sets: setCompanions,
      completedAt: widget.selectedDate,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged "$name" for ${widget.selectedDate.day}/${widget.selectedDate.month}!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 12.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Log Completed Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Chip(
                label: Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.primaryGlow,
                labelStyle: const TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Workout Title', isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (min)', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('EXERCISES LOGGED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              TextButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Exercise', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Expanded(
            child: _exercises.isEmpty
                ? Center(
                    child: TextButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.fitness_center_rounded),
                      label: const Text('Tap to add exercises to this log'),
                    ),
                  )
                : ListView.builder(
                    itemCount: _exercises.length,
                    itemBuilder: (context, exIdx) {
                      final ex = _exercises[exIdx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ex.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                    onPressed: () => setState(() => _exercises.removeAt(exIdx)),
                                  ),
                                ],
                              ),
                              ...ex.sets.asMap().entries.map((setEntry) {
                                final sIdx = setEntry.key;
                                final setInput = setEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Text('Set ${sIdx + 1}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          controller: TextEditingController(text: '${setInput.weightKg}'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(labelText: 'kg', isDense: true),
                                          onChanged: (v) => setInput.weightKg = double.tryParse(v) ?? 0.0,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          controller: TextEditingController(text: '${setInput.reps}'),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(labelText: 'reps', isDense: true),
                                          onChanged: (v) => setInput.reps = int.tryParse(v) ?? 0,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textMuted),
                                        onPressed: () {
                                          setState(() {
                                            ex.sets.removeAt(sIdx);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    final lastWeight = ex.sets.isNotEmpty ? ex.sets.last.weightKg : 40.0;
                                    final lastReps = ex.sets.isNotEmpty ? ex.sets.last.reps : 10;
                                    ex.sets.add(_SetInput(weightKg: lastWeight, reps: lastReps));
                                  });
                                },
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Add Set', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveLoggedSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Save Workout Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualExerciseInput {
  String exerciseName;
  List<_SetInput> sets;

  _ManualExerciseInput({
    required this.exerciseName,
    required this.sets,
  });
}

class _SetInput {
  double weightKg;
  int reps;

  _SetInput({
    required this.weightKg,
    required this.reps,
  });
}
