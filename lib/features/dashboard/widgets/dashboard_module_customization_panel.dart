import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard_module_registry.dart';
import '../dashboard_personalization_controller.dart';

const _minimumDashboardControlSize = Size(48, 48);

/// The non-drag dashboard customization surface. It gives keyboard and screen
/// reader users the same reorder, visibility, and collapse operations a later
/// drag affordance may offer, without treating a gesture as the only path.
class DashboardModuleCustomizationPanel extends ConsumerWidget {
  const DashboardModuleCustomizationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardPersonalizationControllerProvider);
    final controller = ref.read(
      dashboardPersonalizationControllerProvider.notifier,
    );
    return Semantics(
      container: true,
      label: 'Customize Today dashboard',
      child: switch (state.status) {
        DashboardPersonalizationStatus.loading => Center(
          child: Semantics(
            label: 'Loading dashboard customization',
            liveRegion: true,
            child: CircularProgressIndicator(),
          ),
        ),
        DashboardPersonalizationStatus.error => _CustomizationError(
          message:
              state.errorMessage ?? 'Dashboard customization is unavailable.',
          onRetry: controller.retry,
        ),
        _ => DashboardModuleCustomizationList(
          layout: state.layout,
          isSaving: state.isSaving,
          onMove: controller.reorder,
          onVisibilityChanged: controller.setVisible,
          onCollapsedChanged: controller.setCollapsed,
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

  const DashboardModuleCustomizationList({
    required this.layout,
    required this.isSaving,
    required this.onMove,
    required this.onVisibilityChanged,
    required this.onCollapsedChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (layout.isEmpty) {
      return Semantics(
        label: 'No dashboard modules are available to customize',
        child: SizedBox.shrink(),
      );
    }
    final savingOffset = isSaving ? 1 : 0;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: layout.length + savingOffset,
        itemBuilder: (context, index) {
          if (isSaving && index == 0) {
            return Semantics(
              liveRegion: true,
              label: 'Saving dashboard customization',
              child: const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              ),
            );
          }
          final layoutIndex = index - savingOffset;
          final item = layout[layoutIndex];
          return FocusTraversalOrder(
            order: NumericFocusOrder(layoutIndex.toDouble()),
            child: _DashboardModuleCustomizationRow(
              item: item,
              index: layoutIndex,
              count: layout.length,
              enabled: !isSaving,
              onMove: onMove,
              onVisibilityChanged: onVisibilityChanged,
              onCollapsedChanged: onCollapsedChanged,
            ),
          );
        },
      ),
    );
  }
}

class _DashboardModuleCustomizationRow extends StatelessWidget {
  final DashboardModuleLayoutItem item;
  final int index;
  final int count;
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
    required this.enabled,
    required this.onMove,
    required this.onVisibilityChanged,
    required this.onCollapsedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final descriptor = item.descriptor;
    final stateDescription = [
      item.isVisible ? 'Visible' : 'Hidden',
      if (descriptor.collapsible) item.isCollapsed ? 'Collapsed' : 'Expanded',
      'Position ${index + 1} of $count',
    ].join(', ');
    return Semantics(
      container: true,
      label: descriptor.customizationLabel,
      value: stateDescription,
      hint: 'Open more options to move, show, hide, or collapse this module.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          // Reordering is exposed through the accessible overflow actions.
          // Avoid a drag affordance when the row itself is not draggable.
          leading: const Icon(Icons.widgets_outlined),
          title: Text(descriptor.label),
          subtitle: Text(
            [
              item.isVisible ? 'Visible' : 'Hidden',
              if (descriptor.collapsible)
                item.isCollapsed ? 'Starts collapsed' : 'Starts expanded',
              'Position ${index + 1} of $count',
            ].join(' · '),
          ),
          trailing: SizedBox(
            width: 48,
            height: 48,
            child: PopupMenuButton<String>(
              enabled: enabled,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: 'More options for ${descriptor.customizationLabel}',
              onSelected: (value) {
                switch (value) {
                  case 'up' when index > 0:
                    unawaited(onMove(item.moduleId, index - 1));
                  case 'down' when index < count - 1:
                    unawaited(onMove(item.moduleId, index + 1));
                  case 'visibility':
                    unawaited(
                      onVisibilityChanged(item.moduleId, !item.isVisible),
                    );
                  case 'collapse' when descriptor.collapsible:
                    unawaited(
                      onCollapsedChanged(item.moduleId, !item.isCollapsed),
                    );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'up',
                  enabled: index > 0,
                  child: Text('Move ${descriptor.customizationLabel} up'),
                ),
                PopupMenuItem<String>(
                  value: 'down',
                  enabled: index < count - 1,
                  child: Text('Move ${descriptor.customizationLabel} down'),
                ),
                PopupMenuItem<String>(
                  value: 'visibility',
                  child: Text(item.isVisible ? 'Hide' : 'Show'),
                ),
                if (descriptor.collapsible)
                  PopupMenuItem<String>(
                    value: 'collapse',
                    child: Text(
                      item.isCollapsed ? 'Start expanded' : 'Start collapsed',
                    ),
                  ),
              ],
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomizationError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CustomizationError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Dashboard customization unavailable: $message',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            minimumSize: _minimumDashboardControlSize,
          ),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
