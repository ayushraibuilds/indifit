import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/ai_routine_service.dart';
import '../../data/repositories/workout_repository.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0;

  // Selected parameters
  String _selectedGoal = 'hypertrophy';
  String _selectedEquipment = 'gym';
  int _daysPerWeek = 3;
  String _selectedExperience = 'beginner';
  final TextEditingController _injuryController = TextEditingController();

  bool _loading = false;
  GeneratedRoutineResult? _generatedRoutine;

  @override
  void dispose() {
    _injuryController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _generateRoutine() async {
    setState(() => _loading = true);

    try {
      final aiService = ref.read(aiRoutineServiceProvider);
      final result = await aiService.generateRoutine(
        goal: _selectedGoal,
        equipment: _selectedEquipment,
        daysPerWeek: _daysPerWeek,
        experience: _selectedExperience,
        injuries: _injuryController.text.isNotEmpty ? _injuryController.text : 'none',
      );

      setState(() {
        _generatedRoutine = result;
        _loading = false;
        _currentStep = 5; // Move to results step
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    }
  }

  Future<void> _saveAndExit() async {
    if (_generatedRoutine == null) return;

    final repo = ref.read(workoutRepositoryProvider);
    await repo.saveRoutine(
      name: _generatedRoutine!.name,
      goal: _generatedRoutine!.goal,
      notes: _generatedRoutine!.notes,
      days: _generatedRoutine!.days,
    );

    if (mounted) {
      Navigator.pop(context, true); // Returns true to trigger updates
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coach Setup'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? _buildLoadingState()
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Step Indicator Line (for steps 0 to 4)
                  if (_currentStep < 5) _buildProgressIndicator(),
                  const SizedBox(height: 24),
                  
                  // Wizard Body Section
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildStepContent(),
                    ),
                  ),
                  
                  // Navigation Buttons at Bottom
                  if (_currentStep < 5) _buildNavigationButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(5, (index) {
        final active = index <= _currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildGoalStep();
      case 1:
        return _buildEquipmentStep();
      case 2:
        return _buildScheduleStep();
      case 3:
        return _buildExperienceStep();
      case 4:
        return _buildSummaryStep();
      case 5:
        return _buildResultStep();
      default:
        return Container();
    }
  }

  Widget _buildGoalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What is your primary fitness goal?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildSelectionCard('hypertrophy', 'Build Muscle', 'Increase muscle size and bulk up with targeted volume training.', Icons.accessibility_new_rounded),
        const SizedBox(height: 12),
        _buildSelectionCard('strength', 'Gain Strength', 'Improve lifting weights and power outputs using lower rep ranges.', Icons.fitness_center_rounded),
        const SizedBox(height: 12),
        _buildSelectionCard('weight_loss', 'Weight Loss / Tone', 'Burn calories, lose fat, and improve muscular endurance.', Icons.trending_down_rounded),
      ],
    );
  }

  Widget _buildSelectionCard(String val, String title, String desc, IconData icon) {
    final active = _selectedGoal == val;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = val),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGlow : AppColors.cardBackground,
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppColors.primary : AppColors.textSecondary, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What equipment do you have access to?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildEquipmentCard('gym', 'Full Gym Access', 'Barbells, dumbbells, cables, and mechanical weight machines.', Icons.home_repair_service_rounded),
        const SizedBox(height: 12),
        _buildEquipmentCard('dumbbells', 'Dumbbells Only', 'Log routines requiring only pairs of dumbbells.', Icons.sports_kabaddi_rounded),
        const SizedBox(height: 12),
        _buildEquipmentCard('bodyweight', 'Bodyweight Only / Calisthenics', 'Zero equipment needed. Exercises using your own body mass.', Icons.sports_gymnastics_rounded),
      ],
    );
  }

  Widget _buildEquipmentCard(String val, String title, String desc, IconData icon) {
    final active = _selectedEquipment == val;
    return GestureDetector(
      onTap: () => setState(() => _selectedEquipment = val),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGlow : AppColors.cardBackground,
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppColors.primary : AppColors.textSecondary, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How many days per week can you train?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  '$_daysPerWeek Days',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recommended: 3 days for beginners, 4-5 days for intermediate/advanced.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 36, color: AppColors.textSecondary),
                      onPressed: _daysPerWeek > 3 
                          ? () => setState(() => _daysPerWeek--)
                          : null,
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 36, color: AppColors.primary),
                      onPressed: _daysPerWeek < 5 
                          ? () => setState(() => _daysPerWeek++)
                          : null,
                    ),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildExperienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What is your lifting experience?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildExperienceCard('beginner', 'Beginner', 'New to workout movements, lifting for under 6 months.', Icons.mood_rounded),
        const SizedBox(height: 12),
        _buildExperienceCard('intermediate', 'Intermediate', 'Lifting consistently for 6-24 months.', Icons.sentiment_satisfied_alt_rounded),
        const SizedBox(height: 12),
        _buildExperienceCard('advanced', 'Advanced', 'Consistently weight training for 2+ years.', Icons.bolt_rounded),
        const SizedBox(height: 24),
        
        const Text('Injuries or Physical Constraints (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _injuryController,
          decoration: const InputDecoration(
            hintText: 'e.g. knee pain, lower back discomfort',
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceCard(String val, String title, String desc, IconData icon) {
    final active = _selectedExperience == val;
    return GestureDetector(
      onTap: () => setState(() => _selectedExperience = val),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGlow : AppColors.cardBackground,
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppColors.primary : AppColors.textSecondary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review AI Coach Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildSummaryRow('Goal', _selectedGoal.toUpperCase()),
                const Divider(color: AppColors.border, height: 24),
                _buildSummaryRow('Equipment', _selectedEquipment.toUpperCase()),
                const Divider(color: AppColors.border, height: 24),
                _buildSummaryRow('Schedule', '$_daysPerWeek Days / Week'),
                const Divider(color: AppColors.border, height: 24),
                _buildSummaryRow('Experience', _selectedExperience.toUpperCase()),
                const Divider(color: AppColors.border, height: 24),
                _buildSummaryRow('Injuries', _injuryController.text.isNotEmpty ? _injuryController.text : 'None reported'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        
        ElevatedButton(
          onPressed: _generateRoutine,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          child: const Text('Generate AI Workout split', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )
      ],
    );
  }

  Widget _buildSummaryRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildResultStep() {
    if (_generatedRoutine == null) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Generation Complete! ⚡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 8),
        Text(_generatedRoutine!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        Text(
          _generatedRoutine!.notes,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        
        const Text('YOUR WEEKLY PLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        
        // Render generated days
        ..._generatedRoutine!.days.map((day) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(day.dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (day.isRestDay)
                        const Text('REST', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12))
                      else
                        Text('${day.exercises.length} Exercises', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  if (!day.isRestDay) ...[
                    const SizedBox(height: 12),
                    ...day.exercises.map((ex) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(ex.name, style: const TextStyle(fontSize: 13)),
                              Text('${ex.sets}x${ex.repsRange}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ))
                  ]
                ],
              ),
            ),
          );
        }),
        
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _saveAndExit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save & Start Training', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text('AI Coach is crafting your split...', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Analyzing goals, balancing muscle frequencies, and bypassing injuries using Gemini Flash...',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(100, 45),
              ),
              child: const Text('Back', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            const SizedBox(width: 100),
          
          if (_currentStep < 4)
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(100, 45),
              ),
              child: const Text('Continue'),
            )
          else
            const SizedBox(), // Summary step has its own generate button
        ],
      ),
    );
  }
}
