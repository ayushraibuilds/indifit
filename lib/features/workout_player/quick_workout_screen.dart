import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';

/// The immutable input snapshot for a standalone B02 session. The draft owns
/// the live set state; this payload only records the exercise identities the
/// user chose for this Quick Workout.
String quickWorkoutSnapshotJson(String routineName) => jsonEncode({
  'version': 1,
  'routineName': routineName,
  'prescriptions': const <Map<String, dynamic>>[],
});

class QuickWorkoutScreen extends ConsumerStatefulWidget {
  const QuickWorkoutScreen({super.key});

  @override
  ConsumerState<QuickWorkoutScreen> createState() => _QuickWorkoutScreenState();
}

class _QuickWorkoutScreenState extends ConsumerState<QuickWorkoutScreen> {
  var _isStarting = false;

  Future<void> _addExerciseAndStart() async {
    if (_isStarting) return;
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QuickExercisePicker(),
    );
    if (exercise?.stableId == null || !mounted) return;

    setState(() => _isStarting = true);
    try {
      final adapter = ref.read(strengthExecutionCompatibilityAdapterProvider);
      final initial = await adapter.startUnscheduledDraft(
        routineName: 'Quick workout',
        executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
        snapshotId: const Uuid().v4(),
      );
      final withExercise = await adapter.addUnscheduledExercise(
        launch: initial,
        exerciseId: exercise!.stableId!,
        exerciseName: exercise.name,
      );
      final prepared = await adapter.prepareExecution(withExercise);
      if (!mounted) return;
      await context.push(
        '/b02-strength-player',
        extra: {'launch': withExercise.copyWith(state: prepared.state)},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quick workout could not start: $error')),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick workout'),
        actions: [
          B05IconAction(
            icon: Icons.close_rounded,
            label: 'Close Quick Workout',
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(B05Layout.space24),
          child: B05Surface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 40,
                  color: context.b05Colors.action,
                ),
                const SizedBox(height: B05Layout.space12),
                Text('Start anywhere', style: B05Typography.pageTitle(context)),
                const SizedBox(height: B05Layout.space8),
                Text(
                  'Choose exercises as you go. No plan or schedule is required.',
                  style: B05Typography.body(context),
                ),
                const SizedBox(height: B05Layout.space20),
                SizedBox(
                  width: double.infinity,
                  child: B05ActionButton(
                    label: _isStarting ? 'Opening picker…' : 'Add exercise',
                    icon: Icons.add_rounded,
                    onPressed: _isStarting ? null : _addExerciseAndStart,
                  ),
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  'You can add exercises and extra sets throughout the session.',
                  style: B05Typography.caption(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Search-first picker shared by the Quick Workout entry and the live player.
/// It intentionally uses the same local Exercise Library query authority as
/// the full Exercise Library screen.
class QuickExercisePicker extends ConsumerStatefulWidget {
  const QuickExercisePicker({super.key});

  @override
  ConsumerState<QuickExercisePicker> createState() =>
      _QuickExercisePickerState();
}

class _QuickExercisePickerState extends ConsumerState<QuickExercisePicker> {
  final _searchController = TextEditingController();
  var _loading = true;
  List<Exercise> _exercises = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_load);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final rows = await ref
          .read(workoutRepositoryProvider)
          .searchExercises(_searchController.text);
      if (!mounted) return;
      setState(() {
        _exercises = rows
            .where((exercise) => exercise.stableId?.trim().isNotEmpty == true)
            .toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space12,
        B05Layout.space16,
        B05Layout.space16 + bottomInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add exercise',
                    style: B05Typography.pageTitle(context),
                  ),
                ),
                B05IconAction(
                  icon: Icons.close_rounded,
                  label: 'Close exercise picker',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: B05Layout.space12),
            TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search exercises',
                hintText: 'Bench press, squat, row…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: B05Layout.space8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _exercises.isEmpty
                  ? const Center(child: Text('No matching exercises.'))
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _exercises.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final exercise = _exercises[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          minVerticalPadding: B05Layout.space8,
                          title: Text(exercise.name),
                          subtitle: Text(
                            '${exercise.equipment} · ${exercise.muscleGroups}',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.of(context).pop(exercise),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
