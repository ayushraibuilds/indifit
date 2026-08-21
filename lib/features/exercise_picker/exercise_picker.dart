import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fixtures/exercise_display_muscles.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/exercise_picker_repository.dart';
import 'exercise_picker_models.dart';

export 'exercise_picker_models.dart';

/// Search-first, compact exercise selection surface shared by add and
/// replacement flows.
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({
    required this.selectionContext,
    super.key,
    this.repository,
    this.onReplacementCommit,
    this.onExerciseSelected,
  });

  final ExercisePickerSelectionContext selectionContext;
  final ExercisePickerRepository? repository;
  final ExerciseReplacementCommitter? onReplacementCommit;
  final FutureOr<void> Function(
    Exercise exercise,
    ExercisePickerSelection selection,
  )?
  onExerciseSelected;

  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

/// Opens the shared picker for general exercise selection.
Future<ExercisePickerSelection?> showExercisePicker({
  required BuildContext context,
  ExercisePickerSelectionContext selectionContext =
      const ExerciseLibraryPickerContext(),
  ExercisePickerRepository? repository,
}) {
  return showIndiFitBottomSheet<ExercisePickerSelection>(
    context: context,
    semanticLabel: selectionContext.semanticLabel,
    builder: (_) => ExercisePicker(
      selectionContext: selectionContext,
      repository: repository,
    ),
  );
}

