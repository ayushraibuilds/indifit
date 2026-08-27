import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_thali.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import 'nutrition_thali_controller.dart';

/// B03-13's bounded composition surface. It delegates identity, quantity
/// validation, calculation, constraint evaluation, persistence, and history
/// writes to [NutritionThaliController].
class ThaliBuilderScreen extends ConsumerStatefulWidget {
  final String mealType;

  const ThaliBuilderScreen({super.key, required this.mealType});

  @override
  ConsumerState<ThaliBuilderScreen> createState() => _ThaliBuilderScreenState();
}

class _ThaliBuilderScreenState extends ConsumerState<ThaliBuilderScreen> {
  late final TextEditingController _searchController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _nameController = TextEditingController(text: 'My Meal');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  NutritionThaliController get _controller =>
      ref.read(nutritionThaliControllerProvider(widget.mealType).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nutritionThaliControllerProvider(widget.mealType));
    final draft = state.draft;
    if (draft != null && _nameController.text != draft.name) {
      _nameController.value = _nameController.value.copyWith(
        text: draft.name,
        selection: TextSelection.collapsed(offset: draft.name.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Build meal · ${widget.mealType.toUpperCase()}'),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, NutritionThaliState state) {
    if (state.status == NutritionThaliStatus.loading ||
        state.status == NutritionThaliStatus.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == NutritionThaliStatus.failure && state.draft == null) {
      return _FailurePanel(
        message: state.errorMessage ?? 'The meal could not be loaded.',
        onRetry: () => _controller.retry(),
      );
    }

    final draft = state.draft;
    if (draft == null) {
      return const Center(child: Text('No meal draft is available.'));
    }
    final isBusy =
        state.status == NutritionThaliStatus.saving ||
        state.status == NutritionThaliStatus.previewLoading ||
        state.status == NutritionThaliStatus.finalizing;

    if (draft.items.isEmpty) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildDraftHeader(draft, enabled: !isBusy),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 150),
                child: _EmptyStateContent(),
              ),
              _buildSearch(context, state, enabled: !isBusy),
              if (state.status == NutritionThaliStatus.failure)
                _FailurePanel(
                  message: state.errorMessage ?? 'The meal operation failed.',
                  compact: true,
                  onRetry: () => _controller.retry(loggedAt: DateTime.now()),
                ),
              _buildActions(context, state, enabled: !isBusy),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildDraftHeader(draft, enabled: !isBusy),
            _buildItemsList(state),
            _buildSearch(context, state, enabled: !isBusy),
            if (state.status == NutritionThaliStatus.failure)
              _FailurePanel(
                message: state.errorMessage ?? 'The meal operation failed.',
                compact: true,
                onRetry: () => _controller.retry(loggedAt: DateTime.now()),
              ),
            _buildActions(context, state, enabled: !isBusy),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftHeader(NutritionThaliDraft draft, {required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _nameController,
        enabled: enabled,
        onChanged: _controller.setName,
        decoration: const InputDecoration(
          labelText: 'Draft name',
          prefixIcon: Icon(Icons.edit_outlined),
        ),
      ),
    );
  }

