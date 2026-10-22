import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/nutrients.dart';
import '../../../core/nutrition_legacy_read_models.dart';
import '../../../core/presentation/consumer_copy.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/typed_quantities.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/catalog/catalogue_quantity_resolver.dart';
import '../meal_presentation_registry.dart';
import 'meal_icon_chip.dart';

/// How a logged food is measured, for showing the amount as it was picked.
final loggedFoodMeasureProvider = FutureProvider.autoDispose
    .family<CatalogueFoodMeasure?, String>(
      (ref, foodId) => CatalogueQuantityResolver(
        ref.watch(databaseProvider),
      ).measureFor(foodId),
    );

/// The amount as picked: "1 katori (150 g)", not "1 serving" (UR-16).
String? loggedItemAmountLabel(WidgetRef ref, NutritionHistoricalReadItem item) {
  final typed = item.quantity.quantity;
  final foodId = item.foodId;
  final measure = typed == null || foodId == null
      ? null
      : ref.watch(loggedFoodMeasureProvider(foodId)).valueOrNull;
  return measure?.pickedAmountLabel(typed!) ??
      loggedQuantityLabel(item.quantity);
}

/// A stored quantity in words, for rows without a household measure.
String? loggedQuantityLabel(NutritionHistoricalQuantity quantity) {
  final typed = quantity.quantity;
  if (typed != null) return QuantityFormatter.format(typed);
  if (quantity.storedAmount == null || quantity.storedUnit.trim().isEmpty) {
    return null;
  }
  return QuantityFormatter.formatStored(
    '${quantity.storedAmount}',
    quantity.storedUnit,
  );
}

/// "120 kcal", "100–140 kcal", or "—" when the fact isn't known.
String loggedFactLabel(NutrientFact? fact, String unit, int precision) {
  if (fact == null || !fact.isAvailable) return '—';
  String format(NutrientAmount? amount) => amount == null
      ? '—'
      : '${amount.value.format(decimalPlaces: precision)} $unit';
  if (fact.lower == null && fact.upper == null) return format(fact.point);
  return '${format(fact.lower)}–${format(fact.upper)}';
}

/// One line inside an expanded thali or recipe row.
class LoggedFoodRowPart {
  const LoggedFoodRowPart({required this.name, this.amount, this.kcal});

  final String name;
  final String? amount;
  final String? kcal;
}

/// The one logged-food row (UR-40): art · name · household amount · kcal ·
/// trailing action ("…" for a logged entry, "+" for a recent). Rows made of
/// several foods (a thali) expand to them.
class LoggedFoodRowLayout extends StatefulWidget {
  const LoggedFoodRowLayout({
    super.key,
    required this.mealType,
    required this.name,
    this.amount,
    this.kcal,
    this.note,
    this.leading,
    this.trailing,
    this.onTap,
    this.parts = const [],
    this.initiallyExpanded = false,
    this.horizontalPadding = 0,
  });

  /// Inset inside a card (search recents).
  final double horizontalPadding;

  /// The meal whose art leads the row.
  final String? mealType;
  final String name;
  final String? amount;
  final String? kcal;

  /// A quiet second line: "Nutrition details incomplete", "Yesterday".
  final String? note;

  /// Replaces the meal art (a checkbox while multi-selecting).
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<LoggedFoodRowPart> parts;
  final bool initiallyExpanded;

  @override
  State<LoggedFoodRowLayout> createState() => _LoggedFoodRowLayoutState();
}

