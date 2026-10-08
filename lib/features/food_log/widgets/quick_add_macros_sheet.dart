import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/nutrients.dart';
import '../../../core/nutrition_consumption_snapshots.dart';
import '../../../core/nutrition_household_measures.dart';
import '../../../core/services/local_schedule_date_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/typed_quantities.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import '../../dashboard/today_surface_controller.dart';
import '../food_log_surface.dart';
import '../meal_presentation_registry.dart';

/// The 10-Second Quick-Add Macros Sheet.
///
/// Permits logging quick calorie & macro estimates in under 10 seconds.
///
/// Truth Contract:
/// - Unentered macronutrients are persisted as `missing` (`—`), NEVER as `0.0`.
/// - Logs under `sourceType: 'quick_add'`.
/// - TDEE down-weighting is automatically triggered in [AdaptiveTdeeRepository]
///   when >40% of daily calories come from unverified quick-adds.
class QuickAddMacrosSheet extends ConsumerStatefulWidget {
  final String initialMealType;
  final DateTime targetDate;

  const QuickAddMacrosSheet({
    super.key,
    required this.initialMealType,
    required this.targetDate,
  });

  static Future<NutritionConsumptionSnapshot?> show(
    BuildContext context, {
    String initialMealType = 'lunch',
    DateTime? targetDate,
  }) {
    return showModalBottomSheet<NutritionConsumptionSnapshot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => QuickAddMacrosSheet(
        initialMealType: initialMealType,
        targetDate: targetDate ?? DateTime.now(),
      ),
    );
  }

  @override
  ConsumerState<QuickAddMacrosSheet> createState() =>
      _QuickAddMacrosSheetState();
}

class _QuickAddMacrosSheetState extends ConsumerState<QuickAddMacrosSheet> {
  late String _mealCategory;
  late DateTime _selectedDate;

  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _fiberController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _calorieError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealCategory = widget.initialMealType;
    _selectedDate = widget.targetDate;
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawCalories = _caloriesController.text.trim();
    final calories = double.tryParse(rawCalories);

    if (calories == null || calories <= 0) {
      setState(() {
        _calorieError = 'Calories are required (greater than 0).';
      });
      return;
    }

    setState(() {
      _calorieError = null;
      _saving = true;
    });