/// Opens the shared picker in typed replacement mode.
///
/// When [onReplacementCommit] is supplied, the picker invokes that callback
/// only after the canonical compatibility result allows the selected UUID and
/// returns a committed result after the callback completes. Without a
/// callback it returns a selected-only result so an existing B02 command can
/// be invoked after the sheet closes. The picker itself never creates a
/// session, changes an occurrence, or writes a draft.
Future<ExerciseReplacementResult?> showExerciseReplacementPicker({
  required BuildContext context,
  required ExerciseReplacementPickerContext selectionContext,
  ExercisePickerRepository? repository,
  ExerciseReplacementCommitter? onReplacementCommit,
}) {
  return showIndiFitBottomSheet<ExerciseReplacementResult>(
    context: context,
    semanticLabel: selectionContext.semanticLabel,
    builder: (_) => ExercisePicker(
      selectionContext: selectionContext,
      repository: repository,
      onReplacementCommit: onReplacementCommit,
    ),
  );
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<Exercise> _exercises = const [];
  List<String> _primaryMuscles = const [];
  List<String> _equipmentOptions = const [];
  String? _selectedPrimaryMuscle;
  String? _selectedEquipment;
  ProductFailurePresentation? _failure;
  var _loading = true;
  var _committing = false;
  ExercisePickerSelection? _pendingSelection;

  ExercisePickerRepository get _repository =>
      widget.repository ?? ref.read(exercisePickerRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadInitial());
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final results = await Future.wait<Object>([
        _repository.readPrimaryMuscles(),
        _repository.readEquipmentOptions(),
        _repository.search(
          ExercisePickerQuery(
            text: _searchController.text,
            primaryMuscle: _selectedPrimaryMuscle,
            equipment: _selectedEquipment,
          ),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _primaryMuscles = results[0] as List<String>;
        _equipmentOptions = results[1] as List<String>;
        _exercises = results[2] as List<Exercise>;
        _loading = false;
      });
    } catch (error) {
      _setFailure(error, clearResults: true);
    }
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) unawaited(_loadResults());
    });
    if (mounted) setState(() {});
  }

  Future<void> _loadResults() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final results = await _repository.search(
        ExercisePickerQuery(
          text: _searchController.text,
          primaryMuscle: _selectedPrimaryMuscle,
          equipment: _selectedEquipment,
        ),
      );
      if (!mounted) return;
      setState(() {
        _exercises = results;
        _loading = false;
      });
    } catch (error) {
      _setFailure(error, clearResults: true);
    }
  }

  void _setFailure(Object error, {bool clearResults = false}) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (clearResults) _exercises = const [];
      _failure = ProductFailurePresentation.fromError(
        error,
        title: 'Exercises unavailable',
      );
    });
  }

  void _selectPrimary(String? value) {
    setState(() => _selectedPrimaryMuscle = value);
    unawaited(_loadResults());
  }

  void _selectEquipment(String? value) {
    setState(() => _selectedEquipment = value);
    unawaited(_loadResults());
  }

  Future<void> _selectExercise(Exercise exercise) async {
    if (_committing) return;
    final selection = ExercisePickerSelection.fromExercise(exercise);
    final pickerContext = widget.selectionContext;
    if (pickerContext is! ExerciseReplacementPickerContext) {
      final callback = widget.onExerciseSelected;
      if (callback != null) {
        try {
          await callback(exercise, selection);
        } catch (error) {
          _setFailure(error);
        }
        return;
      }
      if (mounted) Navigator.of(context).pop(selection);
      return;
    }

    final candidate = pickerContext.compatibility.forExerciseId(
      selection.exerciseId,
    );
    if (!candidate.isSelectable ||
        selection.exerciseId ==
            pickerContext.target.currentPerformedExerciseId) {
      return;
    }

    final confirmed = await _confirmReplacement(
      selection: selection,
      candidate: candidate,
      target: pickerContext.target,
    );
    if (!confirmed || !mounted) return;

    final commit = widget.onReplacementCommit;
    setState(() {
      _committing = commit != null;
      _pendingSelection = selection;
      _failure = null;
    });
    if (commit == null) {
      _popReplacement(
        ExerciseReplacementResult(
          target: pickerContext.target,
          selection: selection,
          status: ExerciseReplacementCommitStatus.selectedOnly,
          preservesLoggedEvidence: candidate.preservesLoggedEvidence,
        ),
      );
      return;
    }

    try {
      await commit(target: pickerContext.target, selection: selection);
      if (!mounted) return;
      _popReplacement(
        ExerciseReplacementResult(
          target: pickerContext.target,
          selection: selection,
          status: ExerciseReplacementCommitStatus.committed,
          preservesLoggedEvidence: candidate.preservesLoggedEvidence,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _committing = false;
        _failure = ProductFailurePresentation.fromError(
          error,
          title: 'Replacement unavailable',
        );
      });
    }
  }

  Future<bool> _confirmReplacement({
    required ExercisePickerSelection selection,
    required CanonicalReplacementCandidate candidate,
    required ExerciseReplacementTarget target,
  }) async {
    if (!candidate.requiresConfirmation) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use this replacement?'),
        content: Text(
          '${candidate.consumerEffect(selection.exerciseNameSnapshot)}\n\n'
          '${target.modeLabel} stays open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep browsing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Use replacement'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _retryCommit() {
    final selection = _pendingSelection;
    if (selection == null || _committing) return;
    final exercise = _exercises.cast<Exercise?>().firstWhere(
      (candidate) => candidate?.stableId?.trim() == selection.exerciseId,
      orElse: () => null,
    );
    if (exercise == null) return;
    unawaited(_selectExercise(exercise));
  }

  void _popReplacement(ExerciseReplacementResult result) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final pickerContext = widget.selectionContext;
    final replacementContext = pickerContext is ExerciseReplacementPickerContext
        ? pickerContext
        : null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space12,
        B05Layout.space16,
        B05Layout.space16 + bottomInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, pickerContext),
            if (replacementContext != null)
              _buildReplacementContext(context, replacementContext),
            const SizedBox(height: B05Layout.space12),
            Semantics(
              textField: true,
              label: 'Search exercises',
              child: TextField(
                controller: _searchController,
                autofocus: true,
                enabled: !_committing,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search exercises',
                  hintText: 'Name, equipment, or muscle',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear exercise search',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _committing
                              ? null
                              : _searchController.clear,
                        ),
                ),
              ),
            ),
            const SizedBox(height: B05Layout.space8),
            _buildFilters(context),
            if (_failure != null) ...[
              const SizedBox(height: B05Layout.space8),
              ProductFailureCard(
                failure: _failure!,
                onRetry: _pendingSelection != null
                    ? _retryCommit
                    : _loadInitial,
                onBack: () => Navigator.of(context).pop(),
              ),
            ],
            if (_committing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: B05Layout.space8),
                child: ConsumerStatusRow(
                  label: 'Applying replacement…',
                  loading: true,
                ),
              ),
            const SizedBox(height: B05Layout.space4),
            Expanded(child: _buildResults(context, replacementContext)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ExercisePickerSelectionContext pickerContext,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            pickerContext.title,
            style: B05Typography.pageTitle(context),
          ),
        ),
        Semantics(
          button: true,
          label: 'Close exercise picker',
          child: IconButton(
            tooltip: 'Close exercise picker',
            icon: const Icon(Icons.close_rounded),
            onPressed: _committing ? null : () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildReplacementContext(
    BuildContext context,
    ExerciseReplacementPickerContext pickerContext,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        container: true,
        label:
            'Replacing ${pickerContext.target.currentExerciseNameSnapshot}. '
            '${pickerContext.target.modeLabel}.',
        child: Text(
          'Replacing ${pickerContext.target.currentExerciseNameSnapshot} · '
          '${pickerContext.target.modeLabel}',
          style: B05Typography.caption(context),
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return SizedBox(
      height: B05Layout.minTouchTarget,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            context: context,
            label: 'All muscles',
            filterType: 'primary muscle',
            selected: _selectedPrimaryMuscle == null,
            onSelected: _selectPrimary,
            value: null,
          ),
          ..._primaryMuscles.map(
            (muscle) => _buildFilterChip(
              context: context,
              label: muscle,
              filterType: 'primary muscle',
              selected: _selectedPrimaryMuscle == muscle,
              onSelected: _selectPrimary,
              value: muscle,
            ),
          ),
          if (_equipmentOptions.isNotEmpty) ...[
            const SizedBox(width: B05Layout.space8),
            _buildFilterChip(
              context: context,
              label: 'All equipment',
              filterType: 'equipment',
              selected: _selectedEquipment == null,
              onSelected: _selectEquipment,
              value: null,
            ),
            ..._equipmentOptions.map(
              (equipment) => _buildFilterChip(
                context: context,
                label: equipment,
                filterType: 'equipment',
                selected: _selectedEquipment == equipment,
                onSelected: _selectEquipment,
                value: equipment,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required String filterType,
    required bool selected,
    required ValueChanged<String?> onSelected,
    required String? value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: B05Layout.space8),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label $filterType filter',
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: _committing
              ? null
              : (isSelected) => onSelected(isSelected ? value : null),
        ),
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    ExerciseReplacementPickerContext? replacementContext,
  ) {
    if (_failure != null && _pendingSelection == null) {
      return const SizedBox.expand();
    }
    if (_loading) {
      return Center(
        child: Semantics(
          label: 'Loading exercises',
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_exercises.isEmpty) {
      final query = _searchController.text.trim();
      return ProductEmptyState(
        icon: Icons.search_off_rounded,
        title: query.isEmpty ? 'No exercises yet' : 'No matching exercises',
        message: query.isEmpty
            ? 'No exercises are available for selection right now.'
            : 'No exercises match “$query”. Try another search or filter.',
        action: query.isEmpty ? null : _searchController.clear,
        actionLabel: query.isEmpty ? null : 'Clear search',
        actionIcon: query.isEmpty ? null : Icons.clear_rounded,
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _exercises.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final exercise = _exercises[index];
        return _buildExerciseRow(context, exercise, replacementContext);
      },
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    Exercise exercise,
    ExerciseReplacementPickerContext? replacementContext,
  ) {
    final muscles = ExerciseDisplayMuscles.fromMuscleGroups(
      exercise.muscleGroups,
    );
    final primary = muscles.primary ?? 'Primary muscle unavailable';
    final equipment = exercise.equipment.trim().isEmpty
        ? 'Equipment unavailable'
        : exercise.equipment.trim();
    final secondary = muscles.secondary.isEmpty
        ? null
        : 'Also works ${muscles.secondary.join(', ')}';
    final candidate = replacementContext?.compatibility.forExerciseId(
      exercise.stableId ?? '',
    );
    final selected =
        widget.selectionContext.selectedExerciseId?.trim() ==
        exercise.stableId?.trim();
    final isCurrent =
        replacementContext != null &&
        exercise.stableId?.trim() ==
            replacementContext.target.currentPerformedExerciseId;
    final isSelectable = replacementContext == null
        ? true
        : candidate!.isSelectable && !isCurrent;
    final unavailableReason = isCurrent
        ? 'This exercise is already selected.'
        : candidate?.consumerUnavailableReason;
    final title = exercise.name.trim();
    final semanticLabel = unavailableReason == null
        ? '$title. Primary muscle $primary. Equipment $equipment.'
        : '$title. Primary muscle $primary. Equipment $equipment. '
              '$unavailableReason';

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: isSelectable && !_committing,
      label: selected ? '$semanticLabel Selected.' : semanticLabel,
      hint: isSelectable
          ? 'Double tap to select.'
          : selected
          ? 'Selected exercise.'
          : unavailableReason,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: B05Layout.space4,
          vertical: B05Layout.space4,
        ),
        enabled: isSelectable && !_committing,
        selected: selected,
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: B05Layout.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$primary · $equipment'),
              if (secondary != null)
                Text(secondary, style: B05Typography.caption(context)),
              if (unavailableReason != null)
                Text(unavailableReason, style: B05Typography.caption(context)),
            ],
          ),
        ),
        trailing: Icon(
          !isSelectable
              ? Icons.lock_outline_rounded
              : selected
              ? Icons.check_circle_outline_rounded
              : replacementContext == null
              ? Icons.add_circle_outline_rounded
              : Icons.swap_horiz_rounded,
          semanticLabel: selected
              ? 'Selected'
              : isSelectable
              ? 'Available'
              : 'Unavailable',
        ),
        onTap: isSelectable && !_committing
            ? () => _selectExercise(exercise)
            : null,
      ),
    );
  }
}
