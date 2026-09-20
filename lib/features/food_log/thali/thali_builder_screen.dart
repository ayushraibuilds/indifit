import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/nutrition_thali.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_feedback.dart';
import '../../dashboard/today_surface_controller.dart';
import '../meal_presentation_registry.dart';
import '../nutrition_thali_controller.dart';
import 'circular_thali_plate.dart';
import 'thali_component_picker_sheet.dart';
import 'thali_item_card.dart';
import 'thali_nutrition_summary_bar.dart';
import 'thali_presets_bar.dart';
import 'thali_quick_adjust_hud.dart';

/// Presentation view mode for the Thali builder.
enum ThaliViewMode {
  /// Interactive circular platter with radial katoris and outer macro ring.
  plate,

  /// Linear reorderable item list.
  list,
}

class ThaliBuilderScreen extends ConsumerStatefulWidget {
  final String mealCategory;
  final String? initialThaliId;
  final DateTime? selectedDate;

  const ThaliBuilderScreen({
    super.key,
    this.mealCategory = 'lunch',
    this.initialThaliId,
    this.selectedDate,
  });

  @override
  ConsumerState<ThaliBuilderScreen> createState() => _ThaliBuilderScreenState();
}

class _ThaliBuilderScreenState extends ConsumerState<ThaliBuilderScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _initialized = false;
  ThaliViewMode _viewMode = ThaliViewMode.plate;
  String? _selectedItemId;

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
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final dates = ref.read(localScheduleDateServiceProvider);
    final selectedLocalDate = widget.selectedDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
    final loggedAt = selectedLocalDate == null
        ? DateTime.now().toUtc()
        : dates.instantForLocalDate(selectedLocalDate, timezoneId);
    final localDate =
        selectedLocalDate ?? dates.localDateFor(loggedAt, timezoneId);

    final snapshot = await controller.logThali(
      loggedAt: loggedAt,
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
    NutritionThaliState state, {
    String? replacingItemId,
  }) {
    ThaliComponentPickerSheet.show(
      context,
      controller: controller,
      state: state,
      replacingItemId: replacingItemId,
    ).then((_) {
      if (replacingItemId != null && mounted) {
        setState(() => _selectedItemId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
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
            backgroundColor: colors.surface,
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
            backgroundColor: colors.danger.foreground,
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
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mealPresentation.icon,
              size: 20,
              color: colors.action,
            ),
            const SizedBox(width: 8),
            Text(
              '${mealPresentation.label} Thali',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('thali_clear_button'),
            icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
            tooltip: 'Reset Plate',
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: colors.surface,
                  title: Text(
                    'Reset Thali?',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  content: Text(
                    'This will clear all items from your current plate.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Reset',
                        style: TextStyle(color: colors.danger.foreground),
                      ),
                    ),
                  ],
                ),
              ).then((confirmed) {
                if (confirmed == true) {
                  controller.clearDraft();
                  setState(() {
                    _selectedItemId = null;
                  });
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
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Thali Name (e.g. Sunday Lunch Thali)',
                            hintStyle: TextStyle(color: colors.textDisabled),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: controller.setName,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: colors.textDisabled,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Divider(color: colors.border, height: 1),
                // Presets Bar
                ThaliPresetsBar(
                  onSelectPreset: (preset) {
                    setState(() {
                      _selectedItemId = null;
                    });
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      'PLATE COMPONENTS (${items.length})',
                                      style: TextStyle(
                                        color: colors.textDisabled,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceSubtle,
                                      borderRadius: B05Radii.smallRadius,
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        B05TouchTarget(
                                          minWidth: B05Layout.minTouchTarget,
                                          minHeight: B05Layout.minTouchTarget,
                                          child: IconButton(
                                            key: const Key('thali_view_mode_plate'),
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              Icons.pie_chart_outline_rounded,
                                              size: 18,
                                              color: _viewMode == ThaliViewMode.plate
                                                  ? colors.action
                                                  : colors.textDisabled,
                                            ),
                                            tooltip: 'Plate View',
                                            onPressed: () {
                                              if (_viewMode != ThaliViewMode.plate) {
                                                setState(() => _viewMode = ThaliViewMode.plate);
                                              }
                                            },
                                          ),
                                        ),
                                        B05TouchTarget(
                                          minWidth: B05Layout.minTouchTarget,
                                          minHeight: B05Layout.minTouchTarget,
                                          child: IconButton(
                                            key: const Key('thali_view_mode_list'),
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              Icons.view_list_rounded,
                                              size: 18,
                                              color: _viewMode == ThaliViewMode.list
                                                  ? colors.action
                                                  : colors.textDisabled,
                                            ),
                                            tooltip: 'List View',
                                            onPressed: () {
                                              if (_viewMode != ThaliViewMode.list) {
                                                setState(() => _viewMode = ThaliViewMode.list);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
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
                                      foregroundColor: colors.action,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_viewMode == ThaliViewMode.plate) ...[
                              Flexible(
                                flex: _selectedItemId != null ? 3 : 5,
                                child: CircularThaliPlate(
                                  items: items,
                                  previews: previewItems,
                                  preview: state.preview,
                                  selectedItemId: _selectedItemId,
                                  onSelectItem: (id) => setState(() => _selectedItemId = id),
                                  onAddDish: () => _openComponentPicker(controller, state),
                                  onViewAllDishes: () => setState(() => _viewMode = ThaliViewMode.list),
                                ),
                              ),
                              if (_selectedItemId != null) ...[
                                () {
                                  final selectedItem = items
                                      .where((i) => i.id == _selectedItemId)
                                      .firstOrNull;
                                  if (selectedItem == null) return const SizedBox.shrink();
                                  final selectedItemPreview = previewItems
                                      .where((p) => p.item.id == selectedItem.id)
                                      .firstOrNull;
                                  return ThaliQuickAdjustHud(
                                    item: selectedItem,
                                    preview: selectedItemPreview,
                                    onIncrement: () =>
                                        controller.incrementQuantity(selectedItem.id),
                                    onDecrement: () =>
                                        controller.decrementQuantity(selectedItem.id),
                                    onRemove: () {
                                      controller.removeItem(selectedItem.id);
                                      setState(() => _selectedItemId = null);
                                    },
                                    onReplace: () =>
                                        _openComponentPicker(
                                          controller,
                                          state,
                                          replacingItemId: selectedItem.id,
                                        ),
                                    onClose: () =>
                                        setState(() => _selectedItemId = null),
                                  );
                                }(),
                              ],
                            ],
                            Expanded(
                              flex: 4,
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
                                    onDelete: () {
                                      if (_selectedItemId == item.id) {
                                        _selectedItemId = null;
                                      }
                                      controller.removeItem(item.id);
                                    },
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
              backgroundColor: colors.action,
              foregroundColor: colors.onAction,
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
    final colors = context.b05Colors;
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
                color: colors.action.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rice_bowl_rounded,
                size: 40,
                color: colors.action,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Thali Plate is Empty',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a preset archetype above or add individual dishes like roti, dal, sabzi, or rice.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
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
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
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
