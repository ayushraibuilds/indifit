import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../food_log/food_log_surface.dart';
import '../../food_log/log_confirmation.dart';
import '../../food_log/my_chai.dart';
import '../../food_log/my_roti.dart';
import '../../food_log/usual_meal.dart';
import '../today_surface_controller.dart';

/// One-tap adds under a Today meal row: "+ Chai" on the snack row once My
/// chai is set up (UF-2), and "+1 roti" on any meal that has a roti (UF-3).
/// Shows nothing otherwise.
class TodayMealQuickAdds extends ConsumerStatefulWidget {
  const TodayMealQuickAdds({
    super.key,
    required this.mealType,
    required this.selectedDate,
    this.mealLogged = true,
  });

  final String mealType;

  /// Whether the meal has food; an empty meal has no roti to count, so its
  /// records aren't read.
  final bool mealLogged;
  final DateTime selectedDate;

  @override
  ConsumerState<TodayMealQuickAdds> createState() => _TodayMealQuickAddsState();
}

class _TodayMealQuickAddsState extends ConsumerState<TodayMealQuickAdds> {
  bool _busy = false;

  DateTime get _day => DateTime(
    widget.selectedDate.year,
    widget.selectedDate.month,
    widget.selectedDate.day,
  );

  void _refresh() {
    ref.invalidate(canonicalFoodRecordsForDayProvider);
    ref.invalidate(foodDiaryReadModelProvider);
    ref.read(todayNutritionRevisionProvider.notifier).state++;
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error, stackTrace) {
      AppLogger.error(failure, error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('$failure. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addChai(MyChaiSettings chai) => _run(() async {
    final snapshot = await logMyChai(
      ref,
      chai: chai,
      mealCategory: widget.mealType,
      day: _day,
    );
    if (!mounted) return;
    _refresh();
    showLoggedFoodUndo(context, snapshot, amount: '1 cup', name: kMyChaiName);
  }, "Couldn't add your chai");

  Future<void> _addRoti(String foodId, String label) => _run(() async {
    final snapshot = await logOneCatalogueServing(
      ref,
      foodId: foodId,
      mealCategory: widget.mealType,
      day: _day,
    );
    if (!mounted) return;
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('That roti is no longer in the food list.'),
        ),
      );
      return;
    }
    _refresh();
    showLoggedFoodUndo(context, snapshot, name: label, again: true);
  }, "Couldn't add a roti");

  @override
  Widget build(BuildContext context) {
    final chai = UsualMealFinder.slotOf(widget.mealType) == 'snack'
        ? ref.watch(myChaiSettingsProvider)
        : null;
    final records = widget.mealLogged
        ? ref.watch(canonicalFoodRecordsForDayProvider(_day)).valueOrNull
        : null;
    final roti = records == null ? null : rotiInMeal(records, widget.mealType);
    if (chai == null && roti == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 2),
      child: Wrap(
        spacing: 8,
        children: [
          if (chai != null)
            ActionChip(
              key: Key('today_add_chai_${widget.mealType}'),
              avatar: const Icon(Icons.local_cafe_outlined, size: 18),
              label: const Text('+ Chai'),
              tooltip: 'Add a cup of My chai',
              onPressed: _busy ? null : () => unawaited(_addChai(chai)),
            ),
          if (roti != null)
            ActionChip(
              key: Key('today_add_roti_${widget.mealType}'),
              label: const Text('+1 roti'),
              tooltip: 'Add one more ${roti.displayLabel}',
              onPressed: _busy
                  ? null
                  : () => unawaited(
                      _addRoti(roti.foodId!, roti.displayLabel!.trim()),
                    ),
            ),
        ],
      ),
    );
  }
}
