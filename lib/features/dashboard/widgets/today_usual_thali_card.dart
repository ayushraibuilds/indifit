import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition_legacy_read_models.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/indi_fit_feedback.dart';
import '../../food_log/food_log_surface.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../../food_log/repeat_meal.dart';
import '../../food_log/usual_thali.dart';
import '../today_surface_controller.dart';

/// "Your usual thali" on Today: one tap logs the plate someone logs most
/// into the meal for this time of day. Hidden when there's no usual plate,
/// or when it's already in that meal today.
class TodayUsualThaliCard extends ConsumerStatefulWidget {
  const TodayUsualThaliCard({super.key, this.now});

  /// Fixed in tests; otherwise the current time.
  final DateTime Function()? now;

  @override
  ConsumerState<TodayUsualThaliCard> createState() =>
      _TodayUsualThaliCardState();
}

class _TodayUsualThaliCardState extends ConsumerState<TodayUsualThaliCard> {
  bool _logging = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  Future<void> _log(UsualThali usual, FoodMealPresentation meal) async {
    setState(() => _logging = true);
    try {
      final outcome = await repeatMealRecords(
        ref,
        mealType: meal.stableId,
        records: [usual.record],
        targetDay: _now(),
      );
      if (!mounted) return;
      ref.read(todayNutritionRevisionProvider.notifier).state++;
      if (outcome.thalis > 0) {
        showIndiFitSuccessFeedback(
          context,
          'Logged your usual thali to ${meal.label.toLowerCase()}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'That thali changed since it was logged. Open the thali '
              'builder to log it.',
            ),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      AppLogger.error('Logging the usual thali failed', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Couldn\'t log your usual thali. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usual = ref.watch(usualThaliProvider).valueOrNull;
    if (usual == null) return const SizedBox.shrink();
    final now = _now();
    final meal = MealPresentationRegistry.forLocalTime(now);
    final today = ref
        .watch(
          canonicalFoodRecordsForDayProvider(
            DateTime(now.year, now.month, now.day),
          ),
        )
        .valueOrNull;
    if (today == null) return const SizedBox.shrink();
    final alreadyLogged = today.any(
      (record) =>
          record is NutritionCanonicalSnapshotReadModel &&
          record.snapshot.sourceType == 'thali' &&
          record.mealCategory == meal.stableId &&
          UsualThaliFinder.signatureOf(record) == usual.signature,
    );
    if (alreadyLogged) return const SizedBox.shrink();

    final items = usual.itemLabels.take(3).join(', ');
    final more = usual.itemLabels.length > 3
        ? ' +${usual.itemLabels.length - 3} more'
        : '';
    final kcal = usual.kcal == null ? '' : ' · ${usual.kcal!.round()} kcal';
    return Card(
      key: const Key('today_usual_thali'),
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        leading: const Icon(Icons.restaurant_rounded),
        title: Text('Your usual thali$kcal'),
        subtitle: Text(
          '$items$more',
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
                key: const Key('today_usual_thali_log'),
                onPressed: () => unawaited(_log(usual, meal)),
                child: Text('Log to ${meal.label.toLowerCase()}'),
              ),
      ),
    );
  }
}
