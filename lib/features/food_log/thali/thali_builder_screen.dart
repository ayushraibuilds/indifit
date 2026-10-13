import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/nutrition_thali.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_feedback.dart';
import '../../dashboard/today_surface_controller.dart';
import '../katori_size_step.dart';
import '../meal_presentation_registry.dart';
import '../nutrition_thali_controller.dart';
import '../widgets/meal_icon_chip.dart';
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
  final FocusNode _nameFocusNode = FocusNode();
  bool _initialized = false;
  bool _triedUsual = false;
  ThaliViewMode _viewMode = ThaliViewMode.plate;
  String? _selectedItemId;

  /// The failure already shown, so a rebuild doesn't show it again.
  String? _shownError;

  static const _noticeDuration = Duration(seconds: 4);

  /// Replaces the notice on screen instead of queueing behind it, so notices
  /// never stack up over the plate (UX-15).
  void _showNotice(SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialThaliId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(
              nutritionThaliControllerProvider(widget.mealCategory).notifier,
            )
            .loadDraft(widget.initialThaliId!);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
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
      if (!_initialized ||
          (_nameController.text != draft.name && !state.dirty)) {
        _nameController.text = draft.name;
        _initialized = true;
      }
    }

    // A brand-new, empty thali starts from the preset the user logs most
    // (P1 H9). Saved drafts and AI handoffs arrive with items, so they skip.
    if (!_triedUsual &&
        widget.initialThaliId == null &&
        state.status == NutritionThaliStatus.ready &&
        draft != null) {
      _triedUsual = true;
      if (draft.items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(controller.startFromUsual());
        });
      }
    }

    // React to user notices (e.g. missing preset items)
    if (state.userNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notice = state.userNotice!;
        controller.clearNotice();
        final fromUsual = notice.startsWith('Started from your usual');
        _showNotice(
          SnackBar(
            content: Text(notice),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
            // An action would keep it up until dismissed (UX-15).
            persist: false,
            duration: _noticeDuration,
            action: fromUsual
                ? SnackBarAction(
                    label: 'Clear plate',
                    onPressed: controller.clearItems,
                  )
                : null,
          ),
        );
      });
    }

    // React to errors: once per error, and not when the summary bar already
    // shows it in place of the totals. Every rebuild used to queue another.
    final error = state.status == NutritionThaliStatus.failure
        ? state.errorMessage
        : null;
    if (error == null) {
      _shownError = null;
    } else if (state.preview != null && error != _shownError) {
      _shownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showNotice(
          SnackBar(
            content: Text(error),
            backgroundColor: colors.danger.foreground,
            behavior: SnackBarBehavior.floating,
            duration: _noticeDuration,
          ),
        );
      });
    }

    final mealPresentation = MealPresentationRegistry.forStableId(
      widget.mealCategory,
    );
    final items = draft?.items.toList() ?? <NutritionThaliItem>[];
    final previewItems = state.preview?.items ?? <NutritionThaliItemPreview>[];

    final isLoading = state.status == NutritionThaliStatus.loading;
    final isFinalizing =
        state.status == NutritionThaliStatus.finalizing ||
        state.status == NutritionThaliStatus.saving;

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MealIconChip(presentation: mealPresentation, size: 32),
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
            tooltip: 'Reset plate',
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: colors.surface,
                  title: Text(
                    'Reset thali?',
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
      // The full-screen spinner is for the first open only: a preset or a
      // reset keeps the plate on screen with a thin progress line.
      body: isLoading && draft == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(
              controller: controller,
              state: state,
              items: items,
              previewItems: previewItems,
              isLoading: isLoading,
              nameRow: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('thali_name_input'),
                        controller: _nameController,
                        focusNode: _nameFocusNode,
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
                      tooltip: 'Rename thali',
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: colors.textDisabled,
                      ),
                      onPressed: () {
                        _nameFocusNode.requestFocus();
                        _nameController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _nameController.text.length,
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Once: "Which katori looks like yours?"; the plate's
              // nutrition is recalculated with the chosen size.
              // It appears once its stored answer is read; growing in
              // place keeps the plate below from jumping.
              katoriPrompt: _GrowIn(
                child: KatoriSizePromptCard(
                  onChosen: (_) => controller.preview(),
                ),
              ),
              presets: ThaliPresetsBar(
                onSelectPreset: (preset) {
                  if (items.isEmpty) {
                    setState(() {
                      _selectedItemId = null;
                    });
                    controller.loadPreset(
                      presetName: preset.name,
                      items: preset.items,
                      presetId: preset.id,
                    );
                    return;
                  }
                  showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Replace plate items?'),
                      content: Text(
                        'Applying "${preset.name}" will replace your current thali items.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Replace'),
                        ),
                      ],
                    ),
                  ).then((confirmed) {
                    if (confirmed == true && mounted) {
                      setState(() {
                        _selectedItemId = null;
                      });
                      controller.loadPreset(
                        presetName: preset.name,
                        items: preset.items,
                        presetId: preset.id,
                      );
                    }
                  });
                },
              ),
              plateComponents: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Plate components (${items.length})',
                        style: B05Typography.sectionLabel(context),
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
                              tooltip: 'Plate view',
                              onPressed: () {
                                if (_viewMode != ThaliViewMode.plate) {
                                  setState(
                                    () => _viewMode = ThaliViewMode.plate,
                                  );
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
                              tooltip: 'List view',
                              onPressed: () {
                                if (_viewMode != ThaliViewMode.list) {
                                  setState(
                                    () => _viewMode = ThaliViewMode.list,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('thali_add_item_button_header'),
                      onPressed: () => _openComponentPicker(controller, state),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add dish'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.action,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      // In the bottom slot, floating notices sit above Log Thali instead of
      // covering it (UX-15).
      bottomNavigationBar: isLoading && draft == null
          ? null
          : ThaliNutritionSummaryBar(
              preview: state.preview,
              isLoading: isFinalizing,
              hasItems: items.isNotEmpty,
              onLogThali: () => _handleLogThali(),
              onSaveTemplate: _handleSaveTemplate,
              failureMessage:
                  state.status == NutritionThaliStatus.failure &&
                      state.preview == null
                  ? state.errorMessage
                  : null,
              onLogWithoutCalories: () {
                controller.acknowledgeUnknownEnergy(true);
                _handleLogThali();
              },
            ),
    );
  }

  /// The plate, the dish list and the quick-adjust panel. Only the katori
  /// question and the plate/list row sit above the plate; the name and the
  /// quick starts follow it. All of it scrolls, and only the totals bar is
  /// pinned, so the whole plate and its legend are on screen when it opens.
  /// An empty plate leads with the quick starts, the usual way to begin.
  Widget _buildBody({
    required NutritionThaliController controller,
    required NutritionThaliState state,
    required List<NutritionThaliItem> items,
    required List<NutritionThaliItemPreview> previewItems,
    required bool isLoading,
    required Widget nameRow,
    required Widget katoriPrompt,
    required Widget presets,
    required Widget plateComponents,
  }) {
    final selectedItem = _viewMode == ThaliViewMode.plate
        ? items.where((i) => i.id == _selectedItemId).firstOrNull
        : null;
    return Column(
      children: [
        if (isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewport) => _buildScroll(
              controller: controller,
              state: state,
              items: items,
              previewItems: previewItems,
              nameRow: nameRow,
              katoriPrompt: katoriPrompt,
              presets: presets,
              plateComponents: plateComponents,
              // Room for the plate and legend once the row above it (and
              // the katori question, when it shows) take their share.
              plateMaxHeight: math.max(
                viewport.maxHeight - _aboveThePlate,
                _minPlateHeight,
              ),
            ),
          ),
        ),
        // Pinned under the list so it is always in view.
        if (selectedItem != null)
          ThaliQuickAdjustHud(
            item: selectedItem,
            preview: previewItems
                .where((p) => p.item.id == selectedItem.id)
                .firstOrNull,
            onIncrement: () => controller.incrementQuantity(selectedItem.id),
            onDecrement: () => controller.decrementQuantity(selectedItem.id),
            onRemove: () {
              controller.removeItem(selectedItem.id);
              setState(() => _selectedItemId = null);
            },
            onReplace: () => _openComponentPicker(
              controller,
              state,
              replacingItemId: selectedItem.id,
            ),
            onClose: () => setState(() => _selectedItemId = null),
          ),
      ],
    );
  }

  /// The plate/list row plus the katori question, roughly. The plate sizes
  /// itself to the rest so it is whole on screen when the builder opens.
  static const _aboveThePlate = 112.0;

  /// Below this the kcal pills crowd the katoris, so a small phone (SE)
  /// scrolls a little rather than shrinking the plate further.
  static const _minPlateHeight = 300.0;

  Widget _buildScroll({
    required NutritionThaliController controller,
    required NutritionThaliState state,
    required List<NutritionThaliItem> items,
    required List<NutritionThaliItemPreview> previewItems,
    required Widget nameRow,
    required Widget katoriPrompt,
    required Widget presets,
    required Widget plateComponents,
    required double plateMaxHeight,
  }) {
    return items.isEmpty
        ? ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              nameRow,
              katoriPrompt,
              presets,
              _buildEmptyPlateState(controller, state),
            ],
          )
        : ReorderableListView.builder(
            key: const Key('thali_items_list'),
            header: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                katoriPrompt,
                plateComponents,
                if (_viewMode == ThaliViewMode.plate)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: plateMaxHeight),
                    child: CircularThaliPlate(
                      items: items,
                      previews: previewItems,
                      preview: state.preview,
                      selectedItemId: _selectedItemId,
                      onSelectItem: (id) =>
                          setState(() => _selectedItemId = id),
                      onAddDish: () => _openComponentPicker(controller, state),
                      onViewAllDishes: () =>
                          setState(() => _viewMode = ThaliViewMode.list),
                    ),
                  ),
                nameRow,
                presets,
                const SizedBox(height: 8),
              ],
            ),
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
                onIncrement: () => controller.incrementQuantity(item.id),
                onDecrement: () => controller.decrementQuantity(item.id),
                onDelete: () {
                  if (_selectedItemId == item.id) {
                    _selectedItemId = null;
                  }
                  controller.removeItem(item.id);
                },
              );
            },
          );
  }

  /// The empty steel plate itself, with its add slot, instead of an icon:
  /// the screen looks like a thali from the first frame.
  Widget _buildEmptyPlateState(
    NutritionThaliController controller,
    NutritionThaliState state,
  ) {
    final colors = context.b05Colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space8,
        B05Layout.space16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircularThaliPlate(
            items: const [],
            previews: const [],
            preview: null,
            selectedItemId: null,
            onSelectItem: (_) {},
            onAddDish: () => _openComponentPicker(controller, state),
            onViewAllDishes: () {},
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            'Your plate is empty',
            textAlign: TextAlign.center,
            style: B05Typography.title(context),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Pick a quick start above, or add dishes like roti, dal, sabzi or rice.',
            textAlign: TextAlign.center,
            style: B05Typography.body(
              context,
            ).copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: B05Layout.space16),
          Center(
            child: FilledButton.icon(
              key: const Key('thali_add_item_empty_button'),
              onPressed: () => _openComponentPicker(controller, state),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first dish'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grows into place when its child appears, instead of pushing what is
/// below in one jump. Plain under Reduce Motion (a zero-length AnimatedSize
/// re-dirties itself during layout).
class _GrowIn extends StatelessWidget {
  const _GrowIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = B05MotionPolicy.transitionDuration(context);
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: B05MotionPolicy.standardCurve,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}
