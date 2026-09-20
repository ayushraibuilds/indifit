import 'package:flutter/material.dart';

import '../../../core/catalog/food_catalog_models.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Title-cases a meal-type id for button copy (e.g. `lunch` → `Lunch`).
/// Falls back to `Meal` for blank input instead of rendering an empty label.
String _titleCaseMeal(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Meal';
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
}

/// Modal bottom sheet for reviewing, portioning, and verifying remote food candidates
/// before saving them to local SQLite and logging.
class RemoteFoodReviewSheet extends StatefulWidget {
  const RemoteFoodReviewSheet({
    super.key,
    required this.candidate,
    required this.mealType,
    required this.selectedDate,
    required this.onConfirm,
  });

  final RemoteFoodCandidate candidate;
  final String mealType;
  final DateTime selectedDate;
  final Future<void> Function({
    required RemoteFoodCandidate candidate,
    required double quantity,
    required ServingOption servingOption,
    required bool logImmediately,
  }) onConfirm;

  static Future<void> show({
    required BuildContext context,
    required RemoteFoodCandidate candidate,
    required String mealType,
    required DateTime selectedDate,
    required Future<void> Function({
      required RemoteFoodCandidate candidate,
      required double quantity,
      required ServingOption servingOption,
      required bool logImmediately,
    }) onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RemoteFoodReviewSheet(
        candidate: candidate,
        mealType: mealType,
        selectedDate: selectedDate,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<RemoteFoodReviewSheet> createState() => _RemoteFoodReviewSheetState();
}

class _RemoteFoodReviewSheetState extends State<RemoteFoodReviewSheet> {
  late ServingOption _selectedServing;
  double _quantity = 1.0;
  bool _isSaving = false;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  bool _macrosEdited = false;

  @override
  void initState() {
    super.initState();
    _selectedServing = widget.candidate.defaultServing;
    _caloriesController = TextEditingController(
        text: widget.candidate.caloriesPer100g.toStringAsFixed(0));
    _proteinController = TextEditingController(
        text: widget.candidate.proteinPer100g.toStringAsFixed(1));
    _carbsController = TextEditingController(
        text: widget.candidate.carbsPer100g.toStringAsFixed(1));
    _fatController = TextEditingController(
        text: widget.candidate.fatPer100g.toStringAsFixed(1));
    for (final c in [
      _caloriesController,
      _proteinController,
      _carbsController,
      _fatController
    ]) {
      c.addListener(_onMacroEdited);
    }
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _onMacroEdited() {
    if (!_macrosEdited && mounted) setState(() => _macrosEdited = true);
  }

  /// Candidate with user-corrected per-100g macros (falls back to provider
  /// values when a field is empty/unparseable).
  RemoteFoodCandidate get _effectiveCandidate {
    double parse(String text, double fallback) {
      final v = double.tryParse(text.trim());
      if (v == null || !v.isFinite || v < 0 || v > 900) return fallback;
      return v;
    }

    final base = widget.candidate;
    if (!_macrosEdited) return base;
    return base.copyWith(
      caloriesPer100g: parse(_caloriesController.text, base.caloriesPer100g),
      proteinPer100g: parse(_proteinController.text, base.proteinPer100g),
      carbsPer100g: parse(_carbsController.text, base.carbsPer100g),
      fatPer100g: parse(_fatController.text, base.fatPer100g),
      verificationLevel: FoodVerificationLevel.unverified,
    );
  }

  Map<String, double> get _currentNutrients {
    return _effectiveCandidate.calculateNutrientsFor(
      quantity: _quantity,
      unitName: _selectedServing.unitName,
    );
  }

  Future<void> _handleConfirm({required bool logImmediately}) async {
    if (_isSaving) return;
    final candidate = _effectiveCandidate;
    if (!candidate.isPhysicallyPossible) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('These label values look incorrect. Please use custom entry.'),
          ),
        );
      }
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onConfirm(
        candidate: candidate,
        quantity: _quantity,
        servingOption: _selectedServing,
        logImmediately: logImmediately,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _effectiveCandidate;
    final nutrients = _currentNutrients;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fetched = candidate.provenance.fetchedAtUtc.toLocal();
    final fetchedLabel =
        '${fetched.day}/${fetched.month}/${fetched.year}';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Product Name and Brand
          Text(
            candidate.name,
            style: B05Typography.title(context).copyWith(fontSize: 20),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (candidate.brand != null && candidate.brand!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                candidate.brand!,
                style: B05Typography.caption(context).copyWith(
                  color: context.b05Colors.action,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Provenance & Source Attribution Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: context.b05Colors.action,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Semantics(
                    label:
                        'Source ${candidate.provenance.attributionText}. Verification ${candidate.verificationLevel.displayLabel}.',
                    child: Text(
                      candidate.provenance.attributionText,
                      style: B05Typography.caption(context).copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (candidate.provenance.sourceUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                candidate.provenance.sourceUrl!,
                style: B05Typography.caption(context).copyWith(
                  fontSize: 11,
                  color: context.b05Colors.action,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Verification: ${candidate.verificationLevel.displayLabel} • Fetched $fetchedLabel${_macrosEdited ? ' • Edited by you' : ''}',
              style: B05Typography.caption(context).copyWith(fontSize: 11),
            ),
          ),

          const SizedBox(height: 12),

          // Physically-impossible guard: block logging until corrected via
          // custom entry. A generic discrepancy warning is not enough.
          if (!candidate.isPhysicallyPossible)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(isDark ? 40 : 30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(140)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.block_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nutrients look incorrect',
                            style: B05Typography.label(context).copyWith(
                              color: Colors.red[isDark ? 200 : 800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Protein + carbs + fat${candidate.fiberPer100g != null ? ' + fiber' : ''} exceeds 105 g per 100 g. Please use custom entry with label values.',
                            style: B05Typography.caption(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 4-4-9 Macro Sanity Warning (if discrepant)
          if (!candidate.isMacroBalanced)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(isDark ? 40 : 30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withAlpha(120)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Macro Discrepancy Flag',
                          style: B05Typography.label(context).copyWith(
                            color: Colors.amber[isDark ? 300 : 900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reported ${candidate.caloriesPer100g.toStringAsFixed(0)} kcal differs from calculated ${candidate.expectedCaloriesPer100g.toStringAsFixed(0)} kcal (4P+4C+9F). Check portion carefully.',
                          style: B05Typography.caption(context).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Balanced macros (4-4-9 verified)',
                    style: B05Typography.caption(context).copyWith(
                      color: Colors.green[isDark ? 300 : 700],
                    ),
                  ),
                ],
              ),
            ),

          // Macro Summary Row for Selected Serving
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2228) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroCol('Calories', '${(nutrients['calories'] ?? 0).toStringAsFixed(0)} kcal', context.b05Colors.action),
                _buildMacroCol('Protein', '${(nutrients['protein'] ?? 0).toStringAsFixed(1)} g', Colors.blue),
                _buildMacroCol('Carbs', '${(nutrients['carbs'] ?? 0).toStringAsFixed(1)} g', Colors.orange),
                _buildMacroCol('Fat', '${(nutrients['fat'] ?? 0).toStringAsFixed(1)} g', Colors.purple),
                if (nutrients.containsKey('fiber'))
                  _buildMacroCol('Fiber', '${(nutrients['fiber'] ?? 0).toStringAsFixed(1)} g', Colors.teal),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Correct label values (per 100 g) — spec §6 override flow.
          Text('Correct label values (per 100 g)',
              style: B05Typography.label(context)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            // Fixed extent (not aspect ratio): narrow 320pt screens and large
            // text scales must not squeeze the label+input below its height.
            mainAxisExtent: 72,
            children: [
              _buildMacroField(
                  context, 'Calories (kcal)', _caloriesController, '0'),
              _buildMacroField(
                  context, 'Protein (g)', _proteinController, '0.0'),
              _buildMacroField(
                  context, 'Carbs (g)', _carbsController, '0.0'),
              _buildMacroField(context, 'Fat (g)', _fatController, '0.0'),
            ],
          ),
          if (_macrosEdited)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Edited values are marked unverified and saved with your correction.',
                style: B05Typography.caption(context).copyWith(fontSize: 11),
              ),
            ),

          const SizedBox(height: 16),

          // Portion & Household Measure Selector
          Text('Portion Size', style: B05Typography.label(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              // Quantity stepper
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withAlpha(100)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Decrease portion',
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _quantity > 0.25
                          ? () => setState(() => _quantity = (_quantity - 0.5 > 0 ? _quantity - 0.5 : 0.25))
                          : null,
                    ),
                    Semantics(
                      label: 'Portion quantity $_quantity',
                      liveRegion: true,
                      child: Text(
                        _quantity == _quantity.toInt() ? _quantity.toInt().toString() : _quantity.toStringAsFixed(1),
                        style: B05Typography.label(context),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase portion',
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => setState(() => _quantity += 0.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Serving unit dropdown
              Expanded(
                child: Semantics(
                  label: 'Serving unit',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withAlpha(100)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ServingOption>(
                        value: _selectedServing,
                        isExpanded: true,
                        items: candidate.servingOptions.map((s) {
                          final unit = s.unitName.toLowerCase().trim();
                          final hasWeight =
                              RegExp(r'\d+\s*(g|ml)$', caseSensitive: false)
                                  .hasMatch(unit);
                          final suffix =
                              unit.contains('ml') || unit.contains('glass')
                                  ? 'ml'
                                  : 'g';
                          final label = hasWeight
                              ? s.unitName
                              : '${s.unitName} (${s.gramWeight.toStringAsFixed(0)} $suffix)';
                          return DropdownMenuItem(
                            value: s,
                            child: Text(
                              label,
                              style: B05Typography.body(context),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedServing = val);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Save & Log Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => _handleConfirm(logImmediately: false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save to My Foods'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : () => _handleConfirm(logImmediately: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.b05Colors.action,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Log ${_titleCaseMeal(widget.mealType)}'),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMacroField(BuildContext context, String label,
      TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: B05Typography.body(context),
    );
  }

  Widget _buildMacroCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: B05Typography.label(context).copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: B05Typography.caption(context).copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
