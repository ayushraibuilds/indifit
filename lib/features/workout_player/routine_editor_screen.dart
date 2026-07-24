import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/database/app_database.dart';

class RoutineEditorScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const RoutineEditorScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _routineNameController = TextEditingController(text: 'My Custom Split');
  
  // Manual Builder state: list of custom days
  final List<_BuilderDayData> _builderDays = [
    _BuilderDayData(name: 'Push Day', dayOfWeek: 1, isRestDay: false, exercises: [
      RoutineExerciseInput(name: 'Push-Ups', sets: 3, repsRange: '10-15'),
    ]),
    _BuilderDayData(name: 'Pull Day', dayOfWeek: 2, isRestDay: false, exercises: [
      RoutineExerciseInput(name: 'Lat Pulldown', sets: 3, repsRange: '8-12'),
    ]),
    _BuilderDayData(name: 'Legs Day', dayOfWeek: 3, isRestDay: false, exercises: [
      RoutineExerciseInput(name: 'Bodyweight Squats', sets: 3, repsRange: '12-15'),
    ]),
    _BuilderDayData(name: 'Rest Day', dayOfWeek: 4, isRestDay: true, exercises: []),
  ];

  List<dynamic> _templates = [];
  bool _loadingTemplates = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/split_templates.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      if (mounted) {
        setState(() {
          _templates = list;
          _loadingTemplates = false;
        });
      }
    } catch (_) {
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
    final repo = ref.read(workoutRepositoryProvider);
    final String name = tpl['name'] ?? 'Workout Split';
    final String goal = tpl['goal'] ?? 'general';
    final String description = tpl['description'] ?? '';
    final List<dynamic> rawDays = tpl['days'] ?? [];

    final daysData = <RoutineDayWithExercises>[];
    for (final d in rawDays) {
      final String dayName = d['name'] ?? 'Training Day';
      final int dayOfWeek = d['dayOfWeek'] ?? (daysData.length + 1);
      final bool isRest = d['isRestDay'] ?? false;
      final List<dynamic> exList = d['exercises'] ?? [];

      final exercises = exList.map((ex) => RoutineExerciseInput(
        name: ex['name'] as String,
        sets: (ex['sets'] as num).toInt(),
        repsRange: ex['repsRange'] as String,
      )).toList();

      daysData.add(RoutineDayWithExercises(
        dayName: dayName,
        dayOfWeek: dayOfWeek,
        isRestDay: isRest,
        exercises: exercises,
      ));
    }

    await repo.saveRoutine(
      name: name,
      goal: goal,
      notes: description,
      days: daysData,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved routine: $name!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    }
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
    final daysData = _builderDays.map((d) => RoutineDayWithExercises(
      dayName: d.name,
      dayOfWeek: d.dayOfWeek,
      isRestDay: d.isRestDay,
      exercises: d.exercises,
    )).toList();

    await repo.saveRoutine(
      name: name,
      goal: 'custom',
      notes: 'Custom manual routine builder',
      days: daysData,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom split saved!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    }
  }

  void _addExerciseToDay(int dayIndex) async {
    final repo = ref.read(workoutRepositoryProvider);
    final exercises = await repo.searchExercises('');
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
            final filtered = exercises.where((e) => e.name.toLowerCase().contains(query.toLowerCase())).toList();
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
                              _builderDays[dayIndex].exercises.add(
                                RoutineExerciseInput(name: ex.name, sets: 3, repsRange: '8-12'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Split Builder', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'Templates'),
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual Builder'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplatesTab(),
          _buildManualBuilderTab(),
        ],
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

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final tpl = _templates[index];
        final String name = tpl['name'] ?? '';
        final String desc = tpl['description'] ?? '';
        final String eq = tpl['equipment'] ?? 'gym';
        final List<dynamic> days = tpl['days'] ?? [];
        final int activeDays = days.where((d) => !(d['isRestDay'] as bool? ?? false)).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: eq == 'bodyweight' ? Colors.blue.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        eq == 'bodyweight' ? 'Home / No Eq' : '$activeDays Days / Wk',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: eq == 'bodyweight' ? Colors.blue : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                const Text('DAY PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: days.map<Widget>((d) {
                    final bool isRest = d['isRestDay'] ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRest ? AppColors.surface : AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        d['name'],
                        style: TextStyle(
                          fontSize: 10,
                          color: isRest ? AppColors.textMuted : AppColors.textPrimary,
                          fontWeight: isRest ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _applyTemplate(tpl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Use This Split', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                  const Text('SPLIT DAYS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textMuted)),
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
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
                            label: Text(day.isRestDay ? 'Rest Day' : 'Training Day'),
                            onSelected: (val) => setState(() => day.isRestDay = val),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
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
                                  child: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: TextField(
                                    controller: TextEditingController(text: '${ex.sets}'),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Sets', isDense: true),
                                    onChanged: (v) {
                                      final parsed = int.tryParse(v);
                                      if (parsed != null && parsed > 0) {
                                        day.exercises[eIndex] = RoutineExerciseInput(
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
                                    controller: TextEditingController(text: ex.repsRange),
                                    decoration: const InputDecoration(labelText: 'Reps', isDense: true),
                                    onChanged: (v) {
                                      day.exercises[eIndex] = RoutineExerciseInput(
                                        name: ex.name,
                                        sets: ex.sets,
                                        repsRange: v,
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
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
                          label: const Text('Add Exercise', style: TextStyle(fontSize: 12)),
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
            child: ElevatedButton.icon(
              onPressed: _saveManualRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Split Routine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }
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
