import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import 'exercise_details_sheet.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _exercises = [];
  String _selectedMuscle = 'All';
  bool _loading = false;

  final List<String> _muscleFilters = [
    'All',
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Quads',
    'Glutes',
    'Hamstrings',
    'Core',
  ];

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _loading = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      
      // Fuzzy search based on query
      final list = await repo.searchExercises(_searchController.text);
      
      // If we have a muscle filter, apply it
      List<Exercise> filtered = list;
      if (_selectedMuscle != 'All') {
        filtered = list.where((ex) => ex.muscleGroups.toLowerCase().contains(_selectedMuscle.toLowerCase())).toList();
      }

      setState(() {
        _exercises = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bench press, squat, curl...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // Horizontal Muscle Filters
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _muscleFilters.length,
                itemBuilder: (context, index) {
                  final muscle = _muscleFilters[index];
                  final isSelected = _selectedMuscle == muscle;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    key: ValueKey(muscle),
                    child: ChoiceChip(
                      label: Text(muscle),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedMuscle = muscle;
                          });
                          _loadExercises();
                        }
                      },
                      selectedColor: AppColors.primaryGlow,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Exercises List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _exercises.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _exercises.length,
                          itemBuilder: (context, index) {
                            final ex = _exercises[index];
                            final muscles = ex.muscleGroups.split(',');
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${ex.equipment} • ${muscles.join(', ')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => ExerciseDetailsSheet(exercise: ex),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No exercises found.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        ],
      ),
    );
  }
}
