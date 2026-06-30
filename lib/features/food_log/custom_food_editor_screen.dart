import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';

class CustomFoodEditorScreen extends ConsumerStatefulWidget {
  const CustomFoodEditorScreen({super.key});

  @override
  ConsumerState<CustomFoodEditorScreen> createState() => _CustomFoodEditorScreenState();
}

class _CustomFoodEditorScreenState extends ConsumerState<CustomFoodEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameHindiController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingSizeController = TextEditingController(text: '100');
  final _servingUnitController = TextEditingController(text: 'g');
  final _categoryController = TextEditingController(text: 'custom');

  @override
  void dispose() {
    _nameController.dispose();
    _nameHindiController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingSizeController.dispose();
    _servingUnitController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomFood() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(foodRepositoryProvider);

    final calories = int.tryParse(_caloriesController.text) ?? 0;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;
    final servingSize = double.tryParse(_servingSizeController.text) ?? 100.0;

    final companion = FoodItemsCompanion.insert(
      name: _nameController.text.trim(),
      nameHindi: _nameHindiController.text.trim().isNotEmpty
          ? Value(_nameHindiController.text.trim())
          : const Value.absent(),
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      servingSize: servingSize,
      servingUnit: _servingUnitController.text.trim(),
      category: _categoryController.text.trim(),
      isCustom: const Value(true),
    );

    try {
      await repo.insertCustomFood(companion);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${_nameController.text}" saved to custom foods.')),
        );
        Navigator.pop(context, true); // Return true to indicate item was created
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save custom food. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Custom Food'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Food Name (English) *',
                  hintText: 'e.g., Homemade Paneer Bhurji',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameHindiController,
                decoration: const InputDecoration(
                  labelText: 'Food Name (Hindi/Optional)',
                  hintText: 'e.g., पनीर भुर्जी',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servingSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Serving Size *',
                      ),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _servingUnitController,
                      decoration: const InputDecoration(
                        labelText: 'Serving Unit (e.g. g, ml, pc) *',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories (kcal) *',
                ),
                validator: (val) => val == null || int.tryParse(val) == null ? 'Invalid' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Protein (g) *',
                      ),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g) *',
                      ),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Fat (g) *',
                      ),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveCustomFood,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Custom Food', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
