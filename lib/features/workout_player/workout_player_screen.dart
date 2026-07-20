import 'dart:async';
import 'dart:convert';
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
  final int initialExerciseIndex;
  final int initialSetIndex;
  final int initialElapsedSeconds;
  final List<WorkoutSetsCompanion>? initialLoggedSets;

  const WorkoutPlayerScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    this.initialExerciseIndex = 0,
    this.initialSetIndex = 0,
    this.initialElapsedSeconds = 0,
    this.initialLoggedSets,
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

  // New Rest Timer & Prior Session sets state
  List<WorkoutSet> _priorSets = [];
  final List<RoutineExercise> _activeExercises = [];
  WorkoutSet? _bestPrSet;
  double _suggestedWeight = 20.0;
  bool _isWarmUp = false;
  int? _selectedRpe;

  @override
  void initState() {
    super.initState();
    _activeExercises.addAll(widget.exercises);
    _currentExerciseIndex = widget.initialExerciseIndex;
    _currentSetIndex = widget.initialSetIndex;
    _elapsedSeconds = widget.initialElapsedSeconds;
    if (widget.initialLoggedSets != null) {
      _loggedSets.addAll(widget.initialLoggedSets!);
    }
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
    if (_activeExercises.isEmpty) return;
    
    final currentEx = _activeExercises[_currentExerciseIndex];
    final repo = ref.read(workoutRepositoryProvider);
    
    // 1. Try to fetch latest logged sets and PR for this exercise
    final latestSets = await repo.getLatestSetsForExercise(currentEx.exerciseName);
    final prSet = await repo.getPersonalRecord(currentEx.exerciseName);
    
    double weight = 20.0;
    int reps = 10;
    double suggested = 20.0;
    
    if (latestSets.isNotEmpty) {
      final setIndex = _currentSetIndex.clamp(0, latestSets.length - 1);
      final lastSet = latestSets[setIndex];
      weight = lastSet.weight;
      reps = lastSet.reps;
      
      // Parse reps target
      int targetRepMax = 10;
      final repsStr = currentEx.repsRange;
      if (repsStr.contains('-')) {
        final parts = repsStr.split('-');
        targetRepMax = int.tryParse(parts[1]) ?? 12;
      } else {
        targetRepMax = int.tryParse(repsStr) ?? 10;
      }
      
      // Heuristic: If reps met or exceeded targetRepMax, increment by 2.5 kg!
      if (lastSet.reps >= targetRepMax) {
        suggested = lastSet.weight + 2.5;
      } else {
        suggested = lastSet.weight;
      }
    } else {
      final repsStr = currentEx.repsRange;
      if (repsStr.contains('-')) {
        final parts = repsStr.split('-');
        final min = int.tryParse(parts[0]) ?? 8;
        final max = int.tryParse(parts[1]) ?? 12;
        reps = ((min + max) / 2).round();
      } else {
        reps = int.tryParse(repsStr) ?? 10;
      }
      suggested = 20.0;
    }

    if (mounted) {
      setState(() {
        _priorSets = latestSets;
        _bestPrSet = prSet;
        _suggestedWeight = suggested;
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

  int _getRecommendedRestSeconds(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('squat') || name.contains('deadlift') || name.contains('bench press')) {
      return 120;
    } else if (name.contains('curl') || name.contains('tricep') || name.contains('lateral') || name.contains('raise')) {
      return 60;
    }
    return 90;
  }

  Future<void> _completeSet() async {
    final currentEx = _activeExercises[_currentExerciseIndex];
    final double weight = double.tryParse(_weightController.text) ?? 0.0;
    final int reps = int.tryParse(_repsController.text) ?? 0;

    if (weight <= 0 || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight and reps.')),
      );
      return;
    }

    if (weight > 500.0 || reps > 100) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unusually High Input'),
          content: Text(
            'You entered ${weight.toStringAsFixed(1)} kg for $reps reps. Are you sure this is correct?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Edit'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Log'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
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
      isWarmUp: Value(_isWarmUp),
      rpe: Value(_selectedRpe),
    );

    _loggedSets.add(newSet);
    await _saveDraft();

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
      if (_currentExerciseIndex < _activeExercises.length - 1) {
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

    final currentEx = _activeExercises[_currentExerciseIndex];
    final recommendedRest = _getRecommendedRestSeconds(currentEx.exerciseName);

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        int secondsRemaining = recommendedRest;
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

            final progress = secondsRemaining / recommendedRest;

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
                  Text(
                    'Recommended rest for ${currentEx.exerciseName}: $recommendedRest seconds.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  
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

  Future<void> _substituteExercise() async {
    final repo = ref.read(workoutRepositoryProvider);
    final currentEx = _activeExercises[_currentExerciseIndex];
    
    final selectedExerciseName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const Text(
                    'Substitute Exercise',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search alternative exercise...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Exercise>>(
                      future: repo.searchExercises(searchQuery.isEmpty ? 'a' : searchQuery),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return const Center(child: Text('No matching exercises found.'));
                        }
                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final ex = items[index];
                            return ListTile(
                              title: Text(ex.name),
                              subtitle: Text(ex.muscleGroups),
                              onTap: () => Navigator.pop(context, ex.name),
                            );
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

    if (selectedExerciseName != null && mounted) {
      setState(() {
        _activeExercises[_currentExerciseIndex] = currentEx.copyWith(
          exerciseName: selectedExerciseName,
        );
      });
      await _prefillInputs();
      await _saveDraft();
    }
  }

  Future<void> _saveDraft() async {
    final repo = ref.read(workoutRepositoryProvider);
    final rawSets = _loggedSets.map((s) => {
      'sessionId': s.sessionId.value,
      'exerciseName': s.exerciseName.value,
      'weight': s.weight.value,
      'reps': s.reps.value,
      'setNumber': s.setNumber.value,
      'isPr': s.isPr.value,
    }).toList();
    final jsonStr = jsonEncode(rawSets);
    
    await repo.saveWorkoutDraft(
      WorkoutDraftsCompanion.insert(
        routineName: widget.routineName,
        currentExerciseIndex: _currentExerciseIndex,
        currentSetIndex: _currentSetIndex,
        elapsedSeconds: _elapsedSeconds,
        loggedSetsJson: jsonStr,
      ),
    );
  }

  Future<void> _finishWorkout() async {
    _workoutTimer?.cancel();
    final repo = ref.read(workoutRepositoryProvider);
    await repo.deleteActiveDraft();
    
    if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_activeExercises.isEmpty) {
      return const Scaffold(body: Center(child: Text('No exercises in this split.')));
    }

    final currentEx = _activeExercises[_currentExerciseIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Exit Workout?'),
            backgroundColor: AppColors.surface,
            content: const Text('Would you like to pause and save this workout as a draft, or discard your progress?'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await ref.read(workoutRepositoryProvider).deleteActiveDraft();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await _saveDraft();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save Draft'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
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
                      'EXERCISE ${_currentExerciseIndex + 1} of ${_activeExercises.length}',
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
                    value: (_currentExerciseIndex) / _activeExercises.length,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 30),

                // 2. Exercise details display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      currentEx.exerciseName,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                                    tooltip: 'Substitute Exercise',
                                    onPressed: _substituteExercise,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGlow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Rest: ${_getRecommendedRestSeconds(currentEx.exerciseName)}s',
                                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getExerciseFormCue(currentEx.exerciseName),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              'Target Effort: RPE 8 (2 reps in reserve)',
                              style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.trending_up_rounded, size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 4),
                            Text(
                              'Suggested Overload: ${_suggestedWeight.toStringAsFixed(1)} kg',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            if (_bestPrSet != null) ...[
                              const SizedBox(width: 16),
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'PR: ${_bestPrSet!.weight.toStringAsFixed(1)}kg x ${_bestPrSet!.reps} (1RM: ${(_bestPrSet!.weight * (1 + _bestPrSet!.reps / 30.0)).toStringAsFixed(1)}kg)',
                                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ]
                          ],
                        ),
                        if (_priorSets.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 4),
                          const Text(
                            'LAST SESSION:',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _priorSets.map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${s.weight}kg x ${s.reps}',
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            )).toList(),
                          ),
                        ]
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
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FilterChip(
                                label: Text(
                                  _isWarmUp ? 'Warm-Up Set' : 'Working Set',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isWarmUp ? AppColors.warning : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selected: _isWarmUp,
                                selectedColor: AppColors.warning.withOpacity(0.15),
                                onSelected: (val) {
                                  setState(() {
                                    _isWarmUp = val;
                                  });
                                },
                              ),
                              Row(
                                children: [
                                  const Text('RPE: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  DropdownButton<int?>(
                                    value: _selectedRpe,
                                    underline: const SizedBox(),
                                    hint: const Text('Optional', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    items: [
                                      const DropdownMenuItem<int?>(value: null, child: Text('None', style: TextStyle(fontSize: 11))),
                                      ...[6, 7, 8, 9, 10].map((rpe) => DropdownMenuItem<int?>(
                                        value: rpe,
                                        child: Text('@ RPE $rpe', style: const TextStyle(fontSize: 11)),
                                      )),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedRpe = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
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
    ),
  );
}
}
