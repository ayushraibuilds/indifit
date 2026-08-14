import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/nutrition_thali.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/theme/colors.dart';
import '../../../core/typed_quantities.dart';

class SavedMealEditBeforeLogSheet extends ConsumerStatefulWidget {
  final NutritionThaliDraft draft;
  final String mealType;
  final DateTime selectedDate;

  const SavedMealEditBeforeLogSheet({
    super.key,
    required this.draft,
    required this.mealType,
    required this.selectedDate,
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.draft.items);
    for (final item in _items) {
      _enabledItemIds.add(item.id);
      _quantityMultipliers[item.id] = 1.0;
    }
  }

  void _adjustMultiplier(String itemId, double delta) {
    setState(() {
      final current = _quantityMultipliers[itemId] ?? 1.0;
      final next = (current + delta).clamp(0.25, 10.0);
      _quantityMultipliers[itemId] = (next * 100).roundToDouble() / 100;
    });
  }

  void _toggleItem(String itemId) {
    setState(() {
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

      // Build modified temporary draft without touching the original saved template
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

      final tempDraft = NutritionThaliDraft(
        id: 'temp-thali::${const Uuid().v4()}',
        userId: widget.draft.userId,
        name: widget.draft.name,
        description: widget.draft.description,
        lifecycle: 'active',
        currentVersion: 1,
        createdAtUtc: DateTime.now().toUtc(),
        updatedAtUtc: DateTime.now().toUtc(),
        items: modifiedItems,
      );

      await thaliRepo.saveDraft(tempDraft);
      final preview = await thaliRepo.preview(draft: tempDraft);
      final when = widget.selectedDate.toUtc();
      final localDate =
          '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';

      final snapshot = await thaliRepo.finalize(
        preview: preview,
        mealCategory: widget.mealType,
        loggedAt: when,
        localDate: localDate,
        timezoneId: 'UTC',
        commandId: 'saved-meal-edit-log::${const Uuid().v4()}',
        consumptionId: 'saved-meal-edit-consumption::${const Uuid().v4()}',
        allowPartial: true,
      );

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
                            'Review portions for today · Template remains unchanged',
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
                  color: AppColors.danger.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(12),
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
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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
                    final effectiveAmount =
                        item.quantity.amount.asDouble * multiplier;
                    final displayQty =
                        '${effectiveAmount == effectiveAmount.roundToDouble() ? effectiveAmount.toInt() : effectiveAmount.toStringAsFixed(1)} ${item.quantity.unit.name}';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isEnabled,
                            onChanged: (_) => _toggleItem(item.id),
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Column(
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
                            ),
                          ),
                          if (isEnabled) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 22,
                              ),
                              color: AppColors.primary,
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
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 22,
                              ),
                              color: AppColors.primary,
                              onPressed: () => _adjustMultiplier(item.id, 0.25),
                            ),
                          ],
                        ],
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCommitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
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
