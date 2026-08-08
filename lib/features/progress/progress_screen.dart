import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/app_colors_extension.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import '../coaching/b04_production_surface_widgets.dart';
import '../workout_player/routine_display_screen.dart';
import 'achievements_screen.dart';
import 'b02_progress_widgets.dart';
import 'widgets/progress_bmi_health_card.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Semantics(
      label: '$value $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: B05Typography.metric(context).copyWith(color: colors.action),
          ),
          Text(label, style: B05Typography.caption(context)),
        ],
      ),
    );
  }
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  // Activity map representing workouts logged on specific days
  final List<DateTime> _activityDays = [];
  final Map<DateTime, double> _volumeByDate = {};
  bool _loading = false;
  List<WorkoutSession> _sessions = [];
  List<BodyMeasurement> _measurements = [];
  double? _targetWeight;
  ProductFailurePresentation? _loadFailure;

  @override
  void initState() {
    super.initState();
    _loadProgressLogs();
  }

  Future<void> _loadProgressLogs() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      final list = await repo.getSessions();
      final measurements = await repo.getBodyMeasurements();
      final prefs = await SharedPreferences.getInstance();
      final targetW = prefs.getDouble('user_target_weight');

      final List<DateTime> act = [];
      final Map<DateTime, double> volMap = {};
      for (final s in list) {
        act.add(s.completedAt);
        final key = DateTime(
          s.completedAt.year,
          s.completedAt.month,
          s.completedAt.day,
        );
        volMap[key] = (volMap[key] ?? 0.0) + s.totalVolume;
      }

      if (!mounted) return;
      setState(() {
        _sessions = list;
        _activityDays.clear();
        _activityDays.addAll(act);
        _volumeByDate.clear();
        _volumeByDate.addAll(volMap);
        _measurements = measurements;
        _targetWeight = targetW;
        _loading = false;
        _loadFailure = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailure = ProductFailurePresentation.fromCode(
          'progress_unavailable',
          title: 'Progress is unavailable',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.emoji_events_rounded,
              color: context.appColors.achievementGold,
            ),
            tooltip: 'Achievements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AchievementsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: ConsumerStatusRow(
                label: 'Loading your progress',
                detail: 'Gathering recent activity and trends.',
                loading: true,
              ),
            )
          : _loadFailure != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ProductFailureCard(
                  failure: _loadFailure!,
                  onRetry: _loadProgressLogs,
                ),
              ),
            )
          : _hasNoMeaningfulData
          ? _buildNoProgressState()
          : RefreshIndicator(
              onRefresh: _loadProgressLogs,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOutcomeSummary(context),
                    const SizedBox(height: B05Layout.space20),
                    const B04WeeklyReviewCard(),
                    const SizedBox(height: B05Layout.space20),
                    Text(
                      'Activity',
                      style: B05Typography.caption(context).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_sessions.isNotEmpty) ...[
                      _buildGitHubHeatmap(context),
                      const SizedBox(height: 20),
                    ],
                    if (_measurements.isNotEmpty) ...[
                      Text(
                        'Weight trend',
                        style: B05Typography.caption(context).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildWeightChartCard(context),
                      const SizedBox(height: 12),
                      ProgressBmiHealthCard(
                        weightKg: _measurements.first.weight,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_sessions.isNotEmpty) ...[
                      Text(
                        'Strength trend',
                        style: B05Typography.caption(context).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVolumeChartCard(context),
                      const SizedBox(height: 20),
                    ],
                    ExpansionTile(
                      title: const Text('Training detail'),
                      subtitle: const Text(
                        'Activity, strength and muscle volume',
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: B02ProgressOverview(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  bool get _hasNoMeaningfulData => _sessions.isEmpty && _measurements.isEmpty;

  Widget _buildNoProgressState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ProductEmptyState(
          icon: Icons.auto_graph_rounded,
          title: 'Your progress starts here',
          message: 'Complete your first workout to see activity and trends.',
          action: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoutineDisplayScreen()),
            );
          },
          actionLabel: 'Start a workout',
          actionIcon: Icons.fitness_center_rounded,
        ),
      ),
    );
  }

  Widget _buildOutcomeSummary(BuildContext context) {
    final latestWeight = _measurements.isNotEmpty
        ? _measurements.first.weight
        : null;
    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your progress', style: B05Typography.pageTitle(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Small, consistent actions add up.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _ProgressMetric(value: '${_sessions.length}', label: 'sessions'),
              if (latestWeight != null)
                _ProgressMetric(
                  value: '${latestWeight.toStringAsFixed(1)} kg',
                  label: 'latest weight',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGitHubHeatmap(BuildContext context) {
    final colors = context.b05Colors;
    // We will render a 12-week grid (12 columns by 7 rows)
    final DateTime now = DateTime.now();
    final DateTime startDate = now.subtract(
      const Duration(days: 84),
    ); // 12 weeks ago

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Training consistency',
                  style: B05Typography.label(context),
                ),
                Text(
                  '${_activityDays.length} sessions completed',
                  style: B05Typography.caption(
                    context,
                  ).copyWith(color: colors.action, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_activityDays.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 36,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: B05Layout.space8),
                    Text(
                      'No workout history yet',
                      style: B05Typography.label(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      'Complete your first workout to begin your consistency view.',
                      textAlign: TextAlign.center,
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              )
            else
              // Grid layout
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(12, (colIndex) {
                  // Column of 7 days representing a week
                  return Column(
                    children: List.generate(7, (rowIndex) {
                      final int dayOffset = (colIndex * 7) + rowIndex;
                      final DateTime checkDate = startDate.add(
                        Duration(days: dayOffset),
                      );
                      final key = DateTime(
                        checkDate.year,
                        checkDate.month,
                        checkDate.day,
                      );
                      final volume = _volumeByDate[key] ?? 0.0;

                      Color cellColor = colors.border.withValues(alpha: 0.4);
                      if (volume > 0) {
                        if (volume < 500) {
                          cellColor = colors.action.withValues(alpha: 0.35);
                        } else if (volume < 1500) {
                          cellColor = colors.action.withValues(alpha: 0.70);
                        } else {
                          cellColor = colors.action;
                        }
                      }

                      return Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                }),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Less', style: B05Typography.caption(context)),
                const SizedBox(width: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.action.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.action.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.action,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text('More', style: B05Typography.caption(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChartCard(BuildContext context) {
    final colors = context.b05Colors;
    if (_measurements.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.scale_rounded, size: 40, color: colors.textDisabled),
                const SizedBox(height: B05Layout.space12),
                Text('No weight logs yet', style: B05Typography.label(context)),
                const SizedBox(height: B05Layout.space4),
                Text(
                  'Log your body weight to begin seeing a trend.',
                  textAlign: TextAlign.center,
                  style: B05Typography.caption(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<FlSpot> spots = [];
    double overallDiff = 0.0;

    // Sort oldest to newest for graph
    final sorted = List<BodyMeasurement>.from(_measurements).reversed.toList();
    final start = sorted.length > 6 ? sorted.length - 6 : 0;
    for (int i = start; i < sorted.length; i++) {
      final double? w = sorted[i].weight;
      if (w != null) {
        spots.add(FlSpot((i - start).toDouble(), w));
      }
    }

    // Calculate overall difference between last and first of the shown set
    if (spots.length >= 2) {
      overallDiff = spots.last.y - spots.first.y;
    }

    double minY = 50.0;
    double maxY = 100.0;
    if (spots.isNotEmpty) {
      final weights = spots.map((s) => s.y).toList();
      final minWeight = weights.reduce((a, b) => a < b ? a : b);
      final maxWeight = weights.reduce((a, b) => a > b ? a : b);
      minY = (minWeight - 2).clamp(0, double.infinity);
      maxY = maxWeight + 2;
    }

    final diffSign = overallDiff >= 0 ? '+' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _measurements.isEmpty
                      ? 'Last 6 measurements'
                      : 'Last ${spots.length} measurements',
                  style: B05Typography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$diffSign${overallDiff.toStringAsFixed(1)} kg overall',
                  style: TextStyle(
                    color: overallDiff <= 0
                        ? colors.success.indicator
                        : colors.danger.indicator,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (_targetWeight != null &&
                _targetWeight! > 0 &&
                _measurements.isNotEmpty &&
                _measurements.first.weight != null) ...[
              const SizedBox(height: 10),
              B05Surface(
                tone: B05SurfaceTone.selected,
                radius: B05SurfaceRadius.small,
                padding: const EdgeInsets.symmetric(
                  horizontal: B05Layout.space12,
                  vertical: B05Layout.space8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Goal Weight: ${_targetWeight!.toStringAsFixed(1)} kg',
                      style: B05Typography.caption(context).copyWith(
                        color: colors.action,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(_measurements.first.weight! - _targetWeight!).abs().toStringAsFixed(1)} kg to go',
                      style: B05Typography.caption(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: spots.isEmpty ? 5 : (spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: colors.action,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors.action.withValues(alpha: 0.10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeChartCard(BuildContext context) {
    final colors = context.b05Colors;
    if (_sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Lifted per Session',
                style: B05Typography.caption(
                  context,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 36,
                      color: colors.action,
                    ),
                    const SizedBox(height: B05Layout.space8),
                    Text(
                      'Track your volume over time',
                      style: B05Typography.label(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      'Complete workout sessions to unlock your volume progression chart.',
                      style: B05Typography.caption(context),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessions.length == 1) {
      final firstVol = _sessions.first.totalVolume.round();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Lifted per Session',
                    style: B05Typography.caption(
                      context,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$firstVol kg total',
                    style: B05Typography.caption(context).copyWith(
                      color: colors.action,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 100,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timeline_rounded,
                      color: colors.action,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$firstVol kg lifted in your first session!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log more sessions to see your volume trend.',
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<FlSpot> spots = [];
    final int count = _sessions.length < 5 ? _sessions.length : 5;
    for (int i = 0; i < count; i++) {
      spots.add(FlSpot(i.toDouble(), _sessions[count - 1 - i].totalVolume));
    }

    String volumeChangeLabel = '';
    if (spots.length >= 2 && spots.first.y > 0) {
      final pctChange = ((spots.last.y - spots.first.y) / spots.first.y * 100)
          .round();
      volumeChangeLabel = pctChange >= 0
          ? '+$pctChange% volume'
          : '$pctChange% volume';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Lifted per Session',
                  style: B05Typography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                if (volumeChangeLabel.isNotEmpty)
                  Text(
                    volumeChangeLabel,
                    style: B05Typography.caption(context).copyWith(
                      color: colors.action,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: colors.success.indicator,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors.success.indicator.withValues(alpha: 0.10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
