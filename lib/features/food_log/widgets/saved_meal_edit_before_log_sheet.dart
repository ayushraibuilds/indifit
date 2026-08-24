import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/nutrition_thali.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/typed_quantities.dart';
import '../../dashboard/today_surface_controller.dart';
import '../saved_meal_presentation.dart';

class SavedMealEditBeforeLogSheet extends ConsumerStatefulWidget {
  final NutritionThaliDraft draft;
  final String mealType;
  final DateTime selectedDate;
  final bool hasPartialNutrition;
  final bool requiresPartialAcknowledgement;

  const SavedMealEditBeforeLogSheet({
    super.key,
    required this.draft,
    required this.mealType,
    required this.selectedDate,
    this.hasPartialNutrition = false,
    this.requiresPartialAcknowledgement = false,
  });

  @override
  ConsumerState<SavedMealEditBeforeLogSheet> createState() =>
      _SavedMealEditBeforeLogSheetState();
}

class _SavedMealEditBeforeLogSheetState
    extends ConsumerState<SavedMealEditBeforeLogSheet> {
  late List<NutritionThaliItem> _items;
  final Set<String> _enabledItemIds = {};
  final Map<String, double> _quantityMultipliers = {};
  bool _isCommitting = false;
  late bool _partialAcknowledged;
  late bool _hasPartialNutrition;
  late bool _requiresPartialAcknowledgement;
  String? _commandId;
  String? _consumptionId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.draft.items);
    _hasPartialNutrition = widget.hasPartialNutrition;
    _requiresPartialAcknowledgement = widget.requiresPartialAcknowledgement;
    _partialAcknowledged = false;
    for (final item in _items) {
      _enabledItemIds.add(item.id);
      _quantityMultipliers[item.id] = 1.0;
    }
  }

  void _adjustMultiplier(String itemId, double delta) {
    setState(() {
      _resetPendingLog();
      final current = _quantityMultipliers[itemId] ?? 1.0;
      final next = (current + delta).clamp(0.25, 10.0);
      _quantityMultipliers[itemId] = (next * 100).roundToDouble() / 100;
    });
  }

  void _toggleItem(String itemId) {
    setState(() {
      _resetPendingLog();
      if (_enabledItemIds.contains(itemId)) {
        if (_enabledItemIds.length > 1) {
          _enabledItemIds.remove(itemId);
        }
      } else {
        _enabledItemIds.add(itemId);
      }
    });
  }

  Future<void> _commitLog() async {
    if (_isCommitting) return;
    setState(() {
      _isCommitting = true;
      _errorMessage = null;
    });

    try {
      final thaliRepo = await ref.read(nutritionThaliRepositoryProvider.future);

      // Build a transient variation over the saved meal. It keeps the saved
      // meal identity/version for snapshot lineage but is never persisted as a
      // second reusable meal.
      final modifiedItems = <NutritionThaliItem>[];
      var position = 0;
      for (final item in _items) {
        if (!_enabledItemIds.contains(item.id)) continue;
        final multiplier = _quantityMultipliers[item.id] ?? 1.0;
        final scaledAmount = item.quantity.amount.multiply(
          QuantityAmount.fromNum(multiplier),
        );
        final scaledQuantity = Quantity(
          amount: scaledAmount,
          unit: item.quantity.unit,
          context: item.quantity.context,
        );

        modifiedItems.add(
          NutritionThaliItem(
            id: 'temp-item::${const Uuid().v4()}',
            position: position++,
            source: item.source,
            foodId: item.foodId,
            recipeVersionId: item.recipeVersionId,
            quantity: scaledQuantity,
            measureId: item.measureId,
            optional: item.optional,
            notes: item.notes,
            displayLabel: item.displayLabel,
          ),
        );
      }

      final variationDraft = NutritionThaliDraft(
        id: widget.draft.id,
        userId: widget.draft.userId,
        name: widget.draft.name,
        description: widget.draft.description,
        lifecycle: 'active',
        currentVersion: widget.draft.currentVersion,
        createdAtUtc: widget.draft.createdAtUtc,
        updatedAtUtc: widget.draft.updatedAtUtc,
        items: modifiedItems,
      );

      final preview = await thaliRepo.preview(draft: variationDraft);
      final hasPartialNutrition =
          preview.isPartial || preview.isUnknown || preview.hasUnresolvedInputs;
      final requiresAcknowledgement = _requiresAcknowledgementFor(preview);
      if (hasPartialNutrition != _hasPartialNutrition ||
          requiresAcknowledgement != _requiresPartialAcknowledgement) {
        if (!mounted) return;
        setState(() {
          _hasPartialNutrition = hasPartialNutrition;
          _requiresPartialAcknowledgement = requiresAcknowledgement;
        });
      }
      if (requiresAcknowledgement && !_partialAcknowledged) {
        if (mounted) {
          setState(() {
            _isCommitting = false;
            _errorMessage =
                'Review the incomplete nutrition before logging this meal.';
          });
        }
        return;
      }

      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final dates = ref.read(localScheduleDateServiceProvider);
      final localDate = _localDateKey(widget.selectedDate);
      final loggedAt = dates.instantForLocalDate(localDate, timezoneId);

      final snapshot = await thaliRepo.finalize(
        preview: preview,
        mealCategory: widget.mealType,
        loggedAt: loggedAt,
        localDate: localDate,
        timezoneId: timezoneId,
        commandId: _commandId ??= 'saved-meal-edit-log::${const Uuid().v4()}',
        consumptionId: _consumptionId ??=
            'saved-meal-edit-consumption::${const Uuid().v4()}',
        allowPartial: true,
        allowCompositionVariation: true,
      );

      ref.read(todayNutritionRevisionProvider.notifier).state++;
      ref.invalidate(b04ProductionRecommendationContextProvider);
      ref.invalidate(b04CurrentFoodControllerProvider);
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, snapshot);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCommitting = false;
          _errorMessage = 'Could not log meal. Please try again.';
        });
      }
    }
  }

  bool _requiresAcknowledgementFor(NutritionThaliPreview preview) {
    const coreNutrients = {'energy', 'protein', 'carbohydrate', 'fat'};
    return preview.hasUnresolvedInputs ||
        coreNutrients.any((nutrientId) {
          final fact = preview.aggregate.facts[nutrientId];
          return fact == null || !fact.isAvailable;
        });
  }

  void _resetPendingLog() {
    _commandId = null;
    _consumptionId = null;
    _partialAcknowledged = false;
  }

  static String _localDateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final activeItemCount = _enabledItemIds.length;
    final mealName = widget.mealType.toUpperCase();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: context.b05Colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.draft.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Adjust for this log · Saved meal stays unchanged',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.b05Colors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              if (_errorMessage != null)
                Container(
                  color: context.b05Colors.danger.container,
                  padding: const EdgeInsets.all(12),
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
                          _errorMessage!,
                          style: TextStyle(
                            color: context.b05Colors.danger.foreground,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_hasPartialNutrition)
                Container(
                  color: context.b05Colors.warning.container,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Text(
                    'Some nutrition details are incomplete and will stay marked as incomplete in this log.',
                    style: TextStyle(
                      color: context.b05Colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_requiresPartialAcknowledgement)
                CheckboxListTile(
                  value: _partialAcknowledged,
                  onChanged: _isCommitting
                      ? null
                      : (value) => setState(
                          () => _partialAcknowledged = value ?? false,
                        ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('Log with incomplete core nutrition'),
                  subtitle: const Text(
                    'Unknown values will remain unknown, not zero.',
                  ),
                ),

              // Items List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isEnabled = _enabledItemIds.contains(item.id);
                    final multiplier = _quantityMultipliers[item.id] ?? 1.0;
                    final displayQty = savedMealQuantityLabel(
                      item.copyWith(
                        quantity: Quantity(
                          amount: item.quantity.amount.multiply(
                            QuantityAmount.fromNum(multiplier),
                          ),
                          unit: item.quantity.unit,
                          context: item.quantity.context,
                        ),
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stackControls =
                              constraints.maxWidth < 360 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.25;
                          final toggle = Checkbox(
                            value: isEnabled,
                            onChanged: (_) => _toggleItem(item.id),
                            activeColor: context.b05Colors.action,
                          );
                          final details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayLabel ?? 'Item',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isEnabled
                                      ? context.b05Colors.textPrimary
                                      : context.b05Colors.textSecondary,
                                  decoration: isEnabled
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayQty,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.b05Colors.textSecondary,
                                ),
                              ),
                            ],
                          );
                          final controls = isEnabled
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Reduce portion',
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 22,
                                      ),
                                      color: context.b05Colors.action,
                                      onPressed: () =>
                                          _adjustMultiplier(item.id, -0.25),
                                    ),
                                    Text(
                                      '${multiplier}x',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Increase portion',
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 22,
                                      ),
                                      color: context.b05Colors.action,
                                      onPressed: () =>
                                          _adjustMultiplier(item.id, 0.25),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink();
                          if (stackControls) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    toggle,
                                    Expanded(child: details),
                                  ],
                                ),
                                if (isEnabled)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: controls,
                                  ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              toggle,
                              Expanded(child: details),
                              if (isEnabled) controls,
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isCommitting || activeItemCount == 0
                        ? null
                        : _commitLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.b05Colors.action,
                      foregroundColor: context.b05Colors.onAction,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCommitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: context.b05Colors.onAction,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'ADD $activeItemCount ${activeItemCount == 1 ? 'ITEM' : 'ITEMS'} TO $mealName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
