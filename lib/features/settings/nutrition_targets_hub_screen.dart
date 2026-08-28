import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/secondary_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/nutrition_target_authority.dart';
import '../coaching/b04_production_surface_controller.dart';
import '../coaching/b04_production_surface_widgets.dart';

/// Single consumer destination for the relationship between the canonical
/// goal, date-scoped nutrition targets, and optional coaching.
///
/// The sections are presented together, but each command still goes through
/// its owning B04 authority: target edits use [NutritionGoalRepository],
/// while coaching consent and eligibility use their append-only repository.
class NutritionTargetsHubScreen extends ConsumerStatefulWidget {
  const NutritionTargetsHubScreen({super.key});

  @override
  ConsumerState<NutritionTargetsHubScreen> createState() =>
      _NutritionTargetsHubScreenState();
}

class _NutritionTargetsHubScreenState
    extends ConsumerState<NutritionTargetsHubScreen> {
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _dateOfBirthController;

  String? _selectedDate;
  String? _seededFormKey;
  NutritionGoalType _goalType = NutritionGoalType.maintenance;
  String? _formError;
  String? _saveMessage;
  bool _saving = false;
  bool _savingEligibility = false;
  bool _savingCoachingConsent = false;
  bool _coachingExpanded = false;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();
    _dateOfBirthController = TextEditingController();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(b04ProductionUserContextProvider);
    return userContext.when(
      loading: () => _shell(
        context,
        const ConsumerStatusRow(
          label: 'Loading nutrition targets',
          detail: 'Getting the target for your current day.',
          loading: true,
        ),
      ),
      error: (_, _) => _shell(
        context,
        ConsumerStatusRow(
          label: 'Nutrition targets unavailable',
          detail:
              'Your target could not be loaded. Your saved values have not changed.',
          error: true,
          onRetry: () => ref.invalidate(b04ProductionUserContextProvider),
        ),
      ),
      data: (user) => _buildForUser(context, user),
    );
  }

  Widget _buildForUser(BuildContext context, B04ProductionUserContext user) {
    _selectedDate ??= user.localDate;
    final selectedDate = _selectedDate!;
    final profile = ref.watch(userProfileProvider);
    final fitnessGoalLabel = profile.isLoaded && profile.hasProfile
        ? SecondaryConsumerCopy.goal(profile.userGoal)
        : null;
    final query = NutritionTargetDateQuery(
      localDate: selectedDate,
      timezoneId: user.timezoneId,
    );
    final target = ref.watch(nutritionTargetsForDateProvider(query));
    final history = ref.watch(nutritionGoalHistoryProvider(user.userId));

    return target.when(
      loading: () => _shell(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateNavigation(context, user),
            const SizedBox(height: B05Layout.space12),
            const ConsumerStatusRow(
              label: 'Loading target',
              detail: 'Reading the saved values for this day.',
              loading: true,
            ),
          ],
        ),
      ),
      error: (_, _) => _shell(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateNavigation(context, user),
            const SizedBox(height: B05Layout.space12),
            ConsumerStatusRow(
              label: 'Target unavailable for this date',
              detail:
                  'No target value is shown until this date can be resolved.',
              error: true,
              onRetry: () =>
                  ref.invalidate(nutritionTargetsForDateProvider(query)),
            ),
          ],
        ),
      ),
      data: (read) {
        _seedForm(user, read);
        return _buildContent(context, user, read, history, fitnessGoalLabel);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    B04ProductionUserContext user,
    NutritionTargetsForDate read,
    AsyncValue<List<NutritionGoalVersionReadModel>> history,
    String? fitnessGoalLabel,
  ) {
    final isToday = read.localDate == user.localDate;
    return _shell(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateNavigation(context, user),
          const SizedBox(height: B05Layout.space16),
          _buildTargetSummary(
            context,
            user,
            read,
            isToday ? fitnessGoalLabel : null,
          ),
          const SizedBox(height: B05Layout.space16),
          if (isToday)
            _buildTodayEditor(context, user, read)
          else
            _buildHistoricalNote(
              context,
              isPast: read.localDate.compareTo(user.localDate) < 0,
            ),
          const SizedBox(height: B05Layout.space16),
          _buildHistory(context, user, history),
          const SizedBox(height: B05Layout.space16),
          _buildOptionalCoaching(context),
        ],
      ),
    );
  }

  Widget _buildOptionalCoaching(BuildContext context) {
    return B05Surface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('Optional coaching'),
        subtitle: const Text(
          'Off by default; goals and targets work without it',
        ),
        onExpansionChanged: (expanded) {
          if (_coachingExpanded == expanded) return;
          setState(() => _coachingExpanded = expanded);
        },
        children: _coachingExpanded
            ? [
                _buildOptionalCoachingBody(
                  context,
                  ref.watch(b04GoalSettingsControllerProvider),
                ),
              ]
            : const [],
      ),
    );
  }

  Widget _buildOptionalCoachingBody(
    BuildContext context,
    B04GoalSettingsState state,
  ) {
    if (state.status == B04GoalSettingsStatus.idle || state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(B05Layout.space16),
        child: ConsumerStatusRow(
          label: 'Loading optional coaching',
          detail:
              'Checking consent and availability. Your targets remain available.',
          loading: true,
        ),
      );
    }
    if (state.status == B04GoalSettingsStatus.failure) {
      return Padding(
        padding: const EdgeInsets.all(B05Layout.space16),
        child: B04ReadStatusCard(
          title: 'Optional coaching unavailable',
          message:
              'Your goal and nutrition targets are still available. Coaching settings could not be loaded.',
          action: TextButton(
            onPressed: () =>
                ref.read(b04GoalSettingsControllerProvider.notifier).load(),
            child: const Text('Retry'),
          ),
        ),
      );
    }

    final availability = state.availability;
    final enabled = availability?.preferences.adaptiveCoachingEnabled ?? false;
    final statusMessage = _coachingAvailabilityMessage(availability);
    final eligibilityDetail = availability == null
        ? 'Your goal and nutrition target remain available.'
        : availability.eligibility == null
        ? 'No age details are available for this check.'
        : 'Availability uses the age details you chose to save for coaching.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        0,
        B05Layout.space16,
        B05Layout.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coaching is separate from your goal and targets. Suggestions never change a target without your explicit action.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Adaptive coaching'),
            subtitle: Text(enabled ? 'Enabled' : 'Disabled'),
            value: enabled,
            onChanged: _savingCoachingConsent
                ? null
                : (_) => enabled
                      ? _setCoachingConsent(CoachingConsentAction.disable)
                      : _enableCoaching(),
          ),
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _savingCoachingConsent
                    ? null
                    : () => _setCoachingConsent(CoachingConsentAction.withdraw),
                child: const Text('Withdraw coaching consent'),
              ),
            ),
          const SizedBox(height: B05Layout.space8),
          Text('Age details', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'IndiFit never guesses age from activity or food logs. This date is used only to check whether coaching is available.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          TextField(
            controller: _dateOfBirthController,
            keyboardType: TextInputType.datetime,
            enabled: !_savingEligibility,
            decoration: const InputDecoration(
              labelText: 'Date of birth',
              hintText: 'YYYY-MM-DD',
            ),
          ),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            label: _savingEligibility ? 'Saving…' : 'Save age details',
            icon: Icons.verified_outlined,
            emphasis: B05ActionEmphasis.secondary,
            onPressed: _savingEligibility ? null : _saveEligibility,
          ),
          const SizedBox(height: B05Layout.space12),
          B04ReadStatusCard(
            title: 'Coaching availability',
            message: statusMessage,
            detail: eligibilityDetail,
          ),
          if (state.consentHistory.isNotEmpty) ...[
            const SizedBox(height: B05Layout.space12),
            _buildCoachingHistory(state),
          ],
          const SizedBox(height: B05Layout.space12),
          Semantics(
            container: true,
            label: 'Coaching safety note',
            child: Text(
              'General wellness guidance only—not medical advice. Suggestions do not diagnose, prescribe treatment, or replace qualified professional care.',
              style: B05Typography.caption(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingHistory(B04GoalSettingsState state) {
    final groups = _coachingHistoryGroups(state.consentHistory);
    return B05Surface(
      padding: EdgeInsets.zero,
      tone: B05SurfaceTone.inset,
      child: ExpansionTile(
        title: const Text('Coaching history'),
        subtitle: const Text('Consent changes'),
        children: [
          for (final group in groups)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: B05Layout.space16,
              ),
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(
                group.events.length == 1
                    ? 'Coaching ${_consentActionLabel(group.events.single.action)}'
                    : '${group.events.length} consent changes',
              ),
              subtitle: Text(
                group.events.length == 1
                    ? ConsumerDateLabel.day(
                        group.localDate,
                        today: _civilDate(state.context!.localDate),
                      )
                    : '${group.events.map((event) => _consentActionLabel(event.action, sentenceCase: true)).join(' → ')} · ${ConsumerDateLabel.day(group.localDate, today: _civilDate(state.context!.localDate))}',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _enableCoaching() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review adaptive coaching'),
        content: const SingleChildScrollView(
          child: Text(
            'Adaptive coaching uses your goals and recent activity to suggest changes. Suggestions are never applied automatically—you choose whether to accept each one. You can turn coaching off at any time. This is general wellness guidance, not medical advice.',
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
    await _setCoachingConsent(CoachingConsentAction.enable);
  }

  Future<void> _setCoachingConsent(CoachingConsentAction action) async {
    setState(() => _savingCoachingConsent = true);
    try {
      await ref
          .read(b04GoalSettingsControllerProvider.notifier)
          .setAdaptiveConsent(action);
    } catch (_) {
      if (mounted) {
        _showMessage('That coaching change could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _savingCoachingConsent = false);
    }
  }

  Future<void> _saveEligibility() async {
    setState(() => _savingEligibility = true);
    try {
      await ref
          .read(b04GoalSettingsControllerProvider.notifier)
          .recordEligibility(dateOfBirthLocalDate: _dateOfBirthController.text);
    } catch (_) {
      if (mounted) {
        _showMessage('Those age details could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _savingEligibility = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _shell(BuildContext context, Widget body) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal & targets')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space16,
                B05Layout.space12,
                B05Layout.space16,
                B05Layout.space32,
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigation(
    BuildContext context,
    B04ProductionUserContext user,
  ) {
    final date = _selectedDate ?? user.localDate;
    final dates = ref.read(localScheduleDateServiceProvider);
    final isToday = date == user.localDate;
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space8,
        vertical: B05Layout.space8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _dateArrow(
                label: 'Previous day',
                icon: Icons.chevron_left_rounded,
                onPressed: () => _selectDate(
                  dates.addCalendarDays(date, user.timezoneId, -1),
                ),
              ),
              Expanded(
                child: Semantics(
                  container: true,
                  label: 'Target date ${_displayDate(date, user.localDate)}',
                  child: Column(
                    children: [
                      Text(
                        _displayDate(date, user.localDate),
                        textAlign: TextAlign.center,
                        style: B05Typography.title(context),
                      ),
                      Text(
                        date,
                        textAlign: TextAlign.center,
                        style: B05Typography.caption(context),
                      ),
                    ],
                  ),
                ),
              ),
              _dateArrow(
                label: 'Next day',
                icon: Icons.chevron_right_rounded,
                onPressed: () => _selectDate(
                  dates.addCalendarDays(date, user.timezoneId, 1),
                ),
              ),
            ],
          ),
          if (!isToday)
            Align(
              alignment: Alignment.centerRight,
              child: B05ActionButton(
                label: 'Back to today',
                icon: Icons.today_outlined,
                hint: 'Show today’s target.',
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: () => _selectDate(user.localDate),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateArrow({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Semantics(
    button: true,
    label: label,
    hint: 'Change target date.',
    onTap: onPressed,
    child: ExcludeSemantics(
      child: IconButton(
        tooltip: label,
        icon: Icon(icon),
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: B05Layout.minTouchTarget,
          minHeight: B05Layout.minTouchTarget,
        ),
      ),
    ),
  );

  Widget _buildTargetSummary(
    BuildContext context,
    B04ProductionUserContext user,
    NutritionTargetsForDate read,
    String? fitnessGoalLabel,
  ) {
    final goal = read.goalVersion;
    if (goal == null) {
      return ProductEmptyState(
        icon: Icons.track_changes_outlined,
        title: read.localDate == user.localDate
            ? 'No target set for today'
            : 'No target saved for this date',
        message: read.localDate == user.localDate
            ? 'Add the values you want to use for today. Earlier dates stay unchanged.'
            : 'This date has no saved target. Nothing is filled in from another day.',
      );
    }

    final values = <_TargetMetric>[
      if (goal.calorieTargetKcal != null)
        _TargetMetric(
          'Calories',
          '${_formatInt(goal.calorieTargetKcal!)} kcal',
        ),
      if (goal.proteinTargetG != null)
        _TargetMetric('Protein', '${_formatGrams(goal.proteinTargetG!)} g'),
      if (goal.carbsTargetG != null)
        _TargetMetric('Carbohydrates', '${_formatGrams(goal.carbsTargetG!)} g'),
      if (goal.fatTargetG != null)
        _TargetMetric('Fat', '${_formatGrams(goal.fatTargetG!)} g'),
    ];

    return B05Surface(
      child: Semantics(
        container: true,
        label:
            'Nutrition target for ${_displayDate(read.localDate, user.localDate)}. ${_goalSourceLabel(goal)}.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fitnessGoalLabel != null) ...[
              Text('Fitness goal', style: B05Typography.title(context)),
              const SizedBox(height: B05Layout.space4),
              Text(fitnessGoalLabel, style: B05Typography.body(context)),
              const SizedBox(height: B05Layout.space12),
            ],
            Text('Nutrition strategy', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space4),
            Text(
              '${_nutritionStrategyLabel(goal.goalType)} · ${_goalSourceLabel(goal)}',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space16),
            Text(
              read.localDate == user.localDate
                  ? 'Today’s target'
                  : 'Target for ${ConsumerDateLabel.day(read.localDate, today: _civilDate(user.localDate))}',
              style: B05Typography.title(context),
            ),
            const SizedBox(height: B05Layout.space16),
            if (values.isEmpty)
              Text(
                'No target values are available for this date.',
                style: B05Typography.body(context),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 520
                      ? constraints.maxWidth
                      : (constraints.maxWidth - B05Layout.space8) / 2;
                  return Wrap(
                    spacing: B05Layout.space8,
                    runSpacing: B05Layout.space8,
                    children: [
                      for (final metric in values)
                        SizedBox(
                          width: width,
                          child: B05Surface(
                            tone: B05SurfaceTone.inset,
                            padding: const EdgeInsets.all(B05Layout.space12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric.label,
                                  style: B05Typography.caption(context),
                                ),
                                const SizedBox(height: B05Layout.space4),
                                Text(
                                  metric.value,
                                  style: B05Typography.title(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: B05Layout.space16),
            Text(
              _effectiveDateLabel(goal, user.localDate),
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: B05Layout.space4),
            Text(
              _goalRelationship(goal),
              style: B05Typography.caption(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayEditor(
    BuildContext context,
    B04ProductionUserContext user,
    NutritionTargetsForDate read,
  ) {
    final goal = read.goalVersion;
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal == null ? 'Set today’s values' : 'Adjust today’s values',
            style: B05Typography.title(context),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Changes take effect today. Earlier dates keep their saved target.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space16),
          DropdownButtonFormField<NutritionGoalType>(
            initialValue: _goalType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nutrition strategy'),
            items: const [
              DropdownMenuItem(
                value: NutritionGoalType.loss,
                child: Text('Calorie deficit', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: NutritionGoalType.maintenance,
                child: Text('Maintenance', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: NutritionGoalType.gain,
                child: Text('Calorie surplus', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: NutritionGoalType.custom,
                child: Text('Custom targets', overflow: TextOverflow.ellipsis),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _goalType = value);
                  },
          ),
          const SizedBox(height: B05Layout.space12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < 520
                  ? constraints.maxWidth
                  : (constraints.maxWidth - B05Layout.space8) / 2;
              return Wrap(
                spacing: B05Layout.space8,
                runSpacing: B05Layout.space12,
                children: [
                  SizedBox(
                    width: width,
                    child: _numberField(
                      controller: _caloriesController,
                      label: 'Calories',
                      suffix: 'kcal',
                      allowDecimal: false,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _numberField(
                      controller: _proteinController,
                      label: 'Protein',
                      suffix: 'g',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _numberField(
                      controller: _carbsController,
                      label: 'Carbohydrates',
                      suffix: 'g',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _numberField(
                      controller: _fatController,
                      label: 'Fat',
                      suffix: 'g',
                    ),
                  ),
                ],
              );
            },
          ),
          if (_formError != null) ...[
            const SizedBox(height: B05Layout.space12),
            _inlineMessage(
              context,
              _formError!,
              color: context.b05Colors.danger,
              icon: Icons.error_outline_rounded,
            ),
          ],
          if (_saveMessage != null) ...[
            const SizedBox(height: B05Layout.space12),
            _inlineMessage(
              context,
              _saveMessage!,
              color: context.b05Colors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
          const SizedBox(height: B05Layout.space16),
          SizedBox(
            width: double.infinity,
            child: B05ActionButton(
              label: _saving ? 'Saving…' : 'Save today’s targets',
              icon: Icons.save_outlined,
              hint: 'Save these target values for today.',
              onPressed: _saving ? null : () => _save(user, read),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalNote(BuildContext context, {required bool isPast}) {
    return B05Surface(
      tone: B05SurfaceTone.inset,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_outlined,
            size: B05Layout.iconMedium,
            color: context.b05Colors.info.foreground,
          ),
          const SizedBox(width: B05Layout.space8),
          Expanded(
            child: Text(
              isPast
                  ? 'Earlier targets are read-only here. Changes made today do not alter this date.'
                  : 'Future dates are read-only here. Today’s saved target continues to apply unless another target takes effect later.',
              style: B05Typography.body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(
    BuildContext context,
    B04ProductionUserContext user,
    AsyncValue<List<NutritionGoalVersionReadModel>> history,
  ) {
    return B05Surface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: const Text('Target history'),
        subtitle: const Text('Review when each saved target took effect'),
        children: [
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.fromLTRB(
                B05Layout.space16,
                0,
                B05Layout.space16,
                B05Layout.space16,
              ),
              child: ConsumerStatusRow(
                label: 'Loading target history',
                loading: true,
              ),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space16,
                0,
                B05Layout.space16,
                B05Layout.space16,
              ),
              child: ConsumerStatusRow(
                label: 'Target history unavailable',
                detail: 'Your current target is still shown above.',
                error: true,
                onRetry: () =>
                    ref.invalidate(nutritionGoalHistoryProvider(user.userId)),
              ),
            ),
            data: (versions) {
              final meaningful = _meaningfulTargetHistory(versions);
              return meaningful.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(
                        B05Layout.space16,
                        0,
                        B05Layout.space16,
                        B05Layout.space16,
                      ),
                      child: Text('No earlier targets yet.'),
                    )
                  : Column(
                      children: [
                        for (final version in meaningful.reversed)
                          _historyRow(context, user, version),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _historyRow(
    BuildContext context,
    B04ProductionUserContext user,
    NutritionGoalVersionReadModel version,
  ) {
    final values = <String>[
      if (version.calorieTargetKcal != null)
        '${_formatInt(version.calorieTargetKcal!)} kcal',
      if (version.proteinTargetG != null)
        'P ${_formatGrams(version.proteinTargetG!)} g',
      if (version.carbsTargetG != null)
        'C ${_formatGrams(version.carbsTargetG!)} g',
      if (version.fatTargetG != null)
        'F ${_formatGrams(version.fatTargetG!)} g',
    ];
    final selected = _selectedDate == version.effectiveFromLocalDate;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_goalSourceLabel(version)}, effective ${version.effectiveFromLocalDate}',
      hint: 'Show this target date.',
      onTap: () => _selectDate(version.effectiveFromLocalDate),
      child: ListTile(
        selected: selected,
        onTap: () => _selectDate(version.effectiveFromLocalDate),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.history_outlined,
          color: selected
              ? context.b05Colors.action
              : context.b05Colors.textSecondary,
        ),
        title: Text(
          '${_nutritionStrategyLabel(version.goalType)} · ${_goalSourceLabel(version)}',
        ),
        subtitle: Text(
          'From ${ConsumerDateLabel.day(version.effectiveFromLocalDate, today: _civilDate(user.localDate))}${values.isEmpty ? '' : ' · ${values.join(' · ')}'}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  TextField _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    bool allowDecimal = true,
  }) => TextField(
    controller: controller,
    enabled: !_saving,
    keyboardType: allowDecimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.number,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(labelText: label, suffixText: suffix),
  );

  Widget _inlineMessage(
    BuildContext context,
    String message, {
    required B05ColorRole color,
    required IconData icon,
  }) => Semantics(
    liveRegion: true,
    container: true,
    label: message,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: B05Layout.iconMedium, color: color.foreground),
        const SizedBox(width: B05Layout.space8),
        Expanded(child: Text(message, style: B05Typography.body(context))),
      ],
    ),
  );

  Future<void> _save(
    B04ProductionUserContext user,
    NutritionTargetsForDate read,
  ) async {
    final calories = _optionalInt(_caloriesController.text);
    final protein = _optionalDouble(_proteinController.text);
    final carbs = _optionalDouble(_carbsController.text);
    final fat = _optionalDouble(_fatController.text);
    if (calories.isInvalid ||
        protein.isInvalid ||
        carbs.isInvalid ||
        fat.isInvalid) {
      setState(() {
        _formError = 'Check the values and try again.';
        _saveMessage = null;
      });
      return;
    }
    if (calories.value == null &&
        protein.value == null &&
        carbs.value == null &&
        fat.value == null) {
      setState(() {
        _formError = 'Enter at least one target value.';
        _saveMessage = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
      _saveMessage = null;
    });
    final current = read.goalVersion;
    final command = NutritionGoalCommand(
      userId: user.userId,
      goalType: _goalType,
      calorieTargetKcal: calories.value,
      proteinTargetG: protein.value,
      carbsTargetG: carbs.value,
      fatTargetG: fat.value,
      effectiveFromLocalDate: user.localDate,
      timezoneId: user.timezoneId,
    );
    try {
      final repository = ref.read(nutritionGoalRepositoryProvider);
      if (current?.source == NutritionGoalSource.calculated ||
          current?.source == NutritionGoalSource.adaptive ||
          current?.source == NutritionGoalSource.override) {
        await repository.recordManualOverride(command);
      } else {
        await repository.recordUserSetGoal(command);
      }
      if (!mounted) return;
      setState(() {
        _saveMessage =
            'Saved for today. Earlier dates keep their saved target.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError =
            'That change could not be saved. Your entered values are still here.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectDate(String date) {
    final normalized = ref
        .read(localScheduleDateServiceProvider)
        .normalizeLocalDate(date);
    if (_selectedDate == normalized) return;
    setState(() {
      _selectedDate = normalized;
      _seededFormKey = null;
      _formError = null;
      _saveMessage = null;
    });
  }

  void _seedForm(B04ProductionUserContext user, NutritionTargetsForDate read) {
    final key = '${user.userId}:${read.localDate}';
    if (_seededFormKey == key) return;
    _seededFormKey = key;
    if (read.localDate != user.localDate) {
      _clearControllers();
      return;
    }
    final goal = read.goalVersion;
    _caloriesController.text = goal?.calorieTargetKcal?.toString() ?? '';
    _proteinController.text = goal?.proteinTargetG == null
        ? ''
        : _formatGrams(goal!.proteinTargetG!);
    _carbsController.text = goal?.carbsTargetG == null
        ? ''
        : _formatGrams(goal!.carbsTargetG!);
    _fatController.text = goal?.fatTargetG == null
        ? ''
        : _formatGrams(goal!.fatTargetG!);
    _goalType = goal?.goalType ?? NutritionGoalType.maintenance;
  }

  void _clearControllers() {
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _goalType = NutritionGoalType.maintenance;
  }

  static String _displayDate(String date, String today) {
    if (date == today) return 'Today';
    return ConsumerDateLabel.day(date, today: _civilDate(today));
  }

  static String _nutritionStrategyLabel(NutritionGoalType value) =>
      SecondaryConsumerCopy.nutritionStrategy(value.stableId);

  static String _goalSourceLabel(NutritionGoalVersionReadModel value) =>
      switch (value.source) {
        NutritionGoalSource.userSet => 'Set by you',
        NutritionGoalSource.override => 'Adjusted by you',
        NutritionGoalSource.calculated => 'Calculated target',
        NutritionGoalSource.adaptive => 'Accepted coaching target',
        NutritionGoalSource.compatibility =>
          'Carried over from earlier settings',
      };

  static String _goalRelationship(
    NutritionGoalVersionReadModel value,
  ) => switch (value.source) {
    NutritionGoalSource.userSet =>
      'These values are user-set and stay in effect until another saved target takes over.',
    NutritionGoalSource.override =>
      'These values were adjusted after a calculated or coached target.',
    NutritionGoalSource.calculated =>
      'These values were calculated from your saved goal and available profile inputs.',
    NutritionGoalSource.adaptive =>
      'These values were accepted from coaching and remain a saved target.',
    NutritionGoalSource.compatibility =>
      'These values were carried over from earlier settings and can be adjusted for today.',
  };

  static List<NutritionGoalVersionReadModel> _meaningfulTargetHistory(
    List<NutritionGoalVersionReadModel> versions,
  ) {
    final meaningful = <NutritionGoalVersionReadModel>[];
    for (final version in versions) {
      if (meaningful.isNotEmpty &&
          _samePresentedTarget(meaningful.last, version)) {
        // Preserve every durable row in the repository while avoiding
        // repeated, unchanged entries in consumer history. The first row
        // remains the truthful date when these displayed values took effect.
        continue;
      } else {
        meaningful.add(version);
      }
    }
    return meaningful;
  }

  static bool _samePresentedTarget(
    NutritionGoalVersionReadModel first,
    NutritionGoalVersionReadModel second,
  ) =>
      first.goalType == second.goalType &&
      first.source == second.source &&
      first.calorieTargetKcal == second.calorieTargetKcal &&
      first.proteinTargetG == second.proteinTargetG &&
      first.carbsTargetG == second.carbsTargetG &&
      first.fatTargetG == second.fatTargetG;

  static String _effectiveDateLabel(
    NutritionGoalVersionReadModel value,
    String today,
  ) {
    final end = value.effectiveToLocalDate;
    if (end == null) {
      return 'In effect from ${ConsumerDateLabel.day(value.effectiveFromLocalDate, today: _civilDate(today))}';
    }
    return 'In effect from ${ConsumerDateLabel.day(value.effectiveFromLocalDate, today: _civilDate(today))} through ${ConsumerDateLabel.day(end, today: _civilDate(today))}';
  }

  static DateTime _civilDate(String date) {
    final year = int.parse(date.substring(0, 4));
    final month = int.parse(date.substring(5, 7));
    final day = int.parse(date.substring(8, 10));
    return DateTime(year, month, day);
  }

  static String _formatInt(int value) => value.toString();

  static String _formatGrams(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  static _OptionalNumber<int> _optionalInt(String text) {
    final value = text.trim();
    if (value.isEmpty) return const _OptionalNumber(null, false);
    final parsed = int.tryParse(value);
    return _OptionalNumber(parsed, parsed == null || parsed <= 0);
  }

  static _OptionalNumber<double> _optionalDouble(String text) {
    final value = text.trim();
    if (value.isEmpty) return const _OptionalNumber(null, false);
    final parsed = double.tryParse(value);
    return _OptionalNumber(
      parsed,
      parsed == null || !parsed.isFinite || parsed < 0,
    );
  }
}

class _TargetMetric {
  final String label;
  final String value;

  const _TargetMetric(this.label, this.value);
}

String _coachingAvailabilityMessage(CoachingAvailabilityReadModel? value) {
  if (value == null) {
    return 'Coaching availability couldn\'t be checked right now.';
  }
  final eligibility = value.eligibility;
  if (eligibility == null) {
    return 'Add your date of birth to check whether adaptive coaching is available.';
  }
  return switch (eligibility.result) {
    CoachingEligibilityResult.eligible =>
      'Adaptive coaching is available when you choose to use it.',
    CoachingEligibilityResult.underage =>
      'Coaching suggestions are unavailable for this age. Your logged activity and target remain available.',
    CoachingEligibilityResult.unknownAge ||
    CoachingEligibilityResult.withheldAge =>
      'Add your date of birth to check whether adaptive coaching is available.',
    CoachingEligibilityResult.conflictingAge ||
    CoachingEligibilityResult.invalidEvidence =>
      'Coaching availability couldn\'t be checked from those age details. Check your date of birth and try again.',
    CoachingEligibilityResult.policyUnavailable =>
      'Coaching availability couldn\'t be checked right now.',
  };
}

List<_CoachingHistoryGroup> _coachingHistoryGroups(
  List<CoachingConsentEventReadModel> events,
) {
  final meaningful = <CoachingConsentEventReadModel>[];
  for (final event in events) {
    if (meaningful.isNotEmpty && meaningful.last.action == event.action) {
      continue;
    }
    meaningful.add(event);
  }

  final groups = <_CoachingHistoryGroup>[];
  for (final event in meaningful) {
    if (groups.isNotEmpty && groups.last.localDate == event.localDate) {
      groups.last.events.add(event);
    } else {
      groups.add(_CoachingHistoryGroup(event.localDate, [event]));
    }
  }
  return groups;
}

class _CoachingHistoryGroup {
  final String localDate;
  final List<CoachingConsentEventReadModel> events;

  _CoachingHistoryGroup(this.localDate, this.events);
}

String _consentActionLabel(
  CoachingConsentAction action, {
  bool sentenceCase = false,
}) {
  final label = switch (action) {
    CoachingConsentAction.enable => 'enabled',
    CoachingConsentAction.disable => 'disabled',
    CoachingConsentAction.withdraw => 'withdrawn',
  };
  return sentenceCase
      ? '${label[0].toUpperCase()}${label.substring(1)}'
      : label;
}

class _OptionalNumber<T extends num> {
  final T? value;
  final bool isInvalid;

  const _OptionalNumber(this.value, this.isInvalid);
}
