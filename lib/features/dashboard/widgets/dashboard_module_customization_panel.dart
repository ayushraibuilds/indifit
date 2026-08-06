import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard_module_registry.dart';
import '../dashboard_personalization_controller.dart';

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
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: layout.length,
        itemBuilder: (context, index) {
          final item = layout[index];
          return FocusTraversalOrder(
            order: NumericFocusOrder(index.toDouble()),
            child: _DashboardModuleCustomizationRow(
              item: item,
              index: index,
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
      hint:
          'Use visibility, collapse, and move controls to customize this module.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptor.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Semantics(
                  label: 'Move ${descriptor.customizationLabel} up',
                  hint: 'Moves this module one position earlier.',
                  button: true,
                  enabled: enabled && index > 0,
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: enabled && index > 0
                        ? () => onMove(item.moduleId, index - 1)
                        : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ),
                Semantics(
                  label: 'Move ${descriptor.customizationLabel} down',
                  hint: 'Moves this module one position later.',
                  button: true,
                  enabled: enabled && index < count - 1,
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: enabled && index < count - 1
                        ? () => onMove(item.moduleId, index + 1)
                        : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ),
                Semantics(
                  label:
                      '${item.isVisible ? 'Hide' : 'Show'} ${descriptor.customizationLabel}',
                  button: true,
                  enabled: enabled,
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: enabled
                        ? () => onVisibilityChanged(
                            item.moduleId,
                            !item.isVisible,
                          )
                        : null,
                    child: Text(item.isVisible ? 'Hide' : 'Show'),
                  ),
                ),
                if (descriptor.collapsible)
                  Semantics(
                    label:
                        '${item.isCollapsed ? 'Expand' : 'Collapse'} ${descriptor.customizationLabel}',
                    button: true,
                    enabled: enabled,
                    excludeSemantics: true,
                    child: OutlinedButton(
                      onPressed: enabled
                          ? () => onCollapsedChanged(
                              item.moduleId,
                              !item.isCollapsed,
                            )
                          : null,
                      child: Text(item.isCollapsed ? 'Expand' : 'Collapse'),
                    ),
                  ),
              ],
            ),
          ],
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
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
