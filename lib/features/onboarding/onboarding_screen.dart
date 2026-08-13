import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';
import '../../core/presentation/diet_preference_presentation.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/tdee_calculator.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
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
  final int _totalPages = 4;

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
  final B05OnboardingDraftStore _draftStore = const B05OnboardingDraftStore();
  Future<void> _draftWrite = Future<void>.value();
  var _draftLoading = true;
  var _draftLoaded = false;
  String? _draftError;
  var _isCompleting = false;
  var _isSkipping = false;
  String? _completionError;
  String? _skipError;

  @override
  void initState() {
    super.initState();
    _ageController.addListener(_validateAge);
    _heightController.addListener(_validateHeight);
    _weightController.addListener(_validateWeight);
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
          _currentPage = _stageForLegacyPage(
            draft.currentPage,
            draft.flowVersion,
          );
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _draftLoading = false;
        _draftLoaded = false;
        _draftError = 'Your setup could not be restored. Try again.';
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
      flowVersion: 2,
    );
    final next = _draftWrite
        .catchError((_) {})
        .then((_) => _draftStore.saveProfileDraft(draft));
    _draftWrite = next;
    return next;
  }

  /// Old releases stored one page for each body field. R6 keeps those answers
  /// but resumes them inside the shorter consumer stages.
  int _stageForLegacyPage(int page, int flowVersion) {
    if (flowVersion >= 2) return page.clamp(0, _totalPages - 1);
    if (page <= 3) return 0;
    if (page <= 4) return 2;
    if (page <= 6) return 1;
    return 3;
  }

  void _dismissInputFocus() {
    FocusScope.of(context).unfocus();
  }

  void _selectOnboardingChoice(VoidCallback selection) {
    _dismissInputFocus();
    setState(selection);
    unawaited(_saveDraft().catchError((_) {}));
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
    // A failed validation should still reveal the required choice or error
    // state. A successful transition must never carry a keyboard to the next
    // page (for example, from a numeric field to goal choices).
    _dismissInputFocus();
    if (_currentPage == 0 && _sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an option above to continue.')),
      );
      return;
    } else if (_currentPage == 0 && _ageError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_ageError!)));
      return;
    } else if (_currentPage == 0 && _heightError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_heightError!)));
      return;
    } else if (_currentPage == 0 && _weightError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_weightError!)));
      return;
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
    _dismissInputFocus();
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
    if (_isCompleting || _isSkipping) return;
    setState(() {
      _isCompleting = true;
      _completionError = null;
      _skipError = null;
    });
    try {
      await _saveDraft();
      await _completeOnboardingOnce();
    } catch (error) {
      if (mounted) {
        setState(
          () => _completionError = 'Your setup could not be saved. Try again.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your setup could not be saved. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _skipOnboarding() async {
    if (_isCompleting || _isSkipping || !_draftLoaded) return;
    _dismissInputFocus();
    setState(() {
      _isSkipping = true;
      _skipError = null;
      _completionError = null;
    });
    try {
      await _draftWrite;
      await _draftStore.markProfileOnboardingSkipped();
      ref.read(onboardingCompletedProvider.notifier).state = true;
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() => _skipError = 'Your setup was not skipped. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isSkipping = false);
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

    // Store user parameters. Target weight is derived only when the user did
    // not provide one in the legacy draft; it is not a required setup step.
    _targetWeight = switch (_goal) {
      'lose' => (_weight * 0.9).roundToDouble(),
      'gain' => (_weight * 1.05).roundToDouble(),
      _ => _weight,
    };

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
    await prefs.remove('onboarding_skipped');

    // Notify router that onboarding is now complete
    ref.read(onboardingCompletedProvider.notifier).state = true;

    // Clear onboarding draft keys after the existing owners have accepted the
    // profile. The save queue was awaited by _completeOnboarding.
    await _draftStore.clearProfileDraft();

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_draftLoaded) return _buildDraftRestoreState();
    final colors = context.b05Colors;
    return ConsumerTaskScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              B05Layout.space16,
              B05Layout.space4,
              B05Layout.space16,
              0,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _draftLoaded && !_isCompleting && !_isSkipping
                    ? _skipOnboarding
                    : null,
                child: const Text('Skip for now'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              B05Layout.space16,
              B05Layout.space12,
              B05Layout.space16,
              B05Layout.space8,
            ),
            child: Row(
              children: [
                B05IconAction(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  hint: 'Return to the previous setup step.',
                  onPressed: _currentPage > 0 ? _prevPage : null,
                ),
                const SizedBox(width: B05Layout.space8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / _totalPages,
                      backgroundColor: colors.surfaceSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.action),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: B05Layout.space12),
                Text(
                  '${_currentPage + 1} of $_totalPages',
                  style: B05Typography.label(
                    context,
                  ).copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          if (_completionError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConsumerStatusRow(
                label: 'Setup could not be completed',
                detail: _completionError,
                error: true,
                onRetry: _isCompleting ? null : _completeOnboarding,
              ),
            ),
          if (_skipError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ConsumerStatusRow(
                label: 'Setup could not be skipped',
                detail: _skipError,
                error: true,
                onRetry: _isSkipping ? null : _skipOnboarding,
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                _dismissInputFocus();
                setState(() => _currentPage = page);
                unawaited(_saveDraft().catchError((_) {}));
              },
              children: [
                _buildAboutPage(),
                _buildGoalPage(),
                _buildActivityPage(),
                _buildDietPage(),
              ],
            ),
          ),
        ],
      ),
      primaryAction: B05ActionButton(
        label: _isCompleting
            ? 'Saving your profile…'
            : _completionError != null && _currentPage == _totalPages - 1
            ? 'Retry setup'
            : _currentPage == _totalPages - 1
            ? 'Finish setup'
            : 'Next Step',
        onPressed: _isCompleting ? null : _nextPage,
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

  Widget _buildAboutPage() {
    final colors = context.b05Colors;
    return OnboardingPageContainer(
      title: 'Welcome to IndiFit!',
      subtitle: 'A few details help us make your starting point useful.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your biological sex:',
            style: B05Typography.label(
              context,
            ).copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Male',
            icon: Icons.male,
            selected: _sex == 'male',
            onTap: () => _selectOnboardingChoice(() => _sex = 'male'),
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            title: 'Female',
            icon: Icons.female,
            selected: _sex == 'female',
            onTap: () => _selectOnboardingChoice(() => _sex = 'female'),
          ),
          const SizedBox(height: B05Layout.space24),
          TextField(
            controller: _nameController,
            maxLength: 100,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            textInputAction: TextInputAction.done,
            onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
            onEditingComplete: _dismissInputFocus,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Name (optional)',
              hintText: 'e.g. Rahul, Priya',
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: colors.action,
              ),
              filled: true,
              fillColor: colors.inset,
              border: OutlineInputBorder(
                borderRadius: B05Radii.largeRadius,
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: B05Radii.largeRadius,
                borderSide: BorderSide(color: colors.border),
              ),
            ),
          ),
          const SizedBox(height: B05Layout.space20),
          Text('How old are you?', style: B05Typography.label(context)),
          const SizedBox(height: B05Layout.space8),
          OnboardingNumberInputField(
            controller: _ageController,
            label: 'Age',
            suffix: 'years',
            icon: Icons.calendar_today,
            errorText: _ageError,
            onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
            onEditingComplete: _dismissInputFocus,
          ),
          const SizedBox(height: B05Layout.space12),
          OnboardingNumberInputField(
            controller: _heightController,
            label: 'Height',
            suffix: 'cm',
            icon: Icons.height,
            errorText: _heightError,
            onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
            onEditingComplete: _dismissInputFocus,
          ),
          const SizedBox(height: B05Layout.space12),
          OnboardingNumberInputField(
            controller: _weightController,
            label: 'Current weight',
            suffix: 'kg',
            icon: Icons.scale,
            errorText: _weightError,
            onChanged: (_) => unawaited(_saveDraft().catchError((_) {})),
            onEditingComplete: _dismissInputFocus,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPage() {
    return OnboardingPageContainer(
      title: 'How do you move most days?',
      subtitle: 'Choose the description that feels closest right now.',
      child: Column(
        children: [
          OnboardingSelectionCard(
            title: 'Sedentary',
            subtitle: 'Little or no exercise (desk job)',
            icon: Icons.chair,
            selected: _activityLevel == 'sedentary',
            onTap: () =>
                _selectOnboardingChoice(() => _activityLevel = 'sedentary'),
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Lightly Active',
            subtitle: 'Light workouts 1-3 days/week',
            icon: Icons.directions_walk,
            selected: _activityLevel == 'light',
            onTap: () =>
                _selectOnboardingChoice(() => _activityLevel = 'light'),
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Moderately Active',
            subtitle: 'Moderate gym training 3-5 days/week',
            icon: Icons.fitness_center,
            selected: _activityLevel == 'moderate',
            onTap: () =>
                _selectOnboardingChoice(() => _activityLevel = 'moderate'),
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Very Active',
            subtitle: 'Heavy exercise/sports 6-7 days/week',
            icon: Icons.bolt,
            selected: _activityLevel == 'active',
            onTap: () =>
                _selectOnboardingChoice(() => _activityLevel = 'active'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    return OnboardingPageContainer(
      title: 'What is your main goal?',
      subtitle: 'You can change this later as your focus changes.',
      child: Column(
        children: [
          OnboardingSelectionCard(
            title: 'Lose weight',
            subtitle: 'Reduce body weight while supporting training.',
            icon: Icons.trending_down,
            selected: _goal == 'lose',
            onTap: () => _selectOnboardingChoice(() => _goal = 'lose'),
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            title: 'Maintain',
            subtitle: 'Keep your weight around its current level.',
            icon: Icons.compare_arrows,
            selected: _goal == 'maintain',
            onTap: () => _selectOnboardingChoice(() => _goal = 'maintain'),
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            title: 'Gain / build muscle',
            subtitle: 'Support muscle and body-weight gain.',
            icon: Icons.trending_up,
            selected: _goal == 'gain',
            onTap: () => _selectOnboardingChoice(() => _goal = 'gain'),
          ),
        ],
      ),
    );
  }

  Widget _buildDietPage() {
    return OnboardingPageContainer(
      title: 'How do you like to eat?',
      subtitle: 'This helps recommendations fit your everyday meals.',
      child: Column(
        children: [
          OnboardingSelectionCard(
            title: 'Vegetarian',
            subtitle: 'Pure veg, dairy products allowed',
            icon: Icons.eco,
            selected:
                DietPreferencePresentation.uiValueFor(_dietPreference) == 'veg',
            onTap: () => _selectOnboardingChoice(
              () => _dietPreference =
                  DietPreferencePresentation.normalizeForOnboarding('veg'),
            ),
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Non-Vegetarian',
            subtitle: 'Chicken, fish, eggs, meat included',
            icon: Icons.restaurant,
            selected:
                DietPreferencePresentation.uiValueFor(_dietPreference) ==
                'non_veg',
            onTap: () => _selectOnboardingChoice(
              () => _dietPreference =
                  DietPreferencePresentation.normalizeForOnboarding('non_veg'),
            ),
          ),
          const SizedBox(height: 12),
          OnboardingSelectionCard(
            title: 'Vegan',
            subtitle: '100% plant-based, no animal products',
            icon: Icons.spa,
            selected:
                DietPreferencePresentation.uiValueFor(_dietPreference) ==
                'vegan',
            onTap: () => _selectOnboardingChoice(
              () => _dietPreference =
                  DietPreferencePresentation.normalizeForOnboarding('vegan'),
            ),
          ),
        ],
      ),
    );
  }
}
