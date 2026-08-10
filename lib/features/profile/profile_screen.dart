import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/user_profile_provider.dart';
import '../../core/presentation/diet_preference_presentation.dart';
import '../../core/presentation/secondary_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/tdee_calculator.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/responsive_form_primitives.dart';
import '../dashboard/dashboard_controller.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/unit_preference.dart';

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
  String? _selectedDiet;
  String? _dietPreferenceSourceValue;
  var _dietPreferenceChanged = false;
  String _selectedEquipment = 'full_gym';
  String _displayUnits = UnitPreferenceNotifier.metric;
  var _heightChanged = false;
  var _weightChanged = false;

  String? _sourceSex;
  String? _sourceGoal;
  String? _sourceActivity;
  String? _sourceEquipment;
  var _sexChanged = false;
  var _goalChanged = false;
  var _activityChanged = false;
  var _equipmentChanged = false;

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

  void _initializeFromProfile(UserProfileState p, String units) {
    if (!_initialized) {
      _displayUnits = units;
      _nameController.text = p.userName ?? '';
      _ageController.text = p.userAge > 0 ? p.userAge.toString() : '25';
      _setMeasurementDisplay(p, units);
      _injuriesController.text = p.injuriesLimitations;

      _sourceSex = p.userSex;
      _sourceGoal = p.userGoal;
      _sourceActivity = p.userActivityLevel;
      _sourceEquipment = p.equipmentAccess;
      _selectedSex = _knownOr(p.userSex, const {'male', 'female'}, 'male');
      _selectedGoal = _knownOr(p.userGoal, const {
        'lose',
        'maintain',
        'gain',
      }, 'maintain');
      _selectedActivity = _knownOr(p.userActivityLevel, const {
        'sedentary',
        'light',
        'moderate',
        'active',
      }, 'moderate');
      _dietPreferenceSourceValue = p.dietPreference;
      _dietPreferenceChanged = false;
      _selectedDiet = DietPreferencePresentation.uiValueFor(p.dietPreference);
      _selectedEquipment = _knownOr(p.equipmentAccess, const {
        'full_gym',
        'dumbbells',
        'bodyweight',
      }, 'full_gym');

      _initialized = true;
    }
  }

  void _setMeasurementDisplay(UserProfileState profile, String units) {
    if (!_heightChanged && profile.userHeight != null) {
      _heightController.text = UnitPreferencePresentation.heightForDisplay(
        profile.userHeight!,
        units,
      ).toStringAsFixed(UnitPreferencePresentation.isImperial(units) ? 1 : 0);
    }
    if (!_weightChanged) {
      _weightController.text = UnitPreferencePresentation.weightForDisplay(
        profile.currentWeight,
        units,
      ).toStringAsFixed(1);
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
    final p = ref.read(userProfileProvider);
    final age = int.tryParse(_ageController.text.trim());
    final displayedHeight = double.tryParse(_heightController.text.trim());
    final displayedWeight = double.tryParse(_weightController.text.trim());
    final height = !_heightChanged
        ? p.userHeight
        : displayedHeight == null
        ? null
        : UnitPreferencePresentation.heightForStorage(
            displayedHeight,
            _displayUnits,
          );
    final weight = !_weightChanged
        ? p.currentWeight
        : displayedWeight == null
        ? null
        : UnitPreferencePresentation.weightForStorage(
            displayedWeight,
            _displayUnits,
          );
    final name = _nameController.text.trim();
    final injuries = _injuriesController.text.trim();
    final sex = ProfilePresentation.valueForSave(
      source: _sourceSex,
      selected: _selectedSex,
      changed: _sexChanged,
    );
    final goal = ProfilePresentation.valueForSave(
      source: _sourceGoal,
      selected: _selectedGoal,
      changed: _goalChanged,
    );
    final activity = ProfilePresentation.valueForSave(
      source: _sourceActivity,
      selected: _selectedActivity,
      changed: _activityChanged,
    );
    final equipment = ProfilePresentation.valueForSave(
      source: _sourceEquipment,
      selected: _selectedEquipment,
      changed: _equipmentChanged,
    );

    // Validation
    if (age == null || age < 13 || age > 120) {
      _showError('Please enter a valid age between 13 and 120 years.');
      return;
    }
    if (height == null || height < 100 || height > 250) {
      _showError(
        UnitPreferencePresentation.isImperial(_displayUnits)
            ? 'Please enter a valid height between 39.4 and 98.4 in.'
            : 'Please enter a valid height between 100 and 250 cm.',
      );
      return;
    }
    if (weight == null || weight < 30 || weight > 300) {
      _showError(
        UnitPreferencePresentation.isImperial(_displayUnits)
            ? 'Please enter a valid weight between 66.1 and 661.4 lb.'
            : 'Please enter a valid weight between 30 and 300 kg.',
      );
      return;
    }

    final bodyOrGoalChanged =
        p.userAge != age ||
        (p.userHeight ?? 0) != height ||
        p.currentWeight != weight ||
        p.userSex != sex ||
        p.userGoal != goal ||
        p.userActivityLevel != activity;

    bool recalculateGoals = false;

    if (bodyOrGoalChanged) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.b05Colors.section,
          title: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: context.b05Colors.action,
                size: 22,
              ),
              const SizedBox(width: B05Layout.space8),
              const Text('Refresh your targets?'),
            ],
          ),
          content: const Text(
            'Your measurements or goal have changed. Would you like to refresh your daily nutrition targets?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current targets'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Refresh targets'),
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
          sex: sex,
          activityLevel: activity,
          goal: _goalChanged ? _selectedGoal : null,
          dietPreference: DietPreferencePresentation.persistedValueFor(
            originalValue: _dietPreferenceSourceValue,
            uiValue: _selectedDiet,
            userChanged: _dietPreferenceChanged,
          ),
          equipmentAccess: equipment,
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
                ? 'Profile updated and nutrition targets refreshed.'
                : 'Profile updated.',
          ),
          backgroundColor: context.b05Colors.success.indicator,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: context.b05Colors.danger.indicator,
      ),
    );
  }

  static String _knownOr(String value, Set<String> allowed, String fallback) {
    final normalized = value.trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final units = ref.watch(unitPreferenceProvider);
    if (!profile.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Padding(
          padding: EdgeInsets.all(B05Layout.space16),
          child: ConsumerStatusRow(
            label: 'Loading profile',
            detail: 'Getting your details ready.',
            loading: true,
          ),
        ),
      );
    }
    if (!profile.hasProfile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ProductEmptyState(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Complete your profile when you’re ready',
          message:
              'Add your details to personalize goals and recommendations. Basic logging remains available without them.',
          actionLabel: 'Complete profile',
          actionIcon: Icons.arrow_forward_rounded,
          action: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          ),
        ),
      );
    }
    _initializeFromProfile(profile, units);
    if (_displayUnits != units) {
      _displayUnits = units;
      _setMeasurementDisplay(profile, units);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(B05Layout.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'Personal details'),
            const SizedBox(height: B05Layout.space8),
            B05Surface(
              padding: const EdgeInsets.all(B05Layout.space16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  IndiFitResponsiveFieldGroup(
                    children: [
                      TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Age (years)',
                          suffixText: 'yrs',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedSex,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Sex'),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedSex = val;
                              _sexChanged = true;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  IndiFitResponsiveFieldGroup(
                    children: [
                      TextField(
                        controller: _heightController,
                        onChanged: (_) => _heightChanged = true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Height',
                          suffixText: UnitPreferencePresentation.heightSymbol(
                            units,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _weightController,
                        onChanged: (_) => _weightChanged = true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Weight',
                          suffixText: UnitPreferencePresentation.weightSymbol(
                            units,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space24),

            _buildSectionHeader(context, 'Goals'),
            const SizedBox(height: B05Layout.space8),
            B05Surface(
              padding: const EdgeInsets.all(B05Layout.space16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedGoal,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'What are you working toward?',
                      prefixIcon: Icon(Icons.flag_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'lose',
                        child: Text('Lose weight'),
                      ),
                      DropdownMenuItem(
                        value: 'maintain',
                        child: Text('Maintain and feel strong'),
                      ),
                      DropdownMenuItem(
                        value: 'gain',
                        child: Text('Build muscle'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGoal = val;
                          _goalChanged = true;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedActivity,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'How active are most days?',
                      prefixIcon: Icon(Icons.directions_run_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'sedentary',
                        child: Text('Mostly seated'),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Text('Lightly active'),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text('Moderately active'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Very active'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedActivity = val;
                          _activityChanged = true;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space24),

            _buildSectionHeader(context, 'Nutrition preferences'),
            const SizedBox(height: B05Layout.space8),
            B05Surface(
              padding: const EdgeInsets.all(B05Layout.space16),
              child: DietPreferenceDropdown(
                selectedUiValue: _selectedDiet,
                decoration: InputDecoration(
                  labelText: 'How do you like to eat?',
                  helperText: _selectedDiet == null
                      ? 'Choose your dietary pattern.'
                      : null,
                  prefixIcon: const Icon(Icons.restaurant_rounded),
                ),
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
            const SizedBox(height: B05Layout.space24),

            _buildSectionHeader(context, 'Training preferences'),
            const SizedBox(height: B05Layout.space8),
            B05Surface(
              padding: const EdgeInsets.all(B05Layout.space16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedEquipment,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'What equipment do you have?',
                      prefixIcon: Icon(Icons.fitness_center_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'full_gym',
                        child: Text('Full gym'),
                      ),
                      DropdownMenuItem(
                        value: 'dumbbells',
                        child: Text('Dumbbells'),
                      ),
                      DropdownMenuItem(
                        value: 'bodyweight',
                        child: Text('Bodyweight'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedEquipment = val;
                          _equipmentChanged = true;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _injuriesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Anything we should work around?',
                      hintText: 'e.g. lower back pain or a shoulder issue',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space24),

            SizedBox(
              width: double.infinity,
              child: B05ActionButton(
                onPressed: _handleSave,
                icon: Icons.save_rounded,
                label: 'Save profile',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: B05Typography.caption(
        context,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .6),
    );
  }
}
