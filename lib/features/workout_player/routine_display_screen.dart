import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import '../onboarding/onboarding_wizard_screen.dart';
import 'workout_player_screen.dart';

class RoutineDisplayScreen extends ConsumerStatefulWidget {
  const RoutineDisplayScreen({super.key});

  @override
  ConsumerState<RoutineDisplayScreen> createState() => _RoutineDisplayScreenState();
}

class _RoutineDisplayScreenState extends ConsumerState<RoutineDisplayScreen> {
  WorkoutRoutine? _activeRoutine;
  List<Map<String, dynamic>> _routineDays = [];
  int _selectedDayOfWeek = DateTime.now().weekday; // 1 = Mon, 7 = Sun
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadActiveRoutine();
  }

  Future<void> _loadActiveRoutine() async {
    setState(() => _loading = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      final routines = await repo.getSavedRoutines();

      if (routines.isNotEmpty) {
        // Grab the latest saved routine
        final active = routines.last;
        final details = await repo.getRoutineDetails(active.id);
        
        setState(() {
          _activeRoutine = active;
          _routineDays = details;
          _loading = false;
        });
      } else {
        setState(() {
          _activeRoutine = null;
          _routineDays = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Split'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (_activeRoutine != null)
            IconButton(
              icon: const Icon(Icons.psychology_rounded, color: AppColors.primary),
              tooltip: 'Re-generate Split',
              onPressed: () async {
                final success = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (context) => const OnboardingWizardScreen()),
                );
                if (success == true) {
                  _loadActiveRoutine();
                }
              },
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _activeRoutine == null
              ? _buildEmptyState()
              : _buildRoutineLayout(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryGlow,
                borderRadius: BorderRadius.circular(40),
              ),
              padding: const EdgeInsets.all(20),
              child: const Icon(
                Icons.psychology_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Workout Split Generated',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Our AI Fitness Coach can design a custom training split matching your equipment, experience, and schedules.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final success = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (context) => const OnboardingWizardScreen()),
                );
                if (success == true) {
                  _loadActiveRoutine();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(200, 48),
              ),
              child: const Text('Generate Split with AI'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineLayout() {
    // Locate details for selected day
    final dayData = _routineDays.firstWhere(
      (d) => (d['day'] as RoutineDay).dayOfWeek == _selectedDayOfWeek,
      orElse: () => {
        'day': RoutineDay(id: 0, routineId: 0, dayOfWeek: _selectedDayOfWeek, name: 'Rest Day', isRestDay: true),
        'exercises': <RoutineExercise>[]
      },
    );

    final RoutineDay day = dayData['day'];
    final List<RoutineExercise> exercises = dayData['exercises'] as List<RoutineExercise>;

    return Column(
      children: [
        // 1. Horizontal Weekday Selector Card
        _buildWeeklyCalendarHeader(),
        const SizedBox(height: 24),

        // 2. Day Schedule Detail Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    if (day.isRestDay)
                      const Text(
                        '🧘 REST',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                      )
                    else
                      Text(
                        '${exercises.length} Exercises',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: day.isRestDay 
                      ? _buildRestDayState()
                      : _buildExercisesList(exercises),
                ),

                // 3. Start Workout Trigger CTA
                if (!day.isRestDay && exercises.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkoutPlayerScreen(
                              routineName: day.name,
                              exercises: exercises,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text('Start Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildWeeklyCalendarHeader() {
    final weekdaysShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final dayNum = index + 1;
          final isSelected = _selectedDayOfWeek == dayNum;
          
          // Check if this day is a rest day
          final daySplit = _routineDays.firstWhere(
            (d) => (d['day'] as RoutineDay).dayOfWeek == dayNum,
            orElse: () => {'day': null},
          );
          final RoutineDay? rDay = daySplit['day'];
          final isRest = rDay?.isRestDay ?? true;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayOfWeek = dayNum),
            child: Container(
              width: 44,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdaysShort[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    isRest ? Icons.spa_rounded : Icons.fitness_center_rounded,
                    size: 14,
                    color: isSelected 
                        ? Colors.white 
                        : (isRest ? AppColors.textMuted : AppColors.primary),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRestDayState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_rounded,
              size: 48,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Time to Recover',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your muscles grow during rest periods. Hydrate and eat well!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          )
        ],
      ),
    );
  }

  Widget _buildExercisesList(List<RoutineExercise> list) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final ex = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryGlow,
              foregroundColor: AppColors.primary,
              child: Text('${index + 1}'),
            ),
            title: Text(ex.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Target: ${ex.sets} Sets of ${ex.repsRange} Reps', style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
