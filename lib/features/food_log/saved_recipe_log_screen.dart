import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';
import '../dashboard/today_surface_controller.dart';
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
        title: Text(selected == null ? 'Recipes' : 'Add recipe'),
        backgroundColor: context.b05Colors.surface,
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
            decoration: InputDecoration(
              labelText: 'Search saved recipes',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        controller.loadRecipes(query: '');
                        setState(() {});
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {});
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
                'RECIPES IN PROGRESS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.b05Colors.action,
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
                ? _buildEmptyRecipes(state.query, controller)
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
      color: context.b05Colors.action.withValues(alpha: 0.08),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.b05Colors.action.withValues(alpha: 0.12),
          child: Icon(Icons.edit_note_rounded, color: context.b05Colors.action),
        ),
        title: Text(
          draft.recipe.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${draft.version.ingredients.length} ingredient${draft.version.ingredients.length == 1 ? '' : 's'} · Finish this recipe before logging it',
        ),
        trailing: Icon(Icons.edit_outlined, color: context.b05Colors.action),
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
        leading: CircleAvatar(
          backgroundColor: context.b05Colors.success.container,
          child: Icon(
            Icons.menu_book_rounded,
            color: context.b05Colors.success.indicator,
          ),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          recipe.currentVersionId == null
              ? 'Still being prepared'
              : recipe.description != null && recipe.description!.trim().isNotEmpty
              ? recipe.description!
              : 'Ready to add',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            IconButton(
              tooltip: 'Delete recipe',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: ctx.b05Colors.section,
                    title: Text('Delete "${recipe.name}"?'),
                    content: const Text(
                      'This recipe will be archived from future logging. Previously logged meals in your diary will remain untouched.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: ctx.b05Colors.danger.container,
                          foregroundColor: ctx.b05Colors.danger.foreground,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await controller.deleteRecipe(recipe.id);
                }
              },
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => controller.selectRecipe(recipe),
      ),
    );
  }

  Widget _buildEmptyRecipes(String query, SavedRecipeLogController controller) {
    final isSearching = query.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ProductEmptyState(
          icon: Icons.menu_book_outlined,
          title: isSearching ? 'No saved recipes match “$query”' : 'No saved recipes yet',
          message: isSearching
              ? 'Try searching with a different recipe name.'
              : 'Create a recipe for meals you make often.',
          action: isSearching
              ? () {
                  _searchController.clear();
                  controller.loadRecipes(query: '');
                  setState(() {});
                }
              : () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NutritionRecipeEditorScreen(),
                    ),
                  );
                  if (mounted) unawaited(controller.loadRecipes());
                },
          actionLabel: isSearching ? 'Clear search' : 'Create recipe',
          actionIcon: isSearching ? Icons.clear_rounded : Icons.add_rounded,
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
          if (recipe.description != null &&
              recipe.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              recipe.description!,
              style: TextStyle(color: context.b05Colors.textSecondary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Updated ${_formatDate(version.updatedAt)}',
            style: TextStyle(color: context.b05Colors.textSecondary),
          ),
          if (state.versions.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: version.id,
              decoration: const InputDecoration(
                labelText: 'Recipe update',
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
          const SizedBox(height: 16),
          // Yield / Servings Callout
          if (hasServing || version.yieldQuantity != null)
            B05Surface(
              tone: B05SurfaceTone.inset,
              padding: const EdgeInsets.all(B05Layout.space12),
              child: Row(
                children: [
                  Icon(
                    Icons.room_service_outlined,
                    color: context.b05Colors.action,
                    size: 20,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasServing
                              ? 'Makes ${_formatServingCount(version.servingDefinition!.count)} serving${version.servingDefinition!.count.asDouble == 1.0 ? '' : 's'}'
                              : 'Total yield: ${version.yieldQuantity!.amount} ${version.yieldQuantity!.definition.displayLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Nutrition scales proportionally when logging portions.',
                          style: TextStyle(
                            color: context.b05Colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // Ingredients Breakdown Section
          Row(
            children: [
              Text(
                'INGREDIENTS',
                style: B05Typography.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${version.ingredients.length})',
                style: TextStyle(
                  color: context.b05Colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (version.ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No ingredients listed in this recipe version.',
                style: TextStyle(color: context.b05Colors.textSecondary),
              ),
            )
          else
            ...version.ingredients.map(
              (ingredient) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: B05Surface(
                  tone: B05SurfaceTone.inset,
                  padding: const EdgeInsets.symmetric(
                    horizontal: B05Layout.space12,
                    vertical: B05Layout.space8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: context.b05Colors.action,
                      ),
                      const SizedBox(width: B05Layout.space8),
                      Expanded(
                        child: Text(
                          _formatFoodName(ingredient.foodId),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${ingredient.quantity.amount} ${ingredient.quantity.definition.displayLabel}',
                        style: TextStyle(
                          color: context.b05Colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'How much?',
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
                    ? 'Amount of the recipe'
                    : 'How many recipes?',
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
          if (state.status != SavedRecipeLogStatus.success) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isPreviewLoading || isFinalizing
                        ? null
                        : () => controller.preview(),
                    child: Text(
                      isPreviewLoading ? 'Calculating…' : 'Review nutrition',
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
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: isFinalizing
                    ? null
                    : () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NutritionRecipeEditorScreen(
                              recipeId: recipe.id,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          unawaited(controller.selectRecipe(recipe));
                        }
                      },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit recipe'),
              ),
            ),
          ],
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
      color: context.b05Colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: context.b05Colors.action),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nutrition for ${preview.amount.displayLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Using the latest saved ingredients for this recipe.',
              style: TextStyle(
                color: context.b05Colors.textSecondary,
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
              incomplete
                  ? 'Some nutrition information is missing'
                  : 'Nutrition information is available',
              style: TextStyle(
                color: incomplete
                    ? context.b05Colors.warning.foreground
                    : context.b05Colors.success.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (incomplete)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: state.partialAcknowledged,
                onChanged: (value) => ref
                    .read(savedRecipeLogControllerProvider.notifier)
                    .acknowledgePartial(value ?? false),
                title: const Text('Add with missing nutrition'),
                subtitle: const Text(
                  'Missing nutrition stays missing rather than becoming zero.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientChip(String id, NutrientFact? fact) {
    final text = fact == null || !fact.isAvailable
        ? '—'
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
      return '${point ?? '—'}${id == 'energy' ? ' kcal' : ' g'}';
    }
    final lower = fact.lower?.value.format(decimalPlaces: precision) ?? point;
    final upper = fact.upper?.value.format(decimalPlaces: precision) ?? point;
    return '${lower ?? '—'}–${upper ?? '—'}${id == 'energy' ? ' kcal' : ' g'}';
  }

  Widget _buildSuccess(BuildContext context, SavedRecipeLogState state) => Card(
    color: context.b05Colors.success.container,
    child: ListTile(
      leading: Icon(
        Icons.check_circle_rounded,
        color: context.b05Colors.success.indicator,
      ),
      title: const Text('Recipe added'),
      subtitle: Text('Added to ${_mealLabel(widget.mealType)}'),
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
    color: context.b05Colors.danger.container,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.b05Colors.danger.indicator,
          ),
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
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final dates = ref.read(localScheduleDateServiceProvider);
    final localDate = widget.selectedDate == null
        ? dates.localDateFor(DateTime.now().toUtc(), timezoneId)
        : _localDateKey(widget.selectedDate!);
    final loggedAt = widget.selectedDate == null
        ? DateTime.now().toUtc()
        : dates.instantForLocalDate(localDate, timezoneId);
    await controller.finalize(
      mealCategory: widget.mealType,
      loggedAt: loggedAt,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    await _returnToTodayAfterSuccessfulSave();
  }

  Future<void> _retryWithStoredTimezone(
    SavedRecipeLogController controller,
  ) async {
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final dates = ref.read(localScheduleDateServiceProvider);
    final localDate = widget.selectedDate == null
        ? dates.localDateFor(DateTime.now().toUtc(), timezoneId)
        : _localDateKey(widget.selectedDate!);
    final loggedAt = widget.selectedDate == null
        ? DateTime.now().toUtc()
        : dates.instantForLocalDate(localDate, timezoneId);
    await controller.retryFinalize(
      mealCategory: widget.mealType,
      loggedAt: loggedAt,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    await _returnToTodayAfterSuccessfulSave();
  }

  Future<void> _returnToTodayAfterSuccessfulSave() async {
    if (!mounted ||
        ref.read(savedRecipeLogControllerProvider).status !=
            SavedRecipeLogStatus.success) {
      return;
    }
    ref.read(todayNutritionRevisionProvider.notifier).state++;
    ref.invalidate(b04ProductionRecommendationContextProvider);
    ref.invalidate(b04CurrentFoodControllerProvider);
    Navigator.of(context).pop(true);
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _mealLabel(String value) => switch (value.trim().toLowerCase()) {
    'breakfast' => 'breakfast',
    'lunch' => 'lunch',
    'dinner' => 'dinner',
    'snack' || 'snacks' => 'snack',
    _ => 'meal',
  };

  static String _formatServingCount(QuantityAmount count) {
    final d = count.asDouble;
    if (d == d.roundToDouble()) {
      return d.toInt().toString();
    }
    return count.format(decimalPlaces: 1);
  }

  static String _formatFoodName(String? foodId) {
    if (foodId == null || foodId.isEmpty) return 'Unknown ingredient';
    if (foodId.startsWith('food::')) {
      final raw = foodId.substring(6).replaceAll('_', ' ').replaceAll('-', ' ');
      return raw
          .split(' ')
          .map((word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '')
          .join(' ');
    }
    return foodId;
  }

  static String _localDateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
