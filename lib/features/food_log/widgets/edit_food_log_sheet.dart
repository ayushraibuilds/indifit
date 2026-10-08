import 'package:flutter/material.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../data/database/app_database.dart';

class EditFoodLogSheet extends StatefulWidget {
  final FoodLog log;
  final Function({
    required int id,
    required String name,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double servingLogged,
  })
  onSave;

  const EditFoodLogSheet({super.key, required this.log, required this.onSave});

  @override
  State<EditFoodLogSheet> createState() => _EditFoodLogSheetState();
}

class _EditFoodLogSheetState extends State<EditFoodLogSheet> {
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _servingController;

  String? _nameError;
  String? _caloriesError;
  String? _servingError;
  String? _proteinError;
  String? _carbsError;
  String? _fatError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.log.name);
    _caloriesController = TextEditingController(
      text: widget.log.calories.toString(),
    );
    _proteinController = TextEditingController(
      text: widget.log.proteinG.toStringAsFixed(1),
    );
    _carbsController = TextEditingController(
      text: widget.log.carbsG.toStringAsFixed(1),
    );
    _fatController = TextEditingController(
      text: widget.log.fatG.toStringAsFixed(1),
    );
    _servingController = TextEditingController(
      text: widget.log.servingLogged.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final calsText = _caloriesController.text.trim().replaceAll(',', '.');
    final cals = int.tryParse(calsText);
    final servingText = _servingController.text.trim().replaceAll(',', '.');
    final s = double.tryParse(servingText);
    final pText = _proteinController.text.trim().replaceAll(',', '.');
    final p = double.tryParse(pText);
    final cText = _carbsController.text.trim().replaceAll(',', '.');
    final c = double.tryParse(cText);
    final fText = _fatController.text.trim().replaceAll(',', '.');
    final f = double.tryParse(fText);

    String? nameErr;
    String? calsErr;
    String? servingErr;
    String? pErr;
    String? cErr;
    String? fErr;

    if (name.isEmpty) {
      nameErr = 'Food name is required';
    }
    if (cals == null || cals < 0) {
      calsErr = 'Valid calories required (≥ 0)';
    }
    if (s == null || s <= 0) {
      servingErr = 'Positive serving required';
    }
    if (p == null || p < 0) {
      pErr = '≥ 0 required';
    }
    if (c == null || c < 0) {
      cErr = '≥ 0 required';
    }
    if (f == null || f < 0) {
      fErr = '≥ 0 required';
    }

    if (nameErr != null ||
        calsErr != null ||
        servingErr != null ||
        pErr != null ||
        cErr != null ||
        fErr != null) {
      setState(() {
        _nameError = nameErr;
        _caloriesError = calsErr;
        _servingError = servingErr;
        _proteinError = pErr;
        _carbsError = cErr;
        _fatError = fErr;
      });
      return;
    }

    widget.onSave(
      id: widget.log.id,
      name: name,
      calories: cals!,
      proteinG: p!,
      carbsG: c!,
      fatG: f!,
      servingLogged: s!,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .86,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: TapRegion(
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Logged Meal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'Food Name',
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _caloriesController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            if (_caloriesError != null) {
                              setState(() => _caloriesError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Calories (kcal)',
                            errorText: _caloriesError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _servingController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) {
                            if (_servingError != null) {
                              setState(() => _servingError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Servings (${widget.log.servingUnit})',
                            errorText: _servingError,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _proteinController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) {
                            if (_proteinError != null) {
                              setState(() => _proteinError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Protein (g)',
                            errorText: _proteinError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _carbsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) {
                            if (_carbsError != null) {
                              setState(() => _carbsError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Carbs (g)',
                            errorText: _carbsError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _fatController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) {
                            if (_fatError != null) {
                              setState(() => _fatError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Fat (g)',
                            errorText: _fatError,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.b05Colors.actionFill,
                      foregroundColor: context.b05Colors.onAction,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
