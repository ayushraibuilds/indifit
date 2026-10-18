import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../food_log/food_log_surface.dart';
import '../../food_log/log_confirmation.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../../food_log/repeat_meal.dart';
import '../../food_log/usual_meal.dart';
import '../today_surface_controller.dart';
import 'today_usual_thali_card.dart';

/// "Your usual breakfast: Poha + Chai · 305 kcal · Log" on Today (UF-1).
/// One card for the meal at this time of day, hidden once that meal has
/// anything logged today. With no usual meal for the slot, the usual thali
/// card (#84) shows instead.
class TodayUsualMealCard extends ConsumerStatefulWidget {
  const TodayUsualMealCard({super.key, this.now});

  /// Fixed in tests; otherwise the current time.
  final DateTime Function()? now;

  @override
  ConsumerState<TodayUsualMealCard> createState() => _TodayUsualMealCardState();
}

class _TodayUsualMealCardState extends ConsumerState<TodayUsualMealCard> {
  bool _logging = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  Future<void> _log(UsualMeal usual) async {
    setState(() => _logging = true);
    try {
      final outcome = await repeatMealRecords(
        ref,
        mealType: usual.mealCategory,
        records: usual.records,
        targetDay: _now(),
      );
      if (!mounted) return;
      ref.read(todayNutritionRevisionProvider.notifier).state++;
      if (outcome.logged == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'That meal changed since it was logged. Add it from search.',
            ),
          ),
        );
        return;
      }
      final meal = loggedMealLabel(usual.mealCategory);
      final kcal = usual.kcal == null ? '' : ' · ${usual.kcal!.round()} kcal';
      final note = outcome.skippedNote == null
          ? ''
          : ' (${outcome.skippedNote})';
      showLoggedSnapshotsUndo(
        context,
        outcome.snapshots,
        message: 'Added your usual: ${usual.title}$kcal to $meal$note',
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('Logging the usual meal failed', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Couldn\'t log your usual meal. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final slot = UsualMealFinder.slotAt(now);
    final usualState = ref.watch(usualMealProvider(slot));
    if (usualState.isLoading) return const SizedBox.shrink();
    final usual = usualState.valueOrNull;
    if (usual == null) return TodayUsualThaliCard(now: widget.now);

    final today = ref
        .watch(
          canonicalFoodRecordsForDayProvider(
            DateTime(now.year, now.month, now.day),
          ),
        )
        .valueOrNull;
    if (today == null) return const SizedBox.shrink();
    final slotLogged = today.any(
      (record) => UsualMealFinder.slotOf(record.mealCategory) == slot,
    );
    if (slotLogged) return const SizedBox.shrink();

    final slotLabel = MealPresentationRegistry.forLocalTime(
      now,
    ).label.toLowerCase();
    final kcal = usual.kcal == null ? '' : ' · ${usual.kcal!.round()} kcal';
    return Card(
      key: const Key('today_usual_meal'),
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        leading: const Icon(Icons.restaurant_rounded),
        title: Text('Your usual $slotLabel'),
        subtitle: Text(
          '${usual.title}$kcal',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _logging
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                key: const Key('today_usual_meal_log'),
                onPressed: () => unawaited(_log(usual)),
                child: const Text('Log'),
              ),
      ),
    );
  }
}
