import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';
import 'nutrition_recipe_editor_screen.dart';
import 'saved_recipe_log_controller.dart';

class SavedRecipeLogScreen extends ConsumerStatefulWidget {
  final String mealType;
  final DateTime? selectedDate;

  const SavedRecipeLogScreen({
    super.key,
    required this.mealType,
    this.selectedDate,
  });

  @override
  ConsumerState<SavedRecipeLogScreen> createState() =>
      _SavedRecipeLogScreenState();
}

class _SavedRecipeLogScreenState extends ConsumerState<SavedRecipeLogScreen> {
  final _searchController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _amountFocus = FocusNode();
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedRecipeLogControllerProvider);
    ref.listen<SavedRecipeLogState>(savedRecipeLogControllerProvider, (
      previous,
      next,
    ) {
      if (!_amountFocus.hasFocus && _amountController.text != next.amountText) {
        _amountController.value = TextEditingValue(
          text: next.amountText,
          selection: TextSelection.collapsed(offset: next.amountText.length),
        );
      }
    });

    final selected = state.selectedRecipe;
    return Scaffold(
      appBar: AppBar(
        title: Text(selected == null ? 'Saved Recipes' : 'Log Recipe'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (selected == null)
            IconButton(
              tooltip: 'Create recipe',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () async {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NutritionRecipeEditorScreen(),
                  ),
                );
                if (mounted) {
                  unawaited(
                    ref
                        .read(savedRecipeLogControllerProvider.notifier)
                        .loadRecipes(),
                  );
                }
              },
            ),
        ],
      ),
      body: selected == null
          ? _buildRecipeList(context, state)
          : _buildSelectedRecipe(context, state),
    );
  }

  Widget _buildRecipeList(BuildContext context, SavedRecipeLogState state) {
    final controller = ref.read(savedRecipeLogControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search saved recipes',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _searchTimer?.cancel();
              _searchTimer = Timer(const Duration(milliseconds: 300), () {
                controller.loadRecipes(query: value);
              });
            },
          ),
          const SizedBox(height: 12),
          if (state.status == SavedRecipeLogStatus.failure)
            _buildErrorBanner(
              context,
              state,
              onRetry: () => controller.loadRecipes(),
            ),
          if (state.drafts.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DRAFT RECIPES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ...state.drafts.map(
              (draft) => _buildDraftCard(context, draft, controller),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child:
                state.status == SavedRecipeLogStatus.loadingRecipes ||
                    state.status == SavedRecipeLogStatus.idle
                ? const Center(child: CircularProgressIndicator())
                : state.recipes.isEmpty && state.drafts.isEmpty
                ? _buildEmptyRecipes(state.query)
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: state.recipes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final recipe = state.recipes[index];
                      return _buildRecipeCard(context, recipe, controller);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(
    BuildContext context,
    NutritionRecipeDraftModel draft,
    SavedRecipeLogController controller,
  ) {
    return Card(
      key: ValueKey('recipe_draft_${draft.version.id}'),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.edit_note_rounded, color: AppColors.primary),
        ),
        title: Text(
          draft.recipe.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${draft.version.ingredients.length} ingredient${draft.version.ingredients.length == 1 ? '' : 's'} · Draft not yet published',
        ),
        trailing: const Icon(Icons.edit_outlined, color: AppColors.primary),
        onTap: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => NutritionRecipeEditorScreen(
                recipeId: draft.recipe.id,
                draftVersionId: draft.version.id,
              ),
            ),
          );
          if (context.mounted) unawaited(controller.loadRecipes());
        },
      ),
    );
  }

  Widget _buildRecipeCard(
    BuildContext context,
    NutritionRecipeModel recipe,
    SavedRecipeLogController controller,
  ) {
    return Card(
      key: ValueKey('saved_recipe_${recipe.id}'),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.menu_book_rounded, color: AppColors.success),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          recipe.currentVersionId == null
              ? 'No published version'
              : 'Current published version available',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit recipe',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NutritionRecipeEditorScreen(recipeId: recipe.id),
                  ),
                );
                if (context.mounted) unawaited(controller.loadRecipes());
              },
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => controller.selectRecipe(recipe),
      ),
    );
  }

  Widget _buildEmptyRecipes(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              query.trim().isEmpty
                  ? 'No saved recipes yet'
                  : 'No saved recipes match “$query”',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recipes must have a published immutable version before they can be logged.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRecipe(BuildContext context, SavedRecipeLogState state) {
    final controller = ref.read(savedRecipeLogControllerProvider.notifier);
    final recipe = state.selectedRecipe!;
    final version = state.selectedVersion;
    if (state.status == SavedRecipeLogStatus.loadingSelection) {
      return const Center(child: CircularProgressIndicator());
    }
    if (version == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _backToRecipeList,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Choose another recipe'),
            ),
            const SizedBox(height: 16),
            _buildErrorBanner(
              context,
              state,
              onRetry: () => controller.selectRecipe(recipe),
            ),
          ],
        ),
      );
    }

    final hasServing = version.servingDefinition != null;
    final isPreviewLoading =
        state.status == SavedRecipeLogStatus.loadingPreview;
    final isFinalizing = state.status == SavedRecipeLogStatus.finalizing;
    final isSuccess = state.status == SavedRecipeLogStatus.success;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: isFinalizing ? null : () => _backToRecipeList(),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Choose another recipe'),
          ),
          const SizedBox(height: 16),
          Text(
            recipe.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Updated ${_formatDate(version.updatedAt)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (state.versions.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: version.id,
              decoration: const InputDecoration(
                labelText: 'Published recipe',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in state.versions)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text('Updated ${_formatDate(item.updatedAt)}'),
                  ),
              ],
              onChanged: isFinalizing
                  ? null
                  : (value) {
                      if (value == null) return;
                      final selected = state.versions.firstWhere(
                        (item) => item.id == value,
                      );
                      controller.selectVersion(selected);
                    },
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Amount to log',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _amountChoice(
                label: 'Whole recipe',
                kind: NutritionRecipeLogAmountKind.wholeRecipe,
                selected: state.amountKind,
                enabled: !isFinalizing,
                onSelected: controller.setAmountKind,
              ),
              if (hasServing)
                _amountChoice(
                  label: '1 serving',
                  kind: NutritionRecipeLogAmountKind.declaredServing,
                  selected: state.amountKind,
                  enabled: !isFinalizing,
                  onSelected: controller.setAmountKind,
                ),
              _amountChoice(
                label: 'Fraction',
                kind: NutritionRecipeLogAmountKind.fraction,
                selected: state.amountKind,
                enabled: !isFinalizing,
                onSelected: controller.setAmountKind,
              ),
              _amountChoice(
                label: 'Scale',
                kind: NutritionRecipeLogAmountKind.scalar,
                selected: state.amountKind,
                enabled: !isFinalizing,
                onSelected: controller.setAmountKind,
              ),
            ],
          ),
          if (state.amountKind == NutritionRecipeLogAmountKind.fraction ||
              state.amountKind == NutritionRecipeLogAmountKind.scalar) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              focusNode: _amountFocus,
              enabled: !isFinalizing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    state.amountKind == NutritionRecipeLogAmountKind.fraction
                    ? 'Positive fraction'
                    : 'Positive scale factor',
                helperText:
                    'Keep the exact value; nutrition is rounded only for display.',
                border: const OutlineInputBorder(),
              ),
              onChanged: controller.setAmountText,
            ),
          ],
          const SizedBox(height: 20),
          if (state.status == SavedRecipeLogStatus.failure &&
              state.errorCode != null)
            _buildErrorBanner(
              context,
              state,
              onRetry: state.preview == null
                  ? () => controller.preview()
                  : state.errorCode == 'stale_recipe_version'
                  ? () => controller.preview()
                  : () => _retryFinalize(controller),
            ),
          if (state.status == SavedRecipeLogStatus.loadingPreview)
            const LinearProgressIndicator(),
          if (state.preview != null) ...[
            _buildPreview(context, state.preview!, state),
            const SizedBox(height: 16),
          ],
          if (state.status != SavedRecipeLogStatus.success)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isPreviewLoading || isFinalizing
                        ? null
                        : () => controller.preview(),
                    child: Text(
                      isPreviewLoading ? 'Calculating…' : 'Preview nutrition',
                    ),
                  ),
                ),
                if (state.preview != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isFinalizing
                          ? null
                          : () => _finalize(controller),
                      child: Text(isFinalizing ? 'Saving…' : 'Confirm & log'),
                    ),
                  ),
                ],
              ],
            ),
          if (isSuccess) _buildSuccess(context, state),
        ],
      ),
    );
  }

  Widget _amountChoice({
    required String label,
    required NutritionRecipeLogAmountKind kind,
    required NutritionRecipeLogAmountKind selected,
    required bool enabled,
    required ValueChanged<NutritionRecipeLogAmountKind> onSelected,
  }) => ChoiceChip(
    label: Text(label),
    selected: kind == selected,
    onSelected: enabled ? (_) => onSelected(kind) : null,
  );

  Widget _buildPreview(
    BuildContext context,
    NutritionRecipeLogPreview preview,
    SavedRecipeLogState state,
  ) {
    final facts = preview.calculation.facts;
    final incomplete = preview.isPartial || preview.isUnknown;
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview • ${preview.amount.displayLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Recipe version ${preview.version.versionNumber} is fixed for this preview.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final nutrientId in const [
                  'energy',
                  'protein',
                  'carbohydrate',
                  'fat',
                  'fibre',
                ])
                  _nutrientChip(nutrientId, facts[nutrientId]),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Completeness: ${preview.calculation.completeness.state.name}',
              style: TextStyle(
                color: incomplete ? AppColors.warning : AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (preview.calculation.missingNutrientIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Unknown nutrients: ${preview.calculation.missingNutrientIds.join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if (preview.calculation.warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  preview.calculation.warnings.join('\n'),
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            if (incomplete)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: state.partialAcknowledged,
                onChanged: (value) => ref
                    .read(savedRecipeLogControllerProvider.notifier)
                    .acknowledgePartial(value ?? false),
                title: const Text('Log with incomplete nutrition'),
                subtitle: const Text(
                  'Unknown nutrients are preserved as unknown, not zero.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientChip(String id, NutrientFact? fact) {
    final text = fact == null || !fact.isAvailable
        ? 'Unknown'
        : _factDisplay(id, fact);
    final label = switch (id) {
      'energy' => 'Energy',
      'protein' => 'Protein',
      'carbohydrate' => 'Carbs',
      'fat' => 'Fat',
      'fibre' => 'Fibre',
      _ => id,
    };
    return Chip(
      label: Text('$label: $text'),
      avatar: fact?.status == NutrientFactStatus.estimated
          ? const Icon(Icons.tune_rounded, size: 16)
          : null,
    );
  }

  String _factDisplay(String id, NutrientFact fact) {
    final precision = id == 'energy' ? 0 : 1;
    final point = fact.point?.value.format(decimalPlaces: precision);
    if (fact.lower == null && fact.upper == null) {
      return '${point ?? 'Unknown'}${id == 'energy' ? ' kcal' : ' g'}';
    }
    final lower = fact.lower?.value.format(decimalPlaces: precision) ?? point;
    final upper = fact.upper?.value.format(decimalPlaces: precision) ?? point;
    return '${lower ?? '—'}–${upper ?? '—'}${id == 'energy' ? ' kcal' : ' g'}';
  }

  Widget _buildSuccess(BuildContext context, SavedRecipeLogState state) => Card(
    color: AppColors.success.withValues(alpha: 0.12),
    child: ListTile(
      leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
      title: const Text('Recipe logged'),
      subtitle: Text(
        'Saved to immutable history${state.savedSnapshot?.recipeVersionId == null ? '' : ' • version preserved'}',
      ),
      trailing: TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Done'),
      ),
    ),
  );

  Widget _buildErrorBanner(
    BuildContext context,
    SavedRecipeLogState state, {
    required VoidCallback onRetry,
  }) => Card(
    color: AppColors.danger.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.errorMessage ?? 'The recipe action failed.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  void _backToRecipeList() {
    ref.read(savedRecipeLogControllerProvider.notifier).clearSelection();
  }

  void _finalize(SavedRecipeLogController controller) {
    unawaited(_finalizeWithStoredTimezone(controller));
  }

  void _retryFinalize(SavedRecipeLogController controller) {
    unawaited(_retryWithStoredTimezone(controller));
  }

  Future<void> _finalizeWithStoredTimezone(
    SavedRecipeLogController controller,
  ) async {
    final loggedAt = (widget.selectedDate ?? DateTime.now()).toUtc();
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final localDate = ref
        .read(localScheduleDateServiceProvider)
        .localDateFor(loggedAt, timezoneId);
    await controller.finalize(
      mealCategory: widget.mealType,
      loggedAt: loggedAt,
      localDate: localDate,
      timezoneId: timezoneId,
    );
  }

  Future<void> _retryWithStoredTimezone(
    SavedRecipeLogController controller,
  ) async {
    final loggedAt = (widget.selectedDate ?? DateTime.now()).toUtc();
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final localDate = ref
        .read(localScheduleDateServiceProvider)
        .localDateFor(loggedAt, timezoneId);
    await controller.retryFinalize(
      mealCategory: widget.mealType,
      loggedAt: loggedAt,
      localDate: localDate,
      timezoneId: timezoneId,
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
