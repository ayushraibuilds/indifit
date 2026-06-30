import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import 'workout_summary_screen.dart';

class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  final String routineName;
  final List<RoutineExercise> exercises;

  const WorkoutPlayerScreen({
    super.key,
    required this.routineName,
    required this.exercises,
  });

  @override
  ConsumerState<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends ConsumerState<WorkoutPlayerScreen> {
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  
  // Workout timer
  Timer? _workoutTimer;
  int _elapsedSeconds = 0;
  
  // Track logged sets
  final List<WorkoutSetsCompanion> _loggedSets = [];
  
  // Input controllers
  final TextEditingController _weightController = TextEditingController(text: '20');
  final TextEditingController _repsController = TextEditingController(text: '10');

  // Confetti trigger
  bool _showPrConfetti = false;
  String _prExerciseName = '';
  double _prWeight = 0.0;
  int _prReps = 0;

  @override
  void initState() {
    super.initState();
    _startWorkoutTimer();
    _prefillInputs();
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    WakelockPlus.disable(); // Safety: make sure screen wake lock is turned off
    super.dispose();
  }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  Future<void> _prefillInputs() async {
    if (widget.exercises.isEmpty) return;
    
    final currentEx = widget.exercises[_currentExerciseIndex];
    final repo = ref.read(workoutRepositoryProvider);
    
    // 1. Try to fetch latest logged sets for this exercise
    final latestSets = await repo.getLatestSetsForExercise(currentEx.exerciseName);
    
    double weight = 20.0;
    int reps = 10;
    
    if (latestSets.isNotEmpty) {
      // Get the set corresponding to our current set index (or the last logged set if we have more sets now)
      final setIndex = _currentSetIndex.clamp(0, latestSets.length - 1);
      weight = latestSets[setIndex].weight;
      reps = latestSets[setIndex].reps;
    } else {
      // Fallback to repsRange parsed values
      final repsStr = currentEx.repsRange;
      if (repsStr.contains('-')) {
        final parts = repsStr.split('-');
        final min = int.tryParse(parts[0]) ?? 8;
        final max = int.tryParse(parts[1]) ?? 12;
        reps = ((min + max) / 2).round();
      } else {
        reps = int.tryParse(repsStr) ?? 10;
      }
    }

    if (mounted) {
      setState(() {
        _weightController.text = weight.toStringAsFixed(1);
        _repsController.text = reps.toString();
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _completeSet() async {
    final currentEx = widget.exercises[_currentExerciseIndex];
    final double weight = double.tryParse(_weightController.text) ?? 0.0;
    final int reps = int.tryParse(_repsController.text) ?? 0;

    if (weight <= 0 || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight and reps.')),
      );
      return;
    }

    // Check if PR using Epley 1RM calculation
    final repo = ref.read(workoutRepositoryProvider);
    final previousPr = await repo.getPersonalRecord(currentEx.exerciseName);
    
    bool isPr = false;
    final current1Rm = weight * (1 + reps / 30.0);
    
    if (previousPr != null) {
      final prev1Rm = previousPr.weight * (1 + previousPr.reps / 30.0);
      if (current1Rm > prev1Rm) {
        isPr = true;
        _triggerPrConfetti(currentEx.exerciseName, weight, reps);
      }
    } else {
      // First time logging is a PR
      isPr = true;
      _triggerPrConfetti(currentEx.exerciseName, weight, reps);
    }

    final newSet = WorkoutSetsCompanion.insert(
      sessionId: 0, // Temp placeholder, will be replaced in repo transaction
      exerciseName: currentEx.exerciseName,
      weight: weight,
      reps: reps,
      setNumber: _currentSetIndex + 1,
      isPr: Value(isPr),
    );

    _loggedSets.add(newSet);

    // Show Rest Timer Bottom Sheet
    await _showRestTimerBottomSheet();

    // Advance sets/exercises logic
    final totalSetsRequired = exSetsCount(currentEx.sets);
    if (_currentSetIndex < totalSetsRequired - 1) {
      // Advance to next set of same exercise
      setState(() {
        _currentSetIndex++;
      });
      await _prefillInputs();
    } else {
      // Completed all sets of this exercise
      if (_currentExerciseIndex < widget.exercises.length - 1) {
        setState(() {
          _currentExerciseIndex++;
          _currentSetIndex = 0;
        });
        await _prefillInputs();
      } else {
        // Workout Finished!
        _finishWorkout();
      }
    }
  }

  int exSetsCount(dynamic sets) {
    if (sets is int) return sets;
    return 3; // Fallback
  }

  void _triggerPrConfetti(String exerciseName, double weight, int reps) {
    setState(() {
      _prExerciseName = exerciseName;
      _prWeight = weight;
      _prReps = reps;
      _showPrConfetti = true;
    });
    // Vibrate on PR!
    Vibration.hasVibrator().then((hasVib) {
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 100, 100, 200]);
      }
    });
    // Auto turn off overlay after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showPrConfetti = false);
      }
    });
  }

  Future<void> _showRestTimerBottomSheet() async {
    // Keep screen awake during rest period
    WakelockPlus.enable();

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        int secondsRemaining = 90;
        Timer? timer;

        return StatefulBuilder(
          builder: (context, setTimerState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (secondsRemaining > 0) {
                setTimerState(() {
                  secondsRemaining--;
                });
              } else {
                t.cancel();
                // Vibration on complete
                Vibration.hasVibrator().then((hasVib) {
                  if (hasVib == true) {
                    Vibration.vibrate(duration: 500);
                  }
                });
                Navigator.pop(context); // Close bottom sheet
              }
            });

            final progress = secondsRemaining / 90.0;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rest Period',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Catch your breath before the next set.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 30),
                  
                  // Circular timer countdown ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      Text(
                        '$secondsRemaining',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Modify timers buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setTimerState(() {
                            secondsRemaining = (secondsRemaining - 15).clamp(0, 300);
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('-15s', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {
                          setTimerState(() {
                            secondsRemaining = (secondsRemaining + 15).clamp(0, 300);
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('+15s', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Skip rest button
                  ElevatedButton(
                    onPressed: () {
                      timer?.cancel();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardBackground,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Skip Rest'),
                  )
                ],
              ),
            );
          },
        );
      },
    );

    // Disable screen awake lock after rest is completed
    WakelockPlus.disable();
  }

  void _finishWorkout() {
    _workoutTimer?.cancel();
    
    // Save to summary
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutSummaryScreen(
          routineName: widget.routineName,
          elapsedSeconds: _elapsedSeconds,
          loggedSets: _loggedSets,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercises.isEmpty) {
      return const Scaffold(body: Center(child: Text('No exercises in this split.')));
    }

    final currentEx = widget.exercises[_currentExerciseIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routineName),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                _formatDuration(_elapsedSeconds),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Progress Header indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EXERCISE ${_currentExerciseIndex + 1} of ${widget.exercises.length}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    Text(
                      'SET ${_currentSetIndex + 1} of ${exSetsCount(currentEx.sets)}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentExerciseIndex) / widget.exercises.length,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 30),

                // 2. Exercise details display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentEx.exerciseName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Target: Keep your scapula retracted and press upward under control.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // 3. Weight/Reps log inputs card
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              // Weight input
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Weight (kg)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _weightController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                                          onPressed: () {
                                            double current = double.tryParse(_weightController.text) ?? 0.0;
                                            if (current > 2.5) {
                                              _weightController.text = (current - 2.5).toStringAsFixed(1);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                          onPressed: () {
                                            double current = double.tryParse(_weightController.text) ?? 0.0;
                                            _weightController.text = (current + 2.5).toStringAsFixed(1);
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 40),
                              
                              // Reps input
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Reps Target', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _repsController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                                          onPressed: () {
                                            int current = int.tryParse(_repsController.text) ?? 0;
                                            if (current > 1) {
                                              _repsController.text = (current - 1).toString();
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                          onPressed: () {
                                            int current = int.tryParse(_repsController.text) ?? 0;
                                            _repsController.text = (current + 1).toString();
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          
                          // Complete Set button
                          ElevatedButton(
                            onPressed: _completeSet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Log & Complete Set', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Finish Workout button
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: OutlinedButton(
                    onPressed: _finishWorkout,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Finish Workout Early', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
          
          // 5. Personal Record (PR) overlay panel
          if (_showPrConfetti)
            Container(
              color: AppColors.primary.withOpacity(0.15),
              child: Center(
                child: Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👑', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        const Text(
                          'NEW PERSONAL RECORD!',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_prExerciseName: ${_prWeight.toStringAsFixed(1)} kg x $_prReps reps',
                          style: const TextStyle(fontSize: 13),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}
