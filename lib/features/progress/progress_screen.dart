import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  // Activity map representing workouts logged on specific days
  final List<DateTime> _activityDays = [];
  bool _loading = false;
  List<WorkoutSession> _sessions = [];

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
      final list = await repo.watchSessions().first;
      
      final List<DateTime> act = [];
      for (final s in list) {
        act.add(s.completedAt);
      }

      if (!mounted) return;
      setState(() {
        _sessions = list;
        _activityDays.addAll(act);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracking'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. GitHub-style activity calendar heatmap (last 12 weeks)
                  const Text(
                    'GYM ACTIVITY HEATMAP',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),
                  _buildGitHubHeatmap(),
                  const SizedBox(height: 30),

                  // 2. Weight Trend Chart Card
                  const Text(
                    'WEIGHT TREND (KG)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),
                  _buildWeightChartCard(),
                  const SizedBox(height: 30),

                  // 3. Workout Volume Trend Card (Strength progression)
                  const Text(
                    'STRENGTH VOLUME PROGRESSION (KG)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),
                  _buildVolumeChartCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildGitHubHeatmap() {
    // We will render a 12-week grid (12 columns by 7 rows)
    final DateTime now = DateTime.now();
    final DateTime startDate = now.subtract(const Duration(days: 84)); // 12 weeks ago

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Consistencies Heatmap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  '${_activityDays.length} sessions completed',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Grid layout
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(12, (colIndex) {
                // Column of 7 days representing a week
                return Column(
                  children: List.generate(7, (rowIndex) {
                    final int dayOffset = (colIndex * 7) + rowIndex;
                    final DateTime checkDate = startDate.add(Duration(days: dayOffset));
                    
                    // Verify if they logged a session on this specific date
                    final hasLogged = _activityDays.any((d) =>
                        d.year == checkDate.year &&
                        d.month == checkDate.month &&
                        d.day == checkDate.day);

                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                        color: hasLogged 
                            ? AppColors.primary 
                            : AppColors.border.withOpacity(0.4),
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
                const Text('Less', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.border.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('More', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Last 6 measurements', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                Text('-1.2 kg overall', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  maxX: 5,
                  minY: 72,
                  maxY: 76,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 75.6),
                        const FlSpot(1, 75.1),
                        const FlSpot(2, 74.8),
                        const FlSpot(3, 74.5),
                        const FlSpot(4, 74.4),
                        const FlSpot(5, 74.2),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.06),
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

  Widget _buildVolumeChartCard() {
    // Generate workout volume spots based on actual completed sessions
    final List<FlSpot> spots = [];
    if (_sessions.isEmpty) {
      spots.addAll([
        const FlSpot(0, 850),
        const FlSpot(1, 920),
        const FlSpot(2, 1050),
        const FlSpot(3, 1180),
      ]);
    } else {
      final int count = _sessions.length < 5 ? _sessions.length : 5;
      for (int i = 0; i < count; i++) {
        spots.add(FlSpot(i.toDouble(), _sessions[count - 1 - i].totalVolume));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Lifted per Session', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                Text('+25% intensity', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
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
                      color: AppColors.success,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.success.withOpacity(0.06),
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
