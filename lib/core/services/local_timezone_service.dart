import 'package:flutter_timezone/flutter_timezone.dart';

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
    final value = (await _read()).trim();
    if (value.isEmpty) {
      throw const LocalTimezoneError(
        'missing_timezone_id',
        'The platform did not provide an IANA timezone identifier.',
      );
    }
    try {
      _dates.validateTimezone(value);
    } on ArgumentError catch (error) {
      throw LocalTimezoneError(
        'invalid_timezone_id',
        'The platform timezone is not a supported IANA identifier.',
        cause: error,
      );
    }
    return value;
  }

  static Future<String> _readPlatformTimezone() async {
    final timezone = await FlutterTimezone.getLocalTimezone();
    return timezone.identifier;
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
