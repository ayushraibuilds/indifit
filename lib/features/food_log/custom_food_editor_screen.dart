import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/b05_semantic_colors.dart';

class CustomFoodEditorScreen extends ConsumerStatefulWidget {
  final String? initialBarcode;
  const CustomFoodEditorScreen({super.key, this.initialBarcode});

  @override
  ConsumerState<CustomFoodEditorScreen> createState() =>
      _CustomFoodEditorScreenState();
}

class _CustomFoodEditorScreenState
    extends ConsumerState<CustomFoodEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameHindiController = TextEditingController();
  final _brandController = TextEditingController();
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
    _brandController.dispose();
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

    try {
      final servingSize = double.parse(_servingSizeController.text.trim());
      final catalog = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      await catalog.createUserFood(
        displayName: _nameController.text,
        servingSize: servingSize,
        servingUnit: _servingUnitController.text,
        energyKcal: double.parse(_caloriesController.text.trim()),
        proteinG: _optionalDouble(_proteinController),
        carbohydrateG: _optionalDouble(_carbsController),
        fatG: _optionalDouble(_fatController),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('"${_nameController.text}" saved to custom foods.'),
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate item was created
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save custom food. Please try again.'),
          ),
        );
      }
    }
  }

  double? _optionalDouble(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : double.parse(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Custom Food')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: TapRegion(
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save a food you make or buy often.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Food name *',
                      hintText: 'e.g. Homemade paneer bhurji',
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameHindiController,
                    decoration: const InputDecoration(
                      labelText: 'Local name (optional)',
                      hintText: 'e.g. पनीर भुर्जी',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand (optional)',
                      hintText: 'e.g. Amul or homemade',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _servingSizeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Serving Size *',
                            hintText: 'e.g. 100',
                          ),
                          validator: (val) {
                            final parsed = double.tryParse(val ?? '');
                            return parsed == null || parsed <= 0
                                ? 'Enter a positive size'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _servingUnitController,
                          decoration: const InputDecoration(
                            labelText: 'Serving Unit (e.g. g, ml, pc) *',
                            hintText: 'g, ml, piece',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Required'
                              : null,
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
                      hintText: 'Per serving',
                    ),
                    validator: (val) {
                      final parsed = double.tryParse(val ?? '');
                      return parsed == null || parsed < 0
                          ? 'Enter calories'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Macros (optional)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leave a value blank when it is not known.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _macroField(
                              controller: _proteinController,
                              label: 'Protein (g)',
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _macroField(
                              controller: _carbsController,
                              label: 'Carbs (g)',
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _macroField(
                              controller: _fatController,
                              label: 'Fat (g)',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveCustomFood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.b05Colors.action,
                      foregroundColor: context.b05Colors.onAction,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Custom Food',
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

  Widget _macroField({
    required TextEditingController controller,
    required String label,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return null;
      return double.tryParse(value) == null ? 'Enter a number' : null;
    },
  );
}
