import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../nutrition/nutrition_providers.dart';
import 'nutrition_ai_controllers.dart';
import 'nutrition_label_ocr_service.dart';

class NutritionLabelOcrScreen extends ConsumerStatefulWidget {
  final String? mealType;
  final String? date;

  const NutritionLabelOcrScreen({
    super.key,
    this.mealType,
    this.date,
  });

  @override
  ConsumerState<NutritionLabelOcrScreen> createState() =>
      _NutritionLabelOcrScreenState();
}

class _NutritionLabelOcrScreenState
    extends ConsumerState<NutritionLabelOcrScreen> {
  late final TextEditingController _nameController;
  final Map<String, TextEditingController> _nutrientControllers = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _nutrientControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers(NutritionLabelOcrState state) {
    if (_nameController.text != state.productName) {
      _nameController.text = state.productName;
    }
    for (final entry in state.editableNutrients.entries) {
      final text = entry.value.toStringAsFixed(1);
      final c = _nutrientControllers.putIfAbsent(
        entry.key,
        () => TextEditingController(text: text),
      );
      if (c.text != text && double.tryParse(c.text) != entry.value) {
        c.text = text;
      }
    }
  }

  DateTime _resolveDate() {
    if (widget.date != null) {
      try {
        return DateTime.parse(widget.date!);
      } catch (_) {}
    }
    return DateTime.now();
  }

  String _resolveMealType() {
    return widget.mealType ?? 'snack';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nutritionLabelOcrControllerProvider);
    final controller = ref.read(nutritionLabelOcrControllerProvider.notifier);
    final colors = context.b05Colors;

    _syncControllers(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Nutrition Label'),
      ),
      body: SafeArea(
        child: switch (state.status) {
          NutritionLabelOcrStatus.idle => _buildIdleState(context, controller),
          NutritionLabelOcrStatus.picking ||
          NutritionLabelOcrStatus.scanning =>
            _buildLoadingState(context, 'Analyzing label image...'),
          NutritionLabelOcrStatus.failure =>
            _buildFailureState(context, state, controller),
          NutritionLabelOcrStatus.ready ||
          NutritionLabelOcrStatus.saving ||
          NutritionLabelOcrStatus.success =>
            _buildReviewState(context, state, controller, colors),
        },
      ),
    );
  }

  Widget _buildIdleState(
    BuildContext context,
    NutritionLabelOcrController controller,
  ) {
    final colors = context.b05Colors;
    return ListView(
      padding: const EdgeInsets.all(B05Layout.space16),
      children: [
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          showBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.document_scanner_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: B05Layout.iconLarge,
                  ),
                  const SizedBox(width: B05Layout.space12),
                  Expanded(
                    child: Text(
                      'Extract Facts from Packaging',
                      style: B05Typography.title(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Text(
                'IndiFit extracts Indian FSSAI (per 100g) and international nutrition facts tables directly from your photo. You can review and adjust any field before saving.',
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space20),
              Row(
                children: [
                  Expanded(
                    child: B05ActionButton(
                      label: 'Take Photo',
                      icon: Icons.camera_alt_rounded,
                      onPressed: () => controller.pickAndScan(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: B05Layout.space12),
                  Expanded(
                    child: B05ActionButton(
                      label: 'Choose Image',
                      icon: Icons.photo_library_rounded,
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: () => controller.pickAndScan(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space16),
          showBorder: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                color: colors.info.indicator,
                size: B05Layout.iconMedium,
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Text(
                  'Privacy Notice: Images are processed ephemerally on secure cloud servers and are immediately deleted after OCR extraction. They are never stored permanently.',
                  style: B05Typography.caption(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: B05Layout.space16),
          Text(message, style: B05Typography.body(context)),
        ],
      ),
    );
  }

  Widget _buildFailureState(
    BuildContext context,
    NutritionLabelOcrState state,
    NutritionLabelOcrController controller,
  ) {
    return ListView(
      padding: const EdgeInsets.all(B05Layout.space16),
      children: [
        B05StatusMessage(
          status: B05SemanticStatus.danger,
          label: state.errorMessage ?? 'Unable to scan nutrition label.',
        ),
        const SizedBox(height: B05Layout.space16),
        B05ActionButton(
          label: 'Try Again',
          icon: Icons.refresh_rounded,
          onPressed: () => controller.pickAndScan(ImageSource.camera),
        ),
        const SizedBox(height: B05Layout.space8),
        B05ActionButton(
          label: 'Pick From Gallery',
          icon: Icons.photo_library_rounded,
          emphasis: B05ActionEmphasis.secondary,
          onPressed: () => controller.pickAndScan(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _buildReviewState(
    BuildContext context,
    NutritionLabelOcrState state,
    NutritionLabelOcrController controller,
    B05SemanticColors colors,
  ) {
    final ocr = state.ocrResult;

    return ListView(
      padding: const EdgeInsets.all(B05Layout.space16),
      children: [
        if (state.isLogged) ...[
          const B05StatusMessage(
            status: B05SemanticStatus.success,
            label: 'Logged to your diary successfully!',
          ),
          const SizedBox(height: B05Layout.space16),
        ],
        if (ocr?.isFallback == true) ...[
          const B05StatusMessage(
            status: B05SemanticStatus.warning,
            label: 'Offline demo estimate shown. Review fields before logging.',
          ),
          const SizedBox(height: B05Layout.space16),
        ],

        // Product Name Card
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space16),
          showBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product Information', style: B05Typography.title(context)),
              const SizedBox(height: B05Layout.space12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Food / Product Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.updateProductName,
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),

        // Basis & Portion Card
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space16),
          showBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Portion & Basis', style: B05Typography.title(context)),
              const SizedBox(height: B05Layout.space12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'per_100g',
                    label: Text('Per 100g'),
                    icon: Icon(Icons.scale_rounded),
                  ),
                  ButtonSegment(
                    value: 'per_serving',
                    label: Text('Per Serving'),
                    icon: Icon(Icons.restaurant_rounded),
                  ),
                ],
                selected: {state.basis},
                onSelectionChanged: (val) => controller.updateBasis(val.first),
              ),
              const SizedBox(height: B05Layout.space12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Logged Amount: ${state.effectiveServingSize.toStringAsFixed(0)} ${state.servingUnit}',
                      style: B05Typography.body(context),
                    ),
                  ),
                  PopupMenuButton<double>(
                    initialValue: state.portionMultiplier,
                    onSelected: controller.updateMultiplier,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0.5, child: Text('0.5x (Half)')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x (Standard)')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x (Double)')),
                    ],
                    child: Chip(
                      label: Text('${state.portionMultiplier.toStringAsFixed(1)}x portion'),
                      avatar: const Icon(Icons.arrow_drop_down),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),

        // Nutrients Table with Confidence Badges
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space16),
          showBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nutrition Facts (Review)', style: B05Typography.title(context)),
              const SizedBox(height: B05Layout.space12),
              _buildNutrientRow(
                context,
                label: 'Calories',
                key: 'calories',
                unit: 'kcal',
                ocrData: ocr?.nutrients['calories'],
                state: state,
                controller: controller,
              ),
              const Divider(),
              _buildNutrientRow(
                context,
                label: 'Protein',
                key: 'protein',
                unit: 'g',
                ocrData: ocr?.nutrients['protein'],
                state: state,
                controller: controller,
              ),
              const Divider(),
              _buildNutrientRow(
                context,
                label: 'Carbohydrates',
                key: 'carbs',
                unit: 'g',
                ocrData: ocr?.nutrients['carbs'],
                state: state,
                controller: controller,
              ),
              const Divider(),
              _buildNutrientRow(
                context,
                label: 'Total Fat',
                key: 'fat',
                unit: 'g',
                ocrData: ocr?.nutrients['fat'],
                state: state,
                controller: controller,
              ),
              const Divider(),
              _buildNutrientRow(
                context,
                label: 'Dietary Fiber',
                key: 'fiber',
                unit: 'g',
                ocrData: ocr?.nutrients['fiber'],
                state: state,
                controller: controller,
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space24),

        // Actions
        B05ActionButton(
          label: state.isLogged
              ? 'Logged to Diary'
              : (state.status == NutritionLabelOcrStatus.saving
                  ? 'Logging...'
                  : 'Log to Diary'),
          icon: Icons.check_circle_outline_rounded,
          onPressed: state.isLogged || state.isBusy
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final router = GoRouter.of(context);
                  final ok = await controller.logToDiary(
                    mealType: _resolveMealType(),
                    date: _resolveDate(),
                  );
                  if (ok && mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Item added to meal diary!')),
                    );
                    router.pop(true);
                  }
                },
        ),
        const SizedBox(height: B05Layout.space12),
        B05ActionButton(
          label: state.isSaved
              ? 'Saved in My Foods'
              : (state.status == NutritionLabelOcrStatus.saving
                  ? 'Saving...'
                  : 'Save as Custom Food'),
          icon: Icons.bookmark_border_rounded,
          emphasis: B05ActionEmphasis.secondary,
          onPressed: state.isSaved || state.isBusy
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final opt = await controller.saveAsCustomFood();
                  if (opt != null && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Saved "${opt.displayName}" to custom foods!')),
                    );
                  }
                },
        ),
        const SizedBox(height: B05Layout.space12),
        B05ActionButton(
          label: 'Retake Photo',
          icon: Icons.camera_alt_outlined,
          emphasis: B05ActionEmphasis.secondary,
          onPressed: () => controller.pickAndScan(ImageSource.camera),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(
    BuildContext context, {
    required String label,
    required String key,
    required String unit,
    required NutrientOcrData? ocrData,
    required NutritionLabelOcrState state,
    required NutritionLabelOcrController controller,
  }) {
    final colors = context.b05Colors;
    final confidence = ocrData?.confidence.toLowerCase() ?? 'medium';

    Color badgeColor;
    String badgeText;
    if (confidence == 'high') {
      badgeColor = colors.success.indicator;
      badgeText = 'High';
    } else if (confidence == 'low') {
      badgeColor = colors.warning.indicator;
      badgeText = 'Low (Check)';
    } else {
      badgeColor = colors.info.indicator;
      badgeText = 'Medium';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: B05Layout.space8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: B05Typography.body(context)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _nutrientControllers[key],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  suffixText: unit,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (text) {
                  final parsed = double.tryParse(text);
                  if (parsed != null) {
                    controller.updateNutrient(key, parsed);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