    try {
      final registry = await ref.read(nutritionRegistryProvider.future);
      final dates = LocalScheduleDateService();
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();

      final localDate = dates.localDateFor(_selectedDate, timezoneId);
      final todayDate = dates.localDateFor(DateTime.now(), timezoneId);
      final isToday = localDate == todayDate;
      final loggedAtUtc = isToday
          ? DateTime.now().toUtc()
          : dates.instantForLocalDate(localDate, timezoneId);

      // Parse optional macros: null means unentered, NOT zero.
      final protein = double.tryParse(_proteinController.text.trim());
      final carbs = double.tryParse(_carbsController.text.trim());
      final fat = double.tryParse(_fatController.text.trim());
      final fiber = double.tryParse(_fiberController.text.trim());
      final description = _descriptionController.text.trim();

      NutrientFact knownFact(
        String nutrientId,
        double amount,
        NutrientUnit unit,
      ) {
        return NutrientFact.known(
          nutrientId: nutrientId,
          point: NutrientAmount(
            value: QuantityAmount.fromString(amount.toStringAsFixed(1)),
            unit: unit,
          ),
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: NutrientSourceType.userEntered,
          sourceReference: 'quick_add',
          factVersion: '1',
        );
      }

      NutrientFact missingFact(String nutrientId, NutrientUnit unit) {
        return NutrientFact.missing(
          nutrientId: nutrientId,
          unit: unit,
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: NutrientSourceType.userEntered,
          sourceReference: 'quick_add',
          factVersion: '1',
        );
      }

      final facts = <String, NutrientFact>{};

      // 1. Energy (Required & Known)
      facts['energy'] = knownFact('energy', calories, NutrientUnit.kilocalorie);

      // 2. Macronutrients: Known if entered, Missing ('—') if omitted.
      facts['protein'] = protein != null && protein >= 0
          ? knownFact('protein', protein, NutrientUnit.gram)
          : missingFact('protein', NutrientUnit.gram);

      facts['carbohydrate'] = carbs != null && carbs >= 0
          ? knownFact('carbohydrate', carbs, NutrientUnit.gram)
          : missingFact('carbohydrate', NutrientUnit.gram);

      facts['fat'] = fat != null && fat >= 0
          ? knownFact('fat', fat, NutrientUnit.gram)
          : missingFact('fat', NutrientUnit.gram);

      facts['fibre'] = fiber != null && fiber >= 0
          ? knownFact('fibre', fiber, NutrientUnit.gram)
          : missingFact('fibre', NutrientUnit.gram);

      // Fill remaining registry definitions as missing facts
      for (final def in registry.definitions) {
        if (!facts.containsKey(def.id)) {
          facts[def.id] = missingFact(def.id, def.unit);
        }
      }

      final fingerprint = sha256
          .convert(
            utf8.encode(
              'quick_add::$calories::$protein::$carbs::$fat::$fiber::${DateTime.now().microsecondsSinceEpoch}',
            ),
          )
          .toString();

      final calculationSnapshot =
          NutritionConsumptionCalculationSnapshot.fromFacts(
            facts: facts,
            registry: registry,
            requestedNutrientIds: const [
              'energy',
              'protein',
              'carbohydrate',
              'fat',
              'fibre',
            ],
            calculatorVersion: 'quick_add_v1',
            calculationFingerprint: fingerprint,
            lineage: {
              'quick_add': true,
              if (description.isNotEmpty) 'note': description,
            },
          );

      final consumptionId = 'quick-add-consumption::${const Uuid().v4()}';
      final commandId = 'quick-add-command::${const Uuid().v4()}';
      final itemLabel = description.isNotEmpty
          ? description
          : 'Quick Add (${calories.round()} kcal)';
      final foodId = 'food::quick_add::$consumptionId';

      final db = ref.read(databaseProvider);
      await db
          .into(db.nutritionFoods)
          .insert(
            NutritionFoodsCompanion.insert(
              id: foodId,
              kind: 'userCreated',
              displayName: itemLabel,
              locale: 'en-IN',
              sourceType: 'user',
              lifecycle: 'active',
            ),
            mode: InsertMode.insertOrReplace,
          );

      final item = NutritionConsumptionItemInput(
        id: '$consumptionId::item::0',
        position: 0,
        sourceType: 'quick_add',
        foodId: foodId,
        displayLabel: itemLabel,
        quantity: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
        calculation: calculationSnapshot,
        evidence: {
          'quick_add': true,
          'calories': calories,
          if (description.isNotEmpty) 'description': description,
        },
      );

      final consumptionRepo = await ref.read(
        nutritionConsumptionRepositoryProvider.future,
      );

      final snapshot = await consumptionRepo.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: kLocalNutritionUserScopeId,
          consumptionId: consumptionId,
          commandId: commandId,
          loggedAtUtc: loggedAtUtc,
          localDate: localDate,
          timezoneId: timezoneId,
          mealCategory: _mealCategory,
          sourceType: 'quick_add',
          calculatorVersion: 'quick_add_v1',
          items: [item],
          evidence: {'quick_add': true},
        ),
      );

      // Invalidate nutrition state
      ref.invalidate(todayNutritionRevisionProvider);
      ref.invalidate(foodDiaryReadModelProvider(_selectedDate));

      if (!mounted) return;
      Navigator.of(context).pop(snapshot);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _calorieError = 'Failed to save quick add: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final meals = ['breakfast', 'lunch', 'dinner', 'snack'];

    return Container(
      decoration: BoxDecoration(
        color: context.b05Colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick-Add Macros', style: B05Typography.title(context)),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Meal Slot & Date Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mealCategory,
                    decoration: InputDecoration(
                      labelText: 'Meal',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: meals.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          foodMealPresentationFor(m).label,
                          style: B05Typography.body(context),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _mealCategory = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        DateFormat('MMM d').format(_selectedDate),
                        style: B05Typography.body(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calories (Required)
            TextField(
              controller: _caloriesController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Calories * (Required)',
                hintText: 'e.g. 520',
                suffixText: 'kcal',
                errorText: _calorieError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Macros Header
            Text(
              'Optional Macros (leave blank for —)',
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: 8),

            // Protein & Carbs Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Protein',
                      hintText: '—',
                      suffixText: 'g',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Carbs',
                      hintText: '—',
                      suffixText: 'g',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Fat & Fiber Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Fat',
                      hintText: '—',
                      suffixText: 'g',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _fiberController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Fiber',
                      hintText: '—',
                      suffixText: 'g',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description / Note
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g. Client Lunch / Street Snack',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.b05Colors.actionFill,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Log calories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
