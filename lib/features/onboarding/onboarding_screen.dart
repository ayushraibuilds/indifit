import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/tdee_calculator.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/repositories/workout_repository.dart';
import 'b05_adaptive_onboarding.dart';
import 'widgets/onboarding_step_widgets.dart';

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
  String? _sex; // Nullable for explicit selection requirement (Item 3.3)
  String _activityLevel =
      'moderate'; // 'sedentary', 'light', 'moderate', 'active'
  String _goal = 'maintain'; // 'lose', 'maintain', 'gain'
  double _targetWeight = 70.0;
  String _dietPreference = 'veg'; // 'veg', 'non-veg', 'vegan'

  // Input controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController(
    text: '25',
  );
  final TextEditingController _heightController = TextEditingController(
    text: '170',
  );
  final TextEditingController _weightController = TextEditingController(
    text: '70',
  );
  final TextEditingController _targetWeightController = TextEditingController(
    text: '70',
  );

  String? _ageError;
  String? _heightError;
  String? _weightError;
  String? _targetWeightError;
  final B05OnboardingDraftStore _draftStore = const B05OnboardingDraftStore();
  Future<void> _draftWrite = Future<void>.value();
  var _draftLoading = true;
  var _draftLoaded = false;
  String? _draftError;
  var _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _ageController.addListener(_validateAge);
    _heightController.addListener(_validateHeight);
    _weightController.addListener(_validateWeight);
    _targetWeightController.addListener(_validateTargetWeight);
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    if (mounted && !_draftLoading) {
      setState(() {
        _draftLoading = true;
        _draftError = null;
      });
    }
    try {
      final draft = await _draftStore.readProfileDraft();
      if (!mounted) return;
      if (draft != null) {
        setState(() {
          _currentPage = draft.currentPage.clamp(0, _totalPages - 1);
          _sex = draft.sex;
          _activityLevel = draft.activityLevel;
          _goal = draft.goal;
          _dietPreference = draft.dietPreference;
        });
        _nameController.text = draft.name;
        _ageController.text = draft.age;
        _heightController.text = draft.height;
        _weightController.text = draft.weight;
        _targetWeightController.text = draft.targetWeight;
        if (_currentPage > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              _pageController.jumpToPage(_currentPage);
            }
          });
        }
      }
      setState(() {
        _draftLoading = false;
        _draftLoaded = true;
        _draftError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _draftLoading = false;
        _draftLoaded = false;
        _draftError = error.toString();
      });
    }
  }

  Future<void> _saveDraft() {
    if (!_draftLoaded) return Future<void>.value();
    final draft = B05ProfileOnboardingDraft(
      currentPage: _currentPage,
      sex: _sex,
      name: _nameController.text,
      age: _ageController.text,
      height: _heightController.text,
      weight: _weightController.text,
      activityLevel: _activityLevel,
      goal: _goal,
      targetWeight: _targetWeightController.text,
      dietPreference: _dietPreference,
    );
    final next = _draftWrite
        .catchError((_) {})
        .then((_) => _draftStore.saveProfileDraft(draft));
    _draftWrite = next;
    return next;
  }

  void _validateAge() {
    final v = int.tryParse(_ageController.text);
    setState(() {
      if (v == null || v < 10 || v > 120) {
        _ageError = 'Enter age between 10 and 120.';
      } else {
        _ageError = null;
      }
    });
  }

  void _validateHeight() {
    final v = double.tryParse(_heightController.text);
    setState(() {
      if (v == null || v < 80 || v > 250) {
        _heightError = 'Enter height between 80 and 250 cm.';
      } else {
        _heightError = null;
      }
    });
  }

  void _validateWeight() {
    final v = double.tryParse(_weightController.text);
    setState(() {
      if (v == null || v < 25 || v > 350) {
        _weightError = 'Enter weight between 25 and 350 kg.';
      } else {
        _weightError = null;
      }
    });
  }

  void _validateTargetWeight() {
    final v = double.tryParse(_targetWeightController.text);
    setState(() {
      if (v == null || v < 25 || v > 350) {
        _targetWeightError = 'Enter target weight between 25 and 350 kg.';
      } else {
        _targetWeightError = null;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_isCompleting) return;
    if (_currentPage == 0 && _sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your biological sex to proceed.'),
        ),
      );
      return;
    } else if (_currentPage == 1 && _ageError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_ageError!)));
      return;
    } else if (_currentPage == 2 && _heightError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_heightError!)));
      return;
    } else if (_currentPage == 3 && _weightError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_weightError!)));
      return;
    } else if (_currentPage == 6 && _targetWeightError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_targetWeightError!)));
      return;
    }

    // Smart pre-fill for target weight when leaving weight page
    if (_currentPage == 3) {
      final currentW = double.tryParse(_weightController.text) ?? 70.0;
      if (_targetWeightController.text == '70' ||
          _targetWeightController.text.isEmpty) {
        final recTarget = switch (_goal) {
          'lose' => (currentW * 0.9).roundToDouble(),
          'gain' => (currentW * 1.05).roundToDouble(),
          _ => currentW,
        };
        _targetWeightController.text = recTarget.toStringAsFixed(1);
      }
    }

    unawaited(_saveDraft().catchError((_) {}));

    if (_currentPage < _totalPages - 1) {
      final nextPage = _currentPage + 1;
      if (B05MotionPolicy.reduceMotion(context)) {
        _pageController.jumpToPage(nextPage);
      } else {
        _pageController.nextPage(
          duration: B05MotionPolicy.transitionDuration(context),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _completeOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      final previousPage = _currentPage - 1;
      if (B05MotionPolicy.reduceMotion(context)) {
        _pageController.jumpToPage(previousPage);
      } else {
        _pageController.previousPage(
          duration: B05MotionPolicy.transitionDuration(context),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // Mifflin-St Jeor formula for BMR + TDEE multiplier + deficit/surplus adjustments
  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await _saveDraft();
      await _completeOnboardingOnce();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not finish onboarding: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _completeOnboardingOnce() async {
    // Parse final text controllers
    _age = int.tryParse(_ageController.text) ?? 25;
    _height = double.tryParse(_heightController.text) ?? 170.0;
    _weight = double.tryParse(_weightController.text) ?? 70.0;
    _targetWeight = double.tryParse(_targetWeightController.text) ?? _weight;

    final gender = _sex == 'female' ? Gender.female : Gender.male;
    final actLevel = switch (_activityLevel) {
      'sedentary' => ActivityLevel.sedentary,
      'light' => ActivityLevel.lightlyActive,
      'active' => ActivityLevel.veryActive,
      _ => ActivityLevel.moderatelyActive,
    };
    final fitnessGoal = switch (_goal) {
      'lose' => FitnessGoal.weightLoss,
      'gain' => FitnessGoal.muscleGain,
      _ => FitnessGoal.maintain,
    };

    final bmr = TdeeCalculator.calculateBmr(
      weightKg: _weight,
      heightCm: _height,
      ageYears: _age,
      gender: gender,
    );
    final tdee = TdeeCalculator.calculateTdee(
      bmr: bmr,
      activityLevel: actLevel,
    );
    final macros = TdeeCalculator.calculateMacros(
      tdee: tdee,
      goal: fitnessGoal,
      weightKg: _weight,
    );

    double dailyCalories = macros.calories.toDouble();
    double dailyProtein = macros.proteinG;
    double dailyCarbs = macros.carbsG;
    double dailyFat = macros.fatG;

    // Store targets in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calorie_goal', dailyCalories.round());
    await prefs.setDouble(
      'protein_goal',
      double.parse(dailyProtein.toStringAsFixed(1)),
    );
    await prefs.setDouble(
      'carbs_goal',
      double.parse(dailyCarbs.toStringAsFixed(1)),
    );
    await prefs.setDouble(
      'fat_goal',
      double.parse(dailyFat.toStringAsFixed(1)),
    );

    // Store user parameters
    if (_nameController.text.trim().isNotEmpty) {
      await prefs.setString('user_name', _nameController.text.trim());
    }
    await prefs.setInt('user_age', _age);
    await prefs.setDouble('user_height', _height);
    await prefs.setDouble('current_weight', _weight);
    await prefs.setDouble('user_target_weight', _targetWeight);
    if (_sex != null) await prefs.setString('user_sex', _sex!);
    await prefs.setString('user_activity_level', _activityLevel);
    await prefs.setString('user_goal', _goal);
    await prefs.setString('user_diet_preference', _dietPreference);

    // Refresh UserProfileNotifier with newly saved parameters
    await ref.read(userProfileProvider.notifier).loadProfile();

    // Log canonical initial weight entry in BodyMeasurements Drift table
    await ref
        .read(workoutRepositoryProvider)
        .logBodyMeasurement(weight: _weight);

    // Complete onboarding flag
    await prefs.setBool('onboarding_completed', true);

    // Notify router that onboarding is now complete
    ref.read(onboardingCompletedProvider.notifier).state = true;

    // Clear onboarding draft keys after the existing owners have accepted the
    // profile. The save queue was awaited by _completeOnboarding.
    await _draftStore.clearProfileDraft();

    // Chain to RoutineWizardScreen with mapped training goal
    final trainingGoal = switch (_goal) {
      'lose' => 'weight_loss',
      'gain' => 'hypertrophy',
      _ => 'hypertrophy',
    };

    if (mounted) {
      context.go('/routine-wizard?goal=$trainingGoal');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_draftLoaded) return _buildDraftRestoreState();
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
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
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
                  unawaited(_saveDraft().catchError((_) {}));
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
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
                  onPressed: _isCompleting ? null : _nextPage,
                  child: Text(
                    _isCompleting
                        ? 'Saving your profile…'
                        : _currentPage == _totalPages - 1
                        ? 'Calculate My Plan'
                        : 'Next Step',
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

  Widget _buildDraftRestoreState() {
    final hasError = _draftError != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                B05StatusMessage(
                  status: hasError
                      ? B05SemanticStatus.danger
                      : B05SemanticStatus.info,
                  label: hasError
                      ? 'Onboarding draft could not be restored'
                      : 'Restoring your onboarding draft',
                  value: hasError
                      ? _draftError
                      : 'Your answers stay on this device.',
                ),
                if (hasError) ...[
                  const SizedBox(height: B05Layout.space12),
                  B05ActionButton(
                    label: 'Retry draft restore',
                    icon: Icons.refresh_rounded,
                    emphasis: B05ActionEmphasis.secondary,
                    hint: 'Try reading the saved onboarding answers again.',
                    onPressed: _draftLoading ? null : _loadDraft,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSexPage() {
    return OnboardingPageContainer(
      title: 'Welcome to IndiFit!',
      subtitle: 'Your intelligent fitness & Indian nutrition companion.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            maxLength: 100,
            onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.outfit().fontFamily,
            ),
            decoration: InputDecoration(
              labelText: 'Your Name (Optional)',
              hintText: 'e.g. Rahul, Priya',
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
              ),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select your biological sex:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              fontFamily: GoogleFonts.outfit().fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Male',
            icon: Icons.male,
            selected: _sex == 'male',
            onTap: () {
              setState(() => _sex = 'male');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            title: 'Female',
            icon: Icons.female,
            selected: _sex == 'female',
            onTap: () {
              setState(() => _sex = 'female');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgePage() {
    return OnboardingPageContainer(
      title: 'How old are you?',
      subtitle: 'Your age helps us compute changes in calorie metabolism.',
      child: OnboardingNumberInputField(
        controller: _ageController,
        label: 'Age',
        suffix: 'years',
        icon: Icons.calendar_today,
        errorText: _ageError,
        onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
      ),
    );
  }

  Widget _buildHeightPage() {
    return OnboardingPageContainer(
      title: 'How tall are you?',
      subtitle: 'Height is vital for calculating structural metabolic needs.',
      child: OnboardingNumberInputField(
        controller: _heightController,
        label: 'Height',
        suffix: 'cm',
        icon: Icons.height,
        errorText: _heightError,
        onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
      ),
    );
  }

  Widget _buildWeightPage() {
    return OnboardingPageContainer(
      title: "What's your current weight?",
      subtitle: 'Used to determine daily macro limits and starting points.',
      child: OnboardingNumberInputField(
        controller: _weightController,
        label: 'Weight',
        suffix: 'kg',
        icon: Icons.scale,
        errorText: _weightError,
        onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
      ),
    );
  }

  Widget _buildActivityPage() {
    return OnboardingPageContainer(
      title: 'What is your activity level?',
      subtitle:
          'Estimates your TDEE multiplier based on gym/lifestyle workouts.',
      child: Column(
        children: [
          OnboardingSelectionCard(
            title: 'Sedentary',
            subtitle: 'Little or no exercise (desk job)',
            icon: Icons.chair,
            selected: _activityLevel == 'sedentary',
            onTap: () {
              setState(() => _activityLevel = 'sedentary');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Lightly Active',
            subtitle: 'Light workouts 1-3 days/week',
            icon: Icons.directions_walk,
            selected: _activityLevel == 'light',
            onTap: () {
              setState(() => _activityLevel = 'light');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Moderately Active',
            subtitle: 'Moderate gym training 3-5 days/week',
            icon: Icons.fitness_center,
            selected: _activityLevel == 'moderate',
            onTap: () {
              setState(() => _activityLevel = 'moderate');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Very Active',
            subtitle: 'Heavy exercise/sports 6-7 days/week',
            icon: Icons.bolt,
            selected: _activityLevel == 'active',
            onTap: () {
              setState(() => _activityLevel = 'active');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    return OnboardingPageContainer(
      title: 'What is your main goal?',
      subtitle: 'We will tailor your caloric balance to hit this goal.',
      child: Column(
        children: [
          OnboardingSelectionCard(
            title: 'Lose Weight',
            subtitle: 'Burn fat with a healthy calorie deficit',
            icon: Icons.trending_down,
            selected: _goal == 'lose',
            onTap: () {
              setState(() => _goal = 'lose');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            title: 'Maintain Weight',
            subtitle: 'Stay active, stay fit, and lock in current weight',
            icon: Icons.compare_arrows,
            selected: _goal == 'maintain',
            onTap: () {
              setState(() => _goal = 'maintain');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            title: 'Gain Muscle',
            subtitle: 'Build lean bulk with a caloric surplus',
            icon: Icons.trending_up,
            selected: _goal == 'gain',
            onTap: () {
              setState(() => _goal = 'gain');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 20),
          B05AdaptiveLessonPath(selectedGoal: _goal),
        ],
      ),
    );
  }

  Widget _buildTargetWeightPage() {
    return OnboardingPageContainer(
      title: 'What is your target weight?',
      subtitle: 'The goal weight you are striving to reach.',
      child: OnboardingNumberInputField(
        controller: _targetWeightController,
        label: 'Target Weight',
        suffix: 'kg',
        icon: Icons.track_changes,
        errorText: _targetWeightError,
        onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
      ),
    );
  }

  Widget _buildDietPage() {
    return OnboardingPageContainer(
      title: 'Dietary preference?',
      subtitle: 'Tailors AI meal options and search recommendations.',
      child: Column(
        children: [
          OnboardingSelectionCard(
            title: 'Vegetarian',
            subtitle: 'Pure veg, dairy products allowed',
            icon: Icons.eco,
            selected: _dietPreference == 'veg',
            onTap: () {
              setState(() => _dietPreference = 'veg');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Non-Vegetarian',
            subtitle: 'Chicken, fish, eggs, meat included',
            icon: Icons.restaurant,
            selected: _dietPreference == 'non-veg',
            onTap: () {
              setState(() => _dietPreference = 'non-veg');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Vegan',
            subtitle: '100% plant-based, no animal products',
            icon: Icons.spa,
            selected: _dietPreference == 'vegan',
            onTap: () {
              setState(() => _dietPreference = 'vegan');
              unawaited(_saveDraft().catchError((_) {}));
            },
          ),
        ],
      ),
    );
  }
}
