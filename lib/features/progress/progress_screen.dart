import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/user_profile_provider.dart';
import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';

import 'achievements_screen.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  // Activity map representing workouts logged on specific days
  final List<DateTime> _activityDays = [];
  final Map<DateTime, double> _volumeByDate = {};
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
      final Map<DateTime, double> volMap = {};
      for (final s in list) {
        act.add(s.completedAt);
        final key = DateTime(s.completedAt.year, s.completedAt.month, s.completedAt.day);
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
        title: const Text('Progress & Analytics'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
            tooltip: 'Achievements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AchievementsScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadProgressLogs();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. GitHub-style activity calendar heatmap (last 12 weeks)
                  const Text(
                    'GYM ACTIVITY HEATMAP',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  _buildGitHubHeatmap(),
                  const SizedBox(height: 20),

                  // 2. Body Weight Sparkline Chart Card
                  const Text(
                    'BODY WEIGHT TREND (KG)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  _buildWeightChartCard(),
                  const SizedBox(height: 12),
                  _buildBmiHealthCard(),
                  const SizedBox(height: 20),

                  // 3. Workout Volume Trend Card (Strength progression)
                  const Text(
                    'STRENGTH VOLUME PROGRESSION (KG)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  _buildVolumeChartCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildBmiHealthCard() {
    final userProfile = ref.watch(userProfileProvider);
    final double? weightKg = _measurements.isNotEmpty ? _measurements.first.weight : null;
    final double? heightCm = userProfile.userHeight;

    if (weightKg == null || weightKg <= 0) {
      return const SizedBox.shrink();
    }

    if (heightCm == null || heightCm <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.straighten_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set your height in onboarding/profile to calculate your BMI.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double heightM = heightCm / 100.0;
    final double bmi = weightKg / (heightM * heightM);

    String category = 'Normal';
    Color categoryColor = AppColors.success;
    if (bmi < 18.5) {
      category = 'Underweight';
      categoryColor = AppColors.warning;
    } else if (bmi >= 25.0 && bmi < 30.0) {
      category = 'Overweight';
      categoryColor = Colors.orangeAccent;
    } else if (bmi >= 30.0) {
      category = 'Obese';
      categoryColor = AppColors.danger;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Body Mass Index (BMI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Based on ${weightKg.toStringAsFixed(1)} kg & ${heightCm.toStringAsFixed(0)} cm', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(bmi.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: categoryColor, fontSize: 16)),
                  Text(category, style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
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
            
            if (_activityDays.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 36, color: AppColors.textSecondary),
                    SizedBox(height: 8),
                    Text('No Workout History Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text(
                      'Log your first workout session to start filling your consistency heatmap!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                    final DateTime checkDate = startDate.add(Duration(days: dayOffset));
                    final key = DateTime(checkDate.year, checkDate.month, checkDate.day);
                    final volume = _volumeByDate[key] ?? 0.0;
                    
                    Color cellColor = AppColors.border.withOpacity(0.4);
                    if (volume > 0) {
                      if (volume < 500) {
                        cellColor = AppColors.primary.withOpacity(0.35);
                      } else if (volume < 1500) {
                        cellColor = AppColors.primary.withOpacity(0.70);
                      } else {
                        cellColor = AppColors.primary;
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
                const Text('Less', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.border.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.35), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.70), borderRadius: BorderRadius.circular(2))),
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
    if (_measurements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.scale_rounded, size: 40, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text(
                  'No weight logs yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  'Use the "+" button below to log your body weight and view trends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
            if (m.weight != null) details.add('Weight: ${m.weight!.toStringAsFixed(1)}kg');
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
    final latest = _measurements.isNotEmpty ? _measurements.first : null;
    final weightController = TextEditingController(text: latest?.weight != null ? latest!.weight!.toStringAsFixed(1) : '');
    final waistController = TextEditingController(text: latest?.waist != null ? latest!.waist!.toStringAsFixed(1) : '');
    final chestController = TextEditingController(text: latest?.chest != null ? latest!.chest!.toStringAsFixed(1) : '');
    final armsController = TextEditingController(text: latest?.arms != null ? latest!.arms!.toStringAsFixed(1) : '');
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
    if (_sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Lifted per Session',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.show_chart_rounded, size: 36, color: AppColors.primary),
                    SizedBox(height: 8),
                    Text(
                      'Track Your Volume Over Time',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete workout sessions to unlock your volume progression chart.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                  const Text(
                    'Total Lifted per Session',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    '$firstVol kg total',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
                    const Icon(Icons.timeline_rounded, color: AppColors.primary, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '$firstVol kg lifted in your first session!',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Log more sessions to see your volume trend.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
      final pctChange = ((spots.last.y - spots.first.y) / spots.first.y * 100).round();
      volumeChangeLabel = pctChange >= 0 ? '+$pctChange% volume' : '$pctChange% volume';
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
                const Text(
                  'Total Lifted per Session',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                ),
                if (volumeChangeLabel.isNotEmpty)
                  Text(
                    volumeChangeLabel,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
