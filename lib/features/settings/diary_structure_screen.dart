import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../food_log/diary_structure_controller.dart';
import '../food_log/meal_presentation_registry.dart';

/// Settings screen for configuring daily meal and snack slots.
///
/// Mental Model & Invariants:
/// - Configuration governs only which *empty* slots appear on a given day.
/// - Removing a slot never hides, deletes, or modifies historical records.
/// - Any day with logged food dynamically preserves and surfaces that slot.
/// - Minimum of 1 active slot is strictly enforced.
class DiaryStructureScreen extends ConsumerWidget {
  const DiaryStructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diaryStructureControllerProvider);
    final activeSlots = state.activeSlots;
    final activeSlotIds = state.activeSlotIds.toSet();
    final availableSlots = MealPresentationRegistry.allSupported
        .where((slot) => !activeSlotIds.contains(slot.stableId))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary structure'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space32,
        ),
        children: [
          _buildInfoBanner(context),
          const SizedBox(height: B05Layout.space24),
          _buildPresetsSection(context, ref, state),
          const SizedBox(height: B05Layout.space24),
          _buildActiveSlotsSection(context, ref, activeSlots),
          if (availableSlots.isNotEmpty) ...[
            const SizedBox(height: B05Layout.space24),
            _buildAvailableSlotsSection(context, ref, availableSlots),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final colors = context.b05Colors;
    return B05Surface(
      tone: B05SurfaceTone.section,
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colors.action,
            size: 24,
          ),
          const SizedBox(width: B05Layout.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your daily diary layout',
                  style: B05Typography.title(context),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(
                  'These settings determine which empty meal slots are shown by default. '
                  'Removing a slot never deletes or hides previously logged food — '
                  'any meal with recorded items always remains visible and editable on that day.',
                  style: B05Typography.body(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection(
    BuildContext context,
    WidgetRef ref,
    DiaryStructureState state,
  ) {
    final controller = ref.read(diaryStructureControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRESETS',
          style: B05Typography.label(context),
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Apply a common structure or reset to default at any time.',
          style: B05Typography.caption(context),
        ),
        const SizedBox(height: B05Layout.space12),
        Wrap(
          spacing: B05Layout.space8,
          runSpacing: B05Layout.space8,
          children: [
            ActionChip(
              label: const Text('Standard (4)'),
              tooltip: 'Breakfast, Lunch, Dinner, Snack',
              onPressed: () => controller.applyPreset(DiaryStructurePreset.standard4),
            ),
            ActionChip(
              label: const Text('3 Meals'),
              tooltip: 'Breakfast, Lunch, Dinner',
              onPressed: () => controller.applyPreset(DiaryStructurePreset.threeMeals),
            ),
            ActionChip(
              label: const Text('5 Meals'),
              tooltip: 'Breakfast, Morning snack, Lunch, Afternoon snack, Dinner',
              onPressed: () => controller.applyPreset(DiaryStructurePreset.fiveMeals),
            ),
            ActionChip(
              label: const Text('Athlete (6)'),
              tooltip:
                  'Breakfast, Morning snack, Lunch, Afternoon snack, Dinner, Post-workout',
              onPressed: () => controller.applyPreset(DiaryStructurePreset.athlete6),
            ),
            ActionChip(
              avatar: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset'),
              tooltip: 'Reset to standard 4 meals',
              onPressed: () => controller.resetToDefault(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveSlotsSection(
    BuildContext context,
    WidgetRef ref,
    List<FoodMealPresentation> activeSlots,
  ) {
    final controller = ref.read(diaryStructureControllerProvider.notifier);
    final canRemove = activeSlots.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE SLOTS (${activeSlots.length})',
              style: B05Typography.label(context),
            ),
          ],
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Drag the handle to reorder meals in your diary.',
          style: B05Typography.caption(context),
        ),
        const SizedBox(height: B05Layout.space12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: activeSlots.length,
          onReorder: controller.reorderSlots,
          itemBuilder: (context, index) {
            final slot = activeSlots[index];
            final accent = slot.accent;
            final mealColors = accent != null
                ? context.b05Colors.meal(accent)
                : context.b05Colors.snack;

            return Container(
              key: ValueKey('active_slot_${slot.stableId}'),
              margin: const EdgeInsets.only(bottom: B05Layout.space8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: ListTile(
                leading: DecoratedBox(
                  decoration: BoxDecoration(
                    color: mealColors.container,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      slot.icon,
                      color: mealColors.indicator,
                      size: 20,
                    ),
                  ),
                ),
                title: Text(
                  slot.label,
                  style: B05Typography.title(context),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: canRemove
                          ? 'Remove ${slot.label} from diary'
                          : 'At least one slot is required',
                      onPressed: canRemove
                          ? () => controller.removeSlot(slot.stableId)
                          : null,
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvailableSlotsSection(
    BuildContext context,
    WidgetRef ref,
    List<FoodMealPresentation> availableSlots,
  ) {
    final controller = ref.read(diaryStructureControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVAILABLE OPTIONAL SLOTS',
          style: B05Typography.label(context),
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Add extra snack or workout-timed slots to your diary.',
          style: B05Typography.caption(context),
        ),
        const SizedBox(height: B05Layout.space12),
        for (final slot in availableSlots) ...[
          Builder(
            builder: (context) {
              final accent = slot.accent;
              final mealColors = accent != null
                  ? context.b05Colors.meal(accent)
                  : context.b05Colors.snack;

              return Container(
                margin: const EdgeInsets.only(bottom: B05Layout.space8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: ListTile(
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: mealColors.container,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        slot.icon,
                        color: mealColors.indicator,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    slot.label,
                    style: B05Typography.title(context),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => controller.addSlot(slot.stableId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
