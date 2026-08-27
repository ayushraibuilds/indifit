import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_count_label.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/legacy_program_compatibility_adapter.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/workout_repository.dart';

class RoutineEditorScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const RoutineEditorScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _routineNameController = TextEditingController(
    text: 'My Custom Split',
  );
  int? _activeRoutineId;
  String? _activeProgramVersionId;
  final List<_BuilderDayData> _builderDays = [];

  List<dynamic> _templates = [];
  bool _loadingTemplates = true;
  bool _applyingTemplate = false;
  String? _templateActivationCommandId;
  String? _templateActivationKey;
  int? _templateRoutineId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadTemplates();
    _loadActiveRoutine();
  }

  Future<void> _loadActiveRoutine() async {
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final selection = await ref
          .read(legacyProgramCompatibilityAdapterProvider)
          .resolveActivePlanSelection();
      if (selection.type == ActivePlanType.b01Program) {
        if (mounted) {
          setState(() => _activeProgramVersionId = selection.programVersionId);
        }
        return;
      }
      if (selection.type == ActivePlanType.legacyRoutine) {
        final active = (await repo.getSavedRoutines()).singleWhere(
          (routine) => routine.id == selection.legacyRoutineId,
        );
        _activeRoutineId = active.id;
        _routineNameController.text = active.name;
        final details = await repo.getRoutineDetails(active.id);
        if (details.isNotEmpty && mounted) {
          final List<_BuilderDayData> loadedDays = [];
          for (final item in details) {
            final RoutineDay day = item['day'];
            final List<RoutineExercise> exercises =
                item['exercises'] as List<RoutineExercise>;
            loadedDays.add(
              _BuilderDayData(
                name: day.name,
                dayOfWeek: day.dayOfWeek,
                isRestDay: day.isRestDay,
                exercises: exercises
                    .map(
                      (e) => RoutineExerciseInput(
                        name: e.exerciseName,
                        sets: e.sets,
                        repsRange: e.repsRange,
                      ),
                    )
                    .toList(),
              ),
            );
          }
          setState(() {
            _builderDays.clear();
            _builderDays.addAll(loadedDays);
          });
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to load active routine for editor: $e');
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/split_templates.json',
      );
      final List<dynamic> list = jsonDecode(jsonStr);
      if (mounted) {
        setState(() {
          _templates = list;
          _loadingTemplates = false;
        });
      }
    } catch (e) {
      AppLogger.warning('Failed to load split_templates.json: $e');
      if (mounted) {
        setState(() => _loadingTemplates = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _routineNameController.dispose();
    super.dispose();
  }

  Future<void> _applyTemplate(Map<String, dynamic> tpl) async {
    if (_applyingTemplate) return;
    setState(() => _applyingTemplate = true);
    final repo = ref.read(workoutRepositoryProvider);
    final String name = tpl['name'] ?? 'Workout Split';
    final String goal = tpl['goal'] ?? 'general';
    final String description = tpl['description'] ?? '';
    final List<dynamic> rawDays = tpl['days'] ?? [];
    final templateKey = tpl['id']?.toString() ?? name;
    if (_templateActivationKey != templateKey) {
      _templateActivationKey = templateKey;
      _templateActivationCommandId = null;
      _templateRoutineId = null;
    }

    final daysData = <RoutineDayWithExercises>[];
    for (final d in rawDays) {
      final String dayName = d['name'] ?? 'Training Day';
      final int dayOfWeek = d['dayOfWeek'] ?? (daysData.length + 1);
      final bool isRest = d['isRestDay'] ?? false;
      final List<dynamic> exList = d['exercises'] ?? [];

      final exercises = exList
          .map(
            (ex) => RoutineExerciseInput(
              name: ex['name'] as String,
              sets: (ex['sets'] as num).toInt(),
              repsRange: ex['repsRange'] as String,
            ),
          )
          .toList();

      daysData.add(
        RoutineDayWithExercises(
          dayName: dayName,
          dayOfWeek: dayOfWeek,
          isRestDay: isRest,
          exercises: exercises,
        ),
      );
    }

    int? scheduledCount;
    try {
      final selection = await ref
          .read(legacyProgramCompatibilityAdapterProvider)
          .resolveActivePlanSelection();
      if (selection.type == ActivePlanType.b01Program) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                'A scheduled program is already active. Manage it before choosing another split.',
              ),
            ),
          );
        }
        return;
      }
      final routineId = await repo.saveRoutine(
        routineId: _templateRoutineId,
        name: name,
        goal: goal,
        notes: description,
        days: daysData,
      );
      _templateRoutineId = routineId;
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      _templateActivationCommandId ??=
          'template-routine-activation::${const Uuid().v4()}';
      final activation = await ref
          .read(legacyProgramCompatibilityAdapterProvider)
          .activateLegacyRoutineAsCanonical(
            legacyRoutineId: routineId,
            activationCoordinator: ref.read(
              programActivationCoordinatorProvider,
            ),
            dates: ref.read(localScheduleDateServiceProvider),
            timezoneId: timezoneId,
            commandId: _templateActivationCommandId!,
          );
      if (activation.occurrences.isEmpty) {
        throw StateError('Canonical activation created no workouts.');
      }
      scheduledCount = activation.occurrences.length;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Template activation failed '
            '[templateKey=$templateKey, routineId=$_templateRoutineId, '
            'commandId=$_templateActivationCommandId, errorType=${error.runtimeType}]',
        error,
        stackTrace,
        'TemplateActivation',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(_templateActivationFailureMessage(error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _applyingTemplate = false);
    }

    if (!mounted || scheduledCount == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      indiFitSuccessSnackBar(
        '✓ Program activated · '
        '${ConsumerCountLabel.format(scheduledCount, 'workout')} scheduled',
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _saveManualRoutine() async {
    final name = _routineNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a split name.')),
      );
      return;
    }

    if (_builderDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one day.')),
      );
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    final daysData = _builderDays
        .map(
          (d) => RoutineDayWithExercises(
            dayName: d.name,
            dayOfWeek: d.dayOfWeek,
            isRestDay: d.isRestDay,
            exercises: d.exercises,
          ),
        )
        .toList();

    await repo.saveRoutine(
      routineId: _activeRoutineId,
      name: name,
      goal: 'custom',
      notes: 'Custom manual routine builder',
      days: daysData,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Custom split saved!'),
          backgroundColor: context.b05Colors.success.indicator,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _addExerciseToDay(int dayIndex) async {
    final repo = ref.read(workoutRepositoryProvider);
    final exercises = await repo.searchExercises('');
    if (!mounted) return;

    final colors = context.b05Colors;

    await showIndiFitBottomSheet(
      context: context,
      semanticLabel: 'Search exercise library',
      maxHeightFactor: 0.85,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = exercises
                .where(
                  (e) => e.name.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
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
                          title: Text(
                            ex.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${ex.muscleGroups} • ${ex.equipment}',
                            style: B05Typography.caption(ctx).copyWith(fontSize: 11),
                          ),
                          trailing: Icon(
                            Icons.add_circle_outline,
                            color: colors.action,
                          ),
                          onTap: () {
                            setState(() {
                              _builderDays[dayIndex].exercises.add(
                                RoutineExerciseInput(
                                  name: ex.name,
                                  sets: 3,
                                  repsRange: '8-12',
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

  @override
  Widget build(BuildContext context) {
    if (_activeProgramVersionId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training plan')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your current plan is already scheduled.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open the calendar to view upcoming workouts, or create a new plan when you want to change your training.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.push('/calendar'),
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: const Text('Open calendar'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/program-author'),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change plan'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Routine Split Builder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.b05Colors.action,
          labelColor: context.b05Colors.action,
          unselectedLabelColor: context.b05Colors.textSecondary,
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_customize_rounded),
              text: 'Templates',
            ),
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual Builder'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTemplatesTab(), _buildManualBuilderTab()],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    if (_loadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templates.isEmpty) {
      return const Center(child: Text('No templates found.'));
    }

    final colors = context.b05Colors;

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final tpl = _templates[index];
        final String name = tpl['name'] ?? '';
        final String desc = tpl['description'] ?? '';
        final String eq = tpl['equipment'] ?? 'gym';
        final List<dynamic> days = tpl['days'] ?? [];
        final int activeDays = days
            .where((d) => !(d['isRestDay'] as bool? ?? false))
            .length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: B05Surface(
            radius: B05SurfaceRadius.large,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: B05Typography.title(context).copyWith(fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: eq == 'bodyweight'
                            ? colors.info.container
                            : colors.selected,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        eq == 'bodyweight'
                            ? 'Home / No Eq'
                            : '$activeDays Days / Wk',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: eq == 'bodyweight'
                              ? colors.info.indicator
                              : colors.action,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: B05Typography.caption(context).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  'DAY PREVIEW',
                  style: B05Typography.caption(context).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: days.map<Widget>((d) {
                    final bool isRest = d['isRestDay'] ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isRest
                            ? colors.inset
                            : colors.section,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        d['name'],
                        style: TextStyle(
                          fontSize: 10,
                          color: isRest
                              ? colors.textDisabled
                              : colors.textPrimary,
                          fontWeight: isRest
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _applyingTemplate
                        ? null
                        : () => _applyTemplate(tpl),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.action,
                      foregroundColor: colors.onAction,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _applyingTemplate ? 'Activating…' : 'Use This Split',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualBuilderTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _routineNameController,
                decoration: const InputDecoration(
                  labelText: 'Split Name',
                  hintText: 'e.g. 4-Day Upper / Lower',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SPLIT DAYS',
                    style: B05Typography.caption(context).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _builderDays.add(
                          _BuilderDayData(
                            name: 'Day ${_builderDays.length + 1}',
                            dayOfWeek: _builderDays.length + 1,
                            isRestDay: false,
                            exercises: [],
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Day'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _builderDays.length,
            itemBuilder: (context, dIndex) {
              final day = _builderDays[dIndex];
              final colors = context.b05Colors;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: B05Surface(
                  radius: B05SurfaceRadius.large,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: day.name,
                              decoration: const InputDecoration(
                                labelText: 'Day Title',
                                isDense: true,
                              ),
                              onChanged: (val) => day.name = val,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: day.isRestDay,
                            label: Text(
                              day.isRestDay ? 'Rest Day' : 'Training Day',
                            ),
                            onSelected: (val) =>
                                setState(() => day.isRestDay = val),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: colors.danger.indicator,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _builderDays.removeAt(dIndex);
                              });
                            },
                          ),
                        ],
                      ),
                      if (!day.isRestDay) ...[
                        const SizedBox(height: 8),
                        ...day.exercises.asMap().entries.map((entry) {
                          final eIndex = entry.key;
                          final ex = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    ex.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: '${ex.sets}',
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Sets',
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      final parsed = int.tryParse(v);
                                      if (parsed != null && parsed > 0) {
                                        day.exercises[eIndex] =
                                            RoutineExerciseInput(
                                              name: ex.name,
                                              sets: parsed,
                                              repsRange: ex.repsRange,
                                            );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 64,
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: ex.repsRange,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Reps',
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      day.exercises[eIndex] =
                                          RoutineExerciseInput(
                                            name: ex.name,
                                            sets: ex.sets,
                                            repsRange: v,
                                          );
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: colors.textDisabled,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      day.exercises.removeAt(eIndex);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => _addExerciseToDay(dIndex),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Add Exercise',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveManualRoutine,
              style: FilledButton.styleFrom(
                backgroundColor: context.b05Colors.action,
                foregroundColor: context.b05Colors.onAction,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Save Split Routine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _templateActivationFailureMessage(Object error) {
  if (error is ActivationRejectedException &&
      error.message.contains('existing workout draft')) {
    return 'Finish or discard your current workout before activating this program.';
  }
  return 'Program could not be activated. Your selected template is still available to retry.';
}

class _BuilderDayData {
  String name;
  int dayOfWeek;
  bool isRestDay;
  List<RoutineExerciseInput> exercises;

  _BuilderDayData({
    required this.name,
    required this.dayOfWeek,
    required this.isRestDay,
    required this.exercises,
  });
}
