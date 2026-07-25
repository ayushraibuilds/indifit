import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/user_profile_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/tdee_calculator.dart';
import '../dashboard/dashboard_controller.dart';

class NutritionGoalsSubScreen extends ConsumerStatefulWidget {
  const NutritionGoalsSubScreen({super.key});

  @override
  ConsumerState<NutritionGoalsSubScreen> createState() => _NutritionGoalsSubScreenState();
}

class _NutritionGoalsSubScreenState extends ConsumerState<NutritionGoalsSubScreen> {
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;

  bool _initialized = false;
  int? _recCalories;
  double? _recProtein;
  double? _recCarbs;
  double? _recFat;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = ref.watch(userProfileProvider);
      _caloriesController.text = profile.calorieGoal.toString();
      _proteinController.text = profile.proteinGoal.round().toString();
      _carbsController.text = profile.carbsGoal.round().toString();
      _fatController.text = profile.fatGoal.round().toString();

      // Calculate TDEE recommendation
      _calculateRecommendation(profile);
      _initialized = true;
    }
  }

  void _calculateRecommendation(UserProfileState profile) {
    final weight = profile.currentWeight > 0 ? profile.currentWeight : 74.5;
    final height = (profile.userHeight != null && profile.userHeight! > 0) ? profile.userHeight! : 170.0;
    
    final bmr = TdeeCalculator.calculateBmr(
      gender: Gender.male,
      weightKg: weight,
      heightCm: height,
      ageYears: 25,
    );
    final tdee = TdeeCalculator.calculateTdee(bmr: bmr, activityLevel: ActivityLevel.moderatelyActive);
    final macros = TdeeCalculator.calculateMacros(tdee: tdee, goal: FitnessGoal.weightLoss, weightKg: weight);

    setState(() {
      _recCalories = macros.calories;
      _recProtein = macros.proteinG;
      _recCarbs = macros.carbsG;
      _recFat = macros.fatG;
    });
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _saveGoals() async {
    final cal = int.tryParse(_caloriesController.text.trim());
    final pro = double.tryParse(_proteinController.text.trim());
    final carb = double.tryParse(_carbsController.text.trim());
    final fat = double.tryParse(_fatController.text.trim());

    if (cal == null || cal < 500 || cal > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid calorie goal (500 - 10,000 kcal).'), backgroundColor: AppColors.danger),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    await ref.read(userProfileProvider.notifier).updateGoals(
      calorieGoal: cal,
      proteinGoal: pro,
      carbsGoal: carb,
      fatGoal: fat,
    );

    // Refresh dashboard state so calorie ring & macro bars update live
    ref.read(dashboardControllerProvider.notifier).loadStateData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition goals updated successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final currentCal = int.tryParse(_caloriesController.text) ?? profile.calorieGoal;
    
    // Check if custom target is >20% off recommendation
    double diffPercent = 0.0;
    if (_recCalories != null && _recCalories! > 0) {
      diffPercent = ((currentCal - _recCalories!) / _recCalories! * 100);
    }
    final showWarning = diffPercent.abs() > 20;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition & Macro Goals'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Recommendation Card
            Card(
              color: AppColors.primary.withOpacity(0.08),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Calculated Recommendation',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Based on your profile (${profile.currentWeight.toStringAsFixed(1)} kg, ${(profile.userHeight ?? 170).round()} cm):',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _recChip('Calories', '${_recCalories ?? 2000} kcal', AppColors.primary),
                        _recChip('Protein', '${(_recProtein ?? 120).round()}g', AppColors.infoBlue),
                        _recChip('Carbs', '${(_recCarbs ?? 230).round()}g', AppColors.warning),
                        _recChip('Fat', '${(_recFat ?? 65).round()}g', AppColors.danger),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'CUSTOM TARGETS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),

            // Soft warning if >20% off recommendation
            if (showWarning) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Note: Your custom calorie target ($currentCal kcal) is ${diffPercent.abs().round()}% ${diffPercent > 0 ? 'higher' : 'lower'} than the calculated recommendation.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Daily Calorie Goal Input
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Daily Calorie Target (kcal)',
                suffixText: 'kcal',
                prefixIcon: const Icon(Icons.local_fire_department_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Protein Target Input
            TextField(
              controller: _proteinController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Protein Target (grams)',
                suffixText: 'g',
                prefixIcon: const Icon(Icons.fitness_center_rounded, color: Colors.blueAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Carbs Target Input
            TextField(
              controller: _carbsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Carbohydrates Target (grams)',
                suffixText: 'g',
                prefixIcon: const Icon(Icons.grain_rounded, color: AppColors.warning),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Fat Target Input
            TextField(
              controller: _fatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Fats Target (grams)',
                suffixText: 'g',
                prefixIcon: const Icon(Icons.opacity_rounded, color: AppColors.danger),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveGoals,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Save Nutrition Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recChip(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
