import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/ai_routine_service.dart';
import '../../data/repositories/legacy_program_compatibility_adapter.dart';
import '../../data/repositories/workout_repository.dart';
import 'b05_adaptive_onboarding.dart';

class RoutineWizardScreen extends ConsumerStatefulWidget {
  final String? initialGoal;

  const RoutineWizardScreen({super.key, this.initialGoal});

  @override
  ConsumerState<RoutineWizardScreen> createState() =>
      _RoutineWizardScreenState();
}

class _RoutineWizardScreenState extends ConsumerState<RoutineWizardScreen> {
  int _currentStep = 0;

  // Selected parameters
  String _selectedGoal = 'hypertrophy';
  String _selectedEquipment = 'gym';
  int _daysPerWeek = 3;
  String _selectedExperience = 'beginner';
  final TextEditingController _injuryController = TextEditingController();

  bool _loading = false;
  bool _profileLoaded = false;
  bool _draftLoaded = false;
  bool _savingRoutine = false;
  GeneratedRoutineResult? _generatedRoutine;
  final B05OnboardingDraftStore _draftStore = const B05OnboardingDraftStore();

  @override
  void initState() {
    super.initState();
    if (widget.initialGoal != null && widget.initialGoal!.isNotEmpty) {
      _selectedGoal = widget.initialGoal!;
    }
    unawaited(_loadDraft());
  }

  Future<void> _loadDraft() async {
    final draft = await _draftStore.readRoutineDraft();
    if (!mounted) return;
    if (draft != null) {
      setState(() {
        _currentStep = draft.currentStep.clamp(0, 4).toInt();
        _selectedGoal = draft.selectedGoal;
        _selectedEquipment = draft.selectedEquipment;
        _daysPerWeek = draft.daysPerWeek;
        _selectedExperience = draft.selectedExperience;
        _injuryController.text = draft.injuries;
      });
    }
    _draftLoaded = true;
  }

