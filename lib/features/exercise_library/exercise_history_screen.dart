import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';

class ExerciseHistoryScreen extends ConsumerStatefulWidget {
  final String exerciseName;

  const ExerciseHistoryScreen({super.key, required this.exerciseName});

  @override
  ConsumerState<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends ConsumerState<ExerciseHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _targetWeightController = TextEditingController(text: '60');
  double _barWeight = 20.0;
  Map<double, int> _calculatedPlates = {};
  double _unmatchedWeight = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculatePlatesNeeded();
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
    final repo = ref.watch(workoutRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.history_rounded), text: 'History & 1RM'),
            Tab(icon: Icon(Icons.calculate_rounded), text: 'Plate Calc'),
          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getExerciseHistory(widget.exerciseName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final history = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildHistoryAndChartTab(history),
              _buildPlateCalculatorTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryAndChartTab(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text(
                'No sets logged yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'History logs and 1RM trend charts will appear here after you log sets in the workout player.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Prepare 1RM points
    final List<FlSpot> spots = [];
    final List<Map<String, dynamic>> sortedHistory = List.from(history.reversed);
    
    for (int i = 0; i < sortedHistory.length; i++) {
      final sets = sortedHistory[i]['sets'] as List<WorkoutSet>;
      
      double best1Rm = 0.0;
      for (final s in sets) {
        final oneRm = s.weight * (1 + s.reps / 30.0);
        if (oneRm > best1Rm) best1Rm = oneRm;
      }
      spots.add(FlSpot(i.toDouble(), best1Rm));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 1RM Trend Chart
          if (spots.length >= 2) ...[
            const Text(
              'ESTIMATED 1RM TREND',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12, right: 24, left: 12),
                child: SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < sortedHistory.length) {
                                final date = sortedHistory[index]['session'].completedAt as DateTime;
                                return Text(
                                  DateFormat('dd/MM').format(date),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            'TRAINING SESSIONS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          // 2. History List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final session = history[index]['session'] as WorkoutSession;
              final sets = history[index]['sets'] as List<WorkoutSet>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM dd, yyyy').format(session.completedAt),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Volume: ${session.totalVolume.round()}kg',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.name,
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const Divider(color: AppColors.border, height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: sets.map((s) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${s.setNumber}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${s.weight}kg x ${s.reps}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            if (s.isPr) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.emoji_events_rounded, color: Colors.orangeAccent, size: 14),
                            ]
                          ],
                        )).toList(),
                      )
                    ],
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildPlateCalculatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PLATE LOADING CALCULATOR',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Weight (kg)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Barbell Weight (kg)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<double>(
                              value: _barWeight,
                              dropdownColor: AppColors.surface,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 20.0, child: Text('20 kg (Std)')),
                                DropdownMenuItem(value: 15.0, child: Text('15 kg')),
                                DropdownMenuItem(value: 10.0, child: Text('10 kg')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _barWeight = val;
                                  });
                                  _calculatePlatesNeeded();
                                }
                              },
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'LOADING PER SIDE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          if (_calculatedPlates.isEmpty && _unmatchedWeight == 0.0)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'Target weight is equal to or less than the barbell weight.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Visual plate layout
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Barbell shaft left
                        Container(width: 24, height: 6, color: Colors.grey),
                        // Loaded plates list
                        if (_calculatedPlates.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Empty Bar', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          )
                        else
                          ..._calculatedPlates.entries.map((entry) {
                            final double plateWeight = entry.key;
                            final int count = entry.value;
                            return Row(
                              children: List.generate(count, (_) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: plateWeight >= 20 ? 14 : 8,
                                height: plateWeight >= 20 ? 56 : 38,
                                decoration: BoxDecoration(
                                  color: _getPlateColor(plateWeight),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: RotatedBox(
                                  quarterTurns: 1,
                                  child: Text(
                                    plateWeight % 1 == 0 ? '${plateWeight.toInt()}' : '$plateWeight',
                                    style: TextStyle(
                                      color: plateWeight >= 20 || plateWeight <= 2.5 ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              )),
                            );
                          }).toList(),
                        // Barbell sleeve end
                        Container(width: 12, height: 12, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Detail breakdown list
                    ..._calculatedPlates.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              Text('${entry.key} kg Plate', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Text('x ${entry.value} per side', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    )).toList(),
                    
                    if (_unmatchedWeight > 0.0) ...[
                      const Divider(color: AppColors.border, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Unmatched remainder', style: TextStyle(color: Colors.orangeAccent)),
                          Text('${_unmatchedWeight.toStringAsFixed(2)} kg per side', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
