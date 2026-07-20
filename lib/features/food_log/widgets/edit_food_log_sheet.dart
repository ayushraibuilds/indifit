import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
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
  }) onSave;

  const EditFoodLogSheet({
    super.key,
    required this.log,
    required this.onSave,
  });

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.log.name);
    _caloriesController = TextEditingController(text: widget.log.calories.toString());
    _proteinController = TextEditingController(text: widget.log.proteinG.toStringAsFixed(1));
    _carbsController = TextEditingController(text: widget.log.carbsG.toStringAsFixed(1));
    _fatController = TextEditingController(text: widget.log.fatG.toStringAsFixed(1));
    _servingController = TextEditingController(text: widget.log.servingLogged.toStringAsFixed(1));
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
    final cals = int.tryParse(_caloriesController.text) ?? widget.log.calories;
    final p = double.tryParse(_proteinController.text) ?? widget.log.proteinG;
    final c = double.tryParse(_carbsController.text) ?? widget.log.carbsG;
    final f = double.tryParse(_fatController.text) ?? widget.log.fatG;
    final s = double.tryParse(_servingController.text) ?? widget.log.servingLogged;

    if (name.isEmpty) return;

    widget.onSave(
      id: widget.log.id,
      name: name,
      calories: cals,
      proteinG: p,
      carbsG: c,
      fatG: f,
      servingLogged: s,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Edit Logged Meal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Food Name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _servingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Servings (${widget.log.servingUnit})'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _proteinController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _carbsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fatController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
