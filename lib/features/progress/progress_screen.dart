import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<BodyMeasurement> _measurements = [];

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
      final measurements = await repo.getBodyMeasurements();
      
      final List<DateTime> act = [];
      for (final s in list) {
        act.add(s.completedAt);
      }

      if (!mounted) return;
      setState(() {
        _sessions = list;
        _activityDays.clear();
        _activityDays.addAll(act);
        _measurements = measurements;
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

                  // Measurements History List
                  if (_measurements.isNotEmpty) ...[
                    const Text(
                      'RECENT MEASUREMENTS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    _buildMeasurementsHistoryCard(),
                    const SizedBox(height: 30),
                  ],

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
      floatingActionButton: FloatingActionButton(
        onPressed: _showLogMeasurementModal,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
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
    final List<FlSpot> spots = [];
    double overallDiff = 0.0;

    if (_measurements.isEmpty) {
      spots.addAll([
        const FlSpot(0, 75.6),
        const FlSpot(1, 75.1),
        const FlSpot(2, 74.8),
        const FlSpot(3, 74.5),
        const FlSpot(4, 74.4),
        const FlSpot(5, 74.2),
      ]);
      overallDiff = -1.4;
    } else {
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
                  _measurements.isEmpty ? 'Last 6 measurements' : 'Last ${spots.length} measurements',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                ),
                Text(
                  '$diffSign${overallDiff.toStringAsFixed(1)} kg overall',
                  style: TextStyle(
                    color: overallDiff <= 0 ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                  maxX: spots.isEmpty ? 5 : (spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
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

  Widget _buildMeasurementsHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: _measurements.take(3).map((m) {
            final dateStr = '${m.recordedAt.day}/${m.recordedAt.month}/${m.recordedAt.year}';
            final List<String> details = [];
            if (m.weight != null) details.add('Weight: ${m.weight}kg');
            if (m.waist != null) details.add('Waist: ${m.waist}cm');
            if (m.chest != null) details.add('Chest: ${m.chest}cm');
            if (m.arms != null) details.add('Arms: ${m.arms}cm');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Expanded(
                    child: Text(
                      details.join(' • '),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLogMeasurementModal() {
    final weightController = TextEditingController();
    final waistController = TextEditingController();
    final chestController = TextEditingController();
    final armsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Log Body Measurements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Track your physical changes over time.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight (kg)'),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: waistController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Waist (cm)'),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: chestController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Chest (cm)'),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: armsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Arms (cm)'),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          final double? w = double.tryParse(weightController.text);
                          final double? wa = double.tryParse(waistController.text);
                          final double? ch = double.tryParse(chestController.text);
                          final double? ar = double.tryParse(armsController.text);

                          if (w == null && wa == null && ch == null && ar == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter at least one measurement.')),
                            );
                            return;
                          }

                          final repo = ref.read(workoutRepositoryProvider);
                          await repo.logBodyMeasurement(
                            weight: w,
                            waist: wa,
                            chest: ch,
                            arms: ar,
                          );

                          // Update SharedPreferences weight so dashboard matches
                          if (w != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setDouble('current_weight', w);
                          }

                          await _loadProgressLogs();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Log'),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
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
