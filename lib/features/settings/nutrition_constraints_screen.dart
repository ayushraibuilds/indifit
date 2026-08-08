import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/secondary_presentation.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/responsive_form_primitives.dart';
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
            tooltip: 'Reload dietary constraints',
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
              label: const Text('Add a preference'),
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
          message: state.message ?? 'Could not load dietary constraints.',
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
              for (
                var index = 0;
                index < state.constraints.length;
                index++
              ) ...[
                _ConstraintCard(
                  constraint: state.constraints[index],
                  onEdit: state.constraints[index].isActive && !busy
                      ? () => _showEditDialog(state.constraints[index])
                      : null,
                  onArchive: state.constraints[index].isActive && !busy
                      ? () => controller.archiveConstraint(
                          state.constraints[index].id,
                        )
                      : null,
                ),
                if (index < state.constraints.length - 1)
                  const SizedBox(height: B05Layout.space12),
              ],
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
                  'Could not save the constraint.',
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
                  'Could not update the constraint.',
            );
          }
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
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
          'Dietary preferences help IndiFit check meals. No known conflict is not a safety guarantee.',
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

class _ConstraintCard extends StatelessWidget {
  final NutritionUserConstraint constraint;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  const _ConstraintCard({
    required this.constraint,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final presentation = NutritionConstraintPresentation.fromDomain(constraint);
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
                Text('Past preference', style: B05Typography.body(context)),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          Text(presentation.detail, style: B05Typography.body(context)),
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
          if (onEdit != null || onArchive != null)
            Align(
              alignment: Alignment.centerRight,
              child: B05ActionGroup(
                children: [
                  if (onEdit != null)
                    B05ActionButton(
                      onPressed: onEdit,
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      emphasis: B05ActionEmphasis.secondary,
                    ),
                  if (onArchive != null)
                    B05ActionButton(
                      onPressed: onArchive,
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
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'What should we avoid?',
            style: B05Typography.title(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'No dietary constraints recorded.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            // Keep the established action label for saved automation and
            // accessibility users; the surrounding copy supplies the warmer
            // consumer framing.
            label: const Text('Add a constraint'),
          ),
        ],
      ),
    ),
  );
}

class _EditConstraintDialog extends StatefulWidget {
  final NutritionUserConstraint constraint;
  final Future<void> Function(NutritionUserConstraint updated) onSave;

  const _EditConstraintDialog({required this.constraint, required this.onSave});

  @override
  State<_EditConstraintDialog> createState() => _EditConstraintDialogState();
}

class _EditConstraintDialogState extends State<_EditConstraintDialog> {
  late NutritionConstraintStrictness _strictness;
  late bool _crossContact;
  late final TextEditingController _notesController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _strictness = widget.constraint.strictness;
    _crossContact = widget.constraint.crossContact;
    _notesController = TextEditingController(text: widget.constraint.notes);
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
    final presentation = NutritionConstraintPresentation.fromDomain(
      widget.constraint,
    );
    return AlertDialog(
      title: const Text('Edit dietary preference'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Avoiding ${presentation.title}'),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: presentation.title,
              child: Text(
                presentation.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NutritionConstraintStrictness>(
              initialValue: _strictness,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'How should we handle it?',
              ),
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
                title: const Text('Include traces and shared equipment'),
              ),
            TextField(
              controller: _notesController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true, child: Text(_error!)),
              ),
          ],
        ),
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
        _error = 'Could not update this preference. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update the constraint. Try again.';
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
          const Text('Dietary constraints are unavailable.'),
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

class _AddConstraintDialog extends StatefulWidget {
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
  State<_AddConstraintDialog> createState() => _AddConstraintDialogState();
}

class _AddConstraintDialogState extends State<_AddConstraintDialog> {
  late NutritionConstraintType _type;
  NutritionConstraintTargetType? _targetType;
  NutritionConstraintStrictness _strictness =
      NutritionConstraintStrictness.avoid;
  bool _crossContact = false;
  bool _saving = false;
  String? _error;
  final _targetIdController = TextEditingController();
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
    _targetIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  NutritionConstraintDefinition get _definition =>
      NutritionConstraintTaxonomy.definitionForType(_type);

  void _setDefaultTargetType() {
    final allowed = _definition.targetTypes.toList()
      ..sort((a, b) => a.stableId.compareTo(b.stableId));
    _targetType = allowed.contains(NutritionConstraintTargetType.ingredient)
        ? NutritionConstraintTargetType.ingredient
        : allowed.contains(NutritionConstraintTargetType.food)
        ? NutritionConstraintTargetType.food
        : allowed.firstOrNull;
  }

  void _selectChoice(DietaryChoicePresentation choice) {
    _targetIdController.text = choice.label;
    _targetIdController.selection = TextSelection.fromPosition(
      TextPosition(offset: _targetIdController.text.length),
    );
    if (_definition.targetTypes.contains(choice.targetType)) {
      _targetType = choice.targetType;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canUseCrossContact = _definition.crossContactSupported;
    return AlertDialog(
      title: const Text('Add dietary constraint'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IndiFitResponsiveFieldGroup(
              children: [
                DropdownButtonFormField<NutritionConstraintType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Why are you avoiding it?',
                  ),
                  items: [
                    for (final definition in widget.definitions)
                      DropdownMenuItem(
                        value: definition.type,
                        child: Text(
                          _friendlyConstraintType(definition.type),
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
                TextField(
                  controller: _targetIdController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Food or ingredient',
                    hintText: 'Search or type a food, such as peanuts',
                    helperText: 'Choose a common food below, or type your own.',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final choice in DietaryChoicesPresentation.search(
                    _targetIdController.text,
                  ).take(8))
                    ChoiceChip(
                      label: Text(choice.label),
                      selected:
                          _targetIdController.text.trim().toLowerCase() ==
                          choice.label.toLowerCase(),
                      onSelected: _saving ? null : (_) => _selectChoice(choice),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NutritionConstraintStrictness>(
              initialValue: _strictness,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'How strict should this be?',
              ),
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
                title: const Text('Include traces and shared equipment'),
              ),
            TextField(
              controller: _notesController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true, child: Text(_error!)),
              ),
          ],
        ),
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

  Future<void> _save() async {
    final rawTarget = _targetIdController.text.trim();
    final selectedChoice = DietaryChoicesPresentation.common.firstWhere(
      (choice) =>
          choice.label.toLowerCase() == rawTarget.toLowerCase() ||
          choice.id == rawTarget.toLowerCase().replaceAll('-', '_'),
      orElse: () => const DietaryChoicePresentation(
        id: '',
        label: '',
        targetType: NutritionConstraintTargetType.ingredient,
      ),
    );
    final targetId = selectedChoice.id.isEmpty ? rawTarget : selectedChoice.id;
    final targetType = selectedChoice.id.isEmpty
        ? _targetType
        : selectedChoice.targetType;
    if (targetType == null || targetId.isEmpty) {
      setState(() => _error = 'Choose what this preference applies to.');
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
        _error = 'Could not save this preference. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the constraint. Try again.';
      });
    }
  }
}

String _friendlyConstraintType(NutritionConstraintType type) => switch (type) {
  NutritionConstraintType.allergy => 'Allergy or safety concern',
  NutritionConstraintType.intolerance => 'Intolerance',
  NutritionConstraintType.religiousRestriction =>
    'Religious or cultural choice',
  NutritionConstraintType.ethicalPreference => 'Lifestyle preference',
  NutritionConstraintType.dietaryPattern => 'Dietary pattern',
  NutritionConstraintType.tasteDislike => 'Taste preference',
  NutritionConstraintType.temporaryAvoidance => 'Temporary choice',
  NutritionConstraintType.regionalPreference => 'Regional preference',
};

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
