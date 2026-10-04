import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/privacy/dpdp_consent_service.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import 'ai_items_thali_handoff.dart';
import 'meal_item_resolver.dart';
import 'natural_language_meal_service.dart';
import 'nutrition_ai_controllers.dart';

class PhotoMealScreen extends ConsumerStatefulWidget {
  final String? mealType;
  final String? date;

  const PhotoMealScreen({super.key, this.mealType, this.date});

  @override
  ConsumerState<PhotoMealScreen> createState() => _PhotoMealScreenState();
}

class _PhotoMealScreenState extends ConsumerState<PhotoMealScreen> {
  DateTime _resolveDate() {
    if (widget.date != null) {
      // An unparseable route date falls back to today.
      final parsed = DateTime.tryParse(widget.date!);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  String _resolveMealType() {
    return widget.mealType ?? 'lunch';
  }

  Future<String> _getOrCreateDeviceUuid(SharedPreferences prefs) async {
    String uuid = prefs.getString('pref_device_uuid') ?? '';
    if (uuid.isEmpty) {
      uuid = const Uuid().v4();
      await prefs.setString('pref_device_uuid', uuid);
    }
    return uuid;
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    SharedPreferences? prefs = sharedPreferencesOrNull(
      () => ref.read(sharedPreferencesProvider),
    );
    prefs ??= await SharedPreferences.getInstance();

    if (!mounted) return;

    final consented = await DpdpConsentService.ensureConsent(
      context: context,
      prefs: prefs,
    );
    if (!consented || !mounted) return;

    final deviceUuid = await _getOrCreateDeviceUuid(prefs);
    final controller = ref.read(photoMealControllerProvider.notifier);
    await controller.pickAndScan(source, deviceUuid: deviceUuid);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoMealControllerProvider);
    final controller = ref.read(photoMealControllerProvider.notifier);
    final colors = context.b05Colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Meal Estimator'),
        actions: [
          if (state.status == PhotoMealStatus.ready ||
              state.status == PhotoMealStatus.failure)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'New Photo',
              onPressed: state.isBusy ? null : controller.reset,
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          PhotoMealStatus.idle => _buildIdleSurface(context),
          PhotoMealStatus.picking ||
          PhotoMealStatus.scanning => _buildLoadingSurface(context, state),
          PhotoMealStatus.failure => _buildFailureSurface(
            context,
            state,
            controller,
          ),
          PhotoMealStatus.ready ||
          PhotoMealStatus.logging ||
          PhotoMealStatus.success => _buildReviewSurface(
            context,
            state,
            controller,
            colors,
          ),
        },
      ),
    );
  }

  Widget _buildIdleSurface(BuildContext context) {
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
                    Icons.camera_alt_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Meal Decomposition',
                      style: B05Typography.title(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Text(
                'Take a photo of your thali, plate, or bowl. The AI decomposes your meal into discrete Indian portions (rotis, katoris of dal/curry, rice bowls) for review before logging.',
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.b05Colors.info.container,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: context.b05Colors.info.indicator,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Review-only contract: Estimates carry ±30% variance. You verify all portions before any entry is committed to your diary.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.b05Colors.info.indicator,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: B05Layout.space24),
              B05ActionButton(
                label: 'Take Photo with Camera',
                icon: Icons.photo_camera_rounded,
                onPressed: () => _pickAndProcess(ImageSource.camera),
              ),
              const SizedBox(height: B05Layout.space12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: const Text('Choose from Gallery'),
                icon: const Icon(Icons.photo_library_rounded),
                onPressed: () => _pickAndProcess(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSurface(BuildContext context, PhotoMealState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              state.status == PhotoMealStatus.picking
                  ? 'Selecting image...'
                  : 'Decomposing meal with Indian vision AI...',
              style: B05Typography.title(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Identifying rotis, katoris of dal & curries, rice, and portions...',
              style: B05Typography.caption(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureSurface(
    BuildContext context,
    PhotoMealState state,
    PhotoMealController controller,
  ) {
    final isRateLimited =
        state.errorMessage?.contains('429') == true ||
        state.errorMessage?.toLowerCase().contains('quota') == true ||
        state.errorMessage?.toLowerCase().contains('rate limit') == true;

    final displayMessage = isRateLimited
        ? 'Daily AI photo scan limit reached (10 scans per 24 hours). Please try again tomorrow, or use text description / quick-add macros.'
        : (state.errorMessage ??
              'An error occurred while uploading or processing the photo. Please check connectivity and try again.');

    return Padding(
      padding: const EdgeInsets.all(B05Layout.space24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isRateLimited
                ? Icons.hourglass_top_rounded
                : Icons.error_outline_rounded,
            size: 48,
            color: isRateLimited
                ? context.b05Colors.warning.indicator
                : context.b05Colors.danger.indicator,
          ),
          const SizedBox(height: 16),
          Text(
            isRateLimited ? 'Daily Quota Reached' : 'Could not analyze photo',
            style: B05Typography.title(context),
          ),
          const SizedBox(height: 8),
          Text(
            displayMessage,
            style: B05Typography.body(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isRateLimited) ...[
            B05ActionButton(
              label: 'Describe Meal with Text',
              icon: Icons.edit_note_rounded,
              onPressed: () {
                final mealParam = widget.mealType != null
                    ? '?mealType=${widget.mealType}'
                    : '';
                final dateParam = widget.date != null
                    ? (mealParam.isEmpty
                          ? '?date=${widget.date}'
                          : '&date=${widget.date}')
                    : '';
                context.pushReplacement('/food/describe$mealParam$dateParam');
              },
            ),
            const SizedBox(height: 12),
          ],
          B05ActionButton(
            label: isRateLimited ? 'Close' : 'Try Again',
            icon: isRateLimited ? Icons.close_rounded : Icons.refresh_rounded,
            emphasis: isRateLimited
                ? B05ActionEmphasis.secondary
                : B05ActionEmphasis.primary,
            onPressed: isRateLimited
                ? () => Navigator.of(context).pop()
                : () => _pickAndProcess(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSurface(
    BuildContext context,
    PhotoMealState state,
    PhotoMealController controller,
    B05SemanticColors colors,
  ) {
    return ListView(
      padding: const EdgeInsets.all(B05Layout.space16),
      children: [
        // A failed log returns here, keeping the items still to log.
        if (state.errorMessage != null) ...[
          B05StatusMessage(
            status: B05SemanticStatus.danger,
            label: state.errorMessage!,
          ),
          const SizedBox(height: B05Layout.space16),
        ],
        // ±30% Review Disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.warning.container,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.warning.indicator.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colors.warning.indicator,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.result?.fallbackReason != null
                      ? 'Offline fallback active. Review quantities before saving.'
                      : 'AI estimate carries ±30% variance. Review & adjust quantities below before logging.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.warning.indicator,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),

        // Photo Preview thumbnail if available
        if (state.imagePath != null && File(state.imagePath!).existsSync()) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(state.imagePath!),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: B05Layout.space16),
        ],

        // Macro Summary Bar
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space16),
          showBorder: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroStat(
                context,
                'Calories',
                '${state.totalCalories} kcal',
                Theme.of(context).colorScheme.primary,
              ),
              _buildMacroStat(
                context,
                'Protein',
                '${state.totalProtein.toStringAsFixed(1)}g',
                colors.success.indicator,
              ),
              _buildMacroStat(
                context,
                'Carbs',
                '${state.totalCarbs.toStringAsFixed(1)}g',
                colors.warning.indicator,
              ),
              _buildMacroStat(
                context,
                'Fat',
                '${state.totalFat.toStringAsFixed(1)}g',
                colors.danger.indicator,
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),

        Text(
          'Identified Items (${state.editableItems.length})',
          style: B05Typography.title(context),
        ),
        const SizedBox(height: B05Layout.space8),

        ...state.editableItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildItemCard(context, index, item, controller, colors);
        }),
        if (state.editableItems.any((i) => i.needsCatalogChoice))
          Padding(
            padding: const EdgeInsets.only(top: B05Layout.space8),
            child: Text(
              'Tap "Choose" on each highlighted item to pick the right food '
              'before logging.',
              style: B05Typography.caption(context),
            ),
          ),

        const SizedBox(height: B05Layout.space20),

        // Action Buttons: Open in Circular Thali or Log to Diary
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: const Text('Open in Circular Thali'),
                icon: const Icon(Icons.pie_chart_outline_rounded),
                onPressed: state.isBusy || state.editableItems.isEmpty
                    ? null
                    : () => _openInCircularThali(
                        _resolveMealType(),
                        _resolveDate(),
                        state.editableItems,
                      ),
              ),
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: B05ActionButton(
                label: state.isLogged
                    ? 'Logged to Diary'
                    : (state.status == PhotoMealStatus.logging
                          ? 'Logging Meal...'
                          : 'Log Meal to Diary'),
                icon: Icons.check_circle_outline_rounded,
                onPressed:
                    state.isLogged ||
                        state.isBusy ||
                        state.editableItems.any((i) => i.needsCatalogChoice)
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final router = GoRouter.of(context);
                        final ok = await controller.logAllToDiary(
                          mealType: _resolveMealType(),
                          date: _resolveDate(),
                        );
                        if (ok && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Meal logged to diary successfully!',
                              ),
                            ),
                          );
                          router.pop(true);
                        }
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: B05Typography.caption(context)),
      ],
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    int index,
    DecomposedFoodItem item,
    PhotoMealController controller,
    B05SemanticColors colors,
  ) {
    final isVerified = item.isCatalogVerified;
    final needsChoice = item.needsCatalogChoice;
    final badgeColor = isVerified
        ? colors.success.indicator
        : needsChoice
        ? colors.warning.indicator
        : colors.info.indicator;
    final badgeText = isVerified
        ? 'Catalog Verified'
        : needsChoice
        ? 'Choose a match'
        : 'AI Vision Estimate';

    final confidenceColor = switch (item.confidence.toLowerCase()) {
      'high' => colors.success.indicator,
      'low' => colors.danger.indicator,
      _ => colors.warning.indicator,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space12),
      child: B05Surface(
        padding: const EdgeInsets.all(B05Layout.space16),
        showBorder: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.foodName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'from photo: "${item.rawSegment}"',
                        style: B05Typography.caption(context),
                      ),
                      if (item.portionNote != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.portionNote!,
                          style: B05Typography.caption(
                            context,
                          ).copyWith(color: colors.warning.indicator),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.confidence[0].toUpperCase()}${item.confidence.substring(1)} Conf',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: confidenceColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Remove item',
                  onPressed: () => controller.removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: B05Layout.space12),
            Row(
              children: [
                // Inline Stepper
                IconButton.outlined(
                  icon: const Icon(Icons.remove, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: item.quantityAmount <= 0.25
                      ? null
                      : () {
                          final step = quantityStep(item, decreasing: true);
                          final newAmount = (item.quantityAmount - step).clamp(
                            0.25,
                            999.0,
                          );
                          controller.updateItemQuantity(
                            index,
                            newAmount,
                            item.quantityUnit,
                          );
                        },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${item.quantityAmount.toStringAsFixed(item.quantityAmount % 1 == 0 ? 0 : 2)} ${item.quantityUnit}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final step = quantityStep(item, decreasing: false);
                    final newAmount = item.quantityAmount + step;
                    controller.updateItemQuantity(
                      index,
                      newAmount,
                      item.quantityUnit,
                    );
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: Text(
                    isVerified ? 'Swap' : (needsChoice ? 'Choose' : 'Match'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () =>
                      _openSwapModal(context, index, item, controller),
                ),
                // Wraps instead of overflowing on narrow phones.
                Expanded(
                  child: Text(
                    '${item.estimatedCalories} kcal • ${item.estimatedProtein.toStringAsFixed(1)}g P',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSwapModal(
    BuildContext context,
    int index,
    DecomposedFoodItem item,
    PhotoMealController controller,
  ) async {
    final catalog = await ref.read(
      nutritionFoodCatalogRepositoryProvider.future,
    );
    // Ambiguous items open on the resolver's candidates; otherwise search.
    final initialMatches = item.catalogChoices.isNotEmpty
        ? item.catalogChoices
        : await catalog.search(query: item.foodName);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        List<NutritionFoodOption> matches = initialMatches;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Swap Food Match',
                            style: B05Typography.title(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Search food in catalog...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setSheetState(() {
                                matches = [];
                              });
                            },
                          ),
                        ),
                        onChanged: (val) async {
                          final results = await catalog.search(query: val);
                          setSheetState(() => matches = results);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: matches.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching catalog foods found.',
                                  style: B05Typography.caption(context),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: matches.length,
                                separatorBuilder: (ctx, i) => const Divider(),
                                itemBuilder: (ctx, i) {
                                  final option = matches[i];
                                  final isCurrent =
                                      item.matchedCatalogOption?.id ==
                                      option.id;
                                  final energy =
                                      option
                                          .facts['energy']
                                          ?.point
                                          ?.value
                                          .asDouble
                                          .toStringAsFixed(0) ??
                                      '—';
                                  final protein =
                                      option
                                          .facts['protein']
                                          ?.point
                                          ?.value
                                          .asDouble
                                          .toStringAsFixed(1) ??
                                      '—';
                                  return ListTile(
                                    title: Text(option.displayName),
                                    subtitle: Text(
                                      '$energy kcal • $protein g P per ${catalogBasisLabel(option)}',
                                    ),
                                    trailing: isCurrent
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          )
                                        : null,
                                    onTap: () {
                                      controller.updateItemFoodMatch(
                                        index,
                                        option,
                                      );
                                      Navigator.pop(sheetCtx);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openInCircularThali(
    String mealType,
    DateTime date,
    List<DecomposedFoodItem> items,
  ) async {
    await openAiItemsInThali(
      context: context,
      ref: ref,
      mealType: mealType,
      items: items,
    );
  }
}
