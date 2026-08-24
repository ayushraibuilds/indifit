import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/nutrition_target_authority.dart';
import '../dashboard/today_surface_controller.dart';
import 'food_contextual_actions.dart';
import 'meal_presentation_registry.dart';

DateTime _civilDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Read-only provider boundary for the legacy B03 food-log read. The panel
/// consumes this typed snapshot; it never queries Drift from a widget. A
/// one-shot read avoids retaining a database stream while an action is being
/// reconciled; mutations explicitly invalidate the provider below.
final foodLogsForDayProvider = FutureProvider.autoDispose
    .family<List<FoodLog>, DateTime>((ref, date) {
      return ref.watch(foodRepositoryProvider).getLogsForDay(_civilDay(date));
    });

/// Canonical B03 snapshots for the selected civil day. The legacy panel below
/// remains available for B05 edit/copy/delete actions, but new food entries
/// are read from this boundary so Food and Today share the same totals.
final canonicalFoodRecordsForDayProvider = FutureProvider.autoDispose
    .family<List<NutritionHistoricalReadRecord>, DateTime>((ref, date) async {
      ref.watch(todayNutritionRevisionProvider);
      final repository = await ref.watch(
        nutritionReadModelRepositoryProvider.future,
      );
      final records = await repository.listForLocalDate(
        userId: kLocalNutritionUserScopeId,
        localDate: _localDateKey(date),
      );
      return records
          .where((record) => !record.isLegacy)
          .toList(growable: false);
    });

class FoodDiaryReadModel {
  const FoodDiaryReadModel({
    required this.daily,
    this.targets = const TodayDomainRead<NutritionTargetsForDate?>.available(
      null,
    ),
  });

  final NutritionDailyReadModel daily;

  /// The target read is separate from food totals so a target-source failure
  /// cannot hide otherwise available logged-food history.
  final TodayDomainRead<NutritionTargetsForDate?> targets;
}

/// Food-root read boundary. It asks the canonical B03 read model for both the
/// day records and its authoritative aggregation without pulling in Today’s
/// unrelated calendar, activity, or coaching reads.
final foodDiaryReadModelProvider = FutureProvider.autoDispose
    .family<FoodDiaryReadModel, DateTime>((ref, date) async {
      ref.watch(todayNutritionRevisionProvider);
      ref.watch(nutritionTargetAuthorityChangesProvider);
      final repository = await ref.watch(
        nutritionReadModelRepositoryProvider.future,
      );
      final daily = await repository.dailyTotals(
        userId: kLocalNutritionUserScopeId,
        localDate: _localDateKey(date),
      );
      TodayDomainRead<NutritionTargetsForDate?> targets;
      try {
        final timezoneId = await ref
            .watch(localTimezoneServiceProvider)
            .currentTimezoneId();
        targets = TodayDomainRead<NutritionTargetsForDate?>.available(
          await ref
              .watch(nutritionTargetAuthorityProvider)
              .resolve(
                NutritionTargetDateQuery(
                  localDate: _localDateKey(date),
                  timezoneId: timezoneId,
                ),
              ),
        );
      } catch (_) {
        targets = const TodayDomainRead<NutritionTargetsForDate?>.unavailable(
          'Nutrition target unavailable',
        );
      }
      return FoodDiaryReadModel(daily: daily, targets: targets);
    });

/// A compact production food-log surface used by the existing food-search/log
/// flow. It keeps mutation and undo behavior inside [FoodContextualActions].
class FoodLogEntriesPanel extends ConsumerWidget {
  const FoodLogEntriesPanel({
    required this.date,
    super.key,
    this.includeCanonical = true,
    this.mealType,
    this.onCanonicalRecordTap,
    this.onCanonicalItemTap,
  });

