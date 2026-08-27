import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../dashboard/today_surface_controller.dart';
import 'meal_templates_screen.dart';
import 'saved_meal_detail_screen.dart';
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
  final Set<String> _deletingSavedMealIds = <String>{};
  var _quickLogInFlight = false;

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

  Future<bool> _handleQuickLog(
    SavedMealDisplayItem item, {
    bool closeAfterSuccess = true,
  }) async {
    if (!item.isLoggable ||
        _quickLogInFlight ||
        ref.read(savedMealsControllerProvider).status ==
            SavedMealsStatus.finalizing) {
      return false;
    }
    setState(() => _quickLogInFlight = true);
    try {
      if (item.requiresPartialAcknowledgement) {
        return await _handleEditBeforeLog(
          item,
          closeAfterSuccess: closeAfterSuccess,
        );
      }

      final now = DateTime.now().toUtc();
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final dates = ref.read(localScheduleDateServiceProvider);
      final localDate = widget.selectedDate == null
          ? dates.localDateFor(now, timezoneId)
          : _localDateKey(widget.selectedDate!);
      final loggedAt = widget.selectedDate == null
          ? now
          : dates.instantForLocalDate(localDate, timezoneId);
      if (!mounted) return false;
      final controller = ref.read(savedMealsControllerProvider.notifier);
      final snapshot = await controller.logSavedMeal(
        draft: item.draft,
        mealCategory: widget.mealType,
        loggedAt: loggedAt,
        localDate: localDate,
        timezoneId: timezoneId,
      );

      if (snapshot != null && mounted) {
        _refreshTodaySurfaces();
        showIndiFitSuccessFeedback(
          context,
          'Logged "${item.draft.name}" to ${widget.mealType.toLowerCase()}!',
        );
        if (closeAfterSuccess && mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
        return true;
      }
      return false;
    } finally {
      _quickLogInFlight = false;
      if (mounted) setState(() {});
    }
  }

  Future<bool> _handleEditBeforeLog(
    SavedMealDisplayItem item, {
    bool closeAfterSuccess = true,
  }) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SavedMealEditBeforeLogSheet(
        draft: item.draft,
        mealType: widget.mealType,
        selectedDate: widget.selectedDate ?? DateTime.now(),
        hasPartialNutrition: item.hasPartialNutrition,
        requiresPartialAcknowledgement: item.requiresPartialAcknowledgement,
      ),
    );

    if (result != null && mounted) {
      showIndiFitSuccessFeedback(
        context,
        'Logged "${item.draft.name}" to ${widget.mealType.toUpperCase()}!',
      );
      if (closeAfterSuccess && mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
      return true;
    }
    return false;
  }

  Future<bool> _handleDelete(SavedMealDisplayItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${item.draft.name}"?'),
        content: const Text(
          'This will remove this saved meal. Past logged meals in your diary will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.b05Colors.danger.container,
              foregroundColor: ctx.b05Colors.danger.foreground,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true ||
        !mounted ||
        !_deletingSavedMealIds.add(item.draft.id)) {
      return false;
    }
    setState(() {});
    try {
      final controller = ref.read(savedMealsControllerProvider.notifier);
      final query = ref.read(savedMealsControllerProvider).query;
      final deleted = await controller.deleteSavedMeal(
        item.draft.id,
        reload: false,
      );
      if (!deleted || !mounted) return false;
      unawaited(IndiFitHaptics.warning());
      await controller.loadSavedMeals(query: query);
      return true;
    } finally {
      _deletingSavedMealIds.remove(item.draft.id);
      if (mounted) setState(() {});
    }
  }

  Future<bool> _openEditor({SavedMealDisplayItem? item}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedMealEditorScreen(
          thaliDraft: item?.draft,
          defaultMealType: widget.mealType,
        ),
      ),
    );
    if (saved == true && mounted) {
      await ref
          .read(savedMealsControllerProvider.notifier)
          .loadSavedMeals(query: ref.read(savedMealsControllerProvider).query);
    }
    return saved == true;
  }

  Future<void> _openMealDetail(SavedMealDisplayItem meal) async {
    final result = await Navigator.push<SavedMealDetailResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedMealDetailScreen(
          meal: meal,
          mealType: widget.mealType,
          onQuickLog: () => _handleQuickLog(meal, closeAfterSuccess: false),
          onReviewPortions: () =>
              _handleEditBeforeLog(meal, closeAfterSuccess: false),
          onEdit: () => _openEditor(item: meal),
          onDelete: () => _handleDelete(meal),
        ),
      ),
    );
    if (!mounted) return;
    if (result == SavedMealDetailResult.logged) {
      if (Navigator.canPop(context)) Navigator.pop(context, true);
    } else if (result == SavedMealDetailResult.updated) {
      await ref
          .read(savedMealsControllerProvider.notifier)
          .loadSavedMeals(query: ref.read(savedMealsControllerProvider).query);
    }
  }

  Future<void> _showOlderMealTemplates() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MealTemplatesScreen(
          mealType: widget.mealType,
          targetDate: widget.selectedDate,
          legacyReadOnly: true,
        ),
      ),
    );
    if (result == true && mounted) {
      _refreshTodaySurfaces();
      Navigator.pop(context, true);
    }
  }

  void _refreshTodaySurfaces() {
    ref.read(todayNutritionRevisionProvider.notifier).state++;
    ref.invalidate(b04ProductionRecommendationContextProvider);
    ref.invalidate(b04CurrentFoodControllerProvider);
  }

  static String _localDateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedMealsControllerProvider);
    final targetMealLabel = widget.mealType.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved meals'),
        backgroundColor: context.b05Colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Create saved meal',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openEditor(),
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
                color: context.b05Colors.danger.container,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: context.b05Colors.danger.indicator,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: context.b05Colors.danger.foreground,
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
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: const [
                      SkeletonCard(height: 96),
                      SkeletonCard(height: 96),
                      SkeletonCard(height: 96),
                      SkeletonCard(height: 96),
                      SkeletonCard(height: 96),
                    ],
                  )
                : state.status == SavedMealsStatus.failure &&
                      state.meals.isEmpty
                ? _buildFailureState()
                : state.meals.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    itemCount: state.meals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final meal = state.meals[index];
                      return _buildMealCard(context, meal, targetMealLabel);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _showOlderMealTemplates,
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('View older saved meals'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;
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
              !hasSearch
                  ? 'No saved meals yet'
                  : 'No saved meals match "${_searchController.text}"',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different name or create a new saved meal.'
                  : 'Save the foods and recipes you eat together to log them again quickly.',
              style: TextStyle(
                color: context.b05Colors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create saved meal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.b05Colors.action,
                foregroundColor: context.b05Colors.onAction,
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

  Widget _buildFailureState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: context.b05Colors.danger.indicator,
            ),
            const SizedBox(height: 16),
            Text(
              'Saved meals could not be loaded',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your saved meals are still safe. Try again when you’re ready.',
              style: TextStyle(
                color: context.b05Colors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(savedMealsControllerProvider.notifier)
                  .loadSavedMeals(
                    query: ref.read(savedMealsControllerProvider).query,
                  ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
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

    final state = ref.watch(savedMealsControllerProvider);
    final deleting = _deletingSavedMealIds.contains(meal.draft.id);
    final actionInFlight =
        _quickLogInFlight ||
        deleting ||
        state.status == SavedMealsStatus.finalizing;
    final actionsDisabled = !meal.isLoggable || actionInFlight;

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
                  color: context.b05Colors.selected,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: context.b05Colors.success.indicator,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  container: true,
                  button: true,
                  enabled: !actionInFlight,
                  label: 'View ${meal.draft.name} composition',
                  hint: 'Double tap to review this saved meal.',
                  onTap: actionInFlight ? null : () => _openMealDetail(meal),
                  child: InkWell(
                    onTap: actionInFlight ? null : () => _openMealDetail(meal),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
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
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.b05Colors.textSecondary,
                semanticLabel: 'View composition',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                enabled: !actionInFlight,
                onSelected: (action) {
                  if (action == 'edit_before_log') {
                    _handleEditBeforeLog(meal);
                  } else if (action == 'edit_template') {
                    _openEditor(item: meal);
                  } else if (action == 'delete') {
                    _handleDelete(meal);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit_before_log',
                    enabled: !actionsDisabled,
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Edit portions before log',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit_template',
                    enabled: !actionInFlight,
                    child: const Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Edit saved meal',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !deleting,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: context.b05Colors.danger.indicator,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Delete',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.b05Colors.danger.foreground,
                            ),
                          ),
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

          if (meal.unavailableMessage != null) ...[
            const SizedBox(height: 12),
            _MealCardNotice(
              icon: Icons.error_outline_rounded,
              color: context.b05Colors.danger.indicator,
              message:
                  '${meal.unavailableMessage!} Edit this saved meal to update its ingredients.',
            ),
          ] else if (meal.hasPartialNutrition) ...[
            const SizedBox(height: 12),
            _MealCardNotice(
              icon: Icons.info_outline_rounded,
              color: context.b05Colors.warning.indicator,
              message: meal.requiresPartialAcknowledgement
                  ? 'Incomplete core nutrition: review before logging.'
                  : 'Nutrition details are partial; unknown values stay unknown.',
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final stackActions =
                  constraints.maxWidth < 380 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.25;
              final review = OutlinedButton(
                onPressed: actionsDisabled
                    ? null
                    : () => _handleEditBeforeLog(meal),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Review portions',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              );
              final log = ElevatedButton(
                onPressed: actionsDisabled ? null : () => _handleQuickLog(meal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.b05Colors.action,
                  foregroundColor: context.b05Colors.onAction,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  meal.requiresPartialAcknowledgement
                      ? 'Review & log'
                      : ConsumerCopy.logToMeal(targetMealLabel),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              );
              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [review, const SizedBox(height: 8), log],
                );
              }
              return Row(
                children: [
                  Expanded(child: review),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: log),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MealCardNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _MealCardNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: context.b05Colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}
