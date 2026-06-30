import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';

class AiMealPlannerScreen extends StatefulWidget {
  const AiMealPlannerScreen({super.key});

  @override
  State<AiMealPlannerScreen> createState() => _AiMealPlannerScreenState();
}

class _AiMealPlannerScreenState extends State<AiMealPlannerScreen> {
  int _calorieGoal = 2000;
  String _dietPreference = 'veg'; // 'veg', 'non-veg', 'vegan'
  bool _loading = false;
  bool _planGenerated = false;

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

  final List<Map<String, dynamic>> _mockWeeklyPlan = [
    // Monday
    {
      'breakfast': 'Oats Upma (1 bowl) with almonds (10 pcs) - 350 kcal | P: 12g',
      'lunch': 'Paneer Bhurji (150g) with 2 Chapatis & Curd - 550 kcal | P: 28g',
      'dinner': 'Yellow Dal Tadka (1 bowl) with Mixed Veg & 2 Chapatis - 480 kcal | P: 18g',
      'snacks': 'Roasted Chana (50g) & Green Tea - 180 kcal | P: 9g',
    },
    // Tuesday
    {
      'breakfast': 'Paneer Stuffed Paratha (1 pc) with curd - 380 kcal | P: 14g',
      'lunch': 'Soya Chunks Curry (1 bowl) with Jeera Rice - 520 kcal | P: 26g',
      'dinner': 'Moong Dal Khichdi (1 plate) with ghee - 440 kcal | P: 12g',
      'snacks': 'Whey Protein Shake with 1 banana - 250 kcal | P: 26g',
    },
    // Wednesday
    {
      'breakfast': 'Besan Cheela (2 pcs) with mint chutney - 320 kcal | P: 12g',
      'lunch': 'Chickpea (Chole) Salad with cucumber & tomatoes - 480 kcal | P: 18g',
      'dinner': 'Tofu Stir-fry (150g) with brown rice (1 cup) - 510 kcal | P: 22g',
      'snacks': 'Mixed seeds (1 handful) & Green Tea - 190 kcal | P: 6g',
    },
    // Thursday
    {
      'breakfast': 'Sprouted Moong Salad (1 bowl) - 280 kcal | P: 14g',
      'lunch': 'Dal Makhani (1 bowl) with Jeera Rice & Veg Salad - 540 kcal | P: 16g',
      'dinner': 'Paneer Tikka (150g) with Grilled Bell Peppers - 460 kcal | P: 24g',
      'snacks': 'Roasted Makhana (1 bowl) - 150 kcal | P: 3g',
    },
    // Friday
    {
      'breakfast': 'Idli (3 pcs) with Sambhar - 310 kcal | P: 8g',
      'lunch': 'Palak Paneer (150g) with 2 Chapatis - 520 kcal | P: 24g',
      'dinner': 'Black Eyed Peas (Lobia) Curry with brown rice - 490 kcal | P: 18g',
      'snacks': 'Boiled Peanut Salad (50g) - 200 kcal | P: 8g',
    },
    // Saturday
    {
      'breakfast': 'Oats Porridge with 1 scoop Whey Protein - 360 kcal | P: 30g',
      'lunch': 'Rajma Masala (1 bowl) with Jeera Rice - 540 kcal | P: 18g',
      'dinner': 'Paneer Kathi Roll (1 pc) - 480 kcal | P: 20g',
      'snacks': 'Buttermilk (1 glass) & Roasted Chana - 160 kcal | P: 7g',
    },
    // Sunday
    {
      'breakfast': 'Vegetable Poha (1 bowl) with peanuts - 290 kcal | P: 7g',
      'lunch': 'Mix Dal Khichdi (1 plate) with Curd - 480 kcal | P: 16g',
      'dinner': 'Paneer Bhurji (150g) with 2 multigrain rotis - 530 kcal | P: 28g',
      'snacks': 'Fruit Salad (Papaya, Apple) - 120 kcal | P: 1g',
    },
  ];

  Future<void> _generatePlan() async {
    setState(() => _loading = true);
    
    // Simulate API compile wait
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _planGenerated = true;
      _loading = false;
    });
  }

  void _showGroceryList() {
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
              
              // Ingredients Checklist
              Expanded(
                child: ListView(
                  children: [
                    _buildGroceryRow('Paneer (Cottage Cheese)', '1.2 kg'),
                    _buildGroceryRow('Whole Wheat Flour (Atta)', '3 kg'),
                    _buildGroceryRow('Brown Rice / Jeera Rice', '1.5 kg'),
                    _buildGroceryRow('Lentils (Toor Dal, Moong, Rajma)', '1.8 kg'),
                    _buildGroceryRow('Rolled Oats', '500g'),
                    _buildGroceryRow('Soya Chunks', '250g'),
                    _buildGroceryRow('Roasted Chana & Makhana', '400g'),
                    _buildGroceryRow('Curd (Yoghurt)', '1.5 kg'),
                  ],
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

  Widget _buildGroceryRow(String name, String qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.check_box_outline_blank_rounded, color: AppColors.textMuted, size: 20),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          Text(qty, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
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
      body: _loading
          ? _buildLoadingState()
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: _planGenerated ? _buildPlanLayout() : _buildSetupLayout(),
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Demo Mode: Offline plan preview. AI Meal Planner connection is simulated locally.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
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
              color: active ? AppColors.primary : AppColors.textSecondary
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanLayout() {
    final dayPlan = _mockWeeklyPlan[_selectedDayIndex];

    return Column(
      children: [
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
              _buildMealSectionCard('Breakfast', dayPlan['breakfast']!, Icons.breakfast_dining_rounded),
              const SizedBox(height: 10),
              _buildMealSectionCard('Lunch', dayPlan['lunch']!, Icons.lunch_dining_rounded),
              const SizedBox(height: 10),
              _buildMealSectionCard('Dinner', dayPlan['dinner']!, Icons.dinner_dining_rounded),
              const SizedBox(height: 10),
              _buildMealSectionCard('Snacks', dayPlan['snacks']!, Icons.cookie_rounded),
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
          const SizedBox(height: 24),
          Text('AI is creating your meal plans...', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
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
