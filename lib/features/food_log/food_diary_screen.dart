import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../dashboard/today_consumer_presentation.dart';
import '../dashboard/today_surface_controller.dart';
import '../dashboard/widgets/dashboard_date_bar.dart';
import 'diary_structure_controller.dart';
import 'food_log_surface.dart';
import 'food_search_screen.dart';
import 'meal_presentation_registry.dart';
import 'repeat_meal.dart';
import 'saved_meals_screen.dart';
import 'saved_recipe_log_screen.dart';
import 'thali/thali_builder_screen.dart';
import 'widgets/quick_add_macros_sheet.dart';

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
      if (slotPresentation.isKnown &&
          seenSlotIds.add(slotPresentation.stableId)) {
        visibleSlots.add(slotPresentation);
      }
    }

    final meals = [
      for (final p in visibleSlots) (type: p.stableId, label: p.label),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final primary = FoodDiaryPrimaryAddAction(
                  onPressed: () => _openMealPicker(context),
                );
                final quickAdd = FilledButton.tonalIcon(
                  key: const ValueKey('food_diary_quick_add'),
                  onPressed: () => _openQuickAdd(context),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text('Quick add'),
                );
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                if (constraints.maxWidth < 340 || textScale > 1.3) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [primary, const SizedBox(height: 8), quickAdd],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: primary),
                    const SizedBox(width: 8),
                    quickAdd,
                  ],
                );
              },
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
            () {
              final yesterday = _civilDay(
                _selectedDay.subtract(const Duration(days: 1)),
              );
              final yesterdayRecords =
                  ref
                      .watch(canonicalFoodRecordsForDayProvider(yesterday))
                      .valueOrNull ??
                  const [];
              final recentFoods =
                  ref.watch(canonicalRecentFoodsProvider).valueOrNull ??
                  const [];

              return Column(
                children: [
                  for (var index = 0; index < meals.length; index++) ...[
                    Builder(
                      builder: (context) {
                        final mealType = meals[index].type;
                        final mealRecords = records
                            .where(
                              (record) =>
                                  foodDiaryMealType(record.mealCategory) ==
                                  mealType,
                            )
                            .toList(growable: false);
                        final yesterdayMealRecords = yesterdayRecords
                            .where(
                              (record) =>
                                  foodDiaryMealType(record.mealCategory) ==
                                  mealType,
                            )
                            .toList(growable: false);
                        final eatAgain = recentFoods
                            .where(
                              (item) =>
                                  foodDiaryMealType(
                                    item.lastLoggedMealCategory ?? '',
                                  ) ==
                                  mealType,
                            )
                            .take(3)
                            .toList(growable: false);

                        return FoodDiaryMealRow(
                          type: mealType,
                          label: meals[index].label,
                          records: mealRecords,
                          isLoading:
                              daily == null &&
                              (diary.isLoading || canonical.isLoading),
                          onOpen: () => _openMealDetail(context, mealType),
                          onAdd: () => _openMealAdd(context, mealType),
                          onCopyYesterday:
                              (mealRecords.isEmpty &&
                                  yesterdayMealRecords.isNotEmpty)
                              ? () => _copyYesterdayMeal(
                                  mealType,
                                  yesterdayMealRecords,
                                )
                              : null,
                          eatAgainItems: eatAgain.isNotEmpty ? eatAgain : null,
                          onFastAdd: (recent) =>
                              _fastAddRecent(mealType, recent),
                        );
                      },
                    ),
                    if (index < meals.length - 1)
                      Divider(height: 16, color: context.b05Colors.border),
                  ],
                ],
              );
            }(),
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
              icon: Icons.rice_bowl_rounded,
              title: 'Thali builder',
              detail: 'Compose and log a complete Indian meal.',
              onTap: () => _openThaliBuilder(context),
            ),
            FoodDiaryShortcut(
              icon: Icons.saved_search_rounded,
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

  Future<String?> _chooseMeal(BuildContext context) {
    final activeSlots = ref.read(diaryMealSlotsProvider);
    final items = activeSlots.isNotEmpty
        ? activeSlots
        : MealPresentationRegistry.values;
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

  Future<void> _openThaliBuilder(BuildContext context) async {
    final meal = await _chooseMeal(context);
    if (meal == null || !context.mounted) return;
    await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) =>
            ThaliBuilderScreen(mealCategory: meal, selectedDate: _selectedDay),
      ),
    );
    if (mounted) _refreshDiaryReads();
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

  Future<void> _openQuickAdd(BuildContext context) async {
    final meal = await _chooseMeal(context);
    if (meal == null || !context.mounted) return;
    final added = await QuickAddMacrosSheet.show(
      context,
      initialMealType: meal,
      targetDate: _selectedDay,
    );
    if (added != null && mounted) _refreshDiaryReads();
  }

  Future<void> _fastAddRecent(
    String mealType,
    CanonicalRecentFood recent,
  ) async {
    try {
      final option = recent.option;
      final quantity =
          recent.historicalQuantity ??
          Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece);
      final coordinator = await ref.read(
        nutritionFoodLoggingCoordinatorProvider.future,
      );
      final preview = await coordinator.preview(
        option: option,
        quantity: quantity,
      );
      final dates = LocalScheduleDateService();
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final localDate = dates.localDateFor(_selectedDay, timezoneId);
      final isToday =
          localDate == dates.localDateFor(DateTime.now(), timezoneId);
      final loggedAtUtc = isToday
          ? DateTime.now().toUtc()
          : dates.instantForLocalDate(localDate, timezoneId);

      await coordinator.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: preview,
        mealCategory: mealType,
        loggedAt: loggedAtUtc,
        localDate: localDate,
        timezoneId: timezoneId,
        commandId: 'fast-add-command::${const Uuid().v4()}',
        consumptionId: 'fast-add-consumption::${const Uuid().v4()}',
      );
      if (!mounted) return;
      _refreshDiaryReads();
      showIndiFitSuccessFeedback(
        context,
        'Logged ${option.displayName} to ${foodDiaryMealTitle(mealType)}',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not log food. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _copyYesterdayMeal(
    String mealType,
    List<NutritionHistoricalReadRecord> yesterdayRecords,
  ) async {
    try {
      final copied = await repeatMealRecords(
        ref,
        mealType: mealType,
        records: yesterdayRecords,
        targetDay: _selectedDay,
      );
      if (mounted) {
        _refreshDiaryReads();
        if (copied > 0) {
          showIndiFitSuccessFeedback(
            context,
            'Copied $copied food${copied == 1 ? '' : 's'} from yesterday into ${foodDiaryMealTitle(mealType)}',
          );
        }
      }
    } on Object catch (error, stackTrace) {
      AppLogger.error('Copying yesterday\'s meal failed', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not copy yesterday\'s meal.'),
          ),
        );
      }
    }
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
