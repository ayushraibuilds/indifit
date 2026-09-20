import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/catalog/food_catalog_models.dart';
import '../../../core/di/providers.dart';
import '../../../core/nutrition_household_measures.dart';
import '../../../core/nutrition_legacy_read_models.dart';
import '../../../core/presentation/consumer_copy.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/typed_quantities.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_feedback.dart';
import '../../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../../data/repositories/nutrition_food_logging_coordinator.dart';
import '../../dashboard/today_surface_controller.dart';
import '../diary_structure_controller.dart';
import '../food_search_view_models.dart';
import '../meal_presentation_registry.dart';
import 'food_search_widgets.dart';

/// Portion, unit, and preparation review bottom sheet for canonical food logging.
///
/// Extracted from `food_search_screen.dart` (PV1-ENG-05D second pass) to isolate
/// modal portion orchestration, text editing, conversion previews, and transactional
/// persistence behind a single, behavior-preserving widget.
class FoodPortionBottomSheet extends ConsumerStatefulWidget {
  final NutritionFoodOption option;
  final String initialMealType;
  final Quantity? initialQuantity;
  final DateTime? targetDate;
  final NutritionHistoricalReadRecord? correctionRecord;
  final NutritionHistoricalReadItem? correctionItem;
  final Future<void> Function(Quantity quantity)? onQuantityPicked;
  final NutritionFoodLoggingCoordinator coordinator;
  final List<dynamic> transformations;
  final NutritionFoodLogPreview? initialPreview;
  final String? categoryId;
  final List<ServingOption>? categoryServingOptions;

  const FoodPortionBottomSheet({
    super.key,
    required this.option,
    required this.initialMealType,
    this.initialQuantity,
    this.targetDate,
    this.correctionRecord,
    this.correctionItem,
    this.onQuantityPicked,
    required this.coordinator,
    required this.transformations,
    this.initialPreview,
    this.categoryId,
    this.categoryServingOptions,
  });

  /// Static launcher that prepares coordinator resources, presents the bottom
  /// sheet, and executes completion callbacks (success feedback, navigation pop,
  /// recent foods refresh).
  static Future<bool?> show(
    BuildContext context, {
    required WidgetRef ref,
    required NutritionFoodOption option,
    String? mealType,
    Quantity? initialQuantity,
    DateTime? targetDate,
    NutritionHistoricalReadRecord? correctionRecord,
    NutritionHistoricalReadItem? correctionItem,
    Future<void> Function(Quantity quantity)? onQuantityPicked,
    required Future<String?> Function() ensureMealContext,
    bool returnToParentOnSave = false,
    Future<void> Function()? onRetryRecentFoods,
    void Function(String selectedMealType, bool isCorrection)? onCommitted,
    String? categoryId,
    List<ServingOption>? categoryServingOptions,
  }) async {
    final isCorrection = correctionRecord != null && correctionItem != null;
    final resolvedMealType =
        mealType ??
        correctionRecord?.mealCategory ??
        await ensureMealContext();
    if (resolvedMealType == null || !context.mounted) return null;

    FocusManager.instance.primaryFocus?.unfocus();
    final coordinator = await ref.read(
      nutritionFoodLoggingCoordinatorProvider.future,
    );
    final transformations = await coordinator.transformationsFor(option);
    if (!context.mounted) return null;

    final baseQuantity = initialQuantity ?? option.baseQuantity;
    final initialPreview = await coordinator.preview(
      option: option,
      quantity: baseQuantity,
      transformation: null,
    );
    if (!context.mounted) return null;

    TransitionRoute<dynamic>? sheetRoute;
    String? committedMealType;

    final dynamic savedResult = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.b05Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        sheetRoute ??= ModalRoute.of(sheetContext);
        return FoodPortionBottomSheet(
          option: option,
          initialMealType: resolvedMealType,
          initialQuantity: initialQuantity,
          targetDate: targetDate,
          correctionRecord: correctionRecord,
          correctionItem: correctionItem,
          onQuantityPicked: onQuantityPicked,
          coordinator: coordinator,
          transformations: transformations,
          initialPreview: initialPreview,
          categoryId: categoryId,
          categoryServingOptions: categoryServingOptions,
        );
      },
    );

    await sheetRoute?.completed;

    final isSaved = savedResult != null && savedResult != false;
    if (isSaved && context.mounted) {
      if (savedResult is String) {
        committedMealType = savedResult;
      }
      final finalMealType = committedMealType ?? resolvedMealType;
      onCommitted?.call(finalMealType, isCorrection);
      if (onQuantityPicked != null) return true;

      showIndiFitSuccessFeedback(
        context,
        isCorrection
            ? '✓ Food entry updated in ${_formatMealLabel(finalMealType)}'
            : '✓ Food added to ${_formatMealLabel(finalMealType)}',
      );
      if (returnToParentOnSave) {
        if (context.mounted) Navigator.of(context).pop(true);
      } else {
        await onRetryRecentFoods?.call();
      }
      return true;
    }

    return false;
  }

  @override
  ConsumerState<FoodPortionBottomSheet> createState() =>
      _FoodPortionBottomSheetState();

  static String _formatMealLabel(String? value) {
    if (value == null || value.trim().isEmpty) return 'meal';
    final presentation = MealPresentationRegistry.forStableId(value);
    return presentation.isKnown ? presentation.label.toLowerCase() : 'meal';
  }
}

