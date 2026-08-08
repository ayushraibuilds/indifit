import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_constraints.dart';
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
        title: const Text('Dietary constraints'),
        actions: [
          IconButton(
            tooltip: 'Reload dietary constraints',
            onPressed: busy ? null : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAdd ? () => _showAddDialog(state.definitions) : null,
        icon: const Icon(Icons.add),
        label: const Text('Add constraint'),
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
        return Center(
          child: Semantics(
            label: 'Loading dietary constraints',
            child: CircularProgressIndicator(),
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
              for (final constraint in state.constraints)
                _ConstraintCard(
                  constraint: constraint,
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        container: true,
        label:
            'Dietary constraints are user-entered records. Evaluation uses explicit evidence. No known conflict does not mean guaranteed safety.',
        child: const Text(
          'Constraints are user-entered records. Food and recipe checks use explicit evidence; missing information stays visible and is not treated as safe.',
        ),
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
    final definition = NutritionConstraintTaxonomy.definitionForId(
      constraint.definitionId,
    );
    final stateLabel = constraint.isActive ? 'Active' : 'Archived';
    final targetLabel =
        '${constraint.target.type.stableId}: ${constraint.target.id}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    definition.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(stateLabel),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Stable target identity $targetLabel',
              child: Text(targetLabel),
            ),
            const SizedBox(height: 4),
            Text('Handling: ${constraint.strictness.stableId}'),
            if (constraint.crossContact) const Text('Cross-contact: included'),
            if (constraint.notes != null) ...[
              const SizedBox(height: 4),
              Text('Note: ${constraint.notes}'),
            ],
            if (onEdit != null || onArchive != null)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    if (onArchive != null)
                      TextButton.icon(
                        onPressed: onArchive,
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Archive'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No dietary constraints recorded.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
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
    return AlertDialog(
      title: const Text('Edit dietary constraint'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(definition.displayName),
            ),
            const SizedBox(height: 8),
            Semantics(
              label:
                  'Stable target identity ${widget.constraint.target.stableKey}',
              child: Text(
                widget.constraint.target.stableKey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
                      value.stableId,
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
    } on NutritionConstraintError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
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
    _targetType = allowed.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _definition.targetTypes.toList()
      ..sort((a, b) => a.stableId.compareTo(b.stableId));
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
                  decoration: const InputDecoration(labelText: 'Category'),
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
                  decoration: const InputDecoration(labelText: 'Target type'),
                  items: [
                    for (final targetType in allowed)
                      DropdownMenuItem(
                        value: targetType,
                        child: Text(
                          targetType.stableId,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _targetType = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetIdController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Stable target ID',
                helperText: 'Use an approved portable ID, not a display name.',
              ),
              textInputAction: TextInputAction.next,
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
                      value.stableId,
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
    final targetId = _targetIdController.text.trim();
    final targetType = _targetType;
    if (targetType == null || targetId.isEmpty) {
      setState(() => _error = 'Choose a target type and enter its stable ID.');
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
    } on NutritionConstraintError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
