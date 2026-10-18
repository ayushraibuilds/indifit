import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../dashboard/weigh_in_reminder.dart';

/// "Weigh-in days" (UR-29): the mornings Today offers a weigh-in. Every day
/// until changed; it is a Today card, not a notification.
class WeighInDaysSetting extends ConsumerStatefulWidget {
  const WeighInDaysSetting({super.key});

  @override
  ConsumerState<WeighInDaysSetting> createState() => _WeighInDaysSettingState();
}

class _WeighInDaysSettingState extends ConsumerState<WeighInDaysSetting> {
  List<int>? _days;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<SharedPreferences> _prefs() async =>
      sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
      await SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _prefs().then((prefs) {
      if (mounted) setState(() => _days = WeighInReminder.days(prefs));
    });
  }

  Future<void> _toggle(int day) async {
    final days = {...?_days};
    days.contains(day) ? days.remove(day) : days.add(day);
    final next = days.toList()..sort();
    setState(() => _days = next);
    await WeighInReminder.setDays(await _prefs(), next);
    ref.read(weighInRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weigh-in days', style: B05Typography.label(context)),
        const SizedBox(height: 4),
        Text(
          days == null
              ? ''
              : days.length == 7
              ? 'Today offers a weigh-in every morning until noon.'
              : days.isEmpty
              ? 'Today won’t offer a weigh-in.'
              : 'Today offers a weigh-in on these mornings until noon.',
          style: B05Typography.caption(context),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (var day = 1; day <= 7; day++)
              Semantics(
                label: _names[day - 1],
                child: FilterChip(
                  key: Key('weigh_in_day_$day'),
                  label: Text(_labels[day - 1]),
                  selected: days?.contains(day) ?? false,
                  onSelected: days == null ? null : (_) => _toggle(day),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
