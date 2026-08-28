import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/consumer_copy.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../dashboard_module_registry.dart';
import '../dashboard_personalization_controller.dart';

const _minimumTodayControlSize = Size(48, 48);

/// The consumer-facing Today customization surface. It deliberately renders
/// only descriptors that the packaged registry marks as supported here; the
/// persisted ID is never part of the UI contract.
class DashboardModuleCustomizationPanel extends ConsumerWidget {
  const DashboardModuleCustomizationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardPersonalizationControllerProvider);
    final controller = ref.read(
      dashboardPersonalizationControllerProvider.notifier,
    );
    final registry = ref.watch(dashboardModuleRegistryProvider);
    final defaults = registry.normalize(const []);
    final canReset = !_sameLayout(state.layout, defaults);

    return Semantics(
      container: true,
      label: ConsumerCopy.customizeTodayAction,
      child: switch (state.status) {
        DashboardPersonalizationStatus.loading => Center(
          child: Semantics(
            label: 'Loading Today customization',
            liveRegion: true,
            child: const CircularProgressIndicator(),
          ),
        ),
        DashboardPersonalizationStatus.error => _CustomizationError(
          message: state.errorMessage ?? 'Today customization is unavailable.',
          onRetry: controller.retry,
        ),
        _ => DashboardModuleCustomizationList(
          layout: state.layout,
          isSaving: state.isSaving,
          onMove: controller.reorder,
          onVisibilityChanged: controller.setVisible,
          onCollapsedChanged: controller.setCollapsed,
          onReset: controller.resetToDefaults,
          canReset: canReset,
        ),
      },
    );
  }
}

class DashboardModuleCustomizationList extends StatelessWidget {
  final List<DashboardModuleLayoutItem> layout;
  final bool isSaving;
  final Future<void> Function(String moduleId, int targetIndex) onMove;
  final Future<void> Function(String moduleId, bool isVisible)
  onVisibilityChanged;
  final Future<void> Function(String moduleId, bool isCollapsed)
  onCollapsedChanged;
  final Future<void> Function()? onReset;
  final bool canReset;

  const DashboardModuleCustomizationList({
    required this.layout,
    required this.isSaving,
    required this.onMove,
    required this.onVisibilityChanged,
    required this.onCollapsedChanged,
    this.onReset,
    this.canReset = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (var index = 0; index < layout.length; index++)
        if (layout[index].descriptor.showInCustomizeToday)
          _CustomizationEntry(item: layout[index], sourceIndex: index),
    ];
    if (entries.isEmpty) {
      return Semantics(
        label: 'No supported Today sections are available to customize',
        child: const SizedBox.shrink(),
      );
    }

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: ReorderableListView(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.zero,
        cacheExtent: 2000,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CustomizationIntro(),
            if (isSaving)
              Semantics(
                liveRegion: true,
                label: 'Saving your Today changes',
                child: const Padding(
                  padding: EdgeInsets.only(bottom: B05Layout.space8),
                  child: LinearProgressIndicator(),
                ),
              ),
          ],
        ),
        footer: onReset == null
            ? null
            : _ResetTodayCustomization(
                enabled: canReset && !isSaving,
                onPressed: onReset!,
              ),
        children: [
          for (var index = 0; index < entries.length; index++)
            _DashboardModuleCustomizationRow(
              key: ValueKey(
                'today-customize-row-${entries[index].item.moduleId}',
              ),
              item: entries[index].item,
              index: index,
              entries: entries,
              enabled: !isSaving,
              onMove: onMove,
              onVisibilityChanged: onVisibilityChanged,
              onCollapsedChanged: onCollapsedChanged,
            ),
        ],
        onReorder: (oldIndex, newIndex) {
          if (isSaving || oldIndex == newIndex) return;
          if (newIndex > oldIndex) newIndex -= 1;
          if (newIndex == oldIndex) return;
          final targetIndex = newIndex.clamp(0, entries.length - 1).toInt();
          unawaited(
            onMove(
              entries[oldIndex].item.moduleId,
              entries[targetIndex].sourceIndex,
            ),
          );
        },
      ),
    );
  }
}

class _CustomizationIntro extends StatelessWidget {
  const _CustomizationIntro();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: B05Layout.space8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose what appears on Today',
          style: B05Typography.title(context),
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Use switches to show or hide sections, and drag handles to reorder them.',
          style: B05Typography.body(context),
        ),
      ],
    ),
  );
}

class _DashboardModuleCustomizationRow extends StatelessWidget {
  final DashboardModuleLayoutItem item;
  final int index;
  final List<_CustomizationEntry> entries;
  final bool enabled;
  final Future<void> Function(String moduleId, int targetIndex) onMove;
  final Future<void> Function(String moduleId, bool isVisible)
  onVisibilityChanged;
  final Future<void> Function(String moduleId, bool isCollapsed)
  onCollapsedChanged;

