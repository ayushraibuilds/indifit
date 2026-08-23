import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/fixtures/exercise_display_muscles.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import '../education/learn_screen.dart';
import '../media/b05_exercise_visual_registry.dart';
import 'exercise_details_sheet.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Exercise> _exercises = [];
  String _selectedMuscle = 'All';
  String _selectedEquipment = 'All';
  bool _loading = false;
  ProductFailurePresentation? _failure;

  final List<String> _muscleFilters = const [
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

  final List<String> _equipmentFilters = const [
    'All',
    'Bodyweight',
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
  ];

  Map<String, int> _muscleCounts = {};

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _loadExercises();
    });
    setState(() {});
  }

  Future<void> _loadExercises() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    try {
      final repo = ref.read(workoutRepositoryProvider);

      // Search matches name, equipment, or muscle in database
      final rawList = await repo.searchExercises(_searchController.text);

      final queryText = _searchController.text.trim().toLowerCase();
      final tokens = queryText.isEmpty
          ? const <String>[]
          : queryText.split(RegExp(r'\s+'));

      // Perform normalized token matching across name, equipment, and muscles
      final searchMatches = rawList.where((ex) {
        if (tokens.isEmpty) return true;
        final searchable = '${ex.name} ${ex.equipment} ${ex.muscleGroups}'
            .toLowerCase();
        return tokens.every(searchable.contains);
      }).toList();

      // Calculate counts for each muscle filter badge using canonical PRIMARY display muscle.
      final Map<String, int> counts = {'All': searchMatches.length};
      for (final m in _muscleFilters) {
        if (m == 'All') continue;
        counts[m] = searchMatches
            .where(
              (ex) => ExerciseDisplayMuscles.fromMuscleGroups(
                ex.muscleGroups,
              ).matchesPrimary(m),
            )
            .length;
      }

      // Filter by PRIMARY muscle category and equipment
      List<Exercise> filtered = searchMatches;
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

      // Sort: if search query present, sort by relevance score then alphabetical; else alphabetical
      if (tokens.isNotEmpty) {
        filtered.sort((a, b) {
          final scoreA = _searchScore(a.name, queryText);
          final scoreB = _searchScore(b.name, queryText);
          final cmp = scoreB.compareTo(scoreA);
          if (cmp != 0) return cmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      } else {
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      }

      if (!mounted) return;
      setState(() {
        _exercises = filtered;
        _muscleCounts = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _exercises = [];
        _failure = ProductFailurePresentation.fromError(
          e,
          title: 'Exercises unavailable',
        );
      });
    }
  }

  static int _searchScore(String name, String query) {
    final lowerName = name.toLowerCase().trim();
    final lowerQuery = query.toLowerCase().trim();
    if (lowerName == lowerQuery) return 3;
    if (lowerName.startsWith(lowerQuery)) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(b05ExerciseVisualRegistryProvider).valueOrNull ??
        const B05ExerciseVisualRegistry.empty();

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
            Semantics(
              textField: true,
              label: 'Search exercises',
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search bench press, squat, curl...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.b05Colors.textDisabled,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(
                            Icons.clear,
                            color: context.b05Colors.textSecondary,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
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

            // Error Card
            if (_failure != null) ...[
              ProductFailureCard(
                failure: _failure!,
                onRetry: _loadExercises,
              ),
              const SizedBox(height: 12),
            ],

            // Exercises List
            Expanded(
              child: _loading
                  ? const SkeletonList(count: 6)
                  : _exercises.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _exercises.length,
                      itemBuilder: (context, index) {
                        final ex = _exercises[index];
                        return _buildExerciseRow(context, ex, registry);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    Exercise ex,
    B05ExerciseVisualRegistry registry,
  ) {
    final displayMuscles = ExerciseDisplayMuscles.fromMuscleGroups(
      ex.muscleGroups,
    );
    final primaryMuscle = displayMuscles.primary ?? 'General';
    final equipment = ex.equipment.trim().isNotEmpty
        ? ex.equipment.trim()
        : 'Bodyweight';
    final secondaryMuscles = displayMuscles.secondary;
    final secondaryText = secondaryMuscles.isNotEmpty
        ? 'Also works ${secondaryMuscles.join(', ')}'
        : null;

    final semanticLabel = secondaryText != null
        ? '${ex.name}. Primary muscle $primaryMuscle. Equipment $equipment. $secondaryText. Tap to view details.'
        : '${ex.name}. Primary muscle $primaryMuscle. Equipment $equipment. Tap to view details.';

    return Card(
      margin: const EdgeInsets.only(bottom: B05Layout.space8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.b05Colors.border),
      ),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: B05Layout.space12,
            vertical: B05Layout.space4,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.b05Colors.inset,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.b05Colors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: ExerciseVisual(
                canonicalExerciseUuid: ex.stableId ?? '',
                registry: registry,
                displayMuscles: ExerciseVisualMuscleFacts(
                  primaryMuscle: displayMuscles.primary,
                  secondaryMuscles: displayMuscles.secondary,
                ),
                equipment: ex.equipment,
                decorative: true,
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: Text(
            ex.name,
            style: B05Typography.body(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$primaryMuscle · $equipment',
                  style: B05Typography.caption(context).copyWith(
                    color: context.b05Colors.textSecondary,
                  ),
                ),
                if (secondaryText != null)
                  Text(
                    secondaryText,
                    style: B05Typography.caption(context).copyWith(
                      color: context.b05Colors.textDisabled,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
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
              builder: (context) => ExerciseDetailsSheet(exercise: ex),
            );
          },
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
