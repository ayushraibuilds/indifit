import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/consumer_number_label.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../food_log/food_log_surface.dart';
import '../../food_log/log_confirmation.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../../food_log/my_roti.dart';
import '../protein_nudge.dart';
import '../today_surface_controller.dart';
import '../weigh_in_reminder.dart';
import '../what_can_i_eat.dart';

/// Opens "What can I eat?" (TF-2 A) for [plan]. "+ Add" logs to [day] in
/// the meal for the time now, closes the sheet and shows the usual
/// confirmation with Undo. [onMoreIdeas] adds a link to the coaching card.
Future<void> showWhatCanIEatSheet(
  BuildContext context, {
  required WhatCanIEatPlan plan,
  required DateTime day,
  VoidCallback? onMoreIdeas,
}) => showIndiFitBottomSheet<void>(
  context: context,
  semanticLabel: 'What can I eat?',
  builder: (_) => WhatCanIEatSheet(
    plan: plan,
    day: day,
    hostContext: context,
    onMoreIdeas: onMoreIdeas,
  ),
);

class WhatCanIEatSheet extends ConsumerStatefulWidget {
  const WhatCanIEatSheet({
    super.key,
    required this.plan,
    required this.day,
    required this.hostContext,
    this.onMoreIdeas,
  });

  final WhatCanIEatPlan plan;
  final DateTime day;

  /// Where the confirmation shows once the sheet has closed.
  final BuildContext hostContext;
  final VoidCallback? onMoreIdeas;

  @override
  ConsumerState<WhatCanIEatSheet> createState() => _WhatCanIEatSheetState();
}

class _WhatCanIEatSheetState extends ConsumerState<WhatCanIEatSheet> {
  bool _busy = false;

  Future<void> _add(ProteinSuggestion suggestion) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final now = ref.read(weighInClockProvider)();
      final meal = MealPresentationRegistry.forLocalTime(now).stableId;
      final snapshot = await logOneCatalogueServing(
        ref,
        foodId: suggestion.foodId,
        mealCategory: meal,
        day: widget.day,
        quantity: suggestion.quantity,
      );
      if (!mounted || snapshot == null) return;
      ref.invalidate(canonicalFoodRecordsForDayProvider);
      ref.invalidate(foodDiaryReadModelProvider);
      ref.read(todayNutritionRevisionProvider.notifier).state++;
      ref.read(proteinNudgeRevisionProvider.notifier).state++;
      Navigator.of(context).pop();
      final host = widget.hostContext;
      if (!host.mounted) return;
      showLoggedFoodUndo(
        host,
        snapshot,
        amount: suggestion.amountLabel,
        name: suggestion.name,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('What can I eat add failed', error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final suggestions = plan.status == WhatCanIEatStatus.noTargets
        ? const <ProteinSuggestion>[]
        : ref.watch(whatCanIEatSuggestionsProvider(plan)).valueOrNull;
    final moreIdeas = widget.onMoreIdeas;
    return Padding(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        key: const Key('what_can_i_eat_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'What can I eat?',
                  style: B05Typography.title(context),
                ),
              ),
              B05IconAction(
                icon: Icons.close_rounded,
                label: 'Close what can I eat',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            plan.status == WhatCanIEatStatus.over &&
                    suggestions != null &&
                    suggestions.isEmpty
                ? "You're over today."
                : plan.headline,
            key: const Key('what_can_i_eat_headline'),
            style: B05Typography.body(context),
          ),
          if (suggestions == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: B05Layout.space16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (plan.status == WhatCanIEatStatus.open && suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: B05Layout.space8),
              child: Text(
                'Nothing from your foods or the staples fits what is left.',
                style: B05Typography.caption(context),
              ),
            ),
          for (final suggestion in suggestions ?? const <ProteinSuggestion>[])
            _SuggestionRow(
              suggestion: suggestion,
              onAdd: _busy ? null : () => unawaited(_add(suggestion)),
            ),
          if (moreIdeas != null) ...[
            const SizedBox(height: B05Layout.space8),
            TextButton(
              key: const Key('what_can_i_eat_more_ideas'),
              onPressed: () {
                Navigator.of(context).pop();
                moreIdeas();
              },
              child: const Text('More meal ideas'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onAdd});

  final ProteinSuggestion suggestion;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final facts =
        '${suggestion.amountLabel} · '
        '${ConsumerNumberLabel.rounded(suggestion.kcal)} kcal · '
        '${ConsumerNumberLabel.grams(suggestion.proteinGrams)} protein';
    return Padding(
      key: ValueKey('what_can_i_eat_${suggestion.foodId}'),
      padding: const EdgeInsets.only(top: B05Layout.space8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.name, style: B05Typography.body(context)),
                Text(facts, style: B05Typography.caption(context)),
              ],
            ),
          ),
          TextButton(
            onPressed: onAdd,
            child: Semantics(
              label: 'Add ${suggestion.name}',
              excludeSemantics: true,
              child: const Text('+ Add'),
            ),
          ),
        ],
      ),
    );
  }
}
