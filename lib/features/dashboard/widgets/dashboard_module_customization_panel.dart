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

    final children = <Widget>[
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
      for (var index = 0; index < entries.length; index++)
        _DashboardModuleCustomizationRow(
          item: entries[index].item,
          index: index,
          count: entries.length,
          sourceIndex: entries[index].sourceIndex,
          enabled: !isSaving,
          onMove: onMove,
          onVisibilityChanged: onVisibilityChanged,
          onCollapsedChanged: onCollapsedChanged,
        ),
      if (onReset != null)
        _ResetTodayCustomization(
          enabled: canReset && !isSaving,
          onPressed: onReset!,
        ),
    ];

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
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
          'Use the switches to show or hide sections. You can change this anytime.',
          style: B05Typography.body(context),
        ),
      ],
    ),
  );
}

class _DashboardModuleCustomizationRow extends StatelessWidget {
  final DashboardModuleLayoutItem item;
  final int index;
  final int count;
  final int sourceIndex;
  final bool enabled;
  final Future<void> Function(String moduleId, int targetIndex) onMove;
  final Future<void> Function(String moduleId, bool isVisible)
  onVisibilityChanged;
  final Future<void> Function(String moduleId, bool isCollapsed)
  onCollapsedChanged;

  const _DashboardModuleCustomizationRow({
    required this.item,
    required this.index,
    required this.count,
    required this.sourceIndex,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: label,
            value: item.isVisible ? 'Shown' : 'Hidden',
            hint: description,
            child: SwitchListTile(
              key: ValueKey('today-customize-toggle-${item.moduleId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              subtitle: Text(description),
              value: item.isVisible,
              onChanged: enabled
                  ? (value) =>
                        unawaited(onVisibilityChanged(item.moduleId, value))
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (index > 0)
                B05IconAction(
                  icon: Icons.keyboard_arrow_up_rounded,
                  label: 'Move $label earlier',
                  onPressed: enabled
                      ? () => unawaited(onMove(item.moduleId, sourceIndex - 1))
                      : null,
                ),
              if (index < count - 1)
                B05IconAction(
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: 'Move $label later',
                  onPressed: enabled
                      ? () => unawaited(onMove(item.moduleId, sourceIndex + 1))
                      : null,
                ),
              if (descriptor.collapsible)
                SizedBox(
                  width: _minimumTodayControlSize.width,
                  height: _minimumTodayControlSize.height,
                  child: PopupMenuButton<String>(
                    enabled: enabled,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: 'More options for $label',
                    onSelected: (value) {
                      if (value == 'collapse') {
                        unawaited(
                          onCollapsedChanged(item.moduleId, !item.isCollapsed),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'collapse',
                        child: Text(
                          item.isCollapsed
                              ? 'Start expanded'
                              : 'Start minimized',
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ),
            ],
          ),
          const Divider(height: B05Layout.space16),
        ],
      ),
    );
  }
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
        label: 'Reset to defaults',
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