  Widget _buildItemsList(NutritionThaliState state) {
    final draft = state.draft!;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: draft.items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: _controller.reorderItem,
      itemBuilder: (context, index) {
        final item = draft.items[index];
        final label =
            item.displayLabel ??
            (item.source == NutritionThaliItemSource.food ? 'Food' : 'Recipe');
        return Card(
          key: ValueKey(item.id),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Tooltip(
              message: 'Reorder $label',
              child: Semantics(
                label: 'Reorder $label',
                child: const Icon(Icons.drag_handle),
              ),
            ),
            title: Text(label),
            subtitle: Text(
              '${item.source == NutritionThaliItemSource.food ? 'Food' : 'Recipe'} · ${_quantityLabel(item.quantity)}${_measureLabel(item, state)}',
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 0,
              children: [
                IconButton(
                  tooltip: 'Edit quantity for $label',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editQuantity(context, item),
                ),
                IconButton(
                  tooltip: 'Remove $label',
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.b05Colors.danger.indicator,
                  ),
                  onPressed: () => _controller.removeItem(item.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearch(
    BuildContext context,
    NutritionThaliState state, {
    required bool enabled,
  }) {
    final hasResults =
        state.query.trim().isNotEmpty &&
        (state.foodResults.isNotEmpty ||
            state.recipeResults.isNotEmpty ||
            state.status == NutritionThaliStatus.searching ||
            state.status == NutritionThaliStatus.ready);
    return Material(
      color: context.b05Colors.section,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              enabled: enabled,
              onChanged: _controller.search,
              decoration: InputDecoration(
                hintText: 'Add food or saved recipe',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _controller.search('');
                          setState(() {});
                        },
                      ),
              ),
            ),
            if (hasResults)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: state.status == NutritionThaliStatus.searching
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _buildSearchResults(context, state),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, NutritionThaliState state) {
    return ListView(
      shrinkWrap: true,
      children: [
        for (final option in state.foodResults)
          ListTile(
            dense: true,
            leading: const Icon(Icons.restaurant_outlined),
            title: Text(option.displayName),
            subtitle: const Text('Food · identity retained'),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () => _controller.addFood(option),
          ),
        for (final option in state.recipeResults)
          ListTile(
            dense: true,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(option.recipeName),
            subtitle: const Text('Recipe'),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () => _controller.addRecipe(option),
          ),
        if (state.foodResults.isEmpty && state.recipeResults.isEmpty)
          const ListTile(
            title: Text('No matching active foods or saved recipes'),
            subtitle: Text(
              'Try another search. Draft or archived recipes are not offered.',
            ),
          ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    NutritionThaliState state, {
    required bool enabled,
  }) {
    final preview = state.preview;
    final draft = state.draft!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.status == NutritionThaliStatus.saving ||
              state.status == NutritionThaliStatus.previewLoading ||
              state.status == NutritionThaliStatus.finalizing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(switch (state.status) {
                    NutritionThaliStatus.saving => 'Saving draft…',
                    NutritionThaliStatus.previewLoading =>
                      'Calculating preview…',
                    NutritionThaliStatus.finalizing => 'Logging meal…',
                    _ => 'Working…',
                  }),
                ],
              ),
            ),
          if (preview != null) _buildPreview(context, state, preview),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled && draft.items.isNotEmpty
                      ? _controller.saveDraft
                      : null,
                  icon: const Icon(Icons.bookmark_outline),
                  label: const Text('Save draft'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: enabled && draft.items.isNotEmpty
                      ? _controller.preview
                      : null,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
          if (preview != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: enabled ? _finalize : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Log complete meal'),
                ),
              ),
            ),
          if (state.status == NutritionThaliStatus.success)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Done'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _finalize() async {
    try {
      final loggedAt = DateTime.now().toUtc();
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final localDate = ref
          .read(localScheduleDateServiceProvider)
          .localDateFor(loggedAt, timezoneId);
      await _controller.finalize(
        loggedAt: loggedAt,
        localDate: localDate,
        timezoneId: timezoneId,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The meal could not be logged. Try again.'),
          ),
        );
      }
    }
  }

  Widget _buildPreview(
    BuildContext context,
    NutritionThaliState state,
    NutritionThaliPreview preview,
  ) {
    final evaluation = preview.constraintEvaluation;
    final nutritionState = preview.isPartial
        ? 'Partial nutrition: some nutrient values are unknown.'
        : preview.isUnknown
        ? 'Nutrition is unknown for the selected items.'
        : 'Nutrition preview is complete for the selected registry fields.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aggregate preview',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(nutritionState),
            for (final item in preview.items)
              Text(
                '${item.displayLabel}: ${_previewQuantityLabel(item)}',
                semanticsLabel:
                    '${item.displayLabel} quantity ${_previewQuantityLabel(item)}',
              ),
            if (preview.hasUnresolvedInputs)
              const Text('One or more quantity inputs still need context.'),
            const SizedBox(height: 6),
            for (final entry in preview.aggregate.facts.entries)
              Text('${entry.key}: ${_factLabel(entry.value)}'),
            if (preview.aggregate.facts.isEmpty)
              const Text('No known nutrient values are available.'),
            if (evaluation != null) ...[
              const Divider(),
              Text(
                'Dietary evaluation: ${_constraintLabel(evaluation.outcome)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (evaluation.missingEvidence.isNotEmpty)
                const Text(
                  'More information is needed to complete this dietary check.',
                ),
              for (final result in evaluation.evaluations)
                Text(
                  '${result.type.displayLabel}: ${_constraintLabel(result.outcome)}',
                ),
              if (evaluation.evaluations.any(
                (item) =>
                    item.outcome != NutritionConstraintOutcome.noKnownConflict,
              ))
                TextButton(
                  onPressed: () => _controller.acknowledgeConstraints(
                    evaluation.evaluations
                        .where(
                          (item) =>
                              item.outcome !=
                              NutritionConstraintOutcome.noKnownConflict,
                        )
                        .map((item) => item.constraintId),
                  ),
                  child: const Text('Acknowledge dietary uncertainty'),
                ),
            ],
            if (preview.isPartial ||
                preview.isUnknown ||
                preview.hasUnresolvedInputs)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: state.partialAcknowledged,
                onChanged: (value) =>
                    _controller.acknowledgePartial(value ?? false),
                title: const Text('I understand this preview is incomplete'),
                subtitle: const Text(
                  'Unknown values remain unknown in the saved snapshot.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuantity(
    BuildContext context,
    NutritionThaliItem item,
  ) async {
    final thaliState = ref.read(
      nutritionThaliControllerProvider(widget.mealType),
    );
    final measureChoices = <_ThaliMeasureChoice>[
      for (final definition in thaliState.standardMeasures)
        _ThaliMeasureChoice(
          id: definition.id,
          label:
              '${definition.displayName}${definition.hasReviewedVolume ? '' : ' · needs context'}',
        ),
      for (final vessel in thaliState.personalVessels)
        _ThaliMeasureChoice(
          id: vessel.id,
          label: 'Vessel · ${vessel.displayName}',
        ),
    ];
    final textController = TextEditingController(
      text: item.quantity.amount.toString(),
    );
    final value = await showDialog<_ThaliQuantityEditValue>(
      context: context,
      builder: (dialogContext) {
        var selectedUnit = item.quantity.unit;
        var selectedMeasureId = item.measureId;
        String? dialogError;
        final unitOptions = item.source == NutritionThaliItemSource.recipe
            ? const [QuantityUnit.serving]
            : const [
                QuantityUnit.gram,
                QuantityUnit.millilitre,
                QuantityUnit.piece,
                QuantityUnit.householdReference,
              ];
        if (!unitOptions.contains(selectedUnit)) {
          selectedUnit = unitOptions.first;
        }
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Quantity · ${item.displayLabel ?? 'item'}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: QuantityUnitRegistry.definitionFor(
                        selectedUnit,
                      ).symbol,
                      helperText: selectedUnit == QuantityUnit.serving
                          ? 'The immutable recipe serving definition is retained.'
                          : 'Enter a positive typed quantity.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<QuantityUnit>(
                    initialValue: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Quantity type',
                    ),
                    items: [
                      for (final unit in unitOptions)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(
                            QuantityUnitRegistry.definitionFor(
                              unit,
                            ).displayLabel,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedUnit = value;
                        dialogError = null;
                      });
                    },
                  ),
                  if (selectedUnit == QuantityUnit.householdReference) ...[
                    const SizedBox(height: 12),
                    if (measureChoices.isEmpty)
                      const Text(
                        'No active standard measures or calibrated vessels are available.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue:
                            measureChoices.any(
                              (choice) => choice.id == selectedMeasureId,
                            )
                            ? selectedMeasureId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Measure or vessel',
                        ),
                        items: [
                          for (final choice in measureChoices)
                            DropdownMenuItem(
                              value: choice.id,
                              child: Text(choice.label),
                            ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMeasureId = value;
                            dialogError = null;
                          });
                        },
                      ),
                  ],
                  if (dialogError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dialogError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedUnit == QuantityUnit.householdReference &&
                      selectedMeasureId == null) {
                    setDialogState(() {
                      dialogError = 'Choose a measure or vessel first.';
                    });
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    _ThaliQuantityEditValue(
                      rawAmount: textController.text,
                      unit: selectedUnit,
                      measureId: selectedUnit == QuantityUnit.householdReference
                          ? selectedMeasureId
                          : null,
                    ),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
    textController.dispose();
    if (value == null) return;
    try {
      _controller.setQuantity(
        item.id,
        Quantity(
          amount: QuantityAmount.fromString(value.rawAmount),
          unit: value.unit,
          context: switch (value.unit) {
            QuantityUnit.serving => item.quantity.context,
            QuantityUnit.householdReference => QuantityContext(
              householdMeasure: HouseholdMeasureReference(
                measureType: value.measureId!,
              ),
            ),
            _ => const QuantityContext(),
          },
        ),
        measureId: value.measureId,
      );
    } on QuantityError {
      _showMessage('That quantity could not be used. Check it and try again.');
    } on FormatException {
      _showMessage('That quantity could not be used. Check it and try again.');
    }
  }

  String _quantityLabel(Quantity quantity) =>
      '${quantity.amount} ${QuantityUnitRegistry.definitionFor(quantity.unit).symbol}${quantity.context.approximate ? ' (approximate)' : ''}';

  String _previewQuantityLabel(NutritionThaliItemPreview item) {
    final quantity = _quantityLabel(item.resolvedQuantity.original);
    final volume = item.resolvedQuantity.evidence['volume'];
    if (volume is Map && (volume['lower'] != null || volume['upper'] != null)) {
      final lower = volume['lower'] ?? '?';
      final upper = volume['upper'] ?? '?';
      final point = volume['point'] ?? '?';
      return '$quantity · volume $lower–$upper ml (point $point ml)';
    }
    return quantity;
  }

  String _measureLabel(NutritionThaliItem item, NutritionThaliState state) {
    final id = item.measureId;
    if (id == null) return '';
    for (final measure in state.standardMeasures) {
      if (measure.id == id) return ' · ${measure.displayName}';
    }
    for (final vessel in state.personalVessels) {
      if (vessel.id == id) return ' · ${vessel.displayName}';
    }
    return ' · saved measure';
  }

  String _factLabel(NutrientFact fact) {
    if (fact.lower != null || fact.upper != null) {
      return '${fact.lower ?? '?'}–${fact.upper ?? '?'} ${fact.unit.symbol}';
    }
    return fact.point?.toString() ?? 'unknown';
  }

  String _constraintLabel(NutritionConstraintOutcome outcome) =>
      switch (outcome) {
        NutritionConstraintOutcome.confirmedConflict => 'Confirmed conflict',
        NutritionConstraintOutcome.possibleConflict => 'Possible conflict',
        NutritionConstraintOutcome.insufficientInformation =>
          'More information needed',
        NutritionConstraintOutcome.noKnownConflict => 'No detected conflict',
      };

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FailurePanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool compact;

  const _FailurePanel({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: context.b05Colors.danger.indicator),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThaliMeasureChoice {
  final String id;
  final String label;

  const _ThaliMeasureChoice({required this.id, required this.label});
}

class _ThaliQuantityEditValue {
  final String rawAmount;
  final QuantityUnit unit;
  final String? measureId;

  const _ThaliQuantityEditValue({
    required this.rawAmount,
    required this.unit,
    required this.measureId,
  });
}

class _EmptyStateContent extends StatelessWidget {
  const _EmptyStateContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 56,
              color: colors.textDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              'Your meal is empty',
              style: B05Typography.title(context).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a food or add a saved recipe. This is a free-form meal, not a recommendation.',
              textAlign: TextAlign.center,
              style: B05Typography.caption(context).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
