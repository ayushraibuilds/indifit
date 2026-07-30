import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';

void main() {
  group('B01 civil local date service', () {
    test(
      'preserves local weekday across DST and does not use UTC day arithmetic',
      () {
        final dates = LocalScheduleDateService(
          nowUtc: () => DateTime.utc(2026, 3, 1),
        );
        expect(
          dates.occurrenceDate(
            activationLocalDate: '2026-03-02',
            timezoneId: 'America/New_York',
            programWeekOrdinal: 0,
            plannedWeekday: DateTime.sunday,
          ),
          '2026-03-08',
        );
        expect(
          dates.occurrenceDate(
            activationLocalDate: '2026-03-02',
            timezoneId: 'America/New_York',
            programWeekOrdinal: 1,
            plannedWeekday: DateTime.sunday,
          ),
          '2026-03-15',
        );
        expect(
          dates.addCalendarDays('2026-10-25', 'Europe/London', 7),
          '2026-11-01',
        );
      },
    );

    test('validates IANA zones and strict ISO civil dates', () {
      final dates = LocalScheduleDateService();
      expect(() => dates.normalizeLocalDate('2026-02-29'), throwsArgumentError);
      expect(() => dates.normalizeLocalDate('2026-2-03'), throwsArgumentError);
      expect(() => dates.validateTimezone('Mars/Olympus'), throwsArgumentError);
      expect(dates.normalizeLocalDate('2026-02-28'), '2026-02-28');
    });
  });
}
