import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../workout_player/widgets/plate_calculator_sheet.dart';
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
  late Future<_ExerciseHistory> _historyFuture;
  var _historyInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    super.dispose();
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
    return const PlateCalculatorView(
      initialTargetWeight: 60.0,
      isEditable: true,
      showHeader: false,
      padding: EdgeInsets.all(B05Layout.space16),
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
