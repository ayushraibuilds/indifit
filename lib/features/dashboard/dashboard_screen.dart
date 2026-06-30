import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../food_log/food_search_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _waterGlasses = 0;
  double _currentWeight = 74.5;
  int _streakCount = 3;
  
  // Goals parameters
  final int _calorieGoal = 2000;
  final double _proteinGoal = 120.0;
  final double _carbsGoal = 230.0;
  final double _fatGoal = 65.0;

  @override
  void initState() {
    super.initState();
    _loadStateData();
  }

  Future<void> _loadStateData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterGlasses = prefs.getInt('water_glasses') ?? 0;
      _currentWeight = prefs.getDouble('current_weight') ?? 74.5;
      _streakCount = prefs.getInt('streak_count') ?? 3;
    });
  }

  Future<void> _incrementWater() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterGlasses++;
      prefs.setInt('water_glasses', _waterGlasses);
    });
  }

  Future<void> _resetWater() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterGlasses = 0;
      prefs.setInt('water_glasses', 0);
    });
  }

  Future<void> _updateWeight(double w) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentWeight = w;
      prefs.setDouble('current_weight', w);
    });
  }

  @override
  Widget build(BuildContext context) {
    final foodRepo = ref.watch(foodRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<FoodLog>>(
          stream: foodRepo.watchLogsForDay(DateTime.now()),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? [];
            
            // Calc total macros logged
            int eatenCalories = 0;
            double eatenProtein = 0.0;
            double eatenCarbs = 0.0;
            double eatenFat = 0.0;

            for (final log in logs) {
              eatenCalories += log.calories;
              eatenProtein += log.proteinG;
              eatenCarbs += log.carbsG;
              eatenFat += log.fatG;
            }

            double calPercent = eatenCalories / _calorieGoal;
            if (calPercent > 1.0) calPercent = 1.0;
            if (calPercent < 0.0) calPercent = 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header (Greeting & Streak)
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // 2. Calorie Ring & Macro Bars
                  _buildCalorieSection(eatenCalories, eatenProtein, eatenCarbs, eatenFat, calPercent),
                  const SizedBox(height: 24),

                  // 3. Log Meals Section Cards
                  _buildMealLogSection(logs),
                  const SizedBox(height: 24),

                  // 4. Water Tracker Card
                  _buildWaterCard(),
                  const SizedBox(height: 24),

                  // 5. Weight Trend Sparkline
                  _buildWeightSparklineCard(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Namaste, Fitness Champ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Let\'s crush your diet goals today!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          ],
        ),
        
        // Streak counter badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text(
                '$_streakCount Days',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCalorieSection(int eaten, double p, double c, double f, double calPercent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Circular Ring
            CircularPercentIndicator(
              radius: 60.0,
              lineWidth: 10.0,
              percent: calPercent,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$eaten',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    'of 2000 kcal',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
              circularStrokeCap: CircularStrokeCap.round,
              backgroundColor: AppColors.border,
              progressColor: AppColors.primary,
            ),
            const SizedBox(width: 24),

            // Horizontal Macro Bars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMacroBar('Protein', p, _proteinGoal, AppColors.success),
                  const SizedBox(height: 12),
                  _buildMacroBar('Carbs', c, _carbsGoal, AppColors.warning),
                  const SizedBox(height: 12),
                  _buildMacroBar('Fat', f, _fatGoal, AppColors.danger),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String label, double eaten, double goal, Color color) {
    double percent = eaten / goal;
    if (percent > 1.0) percent = 1.0;
    if (percent < 0.0) percent = 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            Text('${eaten.round()}/${goal.round()}g', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6.0,
          ),
        ),
      ],
    );
  }

  Widget _buildMealLogSection(List<FoodLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MEALS TODAY',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        _buildMealCard('Breakfast', 'breakfast', logs),
        const SizedBox(height: 8),
        _buildMealCard('Lunch', 'lunch', logs),
        const SizedBox(height: 8),
        _buildMealCard('Dinner', 'dinner', logs),
        const SizedBox(height: 8),
        _buildMealCard('Snacks', 'snack', logs),
      ],
    );
  }

  Widget _buildMealCard(String title, String type, List<FoodLog> allLogs) {
    final mealLogs = allLogs.where((l) => l.mealType == type).toList();
    int totalCals = mealLogs.fold(0, (sum, item) => sum + item.calories);

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('$totalCals kcal', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        subtitle: Text(
          mealLogs.isEmpty ? 'Tap plus to log item' : '${mealLogs.length} items logged',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FoodSearchScreen(mealType: type)),
            );
          },
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          if (mealLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No food logged yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            ...mealLogs.map((log) => _buildLoggedItemRow(log)),
        ],
      ),
    );
  }

  Widget _buildLoggedItemRow(FoodLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                  '${log.servingLogged} logged • ${log.calories} kcal',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
            onPressed: () async {
              final repo = ref.read(foodRepositoryProvider);
              await repo.deleteLogEntry(log.id);
            },
          )
        ],
      ),
    );
  }

  Widget _buildWaterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Water Intake', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Logged: ${_waterGlasses * 250} ml (Goal: 2.5L)',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                if (_waterGlasses > 0)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
                    onPressed: _resetWater,
                  ),
                ElevatedButton.icon(
                  onPressed: _incrementWater,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF).withOpacity(0.15),
                    foregroundColor: const Color(0xFF0066FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.local_drink, size: 16),
                  label: const Text('Add 250ml'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSparklineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Weight Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'Current weight: $_currentWeight kg',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                
                // Weight entry adjust button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.textSecondary, size: 16),
                      onPressed: () => _updateWeight(_currentWeight - 0.1),
                    ),
                    Text('${_currentWeight.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary, size: 16),
                      onPressed: () => _updateWeight(_currentWeight + 0.1),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            
            // Sparkline LineChart
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 5,
                  minY: 73.0,
                  maxY: 76.0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 75.8),
                        const FlSpot(1, 75.5),
                        const FlSpot(2, 75.2),
                        const FlSpot(3, 74.9),
                        const FlSpot(4, 74.7),
                        FlSpot(5, _currentWeight),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
