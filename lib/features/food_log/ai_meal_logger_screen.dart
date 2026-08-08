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
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/privacy/nutrition_estimate_privacy.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/responsive_form_primitives.dart';
import 'food_log_surface.dart';

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
  String? _estimateError;
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
          backgroundColor: dialogContext.b05Colors.section,
          title: Text(
            isCamera
                ? 'Camera Access Required'
                : 'Photo Gallery Access Required',
            style: B05Typography.title(dialogContext),
          ),
          content: Text(
            isCamera
                ? 'IndiFit can send this meal photo to the approved estimation service after you confirm. The temporary photo is deleted after processing and is not backed up.'
                : 'IndiFit can send the selected meal photo to the approved estimation service after you confirm. The temporary photo is deleted after processing and is not backed up.',
            style: B05Typography.body(dialogContext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
      _estimateError = null;
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
      if (mounted) {
        final message = _estimateErrorMessage(error);
        setState(() {
          _loading = false;
          _estimateError = message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
      _estimateError = null;
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
        final message = _estimateErrorMessage(error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        setState(() => _estimateError = message);
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
      _estimateError = null;
      _saveError = null;
      _initEditControllers();
    });
  }

  String _estimateErrorMessage(Object error) {
    final code = switch (error) {
      NutritionEstimateValidationError(:final code) => code,
      NutritionEstimateConflictError(:final code) => code,
      NutritionEstimatePersistenceError(:final code) => code,
      _ => 'estimate_operation_failed',
    };
    return ProductFailurePresentation.fromCode(
      code,
      title: 'Estimate unavailable',
    ).message;
  }

  Future<void> _logMeal() async {
    final estimate = _estimate;
    if (estimate == null || _saving) return;

    final String name = _nameEditController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meal name cannot be empty.'),
          backgroundColor: context.b05Colors.danger.indicator,
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
        SnackBar(
          content: Text(
            'Enter valid finite non-negative values, or leave an unknown nutrient blank.',
          ),
          backgroundColor: context.b05Colors.danger.indicator,
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
      } on QuantityError {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'That amount could not be used. Check it and try again.',
            ),
            backgroundColor: context.b05Colors.danger.indicator,
          ),
        );
        return;
      }
    }
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a positive serving count before logging.'),
          backgroundColor: context.b05Colors.danger.indicator,
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
    return B05Surface(
      subtle: true,
      showBorder: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this estimate',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('Based on the meal information you provided.'),
          Text(_completenessLabel(estimate.completeness.state.name)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final logDate = widget.selectedDate ?? DateTime.now();
    final dateStr = ConsumerDateLabel.dateTime(logDate);
    final explicitDate = DateFormat('EEE, MMM d').format(logDate.toLocal());

    return ConsumerTaskScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log ${_mealLabel(widget.mealType)}',
              style: B05Typography.title(context),
            ),
            Text(dateStr, style: B05Typography.caption(context)),
            if (dateStr != explicitDate)
              Text(
                'Logging for $explicitDate',
                style: B05Typography.caption(context),
              ),
          ],
        ),
      ),
      body: _loading
          ? _buildLoadingState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                B05StatusMessage(
                  status: B05SemanticStatus.warning,
                  label: 'Estimates are approximate',
                  value: 'Check ingredients for allergies and medical safety.',
                ),
                if (_estimateError != null) ...[
                  const SizedBox(height: 12),
                  ConsumerStatusRow(
                    label: 'Estimate unavailable',
                    detail: _estimateError,
                    error: true,
                    onRetry: _retryEstimate,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  _estimate == null
                      ? 'Describe what you ate, then review the estimate before saving.'
                      : 'Review the estimate and adjust anything that looks different from your meal.',
                  style: B05Typography.body(context),
                ),
                const SizedBox(height: 16),
                if (_estimate == null) ...[
                  _buildTextEstimatorCard(),
                  const SizedBox(height: 16),
                  _buildPhotoEstimatorCard(),
                ] else
                  _buildResultSection(),
                const SizedBox(height: 12),
                _LoggedMealsSection(date: logDate),
              ],
            ),
      primaryAction: _buildPrimaryAction(),
    );
  }

  Widget _buildTextEstimatorCard() {
    return B05Surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Describe your meal', style: B05Typography.title(context)),
          const SizedBox(height: 4),
          TextField(
            controller: _textController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'e.g. 2 rotis with paneer bhurji and dal tadka',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: Icon(
                  Icons.restaurant_outlined,
                  size: 14,
                  color: context.b05Colors.action,
                ),
                label: Text(
                  '2 rotis + paneer',
                  style: B05Typography.caption(context),
                ),
                onPressed: () => setState(
                  () => _textController.text = '2 rotis with paneer bhurji',
                ),
              ),
              ActionChip(
                avatar: Icon(
                  Icons.restaurant_outlined,
                  size: 14,
                  color: context.b05Colors.action,
                ),
                label: Text(
                  'Oats + almonds',
                  style: B05Typography.caption(context),
                ),
                onPressed: () => setState(
                  () => _textController.text =
                      '1 bowl oats with milk and 10 almonds',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoEstimatorCard() {
    return B05Surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Use a photo (optional)', style: B05Typography.title(context)),
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

          IndiFitResponsiveFieldGroup(
            children: [
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: Icon(
                  Icons.photo_library_rounded,
                  size: 18,
                  color: context.b05Colors.action,
                ),
                label: const Text('Gallery'),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: context.b05Colors.action,
                ),
                label: const Text('Camera'),
              ),
            ],
          ),
          if (_selectedImage != null) ...[
            const SizedBox(height: 12),
            B05ActionButton(
              onPressed: _saving ? null : _submitPhotoEstimate,
              icon: Icons.photo_camera_outlined,
              label: 'Estimate this photo',
              emphasis: B05ActionEmphasis.secondary,
            ),
          ],
          if (_imageCleanup != null && !_imageCleanup!.succeeded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temporary photo cleanup needs a retry. No photo content was saved to nutrition data.',
                    style: B05Typography.caption(
                      context,
                    ).copyWith(color: context.b05Colors.danger.foreground),
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
    );
  }

  Widget _buildResultSection() {
    final estimate = _estimate;
    if (estimate == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        B05Surface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review your meal', style: B05Typography.title(context)),
              const SizedBox(height: 4),
              Text(
                'These numbers are approximate. Missing information stays blank rather than becoming zero.',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: 16),
              _buildUncertaintySummary(estimate),
              const SizedBox(height: 16),
              TextField(
                controller: _nameEditController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Meal name',
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
              IndiFitResponsiveFieldGroup(
                children: [
                  TextField(
                    controller: _caloriesEditController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calories (kcal)',
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                  TextField(
                    controller: _proteinEditController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IndiFitResponsiveFieldGroup(
                children: [
                  TextField(
                    controller: _carbsEditController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Carbs (g)',
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                  TextField(
                    controller: _fatEditController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fat (g)',
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ],
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 16),
                ConsumerStatusRow(
                  label: 'Meal could not be saved',
                  detail: _saveError,
                  error: true,
                  onRetry: _saving ? null : _logMeal,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const ConsumerStatusRow(
      label: 'Estimating nutrition',
      detail: 'This usually takes a few seconds.',
      loading: true,
    );
  }

  Widget _buildPrimaryAction() {
    if (_estimate != null) {
      return B05ActionButton(
        label: _saving ? 'Saving meal…' : 'Save meal',
        icon: Icons.check_rounded,
        onPressed: _saving ? null : _logMeal,
      );
    }
    final hasDescription = _textController.text.trim().isNotEmpty;
    return B05ActionButton(
      label: 'Estimate nutrition',
      icon: Icons.auto_awesome_rounded,
      onPressed: _saving || _loading || !hasDescription
          ? null
          : _submitTextEstimate,
    );
  }

  Future<void> _retryEstimate() {
    if (_selectedImage != null) return _submitPhotoEstimate();
    return _submitTextEstimate();
  }

  static String _mealLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'breakfast' => 'breakfast',
      'lunch' => 'lunch',
      'dinner' => 'dinner',
      'snack' => 'snack',
      _ => 'meal',
    };
  }
}

class _LoggedMealsSection extends ConsumerStatefulWidget {
  const _LoggedMealsSection({required this.date});

  final DateTime date;

  @override
  ConsumerState<_LoggedMealsSection> createState() =>
      _LoggedMealsSectionState();
}

class _LoggedMealsSectionState extends ConsumerState<_LoggedMealsSection> {
  var _expanded = false;
  var _autoExpanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final logs = ref.watch(foodLogsForDayProvider(widget.date));
    if (!_expanded &&
        !_autoExpanded &&
        logs.hasValue &&
        logs.value!.isNotEmpty) {
      _autoExpanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _expanded = true);
      });
    }
    return B05Surface(
      padding: EdgeInsets.zero,
      radius: B05SurfaceRadius.small,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            label: 'Logged meals',
            value: _expanded ? 'Expanded' : 'Collapsed',
            hint: _expanded
                ? 'Hide meals logged for this day.'
                : 'Show meals logged for this day.',
            onTap: _toggle,
            child: ExcludeSemantics(
              child: ListTile(
                title: const Text('Logged meals'),
                subtitle: const Text('Review or edit meals for this day.'),
                trailing: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: colors.action,
                ),
                onTap: _toggle,
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space12,
                0,
                B05Layout.space12,
                B05Layout.space12,
              ),
              child: FoodLogEntriesPanel(date: widget.date),
            ),
        ],
      ),
    );
  }
}

String _completenessLabel(String value) => switch (value) {
  'complete' => 'All requested values are available.',
  'partial' => 'Some values are not available yet.',
  'unknown' || 'missing' => 'Nutrition details are not available yet.',
  _ => 'Some values are not available yet.',
};
