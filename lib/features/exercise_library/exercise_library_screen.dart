import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/fixtures/exercise_display_muscles.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import '../education/learn_screen.dart';
import 'exercise_details_sheet.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
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

      // Text search matches name, equipment, or any associated muscle in database
      final list = await repo.searchExercises(_searchController.text);

      // Calculate counts for each muscle filter badge using canonical PRIMARY display muscle.
      // Under frozen product audit rules, category browsing is strictly governed by primary muscle.
      final Map<String, int> counts = {'All': list.length};
      for (final m in _muscleFilters) {
        if (m == 'All') continue;
        counts[m] = list
            .where(
              (ex) => ExerciseDisplayMuscles.fromMuscleGroups(
                ex.muscleGroups,
              ).matchesPrimary(m),
            )
            .length;
      }

      // Filter by PRIMARY muscle category and equipment
      List<Exercise> filtered = list;
      if (_selectedMuscle != 'All') {
        filtered = filtered
            .where(
              (ex) => ExerciseDisplayMuscles.fromMuscleGroups(
                ex.muscleGroups,
              ).matchesPrimary(_selectedMuscle),
            )
            .toList();
      }
      if (_selectedEquipment != 'All') {
        filtered = filtered
            .where(
              (ex) => ex.equipment.toLowerCase().contains(
                _selectedEquipment.toLowerCase(),
              ),
            )
            .toList();
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
        actions: [
          Semantics(
            button: true,
            label: 'Mini lessons',
            hint: 'Opens offline lessons about training and nutrition.',
            child: IconButton(
              tooltip: 'Mini lessons',
              icon: const Icon(Icons.school_outlined),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LearnScreen())),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bench press, squat, curl...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.b05Colors.textDisabled,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: context.b05Colors.textSecondary,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),

            // Horizontal Muscle Filters
            SizedBox(
              height: B05Layout.minTouchTarget,
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
                      selectedColor: context.b05Colors.selected,
                      backgroundColor: context.b05Colors.inset,
                      labelStyle: B05Typography.caption(context).copyWith(
                        color: isSelected
                            ? context.b05Colors.action
                            : context.b05Colors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? context.b05Colors.action
                              : context.b05Colors.border,
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
              height: B05Layout.minTouchTarget,
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
                      selectedColor: context.b05Colors.selected,
                      backgroundColor: context.b05Colors.inset,
                      labelStyle: B05Typography.caption(context).copyWith(
                        color: isSelected
                            ? context.b05Colors.action
                            : context.b05Colors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? context.b05Colors.action
                              : context.b05Colors.border,
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
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      itemCount: _exercises.length,
                      itemBuilder: (context, index) {
                        final ex = _exercises[index];
                        final displayMuscles =
                            ExerciseDisplayMuscles.fromMuscleGroups(
                              ex.muscleGroups,
                            );
                        final muscleText = displayMuscles.all.join(', ');
                        final subtitleText = muscleText.isNotEmpty
                            ? '${ex.equipment} • $muscleText'
                            : ex.equipment;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            title: Text(
                              ex.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Icon(
                              Icons.info_outline_rounded,
                              color: context.b05Colors.action,
                              size: B05Layout.iconMedium,
                            ),
                            onTap: () {
                              showIndiFitBottomSheet<void>(
                                context: context,
                                semanticLabel: 'Exercise details',
                                builder: (context) =>
                                    ExerciseDetailsSheet(exercise: ex),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final query = _searchController.text.trim();
    final message = query.isNotEmpty
        ? 'No exercises match "$query".\nTry a different search term or change muscle filters.'
        : 'No exercises are available yet.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(B05Layout.space24),
        child: ProductEmptyState(
          icon: Icons.search_off_rounded,
          title: query.isNotEmpty
              ? 'No matching exercises'
              : 'No exercises yet',
          message: message,
          action: query.isNotEmpty ? _searchController.clear : null,
          actionLabel: query.isNotEmpty ? 'Clear search' : null,
          actionIcon: query.isNotEmpty ? Icons.clear_rounded : null,
        ),
      ),
    );
  }
}
