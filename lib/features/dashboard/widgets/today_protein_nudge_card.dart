import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_preferences_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/services/local_schedule_date_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../food_log/food_log_surface.dart';
import '../../food_log/log_confirmation.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../../food_log/my_roti.dart';
import '../protein_nudge.dart';
import '../today_surface_controller.dart';
import '../weigh_in_reminder.dart';

/// "You're 42 g short of protein. Paneer bhurji (1 katori) = 18 g · Add"
/// on Today in the evening (UF-5). "Not today" hides it until tomorrow.
class TodayProteinNudgeCard extends ConsumerStatefulWidget {
  const TodayProteinNudgeCard({
    super.key,
    required this.proteinTarget,
    required this.proteinEaten,
    required this.kcalTarget,
    required this.kcalEaten,
  });

  final double? proteinTarget;
  final double? proteinEaten;
  final double? kcalTarget;
  final double? kcalEaten;

  @override
  ConsumerState<TodayProteinNudgeCard> createState() =>
      _TodayProteinNudgeCardState();
}

class _TodayProteinNudgeCardState extends ConsumerState<TodayProteinNudgeCard> {
  String? _dismissed;
  String? _today;
  bool _busy = false;

  Future<SharedPreferences> _prefs() async =>
      sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
      await SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    // Every ref read happens before the first await: the card can leave
    // the tree while they run.
    final timezones = ref.read(localTimezoneServiceProvider);
    final now = ref.read(weighInClockProvider)();
    final prefsFuture = _prefs();
    final prefs = await prefsFuture;
    final timezoneId = await timezones.currentTimezoneId();
    if (!mounted) return;
    setState(() {
      _today = LocalScheduleDateService().localDateFor(now.toUtc(), timezoneId);
      _dismissed = prefs.getString(
        AppPreferenceKeys.prefProteinNudgeDismissedDate,
      );
    });
  }

  Future<void> _notToday() async {
    final today = _today;
    if (today == null) return;
    final prefs = _prefs();
    await dismissProteinNudge(await prefs, today);
    if (mounted) setState(() => _dismissed = today);
  }

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
        day: now,
        quantity: suggestion.quantity,
      );
      if (!mounted || snapshot == null) return;
      ref.invalidate(canonicalFoodRecordsForDayProvider);
      ref.invalidate(foodDiaryReadModelProvider);
      ref.read(todayNutritionRevisionProvider.notifier).state++;
      ref.read(proteinNudgeRevisionProvider.notifier).state++;
      showLoggedFoodUndo(
        context,
        snapshot,
        amount: suggestion.amountLabel,
        name: suggestion.name,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('Protein nudge add failed', error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    if (today == null) return const SizedBox.shrink();
    final now = ref.watch(weighInClockProvider)();
    if (!ProteinNudge.shouldShow(
      localNow: now,
      proteinTarget: widget.proteinTarget,
      proteinEaten: widget.proteinEaten,
      dismissedDate: _dismissed,
      todayLocalDate: today,
    )) {
      return const SizedBox.shrink();
    }
    final gap = widget.proteinTarget! - (widget.proteinEaten ?? 0);
    final remainingKcal = widget.kcalTarget == null
        ? null
        : widget.kcalTarget! - (widget.kcalEaten ?? 0);
    final suggestions = ref
        .watch(
          proteinSuggestionsProvider((gap: gap, remainingKcal: remainingKcal)),
        )
        .valueOrNull;
    if (suggestions == null || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const Key('today_protein_nudge'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ProteinNudge.headline(gap),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final suggestion in suggestions)
              Row(
                key: ValueKey('protein_nudge_${suggestion.foodId}'),
                children: [
                  Expanded(child: Text(suggestion.line)),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_add(suggestion)),
                    child: const Text('Add'),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('today_protein_nudge_not_today'),
                onPressed: () => unawaited(_notToday()),
                child: const Text('Not today'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
