import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../dashboard/today_consumer_presentation.dart';
import '../dashboard/today_surface_controller.dart';
import '../dashboard/widgets/dashboard_date_bar.dart';
import 'diary_structure_controller.dart';
import 'food_log_surface.dart';
import 'food_search_screen.dart';
import 'meal_presentation_registry.dart';
import 'saved_meals_screen.dart';
import 'saved_recipe_log_screen.dart';

/// Food diary screen (PV1-ENG-05D first pass).
///
/// Extracted verbatim from `food_search_screen.dart`; unchanged.

class FoodDiaryScreen extends ConsumerStatefulWidget {
  const FoodDiaryScreen({super.key, required this.selectedDate, this.today});

  final DateTime selectedDate;
  final DateTime? today;

  @override
  ConsumerState<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends ConsumerState<FoodDiaryScreen> {
  late DateTime _selectedDay;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _selectedDay = _civilDay(widget.selectedDate);
    _today = _civilDay(widget.today ?? DateTime.now());
  }

  @override
  void didUpdateWidget(covariant FoodDiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _selectedDay = _civilDay(widget.selectedDate);
    }
    if (oldWidget.today != widget.today) {
      _today = _civilDay(widget.today ?? DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final diary = ref.watch(foodDiaryReadModelProvider(_selectedDay));
    final daily = diary.valueOrNull?.daily;
    final canonical = daily == null && diary.hasError
        ? ref.watch(canonicalFoodRecordsForDayProvider(_selectedDay))
        : const AsyncData<List<NutritionHistoricalReadRecord>>([]);
    final nutritionRead = diary.hasError
        ? const TodayDomainRead<NutritionDailyReadModel>.unavailable(
            'Food diary unavailable',
          )
        : daily == null
        ? null
        : TodayDomainRead.available(daily);
    final configuredSlots = ref.watch(diaryMealSlotsProvider);
    final presentation = TodayNutritionPresentation.from(
      nutritionRead,
      loading: diary.isLoading,
      targetRead: diary.valueOrNull?.targets,
      configuredMeals: [
        for (final slot in configuredSlots) (slot.stableId, slot.label),
      ],
    );
    final records = daily?.records ?? canonical.valueOrNull ?? [];

    // Per-day data-driven surfacing of logged slots is not "expanding defaults" —
    // it is truthful rendering of historical evidence. Defaults govern empty-day structure.
    final visibleSlots = List<FoodMealPresentation>.from(configuredSlots);
    final seenSlotIds = visibleSlots.map((s) => s.stableId).toSet();
    for (final record in records) {
      final normType = foodDiaryMealType(record.mealCategory);
      final slotPresentation = MealPresentationRegistry.forStableId(normType);
      if (slotPresentation.isKnown && seenSlotIds.add(slotPresentation.stableId)) {
        visibleSlots.add(slotPresentation);
      }
    }

    final meals = [
      for (final p in visibleSlots)
        (type: p.stableId, label: p.label),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Food diary', style: B05Typography.title(context)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            DashboardDateBar(
              selectedDate: _selectedDay,
              today: _today,
              onDateChanged: (date) {
                final nextDay = _civilDay(date);
                if (_isSameDay(nextDay, _selectedDay)) return;
                setState(() => _selectedDay = nextDay);
              },
            ),
            const SizedBox(height: 12),
            FoodDiaryPrimaryAddAction(
              onPressed: () => _openMealPicker(context),
            ),
            const SizedBox(height: 16),
            FoodDiarySummary(
              presentation: presentation,
              targetRead: diary.valueOrNull?.targets,
            ),
            if (diary.hasError && daily == null) ...[
              const SizedBox(height: 12),
              ProductFailureCard(
                failure: ProductFailurePresentation.fromCode(
                  'food_log_unavailable',
                  title: 'Daily food is unavailable',
                ),
                onRetry: () =>
                    ref.invalidate(foodDiaryReadModelProvider(_selectedDay)),
              ),
            ],
            const SizedBox(height: 16),
            Text('Meals', style: B05Typography.title(context)),
            const SizedBox(height: 2),
            Text(
              'See what you logged by meal.',
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: 8),
            if (daily == null && (diary.isLoading || canonical.isLoading))
              const B05StatusMessage(
                status: B05SemanticStatus.info,
                label: 'Loading meals',
              ),
            for (var index = 0; index < meals.length; index++) ...[
              FoodDiaryMealRow(
                type: meals[index].type,
                label: meals[index].label,
                records: records
                    .where(
                      (record) =>
                          foodDiaryMealType(record.mealCategory) ==
                          meals[index].type,
                    )
                    .toList(growable: false),
                isLoading:
                    daily == null && (diary.isLoading || canonical.isLoading),
                onOpen: () => _openMealDetail(context, meals[index].type),
                onAdd: () => _openMealAdd(context, meals[index].type),
              ),
              if (index < meals.length - 1)
                Divider(height: 16, color: context.b05Colors.border),
            ],
            const SizedBox(height: 20),
            Text('Food tools', style: B05Typography.title(context)),
            const SizedBox(height: 2),
            Text(
              'Repeat from history or use a saved meal when helpful.',
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: 8),
            FoodDiaryShortcut(
              icon: Icons.repeat_rounded,
              title: 'Recent and frequent',
              detail: 'Repeat foods using your real local history.',
              onTap: () => _openMealPicker(context),
            ),
            FoodDiaryShortcut(
              icon: Icons.bookmark_outline_rounded,
              title: 'Saved meals',
              detail: 'Log a meal combination you saved.',
              onTap: () => _openSavedMeals(context),
            ),
            FoodDiaryShortcut(
              icon: Icons.menu_book_rounded,
              title: 'Saved recipes',
              detail: 'Open a complete recipe without rebuilding it.',
              onTap: () => _openSavedRecipes(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMealAdd(BuildContext context, String mealType) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          mealType: mealType,
          selectedDate: _selectedDay,
          returnToParentOnSave: true,
        ),
      ),
    );
    if (mounted) _refreshDiaryReads();
  }

