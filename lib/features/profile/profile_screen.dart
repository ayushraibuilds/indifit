import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/user_profile_provider.dart';
import '../../core/presentation/diet_preference_presentation.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/tdee_calculator.dart';
import '../dashboard/dashboard_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _injuriesController;

  String _selectedSex = 'male';
  String _selectedGoal = 'maintain';
  String _selectedActivity = 'moderate';
  String _selectedDiet = 'veg';
  String? _dietPreferenceSourceValue;
  var _dietPreferenceChanged = false;
  String _selectedEquipment = 'full_gym';

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _injuriesController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final p = ref.watch(userProfileProvider);
      _nameController.text = p.userName ?? '';
      _ageController.text = p.userAge > 0 ? p.userAge.toString() : '25';
      _heightController.text = (p.userHeight != null && p.userHeight! > 0)
          ? p.userHeight!.round().toString()
          : '170';
      _weightController.text = p.currentWeight > 0
          ? p.currentWeight.toStringAsFixed(1)
          : '70.0';
      _injuriesController.text = p.injuriesLimitations;

      _selectedSex = p.userSex;
      _selectedGoal = p.userGoal;
      _selectedActivity = p.userActivityLevel;
      _dietPreferenceSourceValue = p.dietPreference;
      _dietPreferenceChanged = false;
      _selectedDiet =
          DietPreferencePresentation.uiValueFor(p.dietPreference) ?? 'veg';
      _selectedEquipment = p.equipmentAccess;

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _injuriesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final name = _nameController.text.trim();
    final injuries = _injuriesController.text.trim();

    // Validation
    if (age == null || age < 13 || age > 120) {
      _showError('Please enter a valid age between 13 and 120 years.');
      return;
    }
    if (height == null || height < 100 || height > 250) {
      _showError('Please enter a valid height between 100 and 250 cm.');
      return;
    }
    if (weight == null || weight < 30 || weight > 300) {
      _showError('Please enter a valid weight between 30 and 300 kg.');
      return;
    }

    final p = ref.read(userProfileProvider);
    final bodyOrGoalChanged =
        p.userAge != age ||
        (p.userHeight ?? 0) != height ||
        p.currentWeight != weight ||
        p.userSex != _selectedSex ||
        p.userGoal != _selectedGoal ||
        p.userActivityLevel != _selectedActivity;

    bool recalculateGoals = false;

    if (bodyOrGoalChanged) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              SizedBox(width: 8),
              Text('Recalculate Goals?'),
            ],
          ),
          content: const Text(
            'Your body measurements or fitness goals have changed. Would you like to recalculate daily calorie & macronutrient targets using Mifflin-St Jeor equation?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Current Goals'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Recalculate Goals'),
            ),
          ],
        ),
      );

      if (choice == null) return; // User dismissed/cancelled dialog
      recalculateGoals = choice;
    }

    int? newCals;
    double? newProtein;
    double? newCarbs;
    double? newFat;

    if (recalculateGoals) {
      final gender = _selectedSex == 'female' ? Gender.female : Gender.male;
      final actLevel = switch (_selectedActivity) {
        'sedentary' => ActivityLevel.sedentary,
        'light' => ActivityLevel.lightlyActive,
        'active' => ActivityLevel.veryActive,
        _ => ActivityLevel.moderatelyActive,
      };
      final fitnessGoal = switch (_selectedGoal) {
        'lose' => FitnessGoal.weightLoss,
        'gain' => FitnessGoal.muscleGain,
        _ => FitnessGoal.maintain,
      };

      final bmr = TdeeCalculator.calculateBmr(
        gender: gender,
        weightKg: weight,
        heightCm: height,
        ageYears: age,
      );
      final tdee = TdeeCalculator.calculateTdee(
        bmr: bmr,
        activityLevel: actLevel,
      );
      final macros = TdeeCalculator.calculateMacros(
        tdee: tdee,
        goal: fitnessGoal,
        weightKg: weight,
      );

      newCals = macros.calories;
      newProtein = macros.proteinG;
      newCarbs = macros.carbsG;
      newFat = macros.fatG;
    }

    await HapticFeedback.mediumImpact();
    await ref
        .read(userProfileProvider.notifier)
        .updateProfile(
          name: name,
          age: age,
          height: height,
          weight: weight,
          sex: _selectedSex,
          activityLevel: _selectedActivity,
          goal: _selectedGoal,
          dietPreference: DietPreferencePresentation.persistedValueFor(
            originalValue: _dietPreferenceSourceValue,
            uiValue: _selectedDiet,
            userChanged: _dietPreferenceChanged,
          ),
          equipmentAccess: _selectedEquipment,
          injuriesLimitations: injuries,
          calorieGoal: newCals,
          proteinGoal: newProtein,
          carbsGoal: newCarbs,
          fatGoal: newFat,
        );

    await ref.read(dashboardControllerProvider.notifier).loadStateData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recalculateGoals
                ? 'Profile updated & nutrition targets recalculated ($newCals kcal)!'
                : 'Profile updated successfully!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Identity & Body Data Section
            _buildSectionHeader('IDENTITY & BODY MEASUREMENTS'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Age (years)',
                              suffixText: 'yrs',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _selectedSex,
                            decoration: const InputDecoration(labelText: 'Sex'),
                            items: const [
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('Female'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSex = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Height',
                              suffixText: 'cm',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              suffixText: 'kg',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Goal & Activity Section
            _buildSectionHeader('FITNESS GOAL & ACTIVITY LEVEL'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedGoal,
                      decoration: const InputDecoration(
                        labelText: 'Primary Fitness Goal',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'lose',
                          child: Text('Weight Loss / Cut'),
                        ),
                        DropdownMenuItem(
                          value: 'maintain',
                          child: Text('Maintain Weight & Recomp'),
                        ),
                        DropdownMenuItem(
                          value: 'gain',
                          child: Text('Muscle Gain / Bulk'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedGoal = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedActivity,
                      decoration: const InputDecoration(
                        labelText: 'Daily Activity Level',
                        prefixIcon: Icon(Icons.directions_run_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'sedentary',
                          child: Text('Sedentary (Desk Job)'),
                        ),
                        DropdownMenuItem(
                          value: 'light',
                          child: Text('Light Activity (1-3 workouts/wk)'),
                        ),
                        DropdownMenuItem(
                          value: 'moderate',
                          child: Text('Moderate Activity (3-5 workouts/wk)'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Very Active (6-7 intense workouts/wk)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedActivity = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. Diet Preference
            _buildSectionHeader('DIETARY PREFERENCE'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DietPreferenceDropdown(
                  selectedUiValue: _selectedDiet,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedDiet = value;
                        _dietPreferenceChanged = true;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Equipment & Injuries
            _buildSectionHeader('EQUIPMENT & INJURIES / LIMITATIONS'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedEquipment,
                      decoration: const InputDecoration(
                        labelText: 'Available Equipment',
                        prefixIcon: Icon(Icons.fitness_center_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'full_gym',
                          child: Text('Full Gym (Barbells, Cables, Machines)'),
                        ),
                        DropdownMenuItem(
                          value: 'dumbbells',
                          child: Text('Dumbbells Only'),
                        ),
                        DropdownMenuItem(
                          value: 'bodyweight',
                          child: Text('Bodyweight / Calisthenics'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedEquipment = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _injuriesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Injuries or Limitations',
                        hintText: 'e.g. Lower back pain, shoulder impingement',
                        prefixIcon: Icon(Icons.medical_services_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Save Profile Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}
