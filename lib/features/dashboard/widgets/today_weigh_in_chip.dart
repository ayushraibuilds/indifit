import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/local_schedule_date_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/adaptive_tdee_models.dart';
import '../../../data/repositories/workout_repository.dart';
import '../weigh_in_reminder.dart';
import 'log_weight_bottom_sheet.dart';

/// "Morning weigh-in" on Today (UR-29, UF-18): opens the weight sheet, or
/// "Not today" hides it until tomorrow.
class TodayWeighInChip extends ConsumerWidget {
  const TodayWeighInChip({super.key});

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(workoutRepositoryProvider);
    final latest = (await repository.getBodyMeasurements())
        .where((row) => row.weight != null)
        .firstOrNull;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await LogWeightBottomSheet.show(context, latest?.weight ?? 70, (
      weight,
    ) async {
      await repository.logWeightAndSyncProfile(weight: weight);
      ref.read(weighInRevisionProvider.notifier).state++;
      ref.invalidate(adaptiveTdeeEstimateProvider);
      try {
        final estimate = await ref.read(adaptiveTdeeEstimateProvider.future);
        final message = weighInLoggedMessage(estimate);
        messenger.showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
        );
      } on Object catch (error, stackTrace) {
        AppLogger.error('Expenditure after weigh-in failed', error, stackTrace);
      }
    });
  }

  Future<void> _notToday(WidgetRef ref) async {
    final prefs =
        sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
        await SharedPreferences.getInstance();
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final now = ref.read(weighInClockProvider)();
    await WeighInReminder.dismissFor(
      prefs,
      LocalScheduleDateService().localDateFor(now.toUtc(), timezoneId),
    );
    ref.read(weighInRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(weighInChipVisibleProvider).valueOrNull ?? false;
    if (!visible) return const SizedBox.shrink();
    return Card(
      key: const Key('today_weigh_in'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.monitor_weight_outlined),
              title: Text('Morning weigh-in'),
              subtitle: Text('Same time each day gives the truest trend.'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('today_weigh_in_not_today'),
                  onPressed: () => unawaited(_notToday(ref)),
                  child: const Text('Not today'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: const Key('today_weigh_in_log'),
                  onPressed: () => unawaited(_log(context, ref)),
                  child: const Text('Log weight'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The confirmation after a weigh-in, with the expenditure progress while
/// it's calibrating: "Weight logged. 3 more weigh-ins to calibrate your
/// expenditure."
String weighInLoggedMessage(AdaptiveTdeeEstimate estimate) {
  final needed = weighInsToCalibrate(estimate);
  if (needed == null) return 'Weight logged.';
  return 'Weight logged. $needed more '
      '${needed == 1 ? 'weigh-in' : 'weigh-ins'} to calibrate your '
      'expenditure.';
}