  const _DashboardModuleCustomizationRow({
    super.key,
    required this.item,
    required this.index,
    required this.entries,
    required this.enabled,
    required this.onMove,
    required this.onVisibilityChanged,
    required this.onCollapsedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final descriptor = item.descriptor;
    final label = descriptor.customizationLabel;
    final description = descriptor.customizationDescription.trim().isEmpty
        ? 'Show this section on Today.'
        : descriptor.customizationDescription;
    final earlierTarget = index > 0 ? entries[index - 1].sourceIndex : null;
    final laterTarget = index < entries.length - 1
        ? entries[index + 1].sourceIndex
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                container: true,
                label: 'Reorder $label',
                hint: 'Drag to move this section earlier or later.',
                child: ReorderableDragStartListener(
                  index: index,
                  enabled: enabled,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.drag_handle_rounded),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  container: true,
                  label: label,
                  value: item.isVisible ? 'Shown' : 'Hidden',
                  hint: description,
                  child: SwitchListTile(
                    key: ValueKey('today-customize-toggle-${item.moduleId}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                    value: item.isVisible,
                    onChanged: enabled
                        ? (value) => unawaited(
                            onVisibilityChanged(item.moduleId, value),
                          )
                        : null,
                  ),
                ),
              ),
              _CustomizationMoreMenu(
                label: label,
                enabled: enabled,
                earlierTargetIndex: earlierTarget,
                laterTargetIndex: laterTarget,
                onMove: (targetIndex) => onMove(item.moduleId, targetIndex),
                collapsible: descriptor.collapsible,
                isCollapsed: item.isCollapsed,
                onCollapsedChanged: (value) =>
                    onCollapsedChanged(item.moduleId, value),
              ),
            ],
          ),
          const Divider(height: B05Layout.space16),
        ],
      ),
    );
  }
}

class _CustomizationMoreMenu extends StatelessWidget {
  const _CustomizationMoreMenu({
    required this.label,
    required this.enabled,
    required this.earlierTargetIndex,
    required this.laterTargetIndex,
    required this.onMove,
    required this.collapsible,
    required this.isCollapsed,
    required this.onCollapsedChanged,
  });

  final String label;
  final bool enabled;
  final int? earlierTargetIndex;
  final int? laterTargetIndex;
  final Future<void> Function(int targetIndex) onMove;
  final bool collapsible;
  final bool isCollapsed;
  final Future<void> Function(bool isCollapsed) onCollapsedChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _minimumTodayControlSize.width,
    height: _minimumTodayControlSize.height,
    child: PopupMenuButton<String>(
      enabled: enabled,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: 'More options for $label',
      onSelected: (value) {
        switch (value) {
          case 'earlier' when earlierTargetIndex != null:
            unawaited(onMove(earlierTargetIndex!));
          case 'later' when laterTargetIndex != null:
            unawaited(onMove(laterTargetIndex!));
          case 'collapse' when collapsible:
            unawaited(onCollapsedChanged(!isCollapsed));
        }
      },
      itemBuilder: (context) => [
        if (earlierTargetIndex != null)
          const PopupMenuItem<String>(
            value: 'earlier',
            child: Text('Move earlier'),
          ),
        if (laterTargetIndex != null)
          const PopupMenuItem<String>(
            value: 'later',
            child: Text('Move later'),
          ),
        if (collapsible)
          PopupMenuItem<String>(
            value: 'collapse',
            child: Text(isCollapsed ? 'Start expanded' : 'Start minimized'),
          ),
      ],
      icon: const Icon(Icons.more_horiz_rounded),
    ),
  );
}

class _ResetTodayCustomization extends StatelessWidget {
  const _ResetTodayCustomization({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: B05Layout.space4,
      bottom: B05Layout.space8,
    ),
    child: SizedBox(
      width: double.infinity,
      child: B05ActionButton(
        label: 'Reset to default',
        hint: 'Show the default Today sections again.',
        icon: Icons.refresh_rounded,
        emphasis: B05ActionEmphasis.secondary,
        onPressed: enabled ? () => unawaited(onPressed()) : null,
      ),
    ),
  );
}

class _CustomizationError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CustomizationError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Today customization unavailable: $message',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: B05Typography.body(context)),
        const SizedBox(height: B05Layout.space8),
        B05ActionButton(
          label: 'Retry',
          emphasis: B05ActionEmphasis.secondary,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}

class _CustomizationEntry {
  const _CustomizationEntry({required this.item, required this.sourceIndex});

  final DashboardModuleLayoutItem item;
  final int sourceIndex;
}

bool _sameLayout(
  List<DashboardModuleLayoutItem> left,
  List<DashboardModuleLayoutItem> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
