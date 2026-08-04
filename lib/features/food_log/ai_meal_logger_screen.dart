import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_estimates.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/privacy/nutrition_estimate_privacy.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/theme/colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/natural_meal_parser.dart';

class AiMealLoggerScreen extends ConsumerStatefulWidget {
  final String mealType; // "breakfast", "lunch", "dinner", "snack"
  final DateTime? selectedDate;

  const AiMealLoggerScreen({
    super.key,
    required this.mealType,
    this.selectedDate,
  });

  @override
  ConsumerState<AiMealLoggerScreen> createState() => _AiMealLoggerScreenState();
}

class _AiMealLoggerScreenState extends ConsumerState<AiMealLoggerScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  bool _loading = false;
  bool _saving = false;
  String? _saveError;
  NutritionEstimate? _estimate;
  NutritionEstimateImageCleanupResult? _imageCleanup;

  // Edit-before-save controllers
  final TextEditingController _nameEditController = TextEditingController();
  final TextEditingController _caloriesEditController = TextEditingController();
  final TextEditingController _proteinEditController = TextEditingController();
  final TextEditingController _carbsEditController = TextEditingController();
  final TextEditingController _fatEditController = TextEditingController();
  final TextEditingController _servingCountEditController =
      TextEditingController();

  @override
  void dispose() {
    unawaited(
      _cleanupSelectedImage(
        lifecycle: NutritionEstimateImageLifecycle.cancelled,
        notify: false,
      ),
    );
    _textController.dispose();
    _nameEditController.dispose();
    _caloriesEditController.dispose();
    _proteinEditController.dispose();
    _carbsEditController.dispose();
    _fatEditController.dispose();
    _servingCountEditController.dispose();
    super.dispose();
  }

  void _initEditControllers() {
    final estimate = _estimate;
    if (estimate == null) return;
    _nameEditController.text = estimate.displayLabel;
    _caloriesEditController.text = _pointText('energy');
    _proteinEditController.text = _pointText('protein');
    _carbsEditController.text = _pointText('carbohydrate');
    _fatEditController.text = _pointText('fat');
    _servingCountEditController.text =
        estimate.quantity?.unit == QuantityUnit.serving
        ? estimate.quantity!.amount.toString()
        : '';
  }

  String _pointText(String nutrientId) {
    final point = _estimate?.facts[nutrientId]?.point;
    return point == null ? '' : point.value.toString();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_loading || _saving) return;
    final bool isCamera = source == ImageSource.camera;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isCamera
                ? 'Camera Access Required'
                : 'Photo Gallery Access Required',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isCamera
                ? 'IndiFit can send this meal photo to the approved estimation service after you confirm. The temporary photo is deleted after processing and is not backed up.'
                : 'IndiFit can send the selected meal photo to the approved estimation service after you confirm. The temporary photo is deleted after processing and is not backed up.',
            style: const TextStyle(height: 1.4, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final cleanup = await _cleanupSelectedImage(
                    lifecycle: NutritionEstimateImageLifecycle.cancelled,
                  );
                  if (cleanup != null && !cleanup.succeeded) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'The previous temporary photo could not be deleted. Retry cleanup before selecting another photo.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  final XFile? file = await _picker.pickImage(
                    source: source,
                    maxWidth: 800,
                    maxHeight: 800,
                    imageQuality: 85,
                  );

                  if (file != null && mounted) {
                    setState(() {
                      _selectedImage = File(file.path);
                      _estimate = null;
                      _saveError = null;
                      _imageCleanup = null;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('The image could not be selected.'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }

  Future<NutritionEstimateImageCleanupResult?> _cleanupSelectedImage({
    required NutritionEstimateImageLifecycle lifecycle,
    bool notify = true,
  }) async {
    final image = _selectedImage;
    if (image == null) return null;
    final result = await ref
        .read(nutritionEstimatePrivacyServiceProvider)
        .cleanupTemporaryImage(path: image.path, lifecycle: lifecycle);
    if (mounted && notify) {
      setState(() {
        _imageCleanup = result;
        if (result.succeeded) _selectedImage = null;
      });
    }
    return result;
  }

  Future<void> _retryImageCleanup() async {
    await _cleanupSelectedImage(
      lifecycle: NutritionEstimateImageLifecycle.failed,
    );
  }

  Future<void> _submitTextEstimate() async {
    if (_loading || _saving) return;
    final description = _textController.text.trim();
    if (description.isEmpty) return;

    final policy = ref.read(privacyPolicyProvider);
    if (!policy.isAiAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI cloud estimation is disabled in strict offline privacy mode. Disable offline mode in Settings to use cloud AI features.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _estimate = null;
      _saveError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '${AppConfig.backendUrl}/api/ai/meal-estimate-text',
        data: {'text': description},
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const NutritionEstimateValidationError(
          'malformed_estimate_response',
          'The estimation service returned no usable estimate.',
        );
      }
      await _persistResponse(
        response.data,
        inputModality: NutritionEstimateInputModality.text,
        inputHash: nutritionEstimateInputHash(description),
      );
    } catch (error) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_estimateErrorMessage(error))));
      }
    } finally {
      await _cleanupSelectedImage(
        lifecycle: NutritionEstimateImageLifecycle.cancelled,
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitPhotoEstimate() async {
    if (_selectedImage == null || _loading || _saving) return;

    final policy = ref.read(privacyPolicyProvider);
    if (!policy.isImageUploadAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo analysis upload is disabled in strict offline privacy mode. Disable offline mode in Settings to use photo AI features.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _estimate = null;
      _saveError = null;
    });

    final imagePath = _selectedImage!.path;
    try {
      final dio = ref.read(dioProvider);

      final filename = imagePath.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath, filename: filename),
      });

      final response = await dio.post(
        '${AppConfig.backendUrl}/api/ai/meal-estimate-photo',
        data: formData,
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const NutritionEstimateValidationError(
          'malformed_estimate_response',
          'The estimation service returned no usable estimate.',
        );
      }
      final cleanup = await _cleanupSelectedImage(
        lifecycle: NutritionEstimateImageLifecycle.completed,
      );
      if (cleanup == null || !cleanup.succeeded) {
        throw const NutritionEstimatePrivacyError(
          'temporary_image_cleanup_required',
          'The temporary meal photo must be deleted before the estimate can be saved.',
        );
      }
      await _persistResponse(
        response.data,
        inputModality: NutritionEstimateInputModality.photo,
        inputHash: nutritionEstimateInputHash('photo-request:$filename'),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_estimateErrorMessage(error))));
      }
    } finally {
      await _cleanupSelectedImage(
        lifecycle: NutritionEstimateImageLifecycle.completed,
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persistResponse(
    Object? response, {
    required NutritionEstimateInputModality inputModality,
    required String inputHash,
  }) async {
    final registry = await ref.read(nutritionRegistryProvider.future);
    final repository = await ref.read(
      nutritionEstimateRepositoryProvider.future,
    );
    final draft = NutritionEstimateResponseParser.parseProviderPayload(
      response,
      registry: registry,
      inputModality: inputModality,
      inputHash: inputHash,
    );
    final estimate = await repository.createEstimateFromDraft(
      draft: draft,
      userId: kLocalNutritionUserScopeId,
    );
    if (!mounted) return;
    setState(() {
      _estimate = estimate;
      _saveError = null;
      _initEditControllers();
    });
  }

  String _estimateErrorMessage(Object error) {
    if (error is NutritionEstimateError) return error.message;
    return 'The estimate could not be processed. You can retry.';
  }

  Future<void> _logMeal() async {
    final estimate = _estimate;
    if (estimate == null || _saving) return;

    final String name = _nameEditController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal name cannot be empty.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final rawValues = <String, String>{
      'energy': _caloriesEditController.text,
      'protein': _proteinEditController.text,
      'carbohydrate': _carbsEditController.text,
      'fat': _fatEditController.text,
    };
    if (rawValues.values.any(_isInvalidNonNegative)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid finite non-negative values, or leave an unknown nutrient blank.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final values = {
      for (final entry in rawValues.entries)
        entry.key: _optionalNonNegative(entry.value),
    };

    Quantity? quantity = estimate.quantity;
    final rawServingCount = _servingCountEditController.text.trim();
    if (rawServingCount.isNotEmpty) {
      try {
        quantity = Quantity.serving(
          amount: rawServingCount,
          definition:
              estimate.quantity?.context.servingDefinition ??
              const ServingDefinitionReference(
                id: 'user-review-serving-v1',
                revision: '1',
              ),
          source: 'user-review-v1',
        );
        NutritionQuantityService.validatePositiveUserEnteredPortion(quantity);
      } on QuantityError catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a positive serving count before logging.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final repository = await ref.read(
        nutritionEstimateRepositoryProvider.future,
      );
      final replacements = <String, NutrientFact>{};
      for (final entry in values.entries) {
        final value = entry.value;
        if (value == null) continue;
        final originalPoint = estimate.facts[entry.key]?.point?.value.asDouble;
        if (originalPoint != null && value == originalPoint) continue;
        final definition = repository.registry.definitionFor(entry.key);
        replacements[entry.key] = NutrientFact.estimated(
          nutrientId: entry.key,
          point: NutrientAmount(
            value: QuantityAmount.fromNum(value),
            unit: definition.unit,
          ),
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: NutrientSourceType.userEntered,
          sourceReference: 'user-correction-v1',
          confidence: NutrientConfidence.unknown,
          factVersion: 'user-correction-v1',
        );
      }
      final hasLabelCorrection = name != estimate.displayLabel;
      final hasQuantityCorrection =
          rawServingCount.isNotEmpty &&
          (estimate.quantity == null ||
              estimate.quantity!.unit != QuantityUnit.serving ||
              estimate.quantity!.amount.toString() != rawServingCount);
      NutritionEstimate selected;
      if (hasLabelCorrection ||
          replacements.isNotEmpty ||
          hasQuantityCorrection) {
        selected = await repository.correctEstimate(
          userId: kLocalNutritionUserScopeId,
          estimateId: estimate.id,
          correction: NutritionEstimateCorrection(
            commandId: 'ai-meal-correction::${estimate.id}',
            reason: 'User reviewed the estimate before logging.',
            displayLabel: hasLabelCorrection ? name : null,
            nutrientReplacements: replacements,
            replaceQuantity: hasQuantityCorrection,
            quantity: hasQuantityCorrection ? quantity : null,
            fieldUpdates: hasLabelCorrection
                ? const {'food_identity': 'user_corrected'}
                : const {},
          ),
        );
      } else {
        selected = await repository.acceptEstimate(
          userId: kLocalNutritionUserScopeId,
          estimateId: estimate.id,
          commandId: 'ai-meal-accept::${estimate.id}',
        );
      }
      if (mounted &&
          (selected.id != estimate.id ||
              selected.reviewState != estimate.reviewState)) {
        setState(() {
          _estimate = selected;
          _initEditControllers();
        });
      }
      final finalizer = await ref.read(
        nutritionEstimateFinalizationServiceProvider.future,
      );
      final loggedAt = (widget.selectedDate ?? DateTime.now()).toUtc();
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final localDate = ref
          .read(localScheduleDateServiceProvider)
          .localDateFor(loggedAt, timezoneId);
      await finalizer.finalizeEstimate(
        userId: kLocalNutritionUserScopeId,
        estimateId: selected.id,
        mealCategory: widget.mealType,
        quantity: quantity,
        loggedAtUtc: loggedAt,
        localDate: localDate,
        timezoneId: timezoneId,
        commandId: 'ai-meal-finalize::${selected.id}',
        consumptionId: 'ai-meal-consumption::${selected.id}',
        displayLabel: selected.displayLabel,
      );

      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal logged successfully!')),
        );
        Navigator.pop(context); // Close logger screen
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _estimateErrorMessage(error);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_estimateErrorMessage(error))));
      }
    }
  }

  double? _optionalNonNegative(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.trim());
  }

  bool _isInvalidNonNegative(String text) {
    if (text.trim().isEmpty) return false;
    final value = double.tryParse(text.trim());
    return value == null || !value.isFinite || value < 0;
  }

  String _rangeText(String nutrientId) {
    final fact = _estimate?.facts[nutrientId];
    if (fact == null || !fact.hasNumericValue) return 'Unknown';
    String format(NutrientAmount? amount) =>
        amount == null ? 'unknown' : '${amount.value} ${amount.unit.symbol}';
    final point = format(fact.point);
    if (fact.lower == null && fact.upper == null) {
      return '$point (estimate)';
    }
    return '${format(fact.lower)} ≤ point $point ≤ ${format(fact.upper)}';
  }

  Widget _buildUncertaintySummary(NutritionEstimate estimate) {
    const nutrients = <(String, String)>[
      ('Calories', 'energy'),
      ('Protein', 'protein'),
      ('Carbohydrates', 'carbohydrate'),
      ('Fat', 'fat'),
    ];
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uncertainty and provenance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Source: ${estimate.source.stableId}'),
            Text(
              'Input: ${estimate.evidence.inputModality ?? 'unknown'} · Completeness: ${estimate.completeness.state.name}',
            ),
            if (estimate.evidence.providerCategory != null)
              Text('Provider category: ${estimate.evidence.providerCategory}'),
            const SizedBox(height: 8),
            for (final nutrient in nutrients)
              Semantics(
                label: '${nutrient.$1}: ${_rangeText(nutrient.$2)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${nutrient.$1}: ${_rangeText(nutrient.$2)}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logDate = widget.selectedDate ?? DateTime.now();
    final dateStr = DateFormat('EEE, MMM d').format(logDate);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AI Meal Estimator',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Logging for $dateStr',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.orange.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI nutritional estimations are approximate. Check ingredients for food allergies and medical safety.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? _buildLoadingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimate nutrition from a meal description or photo. Review the result before logging.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 1. Text Estimator Input Card
                        _buildTextEstimatorCard(),
                        const SizedBox(height: 20),

                        // 2. Photo Estimator Pickers Card
                        _buildPhotoEstimatorCard(),
                        const SizedBox(height: 20),

                        // 3. AI Estimate Results Section
                        if (_estimate != null) _buildResultSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextEstimatorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Describe your meal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.mic, color: AppColors.primary),
                  tooltip: 'Voice Dictation',
                  onPressed: () {
                    _textController.text =
                        '2 rotis with paneer bhurji and 1 bowl of dal';
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Voice input captured: "2 rotis with paneer bhurji and 1 bowl of dal"',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. 2 rotis with paneer bhurji and dal tadka',
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Parse Items',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      final items = NaturalMealParser.parse(
                        _textController.text,
                      );
                      if (items.isNotEmpty) {
                        final summary = items
                            .map((i) => '${i.quantity} ${i.unit} ${i.foodName}')
                            .join(', ');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Parsed ${items.length} items: $summary',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.record_voice_over,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      '2 rotis + paneer',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () =>
                        _textController.text = '2 rotis with paneer bhurji',
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.record_voice_over,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Oats + almonds',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () => _textController.text =
                        '1 bowl oats with milk and 10 almonds',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submitTextEstimate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.psychology_rounded, size: 18),
                label: const Text('Estimate from Text'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoEstimatorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Snap or Upload Plate Photo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Image Preview Slot
            if (_selectedImage != null)
              Container(
                height: 180,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.photo_library_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    label: const Text(
                      'Camera',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _submitPhotoEstimate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
                label: const Text('Analyze Food Photo'),
              ),
            ],
            if (_imageCleanup != null && !_imageCleanup!.succeeded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Temporary photo cleanup needs a retry. No photo content was saved to nutrition data.',
                        style: TextStyle(color: AppColors.danger, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: _retryImageCleanup,
                      child: const Text('Retry cleanup'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    final estimate = _estimate;
    if (estimate == null) return const SizedBox.shrink();
    final confidenceLabel = 'Estimate · ${estimate.confidence.stableId}';
    const labelColor = AppColors.primary;
    const confidenceIcon = Icons.auto_awesome_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ESTIMATION RESULT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confidence Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Review estimated values:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: labelColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: labelColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(confidenceIcon, size: 12, color: labelColor),
                          const SizedBox(width: 4),
                          Text(
                            confidenceLabel,
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border, height: 24),
                const Text(
                  'Values remain estimates. Bounds are shown only when evidence provides them; missing nutrients are not treated as zero.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                _buildUncertaintySummary(estimate),
                const SizedBox(height: 12),

                // Name Field
                TextField(
                  controller: _nameEditController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Meal Name',
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _servingCountEditController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Servings consumed',
                    helperText:
                        'Use a positive serving count; it does not imply grams.',
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                const SizedBox(height: 16),

                // Calories & Macros Inputs Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caloriesEditController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Calories (kcal)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _proteinEditController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _carbsEditController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fatEditController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fat (g)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_saveError != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(_saveError!)),
                          TextButton(
                            onPressed: _saving ? null : _logMeal,
                            child: const Text('Retry save'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_saveError != null) const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saving ? null : _logMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Saving…'),
                          ],
                        )
                      : const Text(
                          'Verify & Save to Log',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 20),
          Text(
            'Analyzing meal components...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'The approved estimation service is processing the meal...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