  final DateTime date;
  final bool includeCanonical;
  final String? mealType;
  final ValueChanged<NutritionHistoricalReadRecord>? onCanonicalRecordTap;
  final void Function(
    NutritionHistoricalReadRecord record,
    NutritionHistoricalReadItem item,
  )?
  onCanonicalItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(foodLogsForDayProvider(_civilDay(date)));
    final canonical = includeCanonical
        ? ref.watch(canonicalFoodRecordsForDayProvider(_civilDay(date)))
        : const AsyncData<List<NutritionHistoricalReadRecord>>([]);
    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space12),
      radius: B05SurfaceRadius.small,
      child: _buildPanelContent(context, ref, logs, canonical),
    );
  }

  Widget _buildPanelContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<FoodLog>> logs,
    AsyncValue<List<NutritionHistoricalReadRecord>> canonical,
  ) {
    if (logs.isLoading || (includeCanonical && canonical.isLoading)) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Loading logged food',
      );
    }
    final normalizedMealType = _normalizeMealType(mealType);
    final legacyItems = (logs.valueOrNull ?? const <FoodLog>[])
        .where(
          (item) =>
              normalizedMealType == null ||
              _normalizeMealType(item.mealType) == normalizedMealType,
        )
        .toList(growable: false);
    final canonicalItems =
        (canonical.valueOrNull ?? const <NutritionHistoricalReadRecord>[])
            .where(
              (item) =>
                  normalizedMealType == null ||
                  _normalizeMealType(item.mealCategory) == normalizedMealType,
            )
            .toList(growable: false);
    if (logs.hasError && (!includeCanonical || canonical.hasError)) {
      return ProductFailureCard(
        failure: ProductFailurePresentation.fromCode(
          'food_log_unavailable',
          title: 'Logged food is unavailable',
        ),
        onRetry: () {
          ref.invalidate(foodLogsForDayProvider(_civilDay(date)));
          ref.invalidate(canonicalFoodRecordsForDayProvider(_civilDay(date)));
        },
      );
    }
    if (canonical.hasError && legacyItems.isEmpty) {
      return ProductFailureCard(
        failure: ProductFailurePresentation.fromCode(
          'food_log_unavailable',
          title: 'Logged food is unavailable',
        ),
        onRetry: () =>
            ref.invalidate(canonicalFoodRecordsForDayProvider(_civilDay(date))),
      );
    }
    if (legacyItems.isEmpty && canonicalItems.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'No food logged for this day',
        value: 'Use Search foods above to add a meal.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Logged food', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space8),
        if (canonicalItems.isNotEmpty)
          _CanonicalFoodRows(
            records: canonicalItems,
            onRecordTap: onCanonicalRecordTap,
            onItemTap: onCanonicalItemTap,
          ),
        if (legacyItems.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: legacyItems.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: B05Layout.space8),
              itemBuilder: (context, index) => FoodContextualActions(
                log: legacyItems[index],
                onChanged: () {
                  ref.invalidate(foodLogsForDayProvider(_civilDay(date)));
                  ref.invalidate(
                    canonicalFoodRecordsForDayProvider(_civilDay(date)),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

String? _normalizeMealType(String? value) {
  final normalized = value?.trim().toLowerCase();
  return switch (normalized) {
    'snacks' => 'snack',
    null || '' => null,
    _ => normalized,
  };
}

class _CanonicalFoodRows extends StatelessWidget {
  const _CanonicalFoodRows({
    required this.records,
    this.onRecordTap,
    this.onItemTap,
  });

  final List<NutritionHistoricalReadRecord> records;
  final ValueChanged<NutritionHistoricalReadRecord>? onRecordTap;
  final void Function(
    NutritionHistoricalReadRecord record,
    NutritionHistoricalReadItem item,
  )?
  onItemTap;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<NutritionHistoricalReadRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.mealCategory, () => []).add(record);
    }
    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          for (final record in entry.value) ...[
            if (record.items.any(
              (item) =>
                  item.originSourceType == 'direct_food' && item.foodId != null,
            ))
              for (final item in record.items.where(
                (item) =>
                    item.originSourceType == 'direct_food' &&
                    item.foodId != null,
              ))
                _CanonicalFoodRow(
                  record: record,
                  item: item,
                  onItemTap: onItemTap,
                )
            else
              _CanonicalFoodRow(record: record, onTap: onRecordTap),
          ],
          if (entry.key != grouped.keys.last)
            const SizedBox(height: B05Layout.space8),
        ],
      ],
    );
  }
}

