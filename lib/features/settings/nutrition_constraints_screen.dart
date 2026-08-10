import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/diet_preference_presentation.dart';
import '../../core/presentation/secondary_presentation.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/responsive_form_primitives.dart';
import '../../data/repositories/nutrition_constraint_repository.dart';
import 'nutrition_constraints_controller.dart';

class NutritionConstraintsScreen extends ConsumerStatefulWidget {
  const NutritionConstraintsScreen({super.key});

  @override
  ConsumerState<NutritionConstraintsScreen> createState() =>
      _NutritionConstraintsScreenState();
}

class _NutritionConstraintsScreenState
    extends ConsumerState<NutritionConstraintsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nutritionConstraintManagementControllerProvider);
    final controller = ref.read(
      nutritionConstraintManagementControllerProvider.notifier,
    );
    final busy =
        state.status == NutritionConstraintManagementStatus.saving ||
        state.status == NutritionConstraintManagementStatus.archiving;
    final canAdd =
        !busy &&
        state.definitions.isNotEmpty &&
        state.status != NutritionConstraintManagementStatus.loading &&
        state.status != NutritionConstraintManagementStatus.failure;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dietary needs'),
        actions: [
          IconButton(
            tooltip: 'Reload dietary needs',
            onPressed: busy ? null : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton:
          state.status == NutritionConstraintManagementStatus.empty
          ? null
          : FloatingActionButton.extended(
              onPressed: canAdd
                  ? () => _showAddDialog(state.definitions)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Add dietary need'),
            ),
      body: _buildBody(state, controller, busy),
    );
  }

  Widget _buildBody(
    NutritionConstraintManagementState state,
    NutritionConstraintManagementController controller,
    bool busy,
  ) {
    switch (state.status) {
      case NutritionConstraintManagementStatus.loading:
        return const Center(
          child: ConsumerStatusRow(
            label: 'Loading your dietary needs',
            detail: 'Getting your saved choices ready.',
            loading: true,
          ),
        );
      case NutritionConstraintManagementStatus.failure:
        return _FailureState(
          message: state.message ?? 'Could not load dietary needs.',
          onRetry: controller.retry,
        );
      case NutritionConstraintManagementStatus.empty:
        return _EmptyState(onAdd: () => _showAddDialog(state.definitions));
      case NutritionConstraintManagementStatus.ready:
      case NutritionConstraintManagementStatus.saving:
      case NutritionConstraintManagementStatus.archiving:
      case NutritionConstraintManagementStatus.success:
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const _DietPatternCard(),
              const SizedBox(height: 12),
              const _DisclosureCard(),
              if (busy) const LinearProgressIndicator(minHeight: 2),
              if (state.message != null && !busy)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(state.message!),
                  ),
                ),
              const SizedBox(height: 12),
              for (final constraint in state.constraints)
                _ConstraintCard(
                  constraint: constraint,
                  resolveTargetLabel: controller.targetDisplayLabel,
                  onEdit: constraint.isActive && !busy
                      ? () => _showEditDialog(constraint)
                      : null,
                  onArchive: constraint.isActive && !busy
                      ? () => controller.archiveConstraint(constraint.id)
                      : null,
                ),
            ],
          ),
        );
    }
  }

  Future<void> _showAddDialog(
    List<NutritionConstraintDefinition> definitions,
  ) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddConstraintDialog(
        definitions: definitions,
        onSave: (type, target, strictness, crossContact, notes) async {
          final controller = ref.read(
            nutritionConstraintManagementControllerProvider.notifier,
          );
          await controller.addConstraint(
            type: type,
            target: target,
            strictness: strictness,
            crossContact: crossContact,
            notes: notes,
          );
          if (controller.currentState.status ==
              NutritionConstraintManagementStatus.failure) {
            throw NutritionConstraintValidationError(
              controller.currentState.errorCode ?? 'constraint_save_failed',
              controller.currentState.message ??
                  'Could not save the dietary need.',
            );
          }
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _showEditDialog(NutritionUserConstraint constraint) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EditConstraintDialog(
        constraint: constraint,
        resolveTargetLabel: ref
            .read(nutritionConstraintManagementControllerProvider.notifier)
            .targetDisplayLabel,
        onSave: (updated) async {
          final controller = ref.read(
            nutritionConstraintManagementControllerProvider.notifier,
          );
          await controller.updateConstraint(updated);
          if (controller.currentState.status ==
              NutritionConstraintManagementStatus.failure) {
            throw NutritionConstraintValidationError(
              controller.currentState.errorCode ?? 'constraint_update_failed',
              controller.currentState.message ??
                  'Could not update the dietary need.',
            );
          }
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }
}

class _DietPatternCard extends ConsumerWidget {
  const _DietPatternCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final uiValue = profile.hasProfile
        ? DietPreferencePresentation.uiValueFor(profile.dietPreference)
        : null;
    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dietary pattern', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Choose the pattern that best fits how you eat. Allergies and strict restrictions stay separate below.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          DietPreferenceDropdown(
            selectedUiValue: uiValue,
            decoration: const InputDecoration(labelText: 'Pattern'),
            onChanged: (value) async {
              if (value == null) return;
              await ref
                  .read(userProfileProvider.notifier)
                  .updateDietPreference(
                    DietPreferencePresentation.persistedValueFor(
                      originalValue: profile.dietPreference,
                      uiValue: value,
                      userChanged: true,
                    ),
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard();

  @override
  Widget build(BuildContext context) => B05Surface(
    showBorder: false,
    subtle: true,
    child: Semantics(
      container: true,
      label:
          'Dietary needs help IndiFit check meals. No known conflict is not a safety guarantee.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What should we avoid?', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Add foods or ingredients you want us to handle carefully. You can change these any time.',
            style: B05Typography.body(context),
          ),
        ],
      ),
    ),
  );
}

class _ConstraintCard extends StatefulWidget {
  final NutritionUserConstraint constraint;
  final Future<String?> Function(NutritionConstraintTarget target)
  resolveTargetLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  const _ConstraintCard({
    required this.constraint,
    required this.resolveTargetLabel,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  State<_ConstraintCard> createState() => _ConstraintCardState();
}

class _ConstraintCardState extends State<_ConstraintCard> {
  late Future<String?> _targetLabel;

  @override
  void initState() {
    super.initState();
    _targetLabel = widget.resolveTargetLabel(widget.constraint.target);
  }

  @override
  void didUpdateWidget(covariant _ConstraintCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.constraint.target != widget.constraint.target) {
      _targetLabel = widget.resolveTargetLabel(widget.constraint.target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = NutritionConstraintPresentation.fromDomain(
      widget.constraint,
    );
    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  presentation.title,
                  style: B05Typography.title(context),
                ),
              ),
              if (!presentation.active)
                Text('Past dietary need', style: B05Typography.body(context)),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          Text(presentation.detail, style: B05Typography.body(context)),
          const SizedBox(height: B05Layout.space4),
          FutureBuilder<String?>(
            future: _targetLabel,
            builder: (context, snapshot) {
              final label = snapshot.data == null
                  ? presentation.title
                  : ConsumerCopy.label(snapshot.data);
              final targetLabel =
                  '${ConsumerCopy.targetType(widget.constraint.target.type.stableId)}: $label';
              return Semantics(
                label: targetLabel,
                child: Text(targetLabel, style: B05Typography.body(context)),
              );
            },
          ),
          const SizedBox(height: B05Layout.space8),
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space4,
            children: [
              Chip(label: Text(presentation.handling)),
              if (presentation.crossContact)
                const Chip(label: Text('Include traces')),
            ],
          ),
          if (presentation.note != null) ...[
            const SizedBox(height: B05Layout.space4),
            Text(
              'Note: ${presentation.note}',
              style: B05Typography.body(context),
            ),
          ],
          if (widget.onEdit != null || widget.onArchive != null)
            Align(
              alignment: Alignment.centerRight,
              child: B05ActionGroup(
                children: [
                  if (widget.onEdit != null)
                    B05ActionButton(
                      onPressed: widget.onEdit,
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      emphasis: B05ActionEmphasis.secondary,
                    ),
                  if (widget.onArchive != null)
                    B05ActionButton(
                      onPressed: widget.onArchive,
                      icon: Icons.archive_outlined,
                      label: 'Archive',
                      emphasis: B05ActionEmphasis.secondary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const _DietPatternCard(),
      const SizedBox(height: 12),
      Text(
        'What should we avoid?',
        style: B05Typography.title(context),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add dietary need'),
      ),
      const SizedBox(height: 8),
      const Text(
        'No added restrictions yet. Add one when you want recommendations to be more careful.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _EditConstraintDialog extends StatefulWidget {
  final NutritionUserConstraint constraint;
  final Future<String?> Function(NutritionConstraintTarget target)
  resolveTargetLabel;
  final Future<void> Function(NutritionUserConstraint updated) onSave;

  const _EditConstraintDialog({
    required this.constraint,
    required this.resolveTargetLabel,
    required this.onSave,
  });

  @override
  State<_EditConstraintDialog> createState() => _EditConstraintDialogState();
}

class _EditConstraintDialogState extends State<_EditConstraintDialog> {
  late NutritionConstraintStrictness _strictness;
  late bool _crossContact;
  late final TextEditingController _notesController;
  late Future<String?> _targetLabel;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _strictness = widget.constraint.strictness;
    _crossContact = widget.constraint.crossContact;
    _notesController = TextEditingController(text: widget.constraint.notes);
    _targetLabel = widget.resolveTargetLabel(widget.constraint.target);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = NutritionConstraintTaxonomy.definitionForId(
      widget.constraint.definitionId,
    );
    return AlertDialog(
      title: const Text('Edit dietary need'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(definition.displayName),
          ),
          const SizedBox(height: 8),
          FutureBuilder<String?>(
            future: _targetLabel,
            builder: (context, snapshot) {
              final label = snapshot.data == null
                  ? ConsumerCopy.target(widget.constraint.target.id)
                  : ConsumerCopy.label(snapshot.data);
              final targetLabel =
                  '${ConsumerCopy.targetType(widget.constraint.target.type.stableId)}: $label';
              return Semantics(
                label: targetLabel,
                child: Text(
                  targetLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<NutritionConstraintStrictness>(
            initialValue: _strictness,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Handling'),
            items: [
              for (final value in NutritionConstraintStrictness.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(
                    ConsumerCopy.strictness(value.stableId),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _strictness = value);
                  },
          ),
          if (definition.crossContactSupported)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _crossContact,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _crossContact = value ?? false),
              title: const Text('Include cross-contact handling'),
            ),
          TextField(
            controller: _notesController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Optional note'),
            maxLines: 2,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text(_error!)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save changes'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notes = _notesController.text.trim();
      await widget.onSave(
        widget.constraint.copyWith(
          strictness: _strictness,
          crossContact: _crossContact,
          notes: notes.isEmpty ? null : notes,
          clearNotes: notes.isEmpty,
        ),
      );
    } on NutritionConstraintError {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update this dietary need. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update the dietary need. Try again.';
      });
    }
  }
}

class _FailureState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailureState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Dietary needs are unavailable.'),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _AddConstraintDialog extends ConsumerStatefulWidget {
  final List<NutritionConstraintDefinition> definitions;
  final Future<void> Function(
    NutritionConstraintType type,
    NutritionConstraintTarget target,
    NutritionConstraintStrictness strictness,
    bool crossContact,
    String? notes,
  )
  onSave;

  const _AddConstraintDialog({required this.definitions, required this.onSave});

  @override
  ConsumerState<_AddConstraintDialog> createState() =>
      _AddConstraintDialogState();
}

class _AddConstraintDialogState extends ConsumerState<_AddConstraintDialog> {
  late NutritionConstraintType _type;
  NutritionConstraintTargetType? _targetType;
  NutritionConstraintStrictness _strictness =
      NutritionConstraintStrictness.avoid;
  bool _crossContact = false;
  bool _saving = false;
  String? _error;
  String? _selectedTargetId;
  String? _selectedTargetLabel;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type =
        widget.definitions.firstOrNull?.type ?? NutritionConstraintType.allergy;
    _setDefaultTargetType();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  NutritionConstraintDefinition get _definition =>
      NutritionConstraintTaxonomy.definitionForType(_type);

  List<NutritionConstraintTargetType> get _allowedTargetTypes {
    final allowed = _definition.targetTypes
        .where(
          (type) => type != NutritionConstraintTargetType.unknownOrUnsupported,
        )
        .toList();
    allowed.sort(
      (left, right) => ConsumerCopy.targetType(
        left.stableId,
      ).compareTo(ConsumerCopy.targetType(right.stableId)),
    );
    return allowed;
  }

  void _setDefaultTargetType() {
    final allowed = _allowedTargetTypes;
    _targetType = allowed.firstOrNull;
    _clearTargetSelection();
  }

  void _clearTargetSelection() {
    _selectedTargetId = null;
    _selectedTargetLabel = null;
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowedTargetTypes;
    final canUseCrossContact = _definition.crossContactSupported;
    return AlertDialog(
      title: const Text('Add a dietary need'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IndiFitResponsiveFieldGroup(
            children: [
              DropdownButtonFormField<NutritionConstraintType>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Why should we avoid it?',
                ),
                items: [
                  for (final definition in widget.definitions)
                    DropdownMenuItem(
                      value: definition.type,
                      child: Text(
                        definition.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _type = value;
                          _setDefaultTargetType();
                        });
                      },
              ),
              DropdownButtonFormField<NutritionConstraintTargetType>(
                initialValue: _targetType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Applies to'),
                items: [
                  for (final targetType in allowed)
                    DropdownMenuItem(
                      value: targetType,
                      child: Text(
                        ConsumerCopy.targetType(targetType.stableId),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _targetType = value;
                          _clearTargetSelection();
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTargetPicker(),
          const SizedBox(height: 12),
          DropdownButtonFormField<NutritionConstraintStrictness>(
            initialValue: _strictness,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Handling'),
            items: [
              for (final value in NutritionConstraintStrictness.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(
                    ConsumerCopy.strictness(value.stableId),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _strictness = value);
                  },
          ),
          if (canUseCrossContact)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _crossContact,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _crossContact = value ?? false),
              title: const Text('Include cross-contact handling'),
            ),
          TextField(
            controller: _notesController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Optional note'),
            maxLines: 2,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text(_error!)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTargetPicker() {
    final targetType = _targetType;
    if (targetType == null) return const SizedBox.shrink();
    final fixedIds = NutritionConstraintTargetCatalog.fixedIds[targetType];
    if (fixedIds != null && fixedIds.isNotEmpty) {
      final values = fixedIds.toList()
        ..sort(
          (left, right) =>
              ConsumerCopy.target(left).compareTo(ConsumerCopy.target(right)),
        );
      return DropdownButtonFormField<String>(
        key: ValueKey(targetType),
        initialValue: _selectedTargetId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'What should we avoid?',
          helperText: 'Choose an item IndiFit can check reliably.',
        ),
        items: [
          for (final value in values)
            DropdownMenuItem(
              value: value,
              child: Text(
                ConsumerCopy.target(value),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _saving
            ? null
            : (value) => setState(() {
                _selectedTargetId = value;
                _selectedTargetLabel = value == null
                    ? null
                    : ConsumerCopy.target(value);
              }),
      );
    }
    final choiceLabel = targetType == NutritionConstraintTargetType.preparation
        ? 'Choose a prepared food'
        : 'Choose a food';
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'What should we avoid?',
        helperText: 'Choose an item IndiFit can check reliably.',
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _saving ? null : _chooseDynamicTarget,
          icon: const Icon(Icons.search_rounded),
          label: Text(_selectedTargetLabel ?? choiceLabel),
        ),
      ),
    );
  }

  Future<void> _chooseDynamicTarget() async {
    final targetType = _targetType;
    if (targetType == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final option = await showDialog<NutritionConstraintTargetOption>(
      context: context,
      builder: (context) => _ConstraintTargetPicker(
        title: targetType == NutritionConstraintTargetType.preparation
            ? 'prepared food'
            : 'food',
        onSearch: (query) => ref
            .read(nutritionConstraintManagementControllerProvider.notifier)
            .searchTargetOptions(type: targetType, query: query),
      ),
    );
    if (!mounted || option == null) return;
    setState(() {
      _selectedTargetId = option.target.id;
      _selectedTargetLabel = ConsumerCopy.label(option.displayLabel);
    });
  }

  Future<void> _save() async {
    final targetId = _selectedTargetId;
    final targetType = _targetType;
    if (targetType == null || targetId == null || targetId.isEmpty) {
      setState(() => _error = 'Choose what this dietary need applies to.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _type,
        NutritionConstraintTarget(type: targetType, id: targetId),
        _strictness,
        _crossContact,
        _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
    } on NutritionConstraintError {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this dietary need. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the dietary need. Try again.';
      });
    }
  }
}

class _ConstraintTargetPicker extends StatefulWidget {
  const _ConstraintTargetPicker({required this.title, required this.onSearch});

  final String title;
  final Future<List<NutritionConstraintTargetOption>> Function(String query)
  onSearch;

  @override
  State<_ConstraintTargetPicker> createState() =>
      _ConstraintTargetPickerState();
}

class _ConstraintTargetPickerState extends State<_ConstraintTargetPicker> {
  final _queryController = TextEditingController();
  late Future<List<NutritionConstraintTargetOption>> _results;

  @override
  void initState() {
    super.initState();
    _results = widget.onSearch('');
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _results = widget.onSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.45;
    return AlertDialog(
      title: Text('Choose ${widget.title}'),
      content: SizedBox(
        width: double.maxFinite,
        height: height,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search ${widget.title}',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: _search,
              onSubmitted: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<NutritionConstraintTargetOption>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Choices are unavailable right now. Try again.',
                      ),
                    );
                  }
                  final options = snapshot.data ?? const [];
                  if (options.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matching choices yet. Try a different search.',
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final label = ConsumerCopy.label(option.displayLabel);
                      return ListTile(
                        title: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
