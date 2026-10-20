import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../progress/weekly_check_in_screen.dart';
import '../check_in_reminder.dart';
import '../weigh_in_reminder.dart';

/// The weekly check-in on Today (R-5): Sunday afternoon and Monday morning.
/// "Open" shows the check-in; "Not now" hides it for that week.
class TodayCheckInCard extends ConsumerWidget {
  const TodayCheckInCard({super.key});

  Future<void> _notNow(WidgetRef ref) async {
    final prefs =
        sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
        await SharedPreferences.getInstance();
    final weekStart = await checkInWeekStart(
      ref.read(weighInClockProvider)(),
      ref.read(localTimezoneServiceProvider),
    );
    await CheckInReminder.dismissFor(prefs, weekStart);
    ref.read(checkInRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(checkInCardTitleProvider).valueOrNull;
    if (title == null) return const SizedBox.shrink();
    return Card(
      key: const Key('today_check_in'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_note_outlined),
              title: Text(title),
              subtitle: const Text('Workouts, protein and weight, Mon–Sun.'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('today_check_in_not_now'),
                  onPressed: () => unawaited(_notNow(ref)),
                  child: const Text('Not now'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: const Key('today_check_in_open'),
                  onPressed: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WeeklyCheckInScreen(),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