  Future<void> _openMealDetail(BuildContext context, String mealType) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FoodMealDetailScreen(
          mealType: mealType,
          selectedDate: _selectedDay,
        ),
      ),
    );
    if (mounted) _refreshDiaryReads();
  }

  Future<String?> _chooseMeal(
    BuildContext context,
  ) {
    final activeSlots = ref.read(diaryMealSlotsProvider);
    final items =
        activeSlots.isNotEmpty ? activeSlots : MealPresentationRegistry.values;
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a meal',
                  style: B05Typography.title(sheetContext),
                ),
              ),
            ),
            for (final item in items)
              ListTile(
                title: Text(item.label),
                leading: DecoratedBox(
                  decoration: BoxDecoration(
                    color: sheetContext.b05Colors
                        .meal(item.accent ?? B05MealAccent.snack)
                        .container,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      item.icon,
                      color: sheetContext.b05Colors
                          .meal(item.accent ?? B05MealAccent.snack)
                          .indicator,
                    ),
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(item.stableId),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openMealPicker(BuildContext context) async {
    final meal = await _chooseMeal(context);
    if (meal == null || !context.mounted) return;
    await _openMealAdd(context, meal);
  }

  Future<void> _openSavedMeals(BuildContext context) async {
    final meal = await _chooseMeal(context);
    if (meal == null || !context.mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SavedMealsScreen(mealType: meal, selectedDate: _selectedDay),
      ),
    );
    if (mounted) _refreshDiaryReads();
  }

  Future<void> _openSavedRecipes(BuildContext context) async {
    final meal = await _chooseMeal(context);
    if (meal == null || !context.mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SavedRecipeLogScreen(mealType: meal, selectedDate: _selectedDay),
      ),
    );
    if (mounted) _refreshDiaryReads();
  }

  void _refreshDiaryReads() {
    ref.invalidate(foodDiaryReadModelProvider(_selectedDay));
    ref.invalidate(canonicalRecentFoodsProvider);
  }

  DateTime _civilDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

