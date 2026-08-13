import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import 'food_contextual_action_controller.dart';
import 'meal_presentation_registry.dart';
import 'widgets/edit_food_log_sheet.dart';

/// A B05 contextual food row. The swipe opens the same action menu exposed by
/// the accessible buttons; Dismissible never removes the row by itself.
class FoodContextualActions extends ConsumerStatefulWidget {
  const FoodContextualActions({required this.log, super.key, this.onChanged});

  final FoodLog log;
  final VoidCallback? onChanged;

  @override
  ConsumerState<FoodContextualActions> createState() =>
      _FoodContextualActionsState();
}

class _FoodContextualActionsState extends ConsumerState<FoodContextualActions> {
  FoodLog get _log => widget.log;

  FoodContextualActionController get _controller =>
      ref.read(foodContextualActionControllerProvider(_log).notifier);

  Future<void> _edit() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: EditFoodLogSheet(
          log: _log,
          onSave:
              ({
                required int id,
                required String name,
                required int calories,
                required double proteinG,
                required double carbsG,
                required double fatG,
                required double servingLogged,
              }) async {
                await _controller.edit(
                  FoodLogEditValues(
                    name: name,
                    calories: calories,
                    proteinG: proteinG,
                    carbsG: carbsG,
                    fatG: fatG,
                    servingLogged: servingLogged,
                  ),
                );
                widget.onChanged?.call();
                if (mounted) _showSuccess('Food entry updated.');
              },
        ),
      ),
    );
  }

  Future<void> _copy() async {
    await _controller.copy();
    if (!mounted) return;
    final state = ref.read(foodContextualActionControllerProvider(_log));
    if (state.status == FoodContextualActionStatus.success) {
      widget.onChanged?.call();
      _showSuccess('Food entry copied.');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete food entry?'),
        content: Text('Remove “${_log.name}” from this logged meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.delete();
    if (!mounted) return;
    final state = ref.read(foodContextualActionControllerProvider(_log));
    if (state.status == FoodContextualActionStatus.success) {
      widget.onChanged?.call();
      final offer = state.undoOffer;
      if (offer != null) _showUndo(offer);
    }
  }

  Future<void> _showActionMenu() async {
    final action = await showModalBottomSheet<_FoodMenuAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(B05Layout.space16),
          child: B05ActionGroup(
            children: [
              B05ActionButton(
                label: 'Edit food entry',
                icon: Icons.edit_outlined,
                onPressed: () =>
                    Navigator.pop(sheetContext, _FoodMenuAction.edit),
              ),
              B05ActionButton(
                label: 'Copy food entry',
                icon: Icons.copy_outlined,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: () =>
                    Navigator.pop(sheetContext, _FoodMenuAction.copy),
              ),
              B05ActionButton(
                label: 'Delete food entry',
                icon: Icons.delete_outline,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: () =>
                    Navigator.pop(sheetContext, _FoodMenuAction.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _FoodMenuAction.edit:
        await _edit();
      case _FoodMenuAction.copy:
        await _copy();
      case _FoodMenuAction.delete:
        await _delete();
      case null:
        break;
    }
  }

  void _showUndo(FoodDeleteUndoOffer offer) {
    final messenger = ScaffoldMessenger.of(context);
    final duration = offer.expiresAtUtc.difference(DateTime.now().toUtc());
    final snackBar = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: const Text('Food entry deleted.'),
        duration: duration.isNegative ? const Duration(seconds: 1) : duration,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(_undo()),
        ),
      ),
    );
    unawaited(
      snackBar.closed.then((_) {
        if (mounted) {
          ref
              .read(foodContextualActionControllerProvider(_log).notifier)
              .expireUndo();
        }
      }),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Future<void> _undo() async {
    await _controller.undo();
    if (!mounted) return;
    final state = ref.read(foodContextualActionControllerProvider(_log));
    if (state.status == FoodContextualActionStatus.success) {
      widget.onChanged?.call();
    }
  }

  Future<bool> _onSwipe(DismissDirection direction) async {
    final state = ref.read(foodContextualActionControllerProvider(_log));
    if (state.isPending) return false;
    await _showActionMenu();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodContextualActionControllerProvider(_log));
    final presentation = foodMealPresentationFor(_log.mealType);
    final colors = context.b05Colors;
    final role = presentation.accent == null
        ? colors.info
        : colors.meal(presentation.accent!);
    final busy = state.isPending;
    final status = state.status;

    return Semantics(
      container: true,
      label: '${presentation.label}: ${_log.name}',
      value: '${_log.servingLogged} ${_log.servingUnit}; ${_log.calories} kcal',
      hint:
          'Swipe to open food actions. Edit, copy and delete buttons provide the same actions.',
      child: Dismissible(
        key: ValueKey('food-contextual-${_log.id}'),
        direction: DismissDirection.horizontal,
        movementDuration: B05MotionPolicy.transitionDuration(context),
        confirmDismiss: _onSwipe,
        background: _FoodSwipeBackground(
          label: 'Food actions',
          icon: Icons.more_horiz_rounded,
          role: role,
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _FoodSwipeBackground(
          label: 'Food actions',
          icon: Icons.more_horiz_rounded,
          role: role,
          alignment: Alignment.centerRight,
        ),
        child: B05Surface(
          padding: const EdgeInsets.all(B05Layout.space12),
          radius: B05SurfaceRadius.small,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: role.container,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(B05Layout.space8),
                        child: Icon(
                          presentation.icon,
                          color: role.indicator,
                          size: B05Layout.iconMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: B05Layout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_log.name, style: B05Typography.title(context)),
                          const SizedBox(height: B05Layout.space4),
                          Text(
                            '${presentation.label} · ${_log.servingLogged} ${_log.servingUnit} · ${_log.calories} kcal',
                            style: B05Typography.body(context),
                          ),
                        ],
                      ),
                    ),
                    B05IconAction(
                      icon: Icons.more_horiz_rounded,
                      label: 'More food actions for ${_log.name}',
                      hint: 'Opens edit, copy and delete actions.',
                      onPressed: busy ? null : _showActionMenu,
                      focusOrder: 4,
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space12),
                B05ActionGroup(
                  children: [
                    B05ActionButton(
                      label: 'Edit food',
                      hint: 'Edit this entry through the existing food editor.',
                      icon: Icons.edit_outlined,
                      onPressed: busy ? null : _edit,
                      focusOrder: 1,
                    ),
                    B05ActionButton(
                      label: 'Copy food',
                      hint: 'Copy this entry into the same meal.',
                      icon: Icons.copy_outlined,
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: busy ? null : _copy,
                      focusOrder: 2,
                    ),
                    B05ActionButton(
                      label: 'Delete food',
                      hint: 'Confirm before deleting this entry.',
                      icon: Icons.delete_outline,
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: busy ? null : _delete,
                      focusOrder: 3,
                    ),
                  ],
                ),
                if (busy) ...[
                  const SizedBox(height: B05Layout.space8),
                  const B05StatusMessage(
                    status: B05SemanticStatus.info,
                    label: 'Updating food entry',
                    value: 'Please wait before trying another action.',
                  ),
                ],
                if (status == FoodContextualActionStatus.failure ||
                    status == FoodContextualActionStatus.unavailable) ...[
                  const SizedBox(height: B05Layout.space8),
                  B05StatusMessage(
                    status: status == FoodContextualActionStatus.failure
                        ? B05SemanticStatus.danger
                        : B05SemanticStatus.unavailable,
                    label: status == FoodContextualActionStatus.failure
                        ? 'Food action failed'
                        : 'Food action unavailable',
                    value: state.message,
                  ),
                  if (state.canRetry) ...[
                    const SizedBox(height: B05Layout.space8),
                    B05ActionButton(
                      label: 'Retry food action',
                      icon: Icons.refresh_rounded,
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: busy ? null : _controller.retry,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _FoodMenuAction { edit, copy, delete }

class _FoodSwipeBackground extends StatelessWidget {
  const _FoodSwipeBackground({
    required this.label,
    required this.icon,
    required this.role,
    required this.alignment,
  });

  final String label;
  final IconData icon;
  final B05ColorRole role;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space16),
        decoration: BoxDecoration(
          color: role.container,
          borderRadius: B05Radii.smallRadius,
          border: Border.all(color: role.indicator),
        ),
        child: Icon(icon, color: role.indicator),
      ),
    );
  }
}
