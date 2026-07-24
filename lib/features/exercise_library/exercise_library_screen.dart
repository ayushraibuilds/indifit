import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/skeleton_loader.dart';
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

  String _selectedEquipment = 'All';

  final List<String> _equipmentFilters = [
    'All',
    'Bodyweight',
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
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

  Map<String, int> _muscleCounts = {};

  Future<void> _loadExercises() async {
    setState(() => _loading = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      
      // Fuzzy search based on query
      final list = await repo.searchExercises(_searchController.text);
      
      // Calculate counts for each muscle filter badge
      final Map<String, int> counts = {'All': list.length};
      for (final m in _muscleFilters) {
        if (m == 'All') continue;
        counts[m] = list.where((ex) => ex.muscleGroups.toLowerCase().contains(m.toLowerCase())).length;
      }

      // Filter by muscle and equipment
      List<Exercise> filtered = list;
      if (_selectedMuscle != 'All') {
        filtered = filtered.where((ex) => ex.muscleGroups.toLowerCase().contains(_selectedMuscle.toLowerCase())).toList();
      }
      if (_selectedEquipment != 'All') {
        filtered = filtered.where((ex) => ex.equipment.toLowerCase().contains(_selectedEquipment.toLowerCase())).toList();
      }

      setState(() {
        _exercises = filtered;
        _muscleCounts = counts;
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
            const SizedBox(height: 8),

            // Horizontal Muscle Filters
            SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _muscleFilters.length,
                itemBuilder: (context, index) {
                  final muscle = _muscleFilters[index];
                  final isSelected = _selectedMuscle == muscle;
                  final count = _muscleCounts[muscle] ?? 0;
                  final labelText = '$muscle · $count';

                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    key: ValueKey('m_$muscle'),
                    child: ChoiceChip(
                      label: Text(labelText),
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
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // Equipment Filters Row
            SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _equipmentFilters.length,
                itemBuilder: (context, index) {
                  final eq = _equipmentFilters[index];
                  final isSelected = _selectedEquipment == eq;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    key: ValueKey('eq_$eq'),
                    child: ChoiceChip(
                      label: Text(eq),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedEquipment = eq;
                          });
                          _loadExercises();
                        }
                      },
                      selectedColor: Colors.blue.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.blue : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? Colors.blue : AppColors.border,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Exercises List
            Expanded(
              child: _loading
                  ? const SkeletonList(count: 6)
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
    final query = _searchController.text.trim();
    final message = query.isNotEmpty
        ? 'No exercises match "$query".\nTry a different search term or change muscle filters.'
        : 'No exercises found in database.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear Search'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
