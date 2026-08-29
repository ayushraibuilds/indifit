import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/di/providers.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../progress/r08f3_strength_performance_presentation.dart';
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
  final String? timezoneId;

  const ExerciseHistoryScreen({
    super.key,
    required this.exerciseName,
    this.stableExerciseId,
    this.timezoneId,
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
        oldWidget.stableExerciseId != widget.stableExerciseId ||
        oldWidget.timezoneId != widget.timezoneId) {
      _historyFuture = _loadHistory();
    }
  }

  Future<_ExerciseHistory> _loadHistory() async {
    final stableExerciseId = widget.stableExerciseId?.trim();
    if (stableExerciseId != null && stableExerciseId.isNotEmpty) {
      final canonical = await ref
          .read(b02ExercisePerformanceReadRepositoryProvider)
          .read(stableExerciseId: stableExerciseId);
      // A stable ID is an exact canonical query. Do not silently replace an
      // empty canonical result with legacy name history for a similarly named
      // exercise.
      return _ExerciseHistory.canonical(canonical);
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
    final summary = R08F3StrengthPerformancePresentation.summarize(history);
    return _buildActualHistory(
      heading: 'Actual performance',
      detail: _canonicalHistoryDetail(summary),
      summary: summary,
      records: [
        for (final record in history)
          _PerformanceHistoryItem(
            date: record.completedAt,
            sessionName: record.sessionName,
            status: _statusLabel(record.exerciseStatus, record.completionKind),
            isCanonical: true,
            wasSubstituted: record.wasSubstituted,
            expectedExerciseName: record.expectedExerciseName,
            sets: record.sets,
          ),
      ],
    );
  }

  static String _canonicalHistoryDetail(
    R08F3StrengthPerformanceSummary summary,
  ) {
    final sessions =
        '${summary.sessionCount} ${summary.sessionCount == 1 ? 'session' : 'sessions'}';
    if (summary.occurrenceCount == summary.sessionCount) {
      return '$sessions saved for this exercise.';
    }
    return '$sessions saved · ${summary.occurrenceCount} exercise entries saved.';
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
    R08F3StrengthPerformanceSummary? summary,
  }) => SingleChildScrollView(
    padding: const EdgeInsets.all(B05Layout.space16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HistoryHeader(heading: heading, detail: detail, summary: summary),
        if (summary != null) ...[
          const SizedBox(height: B05Layout.space16),
          _buildCanonicalTrend(summary),
        ],
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
                      DateFormat(
                        'MMM d, y',
                      ).format(_dateInHistoryTimezone(record.date)),
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
                if (record.wasSubstituted) ...[
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    record.expectedExerciseName == null
                        ? 'Replacement used in this session'
                        : 'Performed instead of ${record.expectedExerciseName}',
                    style: B05Typography.caption(
                      context,
                    ).copyWith(color: context.b05Colors.textSecondary),
                  ),
                ],
                const SizedBox(height: B05Layout.space12),
                if (record.isCanonical)
                  _R08F3PerformedSetList(sets: record.sets)
                else
                  R07CPerformedSetList(sets: record.sets),
              ],
            ),
          ),
          const SizedBox(height: B05Layout.space12),
        ],
      ],
    ),
  );

  static String _statusLabel(String status, [String? completionKind]) {
    if (completionKind == 'partial') return 'Partially complete';
    return switch (status) {
      'completed' => 'Completed',
      'partial' => 'Partially complete',
      'skipped' => 'Skipped',
      'inProgress' => 'In progress',
      _ => 'Logged',
    };
  }

  Widget _buildCanonicalTrend(R08F3StrengthPerformanceSummary summary) {
    final colors = context.b05Colors;
    if (summary.canShowTrend) {
      final points = summary.trendPoints;
      final basis = summary.trendBasis!;
      final values = [
        for (final point in points)
          '${DateFormat('MMM d').format(_dateInHistoryTimezone(point.completedAt))}: ${R08F3StrengthPerformancePresentation.formatTrendLoad(point)}${point.isPartial ? ' (partial session)' : ''}',
      ];
      return B05Surface(
        tone: B05SurfaceTone.inset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recorded load over sessions',
              style: B05Typography.title(context),
            ),
            const SizedBox(height: B05Layout.space4),
            Text(
              'Heaviest recorded working load · ${R08F3StrengthPerformancePresentation.formatLoadBasis(basis)}',
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: B05Layout.space12),
            Semantics(
              container: true,
              label: 'Recorded load over sessions. ${values.join('. ')}.',
              hint: 'The session values are also listed below the chart.',
              child: ExcludeSemantics(
                child: SizedBox(
                  key: const ValueKey('exercise_performance_load_chart'),
                  height: 180,
                  child: LineChart(
                    _performanceChartData(context, points),
                    duration: B05MotionPolicy.transitionDuration(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: B05Layout.space8),
            Text(
              'Session values: ${values.join(' · ')}',
              style: B05Typography.caption(
                context,
              ).copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      );
    }

    final detail = summary.hasMultipleOccurrencesPerSession
        ? 'A session contains this exercise more than once. Each entry is preserved below instead of merged into a chart.'
        : summary.sessionCount == 1
        ? 'One session saved. More sessions will show a factual comparison.'
        : summary.hasIncompleteTrend
        ? 'Some sessions do not have comparable load details. Their saved sets remain below.'
        : 'Recorded sets use different load units. Compare each saved session below.';
    return B05Surface(
      tone: B05SurfaceTone.inset,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.show_chart_rounded, color: colors.textSecondary),
          const SizedBox(width: B05Layout.space12),
          Expanded(child: Text(detail, style: B05Typography.body(context))),
        ],
      ),
    );
  }

  LineChartData _performanceChartData(
    BuildContext context,
    List<R08F3StrengthTrendPoint> points,
  ) {
    final colors = context.b05Colors;
    final loads = points.map((point) => point.loadKg).toList(growable: false);
    final minimum = loads.reduce(
      (first, second) => first < second ? first : second,
    );
    final maximum = loads.reduce(
      (first, second) => first > second ? first : second,
    );
    final spread = maximum - minimum;
    final padding = spread == 0
        ? (maximum == 0 ? 1 : maximum * .15)
        : spread * .2;
    final minY = (minimum - padding).clamp(0, double.infinity).toDouble();
    final maxY = (maximum + padding).toDouble();
    final ySpan = (maxY - minY).abs() < .001 ? 1.0 : maxY - minY;
    final maxX = (points.length - 1).toDouble();
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ySpan / 2,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: colors.border.withValues(alpha: .35), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: (44 * textScale).clamp(44.0, 72.0),
            interval: ySpan / 2,
            getTitlesWidget: (value, _) => Text(
              value.toStringAsFixed(0),
              style: B05Typography.caption(context),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: maxX == 0 ? 1 : maxX,
            getTitlesWidget: (value, _) {
              final index = value.round();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              if (index != 0 && index != points.length - 1) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  DateFormat(
                    'MMM d',
                  ).format(_dateInHistoryTimezone(points[index].completedAt)),
                  style: B05Typography.caption(context),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => colors.surfaceSubtle,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          getTooltipItems: (spots) => [
            for (final spot in spots)
              LineTooltipItem(
                '${DateFormat('MMM d').format(_dateInHistoryTimezone(points[spot.spotIndex].completedAt))}\n${R08F3StrengthPerformancePresentation.formatTrendLoad(points[spot.spotIndex])}',
                TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var index = 0; index < points.length; index++)
              FlSpot(index.toDouble(), points[index].loadKg),
          ],
          isCurved: false,
          color: colors.action,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 4,
              color: colors.section,
              strokeColor: colors.action,
              strokeWidth: 2,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.action.withValues(alpha: 0.16),
                colors.action.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlateCalculatorTab() {
    return const PlateCalculatorView(
      initialTargetWeight: 60.0,
      isEditable: true,
      showHeader: false,
      padding: EdgeInsets.all(B05Layout.space16),
    );
  }

  DateTime _dateInHistoryTimezone(DateTime instant) {
    final timezoneId = widget.timezoneId?.trim();
    if (timezoneId == null || timezoneId.isEmpty) return instant.toLocal();
    try {
      return tz.TZDateTime.from(
        instant.toUtc(),
        LocalScheduleDateService().locationFor(timezoneId),
      );
    } on ArgumentError {
      // Legacy callers without a valid stored timezone keep their established
      // device-local presentation. Progress always supplies a validated zone.
      return instant.toLocal();
    }
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
    this.isCanonical = false,
    this.wasSubstituted = false,
    this.expectedExerciseName,
  });

  final DateTime date;
  final String sessionName;
  final String? status;
  final bool isCanonical;
  final bool wasSubstituted;
  final String? expectedExerciseName;
  final List<B02PerformedSet> sets;
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.heading,
    required this.detail,
    this.summary,
  });

  final String heading;
  final String detail;
  final R08F3StrengthPerformanceSummary? summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return B05Surface(
      tone: B05SurfaceTone.inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.action.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: colors.action,
                  size: B05Layout.iconMedium,
                ),
              ),
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
          if (summary != null &&
              (summary!.latestRecordedSet != null ||
                  summary!.heaviestRecordedSet != null ||
                  summary!.comparisonText != null ||
                  summary!.partialSessionCount > 0)) ...[
            const SizedBox(height: B05Layout.space16),
            Divider(color: context.b05Colors.border),
            const SizedBox(height: B05Layout.space12),
            if (summary!.latestRecordedSet case final latest?) ...[
              Text(
                'Latest recorded set',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: B05Layout.space4),
              Semantics(
                label:
                    'Latest recorded set: ${R08F3StrengthPerformancePresentation.formatActualFact(latest)}',
                child: ExcludeSemantics(
                  child: Text(
                    R08F3StrengthPerformancePresentation.formatActualFact(
                      latest,
                    ),
                    style: B05Typography.title(context),
                  ),
                ),
              ),
            ],
            if (summary!.heaviestRecordedSet case final heaviest?) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                'Heaviest working set (${R08F3StrengthPerformancePresentation.formatLoadBasis(summary!.trendBasis!)})',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: B05Layout.space4),
              Semantics(
                label:
                    'Heaviest working set, ${R08F3StrengthPerformancePresentation.formatLoadBasis(summary!.trendBasis!)}: ${R08F3StrengthPerformancePresentation.formatActualFact(heaviest)}',
                child: ExcludeSemantics(
                  child: Text(
                    R08F3StrengthPerformancePresentation.formatActualFact(
                      heaviest,
                    ),
                    style: B05Typography.title(context),
                  ),
                ),
              ),
            ],
            if (summary!.comparisonText case final comparison?) ...[
              const SizedBox(height: B05Layout.space8),
              Text(comparison, style: B05Typography.body(context)),
            ],
            if (summary!.partialSessionCount > 0) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                '${summary!.partialSessionCount} ${summary!.partialSessionCount == 1 ? 'partial session is' : 'partial sessions are'} labelled below.',
                style: B05Typography.caption(context),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _R08F3PerformedSetList extends StatelessWidget {
  const _R08F3PerformedSetList({required this.sets});

  final List<B02PerformedSet> sets;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const SizedBox.shrink();
    final colors = context.b05Colors;
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final set in sets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Semantics(
                label:
                    'Logged set ${R08F3StrengthPerformancePresentation.formatActualSet(set)}',
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: colors.success.foreground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          R08F3StrengthPerformancePresentation.formatActualSet(
                            set,
                          ),
                          style: B05Typography.body(
                            context,
                          ).copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
