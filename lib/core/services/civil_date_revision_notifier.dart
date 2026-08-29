import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_schedule_date_service.dart';

/// Emits one revision at each local civil-date boundary.
///
/// This is a date-boundary signal, not a polling refresh loop. Consumers still
/// derive their state from B01/B02 repositories; the one-shot timer only tells
/// them that a date-keyed read must be performed again while the app remains
/// open in the foreground. App resume calls [refresh] as a second guard for
/// sleep, clock, and timezone changes.
class CivilDateRevisionNotifier extends StateNotifier<int> {
  CivilDateRevisionNotifier({
    required LocalScheduleDateService dates,
    required Future<String> Function() timezoneId,
  }) : _dates = dates,
       _timezoneId = timezoneId,
       super(0);

  final LocalScheduleDateService _dates;
  final Future<String> Function() _timezoneId;
  Timer? _timer;
  String? _timezone;
  var _started = false;

  /// Starts the one-shot civil-midnight scheduler owned by the application
  /// lifecycle host. Read-model consumers can use this provider without
  /// creating a long-lived timer in tests or embedded feature surfaces.
  void start() {
    if (!mounted || _started) return;
    _started = true;
    unawaited(_loadTimezoneAndSchedule());
  }

  /// Re-checks the timezone and invalidates date-scoped consumers after app
  /// resume. The revision contains no domain data and is never persisted.
  void refresh() {
    if (!mounted) return;
    state++;
    if (_started) unawaited(_loadTimezoneAndSchedule());
  }

  Future<void> _loadTimezoneAndSchedule() async {
    try {
      final timezone = await _timezoneId();
      if (!mounted) return;
      _timezone = timezone;
      _scheduleNextBoundary();
    } catch (_) {
      // The feature providers retain their existing error/loading behavior if
      // timezone resolution is unavailable. A later app resume retries it.
    }
  }

  void _scheduleNextBoundary() {
    final timezone = _timezone;
    if (!mounted || timezone == null) return;
    _timer?.cancel();
    final nowUtc = _dates.nowUtc();
    final today = _dates.todayIn(timezone);
    final tomorrow = _dates.addCalendarDays(today, timezone, 1);
    final nextMidnightUtc = _dates.instantForLocalDate(
      tomorrow,
      timezone,
      hour: 0,
    );
    final delay = nextMidnightUtc.difference(nowUtc);
    _timer = Timer(
      delay.isNegative || delay == Duration.zero
          ? const Duration(milliseconds: 100)
          : delay,
      () {
        if (!mounted) return;
        state++;
        _scheduleNextBoundary();
      },
    );
  }

  @override
  void dispose() {
    _started = false;
    _timer?.cancel();
    super.dispose();
  }
}
