import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/nutrition_thali.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/indi_fit_feedback.dart';
import '../../dashboard/today_surface_controller.dart';
import '../meal_presentation_registry.dart';
import '../nutrition_thali_controller.dart';
import 'thali_component_picker_sheet.dart';
import 'thali_item_card.dart';
import 'thali_nutrition_summary_bar.dart';
import 'thali_presets_bar.dart';

class ThaliBuilderScreen extends ConsumerStatefulWidget {
  final String mealCategory;
  final String? initialThaliId;

  const ThaliBuilderScreen({
    super.key,
    this.mealCategory = 'lunch',
    this.initialThaliId,
  });

  @override
  ConsumerState<ThaliBuilderScreen> createState() => _ThaliBuilderScreenState();
}

class _ThaliBuilderScreenState extends ConsumerState<ThaliBuilderScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialThaliId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(nutritionThaliControllerProvider(widget.mealCategory).notifier)
            .loadDraft(widget.initialThaliId!);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogThali({bool saveAsTemplate = false}) async {
    final controller = ref.read(
      nutritionThaliControllerProvider(widget.mealCategory).notifier,
    );
    final now = DateTime.now().toUtc();
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final dates = ref.read(localScheduleDateServiceProvider);
    final localDate = dates.localDateFor(now, timezoneId);

    final snapshot = await controller.logThali(
      loggedAt: now,
      localDate: localDate,
      timezoneId: timezoneId,
      saveAsTemplate: saveAsTemplate,
    );

    if (snapshot != null && mounted) {
      ref.read(todayNutritionRevisionProvider.notifier).state++;
      showIndiFitSuccessFeedback(context, 'Thali logged successfully!');
      Navigator.of(context).pop(snapshot);
    }
  }

  Future<void> _handleSaveTemplate() async {
    final controller = ref.read(
      nutritionThaliControllerProvider(widget.mealCategory).notifier,
    );
    await controller.saveDraft();
    final state = ref.read(
      nutritionThaliControllerProvider(widget.mealCategory),
    );
    if (state.status != NutritionThaliStatus.failure && mounted) {
      showIndiFitSuccessFeedback(context, 'Thali saved as template!');
    }
  }

  void _openComponentPicker(
    NutritionThaliController controller,
    NutritionThaliState state,
  ) {
    ThaliComponentPickerSheet.show(
      context,
      controller: controller,
      state: state,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      nutritionThaliControllerProvider(widget.mealCategory),
    );
    final controller = ref.read(
      nutritionThaliControllerProvider(widget.mealCategory).notifier,
    );

    // Sync draft name into controller on first load or preset change
    final draft = state.draft;
    if (draft != null) {
      if (!_initialized || (_nameController.text != draft.name && !state.dirty)) {
        _nameController.text = draft.name;
        _initialized = true;
      }
    }

    // React to user notices (e.g. missing preset items)
    if (state.userNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notice = state.userNotice!;
        controller.clearNotice();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notice),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    // React to errors
    if (state.status == NutritionThaliStatus.failure &&
        state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    final mealPresentation =
        MealPresentationRegistry.forStableId(widget.mealCategory);
    final items = draft?.items.toList() ?? <NutritionThaliItem>[];
    final previewItems = state.preview?.items ?? <NutritionThaliItemPreview>[];

    final isLoading = state.status == NutritionThaliStatus.loading;
    final isFinalizing = state.status == NutritionThaliStatus.finalizing ||
        state.status == NutritionThaliStatus.saving;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mealPresentation.icon,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '${mealPresentation.label} Thali',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('thali_clear_button'),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Reset Plate',
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text(
                    'Reset Thali?',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  content: const Text(
                    'This will clear all items from your current plate.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ).then((confirmed) {
                if (confirmed == true) {
                  controller.clearDraft();
                }
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thali Name Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('thali_name_input'),
                          controller: _nameController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Thali Name (e.g. Sunday Lunch Thali)',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: controller.setName,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.cardBorder, height: 1),
                // Presets Bar
                ThaliPresetsBar(
                  onSelectPreset: (preset) {
                    controller.loadPreset(
                      presetName: preset.name,
                      items: preset.items,
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Items List / Empty State
                Expanded(
                  child: items.isEmpty
                      ? _buildEmptyPlateState(controller, state)
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'PLATE COMPONENTS (${items.length})',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton.icon(
                                    key: const Key('thali_add_item_button_header'),
                                    onPressed: () => _openComponentPicker(
                                      controller,
                                      state,
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Dish'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ReorderableListView.builder(
                                key: const Key('thali_items_list'),
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: items.length,
                                onReorder: controller.reorderItem,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final itemPreview = previewItems
                                      .where((p) => p.item.id == item.id)
                                      .firstOrNull;
                                  return ThaliItemCard(
                                    key: ValueKey(item.id),
                                    item: item,
                                    preview: itemPreview,
                                    index: index,
                                    onIncrement: () =>
                                        controller.incrementQuantity(item.id),
                                    onDecrement: () =>
                                        controller.decrementQuantity(item.id),
                                    onDelete: () =>
                                        controller.removeItem(item.id),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                // Sticky Bottom Summary Bar
                ThaliNutritionSummaryBar(
                  preview: state.preview,
                  isLoading: isFinalizing,
                  hasItems: items.isNotEmpty,
                  onLogThali: () => _handleLogThali(),
                  onSaveTemplate: _handleSaveTemplate,
                ),
              ],
            ),
      floatingActionButton: items.isNotEmpty
          ? FloatingActionButton.extended(
              key: const Key('thali_add_item_fab'),
              onPressed: () => _openComponentPicker(controller, state),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Dish'),
            )
          : null,
    );
  }

  Widget _buildEmptyPlateState(
    NutritionThaliController controller,
    NutritionThaliState state,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rice_bowl_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Thali Plate is Empty',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a preset archetype above or add individual dishes like roti, dal, sabzi, or rice.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('thali_add_item_empty_button'),
              onPressed: () => _openComponentPicker(controller, state),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Dish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