  void _saveDraft() {
    if (!_draftLoaded) return;
    unawaited(
      _draftStore.saveRoutineDraft(
        B05RoutineWizardDraft(
          currentStep: _currentStep.clamp(0, 4).toInt(),
          selectedGoal: _selectedGoal,
          selectedEquipment: _selectedEquipment,
          daysPerWeek: _daysPerWeek,
          selectedExperience: _selectedExperience,
          injuries: _injuryController.text,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_profileLoaded) {
      final p = ref.watch(userProfileProvider);
      if (p.equipmentAccess.isNotEmpty) {
        _selectedEquipment = p.equipmentAccess;
      }
      if (p.injuriesLimitations.isNotEmpty && _injuryController.text.isEmpty) {
        _injuryController.text = p.injuriesLimitations;
      }
      _profileLoaded = true;
    }
  }

  @override
  void dispose() {
    _injuryController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      _saveDraft();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _saveDraft();
    }
  }

  Future<void> _generateRoutine() async {
    if (_loading) return;
    _saveDraft();
    setState(() => _loading = true);

    try {
      final aiService = ref.read(aiRoutineServiceProvider);
      final result = await aiService.generateRoutine(
        goal: _selectedGoal,
        equipment: _selectedEquipment,
        daysPerWeek: _daysPerWeek,
        experience: _selectedExperience,
        injuries: _injuryController.text.isNotEmpty
            ? _injuryController.text
            : 'none',
      );

      setState(() {
        _generatedRoutine = result;
        _loading = false;
        _currentStep = 5; // Preview step
        _saveDraft();
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation error: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _saveAndApplyRoutine() async {
    if (_generatedRoutine == null || _savingRoutine) return;
    setState(() => _savingRoutine = true);

    try {
      final selection = await ref
          .read(legacyProgramCompatibilityAdapterProvider)
          .resolveActivePlanSelection();
      if (selection.type == ActivePlanType.b01Program) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A scheduled program is active. Create a replacement version from the training-program flow instead.',
              ),
            ),
          );
        }
        return;
      }
      final workoutRepo = ref.read(workoutRepositoryProvider);
      await workoutRepo.saveRoutine(
        name: _generatedRoutine!.name,
        goal: _selectedGoal,
        notes: _generatedRoutine!.notes,
        days: _generatedRoutine!.days,
      );
      await _draftStore.clearRoutineDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout routine activated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save routine: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingRoutine = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coach Setup'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              final router = GoRouter.of(context);
              await _draftStore.clearRoutineDraft();
              if (mounted) router.go('/');
            },
            child: const Text(
              'Skip',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingState()
          : Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildStepContent(),
                  ),
                ),
                _buildBottomNavigation(),
              ],
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(6, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 24),
          Text(
            'Designing your custom split...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Balancing volume, frequency & progressive overload',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildGoalStep();
      case 1:
        return _buildEquipmentStep();
      case 2:
        return _buildFrequencyStep();
      case 3:
        return _buildExperienceStep();
      case 4:
        return _buildInjuriesStep();
      case 5:
        return _buildPreviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildGoalStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What is your primary fitness goal?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'We will optimize volume & rep ranges for this objective.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _buildSelectCard(
            'hypertrophy',
            'Build Muscle (Hypertrophy)',
            'Focus on 8-12 rep ranges and volume build-up',
            Icons.fitness_center_rounded,
          ),
          _buildSelectCard(
            'strength',
            'Gain Strength',
            'Focus on lower reps (3-6) and compound lifts',
            Icons.sports_gymnastics_rounded,
          ),
          _buildSelectCard(
            'weight_loss',
            'Fat Loss & Conditioning',
            'Higher density, moderate weights & cardio integration',
            Icons.local_fire_department_rounded,
          ),
          const SizedBox(height: 20),
          B05AdaptiveLessonPath(selectedGoal: _selectedGoal),
        ],
      ),
    );
  }

  Widget _buildEquipmentStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What equipment do you have access to?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'We will only select exercises matching your equipment.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _buildSelectCard(
            'gym',
            'Full Gym',
            'Barbells, dumbbells, cables, machines',
            Icons.business_rounded,
            optionType: 'equip',
          ),
          _buildSelectCard(
            'dumbbells',
            'Dumbbells Only',
            'Home or minimalist setup with dumbbells & bench',
            Icons.fitness_center_outlined,
            optionType: 'equip',
          ),
          _buildSelectCard(
            'bodyweight',
            'Bodyweight / Calisthenics',
            'Pull-up bar, floor, bodyweight exercises',
            Icons.accessibility_new_rounded,
            optionType: 'equip',
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How many days per week can you train?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consistency beats perfection. Choose a realistic commitment.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [3, 4, 5, 6].map((days) {
              final isSelected = _daysPerWeek == days;
              return GestureDetector(
                onTap: () {
                  setState(() => _daysPerWeek = days);
                  _saveDraft();
                },
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '$days',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '$_daysPerWeek days per week split',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What is your weightlifting experience level?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Controls exercise complexity & recovery demands.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _buildSelectCard(
            'beginner',
            'Beginner (< 1 year)',
            'Simple compound movements, lower overall volume',
            Icons.eco_rounded,
            optionType: 'exp',
          ),
          _buildSelectCard(
            'intermediate',
            'Intermediate (1-3 years)',
            'Standard splits, higher intensity techniques',
            Icons.trending_up_rounded,
            optionType: 'exp',
          ),
          _buildSelectCard(
            'advanced',
            'Advanced (3+ years)',
            'High frequency, specialized exercises & volume',
            Icons.military_tech_rounded,
            optionType: 'exp',
          ),
        ],
      ),
    );
  }

  Widget _buildInjuriesStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Any injuries or physical limitations?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The AI will filter out exercises that stress these areas.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _injuryController,
            maxLines: 3,
            onChanged: (_) => _saveDraft(),
            decoration: InputDecoration(
              hintText:
                  'e.g. Lower back pain, shoulder impingement, weak knees (or leave blank if none)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    if (_generatedRoutine == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _generatedRoutine!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _generatedRoutine!.notes,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _generateRoutine,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Re-roll', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _generatedRoutine!.days.length,
            itemBuilder: (context, index) {
              final day = _generatedRoutine!.days[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    day.dayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    day.isRestDay
                        ? 'Rest Day'
                        : '${day.exercises.length} exercises',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  children: day.exercises.map((e) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        e.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Text(
                        '${e.sets} sets × ${e.repsRange} reps',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectCard(
    String val,
    String title,
    String desc,
    IconData icon, {
    String optionType = 'goal',
  }) {
    final bool isSelected =
        (optionType == 'goal' && _selectedGoal == val) ||
        (optionType == 'equip' && _selectedEquipment == val) ||
        (optionType == 'exp' && _selectedExperience == val);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            if (optionType == 'goal') _selectedGoal = val;
            if (optionType == 'equip') _selectedEquipment = val;
            if (optionType == 'exp') _selectedExperience = val;
          });
          _saveDraft();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0 && _currentStep < 5) ...[
            OutlinedButton(onPressed: _prevStep, child: const Text('Back')),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _savingRoutine
                  ? null
                  : () {
                      if (_currentStep == 4) {
                        _generateRoutine();
                      } else if (_currentStep == 5) {
                        _saveAndApplyRoutine();
                      } else {
                        _nextStep();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 4
                    ? 'Generate Routine'
                    : _currentStep == 5
                    ? 'Activate Routine'
                    : 'Continue',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
