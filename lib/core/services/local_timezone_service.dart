import 'package:flutter_timezone/flutter_timezone.dart';

import '../utils/app_logger.dart';
import 'local_schedule_date_service.dart';

typedef LocalTimezoneReader = Future<String> Function();

/// Resolves the platform's canonical IANA timezone identifier for new events.
///
/// `DateTime.timeZoneName` is intentionally not used: abbreviations such as
/// IST and PST are ambiguous and cannot preserve DST or historical day
/// boundaries.
class LocalTimezoneService {
  final LocalTimezoneReader _read;
  final LocalScheduleDateService _dates;

  LocalTimezoneService({
    LocalTimezoneReader? read,
    LocalScheduleDateService? dates,
  }) : _read = read ?? _readPlatformTimezone,
       _dates = dates ?? LocalScheduleDateService();

  Future<String> currentTimezoneId() async {
    final raw = (await _readSafely()).trim();
    if (raw.isEmpty) {
      final fallback = _resolveFallbackFromDeviceOffset();
      AppLogger.warning(
        'The platform provided an empty timezone identifier. Falling back to "$fallback".',
      );
      return fallback;
    }

    final normalized = LocalScheduleDateService.normalizeTimezoneId(raw);
    try {
      _dates.validateTimezone(normalized);
      return normalized;
    } on ArgumentError catch (error) {
      final fallback = _resolveFallbackFromDeviceOffset();
      AppLogger.warning(
        'The platform timezone "$raw" is not recognized. Falling back to "$fallback": $error',
      );
      return fallback;
    }
  }

  Future<String> _readSafely() async {
    try {
      return await _read();
    } catch (e) {
      AppLogger.warning('Failed to read platform timezone: $e');
      return '';
    }
  }

  static String _resolveFallbackFromDeviceOffset() {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();

    if (hours == 5 && minutes == 30) return 'Asia/Kolkata';
    if (hours == 0 && minutes == 0) return 'UTC';
    if (hours == -5 && minutes == 0) return 'America/New_York';
    if (hours == -8 && minutes == 0) return 'America/Los_Angeles';
    if (hours == 1 && minutes == 0) return 'Europe/London';
    if (hours == 2 && minutes == 0) return 'Europe/Paris';
    if (hours == 8 && minutes == 0) return 'Asia/Singapore';
    if (hours == 9 && minutes == 0) return 'Asia/Tokyo';
    return 'Asia/Kolkata';
  }

  static Future<String> _readPlatformTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      return timezone.identifier;
    } catch (e) {
      AppLogger.warning('FlutterTimezone.getLocalTimezone failed: $e');
      return '';
    }
  }
}

class LocalTimezoneError implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const LocalTimezoneError(this.code, this.message, {this.cause});

  @override
  String toString() => 'LocalTimezoneError($code): $message';
}