class _LoggedFoodRowLayoutState extends State<LoggedFoodRowLayout> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final presentation = MealPresentationRegistry.forStableId(
      widget.mealType ?? 'snack',
    );
    final role = context.b05Colors.meal(
      presentation.accent ?? B05MealAccent.snack,
    );
    final expandable = widget.parts.length > 1;
    // Narrow or large text: the kcal joins the detail line instead of
    // taking its own column.
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final detail = [
      if (widget.amount?.isNotEmpty == true) widget.amount!,
      if (expandable) '${widget.parts.length} items',
      if (compact && widget.kcal != null) widget.kcal!,
    ].join(' · ');
    final kcalStyle = B05Typography.label(
      context,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      container: true,
      label: [widget.name, if (detail.isNotEmpty) detail].join(', '),
      value: widget.kcal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('logged_food_row_${widget.name}'),
              borderRadius: B05Radii.smallRadius,
              onTap: expandable
                  ? () => setState(() => _expanded = !_expanded)
                  : widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: B05Layout.space8),
                child: Row(
                  children: [
                    widget.leading ??
                        MealIconChip(presentation: presentation, color: role),
                    const SizedBox(width: B05Layout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: B05Typography.label(context),
                          ),
                          if (detail.isNotEmpty)
                            Text(
                              detail,
                              maxLines: compact ? 3 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: B05Typography.caption(context),
                            ),
                          if (widget.note != null)
                            Text(
                              widget.note!,
                              style: B05Typography.caption(context),
                            ),
                        ],
                      ),
                    ),
                    if (!compact && widget.kcal != null) ...[
                      const SizedBox(width: B05Layout.space8),
                      Text(widget.kcal!, style: kcalStyle),
                    ],
                    if (expandable)
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        semanticLabel: _expanded ? 'Collapse' : 'Expand',
                      ),
                    // Large text makes an add button wide: it gets its own
                    // line below instead.
                    if (!compact) ?widget.trailing,
                  ],
                ),
              ),
            ),
          ),
          if (compact && widget.trailing != null)
            Align(alignment: Alignment.centerRight, child: widget.trailing),
          if (expandable && _expanded)
            for (final part in widget.parts)
              Padding(
                key: ValueKey('logged_food_part_${part.name}'),
                padding: const EdgeInsets.only(
                  left: 40 + B05Layout.space12,
                  bottom: B05Layout.space4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          part.name,
                          if (part.amount?.isNotEmpty == true) part.amount!,
                        ].join(' · '),
                        style: B05Typography.caption(context),
                      ),
                    ),
                    if (part.kcal != null)
                      Text(part.kcal!, style: B05Typography.caption(context)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// [LoggedFoodRowLayout] for a logged record, or one item of it. [onActions]
/// is the record-actions entry point (UR-11, UR-51) behind "…".
/// Whether [item]'s numbers came from an AI estimate, not a catalogue food.
bool isAiEstimateItem(NutritionHistoricalReadItem item) =>
    item.facts['energy']?.source == NutrientSourceType.aiEstimate;

class LoggedFoodRow extends ConsumerWidget {
  const LoggedFoodRow({
    super.key,
    required this.record,
    this.item,
    this.onActions,
  });

  final NutritionHistoricalReadRecord record;
  final NutritionHistoricalReadItem? item;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final single = item;
    final name = single?.displayLabel?.trim().isNotEmpty == true
        ? single!.displayLabel!.trim()
        : record.displayLabel;
    final items = record.items;
    final composite = single == null && items.length > 1;
    final amount = single != null
        ? loggedItemAmountLabel(ref, single)
        : composite
        ? null
        : items.isEmpty
        ? null
        : loggedItemAmountLabel(ref, items.single);
    final kcal = loggedFactLabel(
      single?.facts['energy'] ?? record.totals.facts['energy'],
      'kcal',
      0,
    );
    final incomplete = single != null
        ? single.facts['energy']?.isAvailable != true
        : record.completeness.state != NutrientCompletenessState.complete;
    // Estimates must never look like catalogue facts (U-4).
    final estimate = single != null
        ? isAiEstimateItem(single)
        : items.isNotEmpty && items.every(isAiEstimateItem);
    final note = [
      if (estimate) 'Estimate',
      if (incomplete) ConsumerCopy.nutritionDetailsIncomplete,
    ].join(' · ');
    return LoggedFoodRowLayout(
      mealType: record.mealCategory,
      name: name,
      amount: amount,
      kcal: kcal,
      note: note.isEmpty ? null : note,
      onTap: onActions,
      parts: [
        if (composite)
          for (final part in items)
            LoggedFoodRowPart(
              name: part.displayLabel?.trim().isNotEmpty == true
                  ? part.displayLabel!.trim()
                  : 'Food',
              amount: loggedItemAmountLabel(ref, part),
              kcal: loggedFactLabel(part.facts['energy'], 'kcal', 0),
            ),
      ],
      trailing: onActions == null
          ? null
          : B05IconAction(
              icon: Icons.more_horiz_rounded,
              label: 'Actions for $name',
              hint: 'Edit, copy, or delete this entry.',
              onPressed: onActions!,
            ),
    );
  }
}
