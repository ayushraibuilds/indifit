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
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fibreController = TextEditingController();
  final _servingSizeController = TextEditingController(text: '1');
  final _servingUnitController = TextEditingController(text: 'serving');
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fibreController.dispose();
    _servingSizeController.dispose();
    _servingUnitController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomFood() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final servingSize = double.parse(_servingSizeController.text.trim());
      final catalog = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      await catalog.createUserFood(
        displayName: _nameController.text,
        servingSize: servingSize,
        servingUnit: _servingUnitController.text,
        energyKcal: _optionalDouble(_caloriesController),
        proteinG: _optionalDouble(_proteinController),
        carbohydrateG: _optionalDouble(_carbsController),
        fatG: _optionalDouble(_fatController),
        fibreG: _optionalDouble(_fibreController),
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
    } finally {
      if (mounted) setState(() => _saving = false);
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
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'Basic information'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Food name *',
                      hintText: 'e.g. Homemade paneer bhurji',
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'Serving'),
                  const SizedBox(height: 4),
                  Text(
                    'Describe the amount your nutrition values refer to.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final stack =
                          constraints.maxWidth < 360 || textScale > 1.3;
                      final amount = TextFormField(
                        controller: _servingSizeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Serving amount *',
                          hintText: 'e.g. 1',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          return parsed == null ||
                                  !parsed.isFinite ||
                                  parsed <= 0
                              ? 'Enter a positive amount'
                              : null;
                        },
                      );
                      final unit = TextFormField(
                        controller: _servingUnitController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Serving unit *',
                          hintText: 'e.g. katori, piece, g',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      );
                      if (stack) {
                        return Column(
                          children: [amount, const SizedBox(height: 12), unit],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: amount),
                          const SizedBox(width: 12),
                          Expanded(child: unit),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'Nutrition'),
                  const SizedBox(height: 4),
                  Text(
                    'Add only values you know. Blank values stay unavailable.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _macroField(
                    controller: _caloriesController,
                    label: 'Calories (kcal) (optional)',
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final columns =
                          constraints.maxWidth < 360 || textScale > 1.3 ? 1 : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
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
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'More nutrients (optional)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: const Text('Add fibre when you know it.'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _macroField(
                          controller: _fibreController,
                          label: 'Fibre (g)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveCustomFood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.b05Colors.action,
                        foregroundColor: context.b05Colors.onAction,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _saving ? 'Saving…' : 'Save custom food',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
      final parsed = double.tryParse(value);
      return parsed == null || !parsed.isFinite || parsed < 0
          ? 'Enter a zero or positive number'
          : null;
    },
  );

  Widget _sectionTitle(BuildContext context, String label) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium);
}
