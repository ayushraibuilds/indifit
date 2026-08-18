import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/responsive_form_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../workout_player/widgets/r07c_workout_presentation.dart';

class R07CPerformanceEmptyState extends StatelessWidget {
  const R07CPerformanceEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 64,
              color: colors.textDisabled.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No performance logged yet',
              style: B05Typography.title(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Your logged sets will appear here after you train this exercise.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseHistoryScreen extends ConsumerStatefulWidget {
  final String exerciseName;
  final String? stableExerciseId;

  const ExerciseHistoryScreen({
    super.key,
    required this.exerciseName,
    this.stableExerciseId,
  });

  @override
  ConsumerState<ExerciseHistoryScreen> createState() =>
      _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends ConsumerState<ExerciseHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _targetWeightController = TextEditingController(
    text: '60',
  );
  double _barWeight = 20.0;
  Map<double, int> _calculatedPlates = {};
  double _unmatchedWeight = 0.0;
  late Future<_ExerciseHistory> _historyFuture;
  var _historyInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculatePlatesNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_historyInitialized) {
      _historyFuture = _loadHistory();
      _historyInitialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant ExerciseHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseName != widget.exerciseName ||
        oldWidget.stableExerciseId != widget.stableExerciseId) {
      _historyFuture = _loadHistory();
    }
  }

  Future<_ExerciseHistory> _loadHistory() async {
    final stableExerciseId = widget.stableExerciseId?.trim();
    if (stableExerciseId != null && stableExerciseId.isNotEmpty) {
      final canonical = await ref
          .read(b02ExercisePerformanceReadRepositoryProvider)
          .read(stableExerciseId: stableExerciseId);
      if (canonical.isNotEmpty) {
        return _ExerciseHistory.canonical(canonical);
      }
    }
    final legacy = await ref
        .read(workoutRepositoryProvider)
        .getExerciseHistory(widget.exerciseName);
    return _ExerciseHistory.legacy(legacy);
  }