class _CanonicalFoodRow extends StatelessWidget {
  const _CanonicalFoodRow({
    required this.record,
    this.item,
    this.onTap,
    this.onItemTap,
  });

  final NutritionHistoricalReadRecord record;
  final NutritionHistoricalReadItem? item;
  final ValueChanged<NutritionHistoricalReadRecord>? onTap;
  final void Function(
    NutritionHistoricalReadRecord record,
    NutritionHistoricalReadItem item,
  )?
  onItemTap;

  @override
  Widget build(BuildContext context) {
    final presentation = foodMealPresentationFor(record.mealCategory);
    final role = context.b05Colors.meal(
      presentation.accent ?? B05MealAccent.snack,
    );
    final displayName = item?.displayLabel?.trim().isNotEmpty == true
        ? item!.displayLabel!
        : record.displayLabel;
    final serving = item == null
        ? record.items
              .map((entry) => _historicalQuantityLabel(entry.quantity))
              .where((value) => value != null)
              .join(' · ')
        : _historicalQuantityLabel(item!.quantity) ?? '';
    final actionTap = item != null
        ? onItemTap == null
              ? null
              : () => onItemTap!(record, item!)
        : onTap == null
        ? null
        : () => onTap!(record);
    final energy = _factLabel(
      item?.facts['energy'] ?? record.totals.facts['energy'],
      'kcal',
      0,
    );
    final protein = _factLabel(
      item?.facts['protein'] ?? record.totals.facts['protein'],
      'g protein',
      1,
    );
    final hasMissingItemFacts =
        item != null &&
        (item!.facts['energy']?.isAvailable != true ||
            item!.facts['protein']?.isAvailable != true);
    return Semantics(
      container: true,
      label: '${presentation.label}: $displayName',
      value: '$energy, $protein',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: actionTap,
          borderRadius: B05Radii.smallRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: B05Layout.space8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: role.container,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(B05Layout.space8),
                    child: Icon(presentation.icon, color: role.indicator),
                  ),
                ),
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: B05Typography.label(context)),
                      const SizedBox(height: B05Layout.space4),
                      Text(
                        [
                          presentation.label,
                          if (serving.isNotEmpty) serving,
                          energy,
                          protein,
                        ].join(' · '),
                        style: B05Typography.caption(context),
                      ),
                      if (hasMissingItemFacts ||
                          (item == null &&
                              record.completeness.state !=
                                  NutrientCompletenessState.complete))
                        Text(
                          'Some nutrition information is missing',
                          style: B05Typography.caption(context),
                        ),
                    ],
                  ),
                ),
                if (actionTap != null)
                  B05IconAction(
                    icon: Icons.more_horiz_rounded,
                    label: 'Actions for $displayName',
                    hint: 'Edit, copy, or delete this entry.',
                    onPressed: actionTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _historicalQuantityLabel(NutritionHistoricalQuantity quantity) {
  final typed = quantity.quantity;
  if (typed != null) return QuantityFormatter.format(typed);
  if (quantity.storedAmount == null || quantity.storedUnit.trim().isEmpty) {
    return null;
  }
  return '${quantity.storedAmount} ${quantity.storedUnit}';
}

String _factLabel(NutrientFact? fact, String unit, int precision) {
  if (fact == null || !fact.isAvailable) return '—';
  String format(NutrientAmount? amount) => amount == null
      ? '—'
      : '${amount.value.format(decimalPlaces: precision)} $unit';
  if (fact.lower == null && fact.upper == null) return format(fact.point);
  return '${format(fact.lower)}–${format(fact.upper)}';
}

String _localDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
