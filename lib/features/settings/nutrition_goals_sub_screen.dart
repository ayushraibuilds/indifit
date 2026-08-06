import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../data/models/b04_goal_models.dart';
import '../coaching/b04_production_surface_controller.dart';
import '../coaching/b04_production_surface_widgets.dart';

/// Production B04 goal and consent surface.
///
/// The form is a command surface over the versioned goal repository. It does
/// not calculate TDEE, apply legacy floors, or maintain a second target.
class NutritionGoalsSubScreen extends ConsumerStatefulWidget {
  const NutritionGoalsSubScreen({super.key});

  @override
  ConsumerState<NutritionGoalsSubScreen> createState() =>
      _NutritionGoalsSubScreenState();
}

class _NutritionGoalsSubScreenState
    extends ConsumerState<NutritionGoalsSubScreen> {
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  NutritionGoalType _goalType = NutritionGoalType.maintenance;
  bool _seeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _seed(B04GoalSettingsState state) {
    if (_seeded || state.status != B04GoalSettingsStatus.ready) return;
    final goal = state.activeGoal;
    if (goal != null) {
      _caloriesController.text = goal.calorieTargetKcal?.toString() ?? '';
      _proteinController.text = goal.proteinTargetG?.toString() ?? '';
      _carbsController.text = goal.carbsTargetG?.toString() ?? '';
      _fatController.text = goal.fatTargetG?.toString() ?? '';
      _goalType = goal.goalType;
    }
    _seeded = true;
  }

  Future<void> _save() async {
    final calories = int.tryParse(_caloriesController.text.trim());
    final protein = double.tryParse(_proteinController.text.trim());
    final carbs = double.tryParse(_carbsController.text.trim());
    final fat = double.tryParse(_fatController.text.trim());
    if (calories == null ||
        calories <= 0 ||
        protein == null ||
        protein < 0 ||
        carbs == null ||
        carbs < 0 ||
        fat == null ||
        fat < 0) {
      _showMessage(
        'Enter valid positive calories and non-negative macro values.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(b04GoalSettingsControllerProvider.notifier)
          .saveUserSetGoal(
            goalType: _goalType,
            calorieTargetKcal: calories,
            proteinTargetG: protein,
            carbsTargetG: carbs,
            fatTargetG: fat,
          );
      if (mounted) _showMessage('User-set target saved as a new goal version.');
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _enableConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review adaptive coaching'),
        content: const SingleChildScrollView(
          child: Text(
            'Adaptive coaching uses your entered goals and historical evidence to show proposals. Proposals are not applied automatically; you accept each target. Incomplete evidence can make guidance unavailable. You can disable or withdraw consent later. Optional AI wording is separate, cannot set targets or bypass safety, and is not enabled by this action. This is general wellness guidance, not medical advice.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable adaptive coaching'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(b04GoalSettingsControllerProvider.notifier)
          .setAdaptiveConsent(CoachingConsentAction.enable);
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    }
  }

  Future<void> _setConsent(CoachingConsentAction action) async {
    try {
      await ref
          .read(b04GoalSettingsControllerProvider.notifier)
          .setAdaptiveConsent(action);
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) => error is B04GoalValidationError
      ? error.message
      : 'That change could not be saved. Try again.';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(b04GoalSettingsControllerProvider);
    _seed(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals & adaptive coaching'),
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.status == B04GoalSettingsStatus.failure
          ? B04ReadStatusCard(
              title: 'Goals & adaptive coaching unavailable',
              message:
                  state.errorMessage ?? 'Try again when your profile is ready.',
              action: TextButton(
                onPressed: () =>
                    ref.read(b04GoalSettingsControllerProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            )
          : _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, B04GoalSettingsState state) {
    final active = state.activeGoal;
    final availability = state.availability;
    final enabled = availability?.preferences.adaptiveCoachingEnabled ?? false;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCanonicalTargetCard(active),
        const SizedBox(height: 16),
        _buildGoalForm(),
        const SizedBox(height: 16),
        _buildConsentCard(state, enabled),
        const SizedBox(height: 16),
        _buildAvailabilityCard(availability),
        const SizedBox(height: 16),
        _buildHistoryCard(state),
        const SizedBox(height: 16),
        const _B04WordingBoundaryCard(),
      ],
    );
  }

  Widget _buildCanonicalTargetCard(NutritionGoalVersionReadModel? active) {
    if (active == null) {
      return const B04ReadStatusCard(
        title: 'Canonical goal version unavailable',
        message:
            'No target is inferred here. Enter a user-set target below to create the first version.',
      );
    }
    final target = active.calorieTargetKcal == null
        ? 'No calorie target'
        : '${active.calorieTargetKcal} kcal/day';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          label:
              'Active goal version $target, source ${active.source.stableId}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active goal version',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                target,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Source: ${active.isUserSet ? 'User-set' : b04ProductionStateLabel(active.source.stableId)}',
              ),
              Text(
                'Effective: ${active.effectiveFromLocalDate} · ${active.timezoneId}',
              ),
              if (active.policyVersion != null)
                Text('Policy: ${active.policyVersion}'),
              if (active.exactResultNumerator != null &&
                  active.exactResultDenominator != null)
                Text(
                  'Exact result: ${active.exactResultNumerator}/${active.exactResultDenominator}',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalForm() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set a user target',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Saving creates a new effective-dated version. It does not invoke a TDEE calculator or silently clamp your value.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<NutritionGoalType>(
            initialValue: _goalType,
            decoration: const InputDecoration(labelText: 'Goal type'),
            items: const [
              DropdownMenuItem(
                value: NutritionGoalType.loss,
                child: Text('Loss'),
              ),
              DropdownMenuItem(
                value: NutritionGoalType.maintenance,
                child: Text('Maintenance'),
              ),
              DropdownMenuItem(
                value: NutritionGoalType.gain,
                child: Text('Gain'),
              ),
              DropdownMenuItem(
                value: NutritionGoalType.custom,
                child: Text('Custom'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _goalType = value);
            },
          ),
          const SizedBox(height: 12),
          _numberField(
            _caloriesController,
            'Daily calorie target',
            'kcal',
            allowDecimal: false,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 150,
                child: _numberField(_proteinController, 'Protein', 'g'),
              ),
              SizedBox(
                width: 150,
                child: _numberField(_carbsController, 'Carbohydrates', 'g'),
              ),
              SizedBox(
                width: 150,
                child: _numberField(_fatController, 'Fat', 'g'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save user-set target'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix, {
    bool allowDecimal = true,
  }) => TextField(
    controller: controller,
    keyboardType: allowDecimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.number,
    decoration: InputDecoration(labelText: label, suffixText: suffix),
  );

  Widget _buildConsentCard(B04GoalSettingsState state, bool enabled) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adaptive coaching consent',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Off by default. Consent is recorded as an append-only event with its policy, copy version, timestamp and local date.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Adaptive coaching'),
            subtitle: Text(enabled ? 'Enabled' : 'Disabled'),
            value: enabled,
            onChanged: enabled
                ? (_) => _setConsent(CoachingConsentAction.disable)
                : (_) => _enableConsent(),
          ),
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _setConsent(CoachingConsentAction.withdraw),
                child: const Text('Withdraw adaptive coaching consent'),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildAvailabilityCard(CoachingAvailabilityReadModel? availability) {
    final reason = availability?.reasonCode ?? 'coaching_unavailable_age';
    return B04ReadStatusCard(
      title: 'Adaptive availability',
      message: b04ProductionStateCopy(reason),
      detail: availability?.eligibility == null
          ? 'Eligibility: not recorded'
          : 'Eligibility: ${b04ProductionStateLabel(availability!.eligibility!.result.stableId)} · ${availability.eligibility!.evaluationLocalDate}',
    );
  }

  Widget _buildHistoryCard(B04GoalSettingsState state) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.goalHistory.isEmpty && state.consentHistory.isEmpty)
            const Text('No goal or consent history is available yet.'),
          for (final goal in state.goalHistory)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(
                'Goal v${goal.versionNumber}: ${goal.calorieTargetKcal ?? 'unavailable'} kcal/day',
              ),
              subtitle: Text(
                '${b04ProductionStateLabel(goal.source.stableId)} · ${goal.effectiveFromLocalDate}',
              ),
            ),
          for (final event in state.consentHistory)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(
                '${b04ProductionStateLabel(event.category.stableId)}: ${event.action.stableId}',
              ),
              subtitle: Text(
                '${event.timestampUtc.toIso8601String()} · ${event.copyVersion}',
              ),
            ),
        ],
      ),
    ),
  );
}

class _B04WordingBoundaryCard extends StatelessWidget {
  const _B04WordingBoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        container: true,
        label: 'Wellness wording boundary',
        child: const Text(
          'IndiFit provides general wellness guidance only. It does not diagnose, prescribe treatment, guarantee outcomes or replace qualified professional care. Safety-sensitive guidance may be unavailable when evidence is uncertain.',
        ),
      ),
    ),
  );
}