  void _retryHistory() {
    setState(() => _historyFuture = _loadHistory());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _calculatePlatesNeeded() {
    final target = double.tryParse(_targetWeightController.text) ?? 0.0;
    if (target <= _barWeight) {
      setState(() {
        _calculatedPlates = {};
        _unmatchedWeight = 0.0;
      });
      return;
    }

    double weightPerSide = (target - _barWeight) / 2.0;
    final denominations = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
    final Map<double, int> result = {};

    for (final denom in denominations) {
      if (weightPerSide >= denom) {
        final count = (weightPerSide / denom).floor();
        result[denom] = count;
        weightPerSide -= count * denom;
      }
    }

    setState(() {
      _calculatedPlates = result;
      _unmatchedWeight = weightPerSide;
    });
  }

  Color _getPlateColor(double weight) {
    if (weight >= 25) return const Color(0xFFEF4444); // Red
    if (weight >= 20) return const Color(0xFF3B82F6); // Blue
    if (weight >= 15) return const Color(0xFFFBBF24); // Yellow
    if (weight >= 10) return const Color(0xFF10B981); // Green
    if (weight >= 5) return Colors.white70; // White
    if (weight >= 2.5) return Colors.grey; // Black
    return Colors.blueGrey; // Silver/Grey
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.action,
          labelColor: colors.action,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.insights_rounded), text: 'Performance'),
            Tab(icon: Icon(Icons.calculate_rounded), text: 'Plate Calc'),
          ],
        ),
      ),
      body: FutureBuilder<_ExerciseHistory>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return TabBarView(
              controller: _tabController,
              children: [
                Center(
                  child: Semantics(
                    label: 'Loading exercise history',
                    child: CircularProgressIndicator(color: colors.action),
                  ),
                ),
                _buildPlateCalculatorTab(),
              ],
            );
          }

          final history = snapshot.data;
          final historyTab = snapshot.hasError
              ? _HistoryErrorState(onRetry: _retryHistory)
              : history == null
              ? const R07CPerformanceEmptyState()
              : history.isCanonical
              ? _buildCanonicalHistoryTab(history.canonical)
              : _buildHistoryAndChartTab(history.legacy);

          return TabBarView(
            controller: _tabController,
            children: [historyTab, _buildPlateCalculatorTab()],
          );
        },
      ),
    );
  }

  Widget _buildCanonicalHistoryTab(List<B02ExercisePerformanceRecord> history) {
    if (history.isEmpty) return const R07CPerformanceEmptyState();
    return _buildActualHistory(
      heading: 'Actual performance',
      detail:
          '${history.length} ${history.length == 1 ? 'session' : 'sessions'} saved for this exercise.',
      records: [
        for (final record in history)
          _PerformanceHistoryItem(
            date: record.completedAt,
            sessionName: record.sessionName,
            status: _statusLabel(record.exerciseStatus),
            sets: record.sets,
          ),
      ],
    );
  }

  Widget _buildHistoryAndChartTab(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return const R07CPerformanceEmptyState();
    return _buildActualHistory(
      heading: 'Earlier workout records',
      detail: 'Saved sets from earlier workouts are shown below.',
      records: [
        for (final entry in history)
          _legacyHistoryItem(
            entry['session'] as WorkoutSession,
            entry['sets'] as List<WorkoutSet>,
          ),
      ],
    );
  }

  _PerformanceHistoryItem _legacyHistoryItem(
    WorkoutSession session,
    List<WorkoutSet> sets,
  ) => _PerformanceHistoryItem(
    date: session.completedAt,
    sessionName: session.name,
    sets: [
      for (final set in sets)
        B02PerformedSet(
          id: 'legacy-${session.id}-${set.id}',
          performedExerciseId: 'legacy-${session.id}',
          ordinal: set.setNumber > 0 ? set.setNumber - 1 : 0,
          role: set.isWarmUp ? B02SetRole.warmup : B02SetRole.working,
          actualLoadKg: set.weight > 0 ? set.weight : null,
          actualReps: set.reps > 0 ? set.reps : null,
          actualRpe: set.rpe,
        ),
    ],
  );

  Widget _buildActualHistory({
    required String heading,
    required String detail,
    required List<_PerformanceHistoryItem> records,
  }) => SingleChildScrollView(
    padding: const EdgeInsets.all(B05Layout.space16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        B05Surface(
          tone: B05SurfaceTone.selected,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, color: context.b05Colors.action),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: B05Typography.title(context)),
                    const SizedBox(height: B05Layout.space4),
                    Text(detail, style: B05Typography.body(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),
        Text('RECENT SESSIONS', style: B05Typography.label(context)),
        const SizedBox(height: B05Layout.space8),
        for (final record in records) ...[
          B05Surface(
            tone: B05SurfaceTone.section,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: B05Layout.space8,
                  runSpacing: B05Layout.space4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMM d, y').format(record.date.toLocal()),
                      style: B05Typography.label(context),
                    ),
                    if (record.status != null)
                      Text(
                        record.status!,
                        style: B05Typography.caption(
                          context,
                        ).copyWith(color: context.b05Colors.textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: B05Layout.space4),
                Text(record.sessionName, style: B05Typography.body(context)),
                const SizedBox(height: B05Layout.space12),
                R07CPerformedSetList(sets: record.sets),
              ],
            ),
          ),
          const SizedBox(height: B05Layout.space12),
        ],
      ],
    ),
  );

  static String _statusLabel(String status) => switch (status) {
    'completed' => 'Completed',
    'partial' => 'Partially complete',
    'skipped' => 'Skipped',
    'inProgress' => 'In progress',
    _ => 'Logged',
  };

  Widget _buildPlateCalculatorTab() {
    final colors = context.b05Colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLATE LOADING CALCULATOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  IndiFitResponsiveFieldGroup(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Weight (kg)',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _targetWeightController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculatePlatesNeeded(),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 100',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Barbell Weight (kg)',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<double>(
                            initialValue: _barWeight,
                            isExpanded: true,
                            dropdownColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 20.0,
                                child: Text(
                                  '20 kg (Std)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 15.0,
                                child: Text('15 kg'),
                              ),
                              DropdownMenuItem(
                                value: 10.0,
                                child: Text('10 kg'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _barWeight = val;
                                });
                                _calculatePlatesNeeded();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'LOADING PER SIDE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          if (_calculatedPlates.isEmpty && _unmatchedWeight == 0.0)
            B05Surface(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'Target weight is equal to or less than the barbell weight.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            )
          else
            B05Surface(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Visual plate layout
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Barbell shaft left
                          Container(width: 24, height: 6, color: Colors.grey),
                          // Loaded plates list
                          if (_calculatedPlates.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Empty Bar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textDisabled,
                                ),
                              ),
                            )
                          else
                            ..._calculatedPlates.entries.map((entry) {
                              final double plateWeight = entry.key;
                              final int count = entry.value;
                              return Row(
                                children: List.generate(
                                  count,
                                  (_) => Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    width: plateWeight >= 20 ? 14 : 8,
                                    height: plateWeight >= 20 ? 56 : 38,
                                    decoration: BoxDecoration(
                                      color: _getPlateColor(plateWeight),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: colors.border),
                                    ),
                                    alignment: Alignment.center,
                                    child: RotatedBox(
                                      quarterTurns: 1,
                                      child: Text(
                                        plateWeight % 1 == 0
                                            ? '${plateWeight.toInt()}'
                                            : '$plateWeight',
                                        style: TextStyle(
                                          color:
                                              plateWeight >= 20 ||
                                                  plateWeight <= 2.5
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          // Barbell sleeve end
                          Container(width: 12, height: 12, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Detail breakdown list
                    ..._calculatedPlates.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 8,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: _getPlateColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.key} kg Plate',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'x ${entry.value} per side',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.action,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_unmatchedWeight > 0.0) ...[
                      Divider(color: colors.border, height: 24),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Still to load',
                            style: TextStyle(color: colors.warning.foreground),
                          ),
                          Text(
                            '${_unmatchedWeight.toStringAsFixed(2)} kg per side',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.warning.foreground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseHistory {
  const _ExerciseHistory._({
    required this.canonical,
    required this.legacy,
    required this.isCanonical,
  });

  factory _ExerciseHistory.canonical(
    List<B02ExercisePerformanceRecord> records,
  ) => _ExerciseHistory._(
    canonical: List.unmodifiable(records),
    legacy: const [],
    isCanonical: true,
  );

  factory _ExerciseHistory.legacy(List<Map<String, dynamic>> records) =>
      _ExerciseHistory._(
        canonical: const [],
        legacy: List.unmodifiable(records),
        isCanonical: false,
      );

  final List<B02ExercisePerformanceRecord> canonical;
  final List<Map<String, dynamic>> legacy;
  final bool isCanonical;
}

class _PerformanceHistoryItem {
  const _PerformanceHistoryItem({
    required this.date,
    required this.sessionName,
    required this.sets,
    this.status,
  });

  final DateTime date;
  final String sessionName;
  final String? status;
  final List<B02PerformedSet> sets;
}

class _HistoryErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _HistoryErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(B05Layout.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_toggle_off_rounded, size: 42),
          const SizedBox(height: B05Layout.space12),
          Text(
            'Exercise history is unavailable right now.',
            style: B05Typography.title(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Your plate calculator is still ready to use. Try loading history again.',
            style: B05Typography.body(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: B05Layout.space16),
          B05ActionButton(
            label: 'Retry history',
            icon: Icons.refresh_rounded,
            emphasis: B05ActionEmphasis.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}