class _FoodPortionBottomSheetState
    extends ConsumerState<FoodPortionBottomSheet> {
  late TextEditingController _amountController;
  late Quantity _selectedQuantity;
  late List<QuantityUnit> _compatibleUnits;
  String? _selectedTransformationId;
  String? _amountError;
  String? _commandId;
  String? _consumptionId;
  late String _selectedMealType;
  var _isFinalizing = false;
  var _previewGeneration = 0;
  NutritionFoodLogPreview? _currentPreview;
  var _previewHasError = false;

  bool get _isCorrection =>
      widget.correctionRecord != null && widget.correctionItem != null;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;
    _selectedQuantity = widget.initialQuantity ?? widget.option.baseQuantity;
    _compatibleUnits = <QuantityUnit>[
      ...switch (_selectedQuantity.dimension) {
        QuantityDimension.mass => const [
          QuantityUnit.gram,
          QuantityUnit.kilogram,
        ],
        QuantityDimension.volume => const [
          QuantityUnit.millilitre,
          QuantityUnit.litre,
        ],
        _ => [widget.option.baseQuantity.unit],
      },
    ];
    if (!_compatibleUnits.contains(_selectedQuantity.unit)) {
      _compatibleUnits.insert(0, _selectedQuantity.unit);
    }
    _currentPreview = widget.initialPreview;
    _amountController = TextEditingController(
      text: _selectedQuantity.amount.toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final currentGen = ++_previewGeneration;
    final transformation = widget.transformations
        .where((item) => item.id == _selectedTransformationId)
        .firstOrNull;
    widget.coordinator
        .preview(
          option: widget.option,
          quantity: _selectedQuantity,
          transformation: transformation,
        )
        .then((preview) {
          if (currentGen == _previewGeneration && mounted) {
            setState(() {
              _currentPreview = preview;
              _previewHasError = false;
            });
          }
        })
        .catchError((_) {
          if (currentGen == _previewGeneration && mounted) {
            setState(() {
              _previewHasError = true;
            });
          }
        });
  }

  void _setQuantity(Quantity quantity) {
    final nextText = quantity.amount.toString();
    _amountController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    setState(() {
      _selectedQuantity = quantity;
      _amountError = null;
      _updatePreview();
    });
  }

  void _applyServingOption(ServingOption opt) {
    if (_selectedQuantity.dimension == QuantityDimension.mass) {
      final gramVal = opt.gramWeight;
      _setQuantity(
        Quantity.fromDecimal(
          amount: gramVal % 1 == 0 ? gramVal.toInt().toString() : gramVal.toString(),
          unit: QuantityUnit.gram,
          context: _selectedQuantity.context,
        ),
      );
    } else if (_selectedQuantity.dimension == QuantityDimension.volume) {
      final mlVal = opt.gramWeight / 1.03;
      _setQuantity(
        Quantity.fromDecimal(
          amount: mlVal.round().toString(),
          unit: QuantityUnit.millilitre,
          context: _selectedQuantity.context,
        ),
      );
    } else {
      final baseGram = widget.option.baseQuantity.amount.asDouble;
      final factor = baseGram > 0 ? opt.gramWeight / baseGram : 1.0;
      _setQuantity(
        Quantity.fromDecimal(
          amount: factor % 1 == 0 ? factor.toInt().toString() : factor.toStringAsFixed(1),
          unit: _selectedQuantity.unit,
          context: _selectedQuantity.context,
        ),
      );
    }
  }

  String _formatServingOptionChipLabel(ServingOption option) {
    return switch (option.unitName) {
      'katori' => '1 Katori (150g)',
      'medium_katori' => 'Med Katori (200g)',
      'small_katori' => 'Small Katori (80g)',
      'serving_bowl' => 'Bowl (300g)',
      'roti_piece' => '1 Roti (35g)',
      'paratha_piece' => '1 Paratha (60g)',
      'stuffed_paratha' => 'Stuffed (110g)',
      'idli_piece' => '1 Idli (40g)',
      'dosa_piece' => '1 Dosa (90g)',
      'glass' => '1 Glass (206ml)',
      'tablespoon' => '1 Tbsp (15g)',
      'teaspoon' => '1 Tsp (5g)',
      'plate' => '1 Plate (150g)',
      '100g' => '100g',
      _ => '${option.unitName} (${option.gramWeight.round()}g)',
    };
  }

  void _updateAmount(String raw) {
    final trimmed = raw.trim();
    final amount = double.tryParse(trimmed);
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '0.') {
      setState(() {
        _amountError = null;
        _currentPreview = null;
      });
      return;
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() {
        _amountError = null;
        _currentPreview = null;
      });
      return;
    }
    final quantity = Quantity.fromDecimal(
      amount: trimmed,
      unit: _selectedQuantity.unit,
      context: _selectedQuantity.context,
    );
    setState(() {
      _selectedQuantity = quantity;
      _amountError = null;
      _updatePreview();
    });
  }

  void _invalidateNutritionReads() {
    ref.read(todayNutritionRevisionProvider.notifier).state++;
    ref.invalidate(b04ProductionRecommendationContextProvider);
    ref.invalidate(b04CurrentFoodControllerProvider);
    ref.invalidate(canonicalRecentFoodsProvider);
  }

  String _quantityUnitLabel(Quantity quantity) =>
      quantity.unit == QuantityUnit.householdReference
          ? quantity.context.householdMeasure!.measureType
          : quantity.unit == QuantityUnit.serving &&
                widget.option.servingUnitLabel?.trim().isNotEmpty == true
          ? widget.option.servingUnitLabel!.trim()
          : quantity.definition.displayLabel;

  String _mealLabel(String? value) {
    if (value == null || value.trim().isEmpty) return 'meal';
    final presentation = MealPresentationRegistry.forStableId(value);
    return presentation.isKnown ? presentation.label.toLowerCase() : 'meal';
  }

  String _mealTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Meal';
    final presentation = MealPresentationRegistry.forStableId(value);
    return presentation.isKnown ? presentation.label : 'Meal';
  }

  String _transformationLabel(dynamic transformation) {
    final source = _preparationLabel(transformation.sourceState);
    final target = _preparationLabel(transformation.targetState);
    if (source == 'Preparation' && target == 'Preparation') {
      return 'Use this preparation';
    }
    return '$source → $target';
  }

  String _preparationLabel(dynamic value) {
    final name = value.toString().split('.').last;
    return switch (name) {
      'raw' => 'Raw',
      'cooked' => 'Cooked',
      _ => 'Preparation',
    };
  }

  Widget _buildMacroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.b05Colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final rawAmount = _amountController.text.trim();
    final parsedAmount = double.tryParse(rawAmount);
    if (parsedAmount == null || !parsedAmount.isFinite || parsedAmount <= 0) {
      setState(() => _amountError = 'Enter an amount greater than zero.');
      return;
    }
    late final Quantity finalQuantity;
    try {
      finalQuantity = Quantity.fromDecimal(
        amount: rawAmount,
        unit: _selectedQuantity.unit,
        context: _selectedQuantity.context,
      );
      NutritionQuantityService.validatePositiveUserEnteredPortion(finalQuantity);
      _selectedQuantity = finalQuantity;
      _updatePreview();
    } on QuantityError {
      setState(() => _amountError = 'Enter an amount greater than zero.');
      return;
    }

    if (widget.onQuantityPicked != null) {
      setState(() => _isFinalizing = true);
      try {
        await widget.onQuantityPicked!(finalQuantity);
        if (mounted) Navigator.of(context).pop(_selectedMealType);
      } catch (_) {
        if (mounted) {
          setState(() => _isFinalizing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Amount could not be updated. Try again.'),
            ),
          );
        }
      }
      return;
    }

    setState(() {
      _isFinalizing = true;
      _commandId ??= 'direct-food-command::${const Uuid().v4()}';
      _consumptionId ??= 'direct-food-consumption::${const Uuid().v4()}';
    });

    try {
      final preview = await widget.coordinator.preview(
        option: widget.option,
        quantity: _selectedQuantity,
        transformation: widget.transformations
            .where((item) => item.id == _selectedTransformationId)
            .firstOrNull,
      );
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final dates = ref.read(localScheduleDateServiceProvider);
      final selectedLocalDate = widget.targetDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(widget.targetDate!);
      final loggedAt = selectedLocalDate == null
          ? DateTime.now().toUtc()
          : dates.instantForLocalDate(selectedLocalDate, timezoneId);
      final localDate =
          selectedLocalDate ?? dates.localDateFor(loggedAt, timezoneId);

      if (_isCorrection) {
        final canonicalRecord =
            widget.correctionRecord is NutritionCanonicalSnapshotReadModel
                ? (widget.correctionRecord as NutritionCanonicalSnapshotReadModel)
                    .snapshot
                : null;
        final correctionTimezone =
            canonicalRecord?.timezoneId ??
            await ref.read(localTimezoneServiceProvider).currentTimezoneId();
        final correctionLoggedAt = canonicalRecord?.loggedAtUtc ?? loggedAt;
        await widget.coordinator.correctDirectFoodItem(
          userId: kLocalNutritionUserScopeId,
          snapshotId: widget.correctionRecord!.stableId,
          itemId: widget.correctionItem!.stableId,
          expectedMealCategory: widget.correctionRecord!.mealCategory,
          mealCategory: _selectedMealType,
          localDate: widget.correctionRecord!.localDate,
          timezoneId: correctionTimezone,
          loggedAtUtc: correctionLoggedAt,
          commandId: _commandId!,
          correctionReason: 'User edited logged food.',
          replacement: preview,
        );
      } else {
        await widget.coordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: preview,
          mealCategory: _selectedMealType,
          loggedAt: loggedAt,
          localDate: localDate,
          timezoneId: timezoneId,
          commandId: _commandId,
          consumptionId: _consumptionId,
        );
      }

      _invalidateNutritionReads();
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}

      if (mounted) Navigator.of(context).pop(_selectedMealType);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isCorrection
                  ? 'Food entry could not be updated. Your changes are still here.'
                  : 'Meal could not be logged. Try again.',
            ),
          ),
        );
        setState(() => _isFinalizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepQuantity = _selectedQuantity / 4;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    Widget decreaseButton() => IconButton(
      tooltip: 'Decrease amount',
      icon: const Icon(Icons.remove_circle_outline),
      onPressed: _selectedQuantity.compareTo(stepQuantity) > 0
          ? () => _setQuantity(_selectedQuantity - stepQuantity)
          : null,
    );

    Widget amountInput() => TextField(
      key: const ValueKey('food_log_dialog_portion_field'),
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, value) {
          final text = value.text;
          return RegExp(r'^\d*(?:\.\d{0,4})?$').hasMatch(text)
              ? value
              : oldValue;
        }),
      ],
      decoration: InputDecoration(
        labelText: 'Amount',
        errorText: _amountError,
        suffixText: _compatibleUnits.length == 1
            ? _quantityUnitLabel(_selectedQuantity)
            : null,
      ),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onChanged: _updateAmount,
    );

    Widget unitPicker() => Semantics(
      label: 'Unit',
      value: _quantityUnitLabel(_selectedQuantity),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Unit',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<QuantityUnit>(
            key: const ValueKey('food_log_dialog_unit_dropdown'),
            isDense: true,
            value: _selectedQuantity.unit,
            items: _compatibleUnits
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(QuantityUnitRegistry.definitionFor(unit).symbol),
                  ),
                )
                .toList(),
            onChanged: (unit) {
              if (unit == null) return;
              _setQuantity(_selectedQuantity.convertTo(unit));
            },
          ),
        ),
      ),
    );

    Widget increaseButton() => IconButton(
      tooltip: 'Increase amount',
      icon: const Icon(Icons.add_circle_outline),
      onPressed: () => _setQuantity(_selectedQuantity + stepQuantity),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      child: FoodQuantityReviewCapture(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.option.displayName,
              style: B05Typography.title(context),
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              label: _isCorrection
                  ? 'Updating in ${_mealLabel(_selectedMealType)}'
                  : 'Adding to ${_mealLabel(_selectedMealType)}',
              child: Text(
                _isCorrection
                    ? ConsumerCopy.updateFoodInMeal(_mealLabel(_selectedMealType))
                    : ConsumerCopy.logToMeal(_mealLabel(_selectedMealType)),
                style: TextStyle(
                  color: context.b05Colors.action,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isCorrection) ...[
              () {
                final configured = ref.read(diaryMealSlotsProvider);
                final available = [
                  ...configured,
                  if (configured.every((m) => m.stableId != _selectedMealType))
                    MealPresentationRegistry.forStableId(_selectedMealType),
                ];
                return DropdownButtonFormField<String>(
                  initialValue: _selectedMealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal',
                    helperText: 'Choose a new meal only if you mean to move it.',
                  ),
                  items: [
                    for (final meal in available)
                      DropdownMenuItem(
                        value: meal.stableId,
                        child: Text(meal.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedMealType = value);
                  },
                );
              }(),
              const SizedBox(height: 12),
            ],

            if (widget.categoryServingOptions != null &&
                widget.categoryServingOptions!.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.categoryServingOptions!.map((opt) {
                    final isSelected = (_selectedQuantity.unit == QuantityUnit.gram &&
                        (_selectedQuantity.amount.asDouble - opt.gramWeight).abs() < 0.1);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                      child: ActionChip(
                        label: Text(_formatServingOptionChipLabel(opt)),
                        backgroundColor: isSelected
                            ? context.b05Colors.action.withValues(alpha: 0.15)
                            : context.b05Colors.surfaceSubtle,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? context.b05Colors.action
                              : context.b05Colors.textPrimary,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? context.b05Colors.action
                              : context.b05Colors.border,
                        ),
                        onPressed: () => _applyServingOption(opt),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            LayoutBuilder(
              builder: (context, constraints) {
                final stackUnit =
                    _compatibleUnits.length > 1 &&
                    (constraints.maxWidth < 340 || textScale > 1.3);
                final controls = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    decreaseButton(),
                    Expanded(child: amountInput()),
                    increaseButton(),
                  ],
                );
                if (stackUnit) {
                  return Column(
                    children: [
                      controls,
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: unitPicker()),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    decreaseButton(),
                    Expanded(child: amountInput()),
                    if (_compatibleUnits.length > 1) ...[
                      const SizedBox(width: 8),
                      SizedBox(width: 104, child: unitPicker()),
                    ],
                    increaseButton(),
                  ],
                );
              },
            ),
            Divider(color: context.b05Colors.border, height: 24),

            if (widget.transformations.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: _selectedTransformationId,
                decoration: const InputDecoration(
                  labelText: 'Logged as (optional)',
                  helperText: 'Choose raw or cooked only when it applies.',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No conversion'),
                  ),
                  ...widget.transformations.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(_transformationLabel(item)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTransformationId = value;
                    _updatePreview();
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            Builder(
              builder: (context) {
                final preview = _currentPreview;
                if (preview == null) {
                  if (_previewHasError) {
                    return Text(
                      'Nutrition preview unavailable. Try again.',
                      style: TextStyle(
                        color: context.b05Colors.warning.foreground,
                      ),
                    );
                  }
                  return Text(
                    'Enter an amount to preview nutrition.',
                    style: TextStyle(color: context.b05Colors.textSecondary),
                  );
                }
                final facts = preview.facts;
                String value(String id, String unit) {
                  final fact = facts[id];
                  if (fact == null || !fact.isAvailable) return '—';
                  final decimals = id == 'energy' ? 0 : 1;
                  if (fact.point != null) {
                    return '${fact.point!.value.format(decimalPlaces: decimals)}$unit';
                  }
                  if (fact.lower != null && fact.upper != null) {
                    return '${fact.lower!.value.format(decimalPlaces: decimals)}–${fact.upper!.value.format(decimalPlaces: decimals)}$unit';
                  }
                  return '—';
                }

                final metrics = [
                  (
                    'Calories',
                    value('energy', ' kcal'),
                    context.b05Colors.action,
                  ),
                  (
                    'Protein',
                    value('protein', 'g'),
                    context.b05Colors.meal(B05MealAccent.breakfast).indicator,
                  ),
                  (
                    'Carbs',
                    value('carbohydrate', 'g'),
                    context.b05Colors.meal(B05MealAccent.lunch).indicator,
                  ),
                  (
                    'Fat',
                    value('fat', 'g'),
                    context.b05Colors.meal(B05MealAccent.dinner).indicator,
                  ),
                ];
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth < 340 || textScale > 1.3 ? 2 : 4;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 8) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        for (final metric in metrics)
                          SizedBox(
                            width: width,
                            child: _buildMacroPreview(
                              metric.$1,
                              metric.$2,
                              metric.$3,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Action buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final stackActions =
                    constraints.maxWidth < 340 || textScale > 1.3;
                final actionWidth = stackActions
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: actionWidth,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.b05Colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: context.b05Colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: actionWidth,
                      child: ElevatedButton(
                        key: const ValueKey('food_log_dialog_save_button'),
                        onPressed: _isFinalizing ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.b05Colors.action,
                          foregroundColor: context.b05Colors.onAction,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isFinalizing
                              ? 'Saving…'
                              : _isCorrection
                              ? 'Update food in ${_mealTitle(_selectedMealType)}'
                              : 'Add to ${_mealTitle(_selectedMealType)}',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
