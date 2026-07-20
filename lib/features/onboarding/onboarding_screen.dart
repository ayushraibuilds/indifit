import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/workout_repository.dart';
import '../dashboard/main_navigation_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 8;

  // Onboarding parameters
  int _age = 25;
  double _height = 170.0;
  double _weight = 70.0;
  String _sex = 'male'; // 'male', 'female'
  String _activityLevel = 'moderate'; // 'sedentary', 'light', 'moderate', 'active'
  String _goal = 'maintain'; // 'lose', 'maintain', 'gain'
  double _targetWeight = 70.0;
  String _dietPreference = 'veg'; // 'veg', 'non-veg', 'vegan'

  // Input controllers
  final TextEditingController _ageController = TextEditingController(text: '25');
  final TextEditingController _heightController = TextEditingController(text: '170');
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _targetWeightController = TextEditingController(text: '70');

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 1) {
      final ageVal = int.tryParse(_ageController.text);
      if (ageVal == null || ageVal < 10 || ageVal > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid age between 10 and 120.')),
        );
        return;
      }
    } else if (_currentPage == 2) {
      final heightVal = double.tryParse(_heightController.text);
      if (heightVal == null || heightVal < 80 || heightVal > 250) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid height in cm (80 - 250cm).')),
        );
        return;
      }
    } else if (_currentPage == 3) {
      final weightVal = double.tryParse(_weightController.text);
      if (weightVal == null || weightVal < 25 || weightVal > 350) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid weight in kg (25 - 350kg).')),
        );
        return;
      }
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Mifflin-St Jeor formula for BMR + TDEE multiplier + deficit/surplus adjustments
  Future<void> _completeOnboarding() async {
    // Parse final text controllers
    _age = int.tryParse(_ageController.text) ?? 25;
    _height = double.tryParse(_heightController.text) ?? 170.0;
    _weight = double.tryParse(_weightController.text) ?? 70.0;
    _targetWeight = double.tryParse(_targetWeightController.text) ?? _weight;

    // 1. Calculate BMR
    double bmr;
    if (_sex == 'male') {
      bmr = (10 * _weight) + (6.25 * _height) - (5 * _age) + 5;
    } else {
      bmr = (10 * _weight) + (6.25 * _height) - (5 * _age) - 161;
    }

    // 2. Calculate TDEE
    double activityMultiplier;
    switch (_activityLevel) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'active':
        activityMultiplier = 1.725;
        break;
      default:
        activityMultiplier = 1.375;
    }
    double tdee = bmr * activityMultiplier;

    // 3. Goal Adjustment
    double dailyCalories;
    if (_goal == 'lose') {
      dailyCalories = tdee - 500; // Caloric deficit
    } else if (_goal == 'gain') {
      dailyCalories = tdee + 300; // Caloric surplus
    } else {
      dailyCalories = tdee; // Maintenance
    }
    
    // Clamp calories to healthy limits
    if (dailyCalories < 1200) dailyCalories = 1200;

    // 4. Calculate Macronutrients
    // Protein: 2.0g per kg of bodyweight for active gym-goers
    double dailyProtein = _weight * 2.0;
    if (dailyProtein < 50) dailyProtein = 50;

    // Fat: 22% of daily calories
    double dailyFat = (dailyCalories * 0.22) / 9;
    if (dailyFat < 30) dailyFat = 30;

    // Carbs: Remaining calories
    double proteinCal = dailyProtein * 4;
    double fatCal = dailyFat * 9;
    double dailyCarbs = (dailyCalories - proteinCal - fatCal) / 4;
    if (dailyCarbs < 80) dailyCarbs = 80;

    // 5. Store targets in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calorie_goal', dailyCalories.round());
    await prefs.setDouble('protein_goal', double.parse(dailyProtein.toStringAsFixed(1)));
    await prefs.setDouble('carbs_goal', double.parse(dailyCarbs.toStringAsFixed(1)));
    await prefs.setDouble('fat_goal', double.parse(dailyFat.toStringAsFixed(1)));
    
    // Store user parameters
    await prefs.setInt('user_age', _age);
    await prefs.setDouble('user_height', _height);
    await prefs.setDouble('current_weight', _weight);
    await prefs.setDouble('user_target_weight', _targetWeight);
    await prefs.setString('user_sex', _sex);
    await prefs.setString('user_activity_level', _activityLevel);
    await prefs.setString('user_goal', _goal);
    await prefs.setString('user_diet_preference', _dietPreference);
    
    // Log canonical initial weight entry in BodyMeasurements Drift table
    await ref.read(workoutRepositoryProvider).logBodyMeasurement(weight: _weight);
    
    // Complete onboarding flag
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress bar
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _totalPages,
                        backgroundColor: AppColors.cardBackground,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentPage + 1}/$_totalPages',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Content PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildSexPage(),
                  _buildAgePage(),
                  _buildHeightPage(),
                  _buildWeightPage(),
                  _buildActivityPage(),
                  _buildGoalPage(),
                  _buildTargetWeightPage(),
                  _buildDietPage(),
                ],
              ),
            ),

            // Bottom Navigation Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _totalPages - 1 ? 'Calculate My Plan' : 'Next Step',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: GoogleFonts.outfit().fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontFamily: GoogleFonts.outfit().fontFamily,
            ),
          ),
          const SizedBox(height: 36),
          child,
        ],
      ),
    );
  }

  Widget _buildSexPage() {
    return _buildPageContainer(
      title: "What's your sex?",
      subtitle: "This helps us calculate your basal metabolic rate (BMR) accurately.",
      child: Column(
        children: [
          _buildSelectionCard(
            title: "Male",
            icon: Icons.male,
            selected: _sex == 'male',
            onTap: () => setState(() => _sex = 'male'),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            title: "Female",
            icon: Icons.female,
            selected: _sex == 'female',
            onTap: () => setState(() => _sex = 'female'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgePage() {
    return _buildPageContainer(
      title: "How old are you?",
      subtitle: "Your age helps us compute changes in calorie metabolism.",
      child: _buildNumberInputField(
        controller: _ageController,
        label: "Age",
        suffix: "years",
        icon: Icons.calendar_today,
      ),
    );
  }

  Widget _buildHeightPage() {
    return _buildPageContainer(
      title: "How tall are you?",
      subtitle: "Height is vital for calculating structural metabolic needs.",
      child: _buildNumberInputField(
        controller: _heightController,
        label: "Height",
        suffix: "cm",
        icon: Icons.height,
      ),
    );
  }

  Widget _buildWeightPage() {
    return _buildPageContainer(
      title: "What's your current weight?",
      subtitle: "Used to determine daily macro limits and starting points.",
      child: _buildNumberInputField(
        controller: _weightController,
        label: "Weight",
        suffix: "kg",
        icon: Icons.scale,
      ),
    );
  }

  Widget _buildActivityPage() {
    return _buildPageContainer(
      title: "What is your activity level?",
      subtitle: "Estimates your TDEE multiplier based on gym/lifestyle workouts.",
      child: Column(
        children: [
          _buildSelectionCard(
            title: "Sedentary",
            subtitle: "Little or no exercise (desk job)",
            icon: Icons.chair,
            selected: _activityLevel == 'sedentary',
            onTap: () => setState(() => _activityLevel = 'sedentary'),
          ),
          const SizedBox(height: 12),
          _buildSelectionCard(
            title: "Lightly Active",
            subtitle: "Light workouts 1-3 days/week",
            icon: Icons.directions_walk,
            selected: _activityLevel == 'light',
            onTap: () => setState(() => _activityLevel = 'light'),
          ),
          const SizedBox(height: 12),
          _buildSelectionCard(
            title: "Moderately Active",
            subtitle: "Moderate gym training 3-5 days/week",
            icon: Icons.fitness_center,
            selected: _activityLevel == 'moderate',
            onTap: () => setState(() => _activityLevel = 'moderate'),
          ),
          const SizedBox(height: 12),
          _buildSelectionCard(
            title: "Very Active",
            subtitle: "Heavy exercise/sports 6-7 days/week",
            icon: Icons.bolt,
            selected: _activityLevel == 'active',
            onTap: () => setState(() => _activityLevel = 'active'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    return _buildPageContainer(
      title: "What is your main goal?",
      subtitle: "We will tailor your caloric balance to hit this goal.",
      child: Column(
        children: [
          _buildSelectionCard(
            title: "Lose Weight",
            subtitle: "Burn fat with a healthy calorie deficit",
            icon: Icons.trending_down,
            selected: _goal == 'lose',
            onTap: () => setState(() => _goal = 'lose'),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            title: "Maintain Weight",
            subtitle: "Stay active, stay fit, and lock in current weight",
            icon: Icons.compare_arrows,
            selected: _goal == 'maintain',
            onTap: () => setState(() => _goal = 'maintain'),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            title: "Gain Muscle",
            subtitle: "Build lean bulk with a caloric surplus",
            icon: Icons.trending_up,
            selected: _goal == 'gain',
            onTap: () => setState(() => _goal = 'gain'),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetWeightPage() {
    return _buildPageContainer(
      title: "What is your target weight?",
      subtitle: "The goal weight you are striving to reach.",
      child: _buildNumberInputField(
        controller: _targetWeightController,
        label: "Target Weight",
        suffix: "kg",
        icon: Icons.track_changes,
      ),
    );
  }

  Widget _buildDietPage() {
    return _buildPageContainer(
      title: "Dietary preference?",
      subtitle: "Tailors AI meal options and search recommendations.",
      child: Column(
        children: [
          _buildSelectionCard(
            title: "Vegetarian",
            subtitle: "Pure veg, dairy products allowed",
            icon: Icons.eco,
            selected: _dietPreference == 'veg',
            onTap: () => setState(() => _dietPreference = 'veg'),
          ),
          const SizedBox(height: 12),
          _buildSelectionCard(
            title: "Non-Vegetarian",
            subtitle: "Chicken, fish, eggs, meat included",
            icon: Icons.restaurant,
            selected: _dietPreference == 'non-veg',
            onTap: () => setState(() => _dietPreference = 'non-veg'),
          ),
          const SizedBox(height: 12),
          _buildSelectionCard(
            title: "Vegan",
            subtitle: "100% plant-based, no animal products",
            icon: Icons.spa,
            selected: _dietPreference == 'vegan',
            onTap: () => setState(() => _dietPreference = 'vegan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.04) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withOpacity(0.12) : const Color(0x1F223250),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontFamily: GoogleFonts.outfit().fontFamily,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInputField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: GoogleFonts.outfit().fontFamily,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffix,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: GoogleFonts.outfit().fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
