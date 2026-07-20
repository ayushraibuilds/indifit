import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/meal_plan_service.dart';

class AiMealPlannerScreen extends ConsumerStatefulWidget {
  const AiMealPlannerScreen({super.key});

  @override
  ConsumerState<AiMealPlannerScreen> createState() => _AiMealPlannerScreenState();
}

class _AiMealPlannerScreenState extends ConsumerState<AiMealPlannerScreen> {
  int _calorieGoal = 2000;
  String _dietPreference = 'veg'; // 'veg', 'non-veg', 'vegan'
  bool _loading = false;
  bool _planGenerated = false;
  GeneratedMealPlanResult? _currentPlanResult;

  // Selected weekday tab in split view
  int _selectedDayIndex = 0;
  final List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calorieGoal = prefs.getInt('calorie_goal') ?? 2000;
      _dietPreference = prefs.getString('user_diet_preference') ?? 'veg';
    });
  }

  Future<void> _generatePlan() async {
    setState(() => _loading = true);

    final result = await ref.read(mealPlanServiceProvider).generateMealPlan(
          calorieGoal: _calorieGoal,
          dietPreference: _dietPreference,
        );

    if (mounted) {
      setState(() {
        _currentPlanResult = result;
        _planGenerated = true;
        _loading = false;
      });
    }
  }

  void _showGroceryList() {
    final groceryList = _currentPlanResult?.groceryList ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Grocery Checklist 🛒',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Est. ingredients to prepare your 7-day meal plan.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const Divider(color: AppColors.border, height: 24),
              Expanded(
                child: groceryList.isEmpty
                    ? const Center(
                        child: Text(
                          'No grocery list generated.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: groceryList.length,
                        itemBuilder: (context, index) {
                          return _buildGroceryRow(groceryList[index]);
                        },
                      ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroceryRow(String item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const Icon(Icons.check_box_outline_blank_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Meal Planner'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.orange.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI recommendations are estimates. Verify ingredients for food allergies and consult a health professional.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? _buildLoadingState()
                : Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _planGenerated ? _buildPlanLayout() : _buildSetupLayout(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Meal Planner Wizard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          'Design an Indian macro-balanced weekly diet plan instantly using AI.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Calorie Input Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text('Daily Calorie Budget Target', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                Text('$_calorieGoal kcal', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 28, color: AppColors.textSecondary),
                      onPressed: () => setState(() => _calorieGoal = (_calorieGoal - 100).clamp(1200, 4000)),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 28, color: AppColors.primary),
                      onPressed: () => setState(() => _calorieGoal = (_calorieGoal + 100).clamp(1200, 4000)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Preference Selection
        const Text('DIET PREFERENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildPreferenceChip('veg', 'Vegetarian 🥦'),
            const SizedBox(width: 8),
            _buildPreferenceChip('non-veg', 'Non-Vegetarian 🍗'),
            const SizedBox(width: 8),
            _buildPreferenceChip('vegan', 'Vegan 🌱'),
          ],
        ),
        const Spacer(),

        ElevatedButton(
          onPressed: _generatePlan,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Generate 7-Day Indian Diet Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )
      ],
    );
  }

  Widget _buildPreferenceChip(String val, String label) {
    final active = _dietPreference == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _dietPreference = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryGlow : AppColors.cardBackground,
            border: Border.all(color: active ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanLayout() {
    final days = _currentPlanResult?.days ?? [];
    final safeIndex = _selectedDayIndex.clamp(0, days.isEmpty ? 0 : days.length - 1);
    final dayPlan = days.isNotEmpty ? days[safeIndex] : <String, dynamic>{};
    final isFallback = _currentPlanResult?.isFallback ?? true;

    return Column(
      children: [
        // Mode badge indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isFallback ? Colors.amber.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isFallback ? Colors.amber : AppColors.success),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFallback ? Icons.cloud_off_rounded : Icons.auto_awesome_rounded,
                size: 14,
                color: isFallback ? Colors.amber : AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                isFallback ? 'Offline Sample Plan' : 'AI-Generated Plan (Gemini 1.5 Flash)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isFallback ? Colors.amber : AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Horizontal Mon-Sun tabs
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final isSelected = _selectedDayIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(_weekdays[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDayIndex = index;
                      });
                    }
                  },
                  selectedColor: AppColors.primaryGlow,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // 2. Tab Day Meal Card splits
        Expanded(
          child: ListView(
            children: [
              _buildMealSectionCard('Breakfast', dayPlan['breakfast']?.toString() ?? 'N/A', Icons.breakfast_dining_rounded),
              const SizedBox(height: 10),
              _buildMealSectionCard('Lunch', dayPlan['lunch']?.toString() ?? 'N/A', Icons.lunch_dining_rounded),
              const SizedBox(height: 10),
              _buildMealSectionCard('Dinner', dayPlan['dinner']?.toString() ?? 'N/A', Icons.dinner_dining_rounded),
              const SizedBox(height: 10),
              _buildMealSectionCard('Snacks', dayPlan['snacks']?.toString() ?? 'N/A', Icons.cookie_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Grocery Checklist and regenerate options
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showGroceryList,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                label: const Text('Shopping List', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _planGenerated = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  elevation: 0,
                ),
                child: const Text('Reset Planner'),
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildMealSectionCard(String title, String desc, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 24),
          Text('AI is creating your meal plans...', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Balancing portion sizes and local Indian macro splits using Gemini...',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
