import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/theme/colors.dart';
import 'saved_meal_editor_screen.dart';
import 'saved_meals_controller.dart';
import 'widgets/saved_meal_edit_before_log_sheet.dart';

class SavedMealsScreen extends ConsumerStatefulWidget {
  final String mealType;
  final DateTime? selectedDate;

  const SavedMealsScreen({
    super.key,
    required this.mealType,
    this.selectedDate,
  });

  @override
  ConsumerState<SavedMealsScreen> createState() => _SavedMealsScreenState();
}

class _SavedMealsScreenState extends ConsumerState<SavedMealsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(savedMealsControllerProvider.notifier)
          .loadSavedMeals(query: query);
    });
  }

  Future<void> _handleQuickLog(SavedMealDisplayItem item) async {
    final controller = ref.read(savedMealsControllerProvider.notifier);
    final snapshot = await controller.logSavedMeal(
      draft: item.draft,
      mealCategory: widget.mealType,
      loggedAt: widget.selectedDate ?? DateTime.now(),
    );

    if (snapshot != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged "${item.draft.name}" to ${widget.mealType.toUpperCase()}!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _handleEditBeforeLog(SavedMealDisplayItem item) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SavedMealEditBeforeLogSheet(
        draft: item.draft,
        mealType: widget.mealType,
        selectedDate: widget.selectedDate ?? DateTime.now(),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged "${item.draft.name}" to ${widget.mealType.toUpperCase()}!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _handleDelete(SavedMealDisplayItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${item.draft.name}"?'),
        content: const Text(
          'This will remove this saved meal template. Past logged meals in your diary will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(savedMealsControllerProvider.notifier)
          .deleteSavedMeal(item.draft.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedMealsControllerProvider);
    final targetMealLabel = widget.mealType.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Meals'),
        backgroundColor: context.b05Colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Create Saved Meal',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SavedMealEditorScreen(defaultMealType: widget.mealType),
                ),
              );
              if (created == true && mounted) {
                unawaited(
                  ref
                      .read(savedMealsControllerProvider.notifier)
                      .loadSavedMeals(),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search saved meals…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.b05Colors.border),
                ),
                filled: true,
                fillColor: context.b05Colors.surfaceSubtle,
              ),
            ),
          ),

          if (state.errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child:
                state.status == SavedMealsStatus.loading ||
                    state.status == SavedMealsStatus.idle
                ? const Center(child: CircularProgressIndicator())
                : state.meals.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: state.meals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final meal = state.meals[index];
                      return _buildMealCard(context, meal, targetMealLabel);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 56,
              color: context.b05Colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.trim().isEmpty
                  ? 'No saved meals yet'
                  : 'No saved meals match "${_searchController.text}"',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Save your commonly eaten meal combinations to log them faster in one tap.',
              style: TextStyle(
                color: context.b05Colors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SavedMealEditorScreen(defaultMealType: widget.mealType),
                  ),
                );
                if (created == true && mounted) {
                  unawaited(
                    ref
                        .read(savedMealsControllerProvider.notifier)
                        .loadSavedMeals(),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create saved meal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(
    BuildContext context,
    SavedMealDisplayItem meal,
    String targetMealLabel,
  ) {
    final calText = meal.estimatedCalories != null
        ? '${meal.estimatedCalories!.round()} kcal'
        : '— kcal';
    final protText = meal.estimatedProteinG != null
        ? '${meal.estimatedProteinG!.toStringAsFixed(1)}g P'
        : '— P';

    return Container(
      decoration: BoxDecoration(
        color: context.b05Colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.b05Colors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.draft.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meal.itemCount} items · $calText · $protText',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.b05Colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) {
                  if (action == 'edit_before_log') {
                    _handleEditBeforeLog(meal);
                  } else if (action == 'edit_template') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SavedMealEditorScreen(
                          thaliDraft: meal.draft,
                          defaultMealType: widget.mealType,
                        ),
                      ),
                    ).then((updated) {
                      if (updated == true && mounted) {
                        ref
                            .read(savedMealsControllerProvider.notifier)
                            .loadSavedMeals();
                      }
                    });
                  } else if (action == 'delete') {
                    _handleDelete(meal);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit_before_log',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Edit portions before log'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit_template',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Edit template'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            meal.summary,
            style: TextStyle(
              fontSize: 13,
              color: context.b05Colors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleEditBeforeLog(meal),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'REVIEW PORTIONS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _handleQuickLog(meal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'LOG TO $targetMealLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
