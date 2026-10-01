import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/training/training_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalScheduleDateService timezone normalization', () {
    test('normalizes legacy and regional aliases to canonical IANA IDs', () {
      expect(
        LocalScheduleDateService.normalizeTimezoneId('Asia/Calcutta'),
        'Asia/Kolkata',
      );
      expect(
        LocalScheduleDateService.normalizeTimezoneId('IST'),
        'Asia/Kolkata',
      );
      expect(
        LocalScheduleDateService.normalizeTimezoneId('GMT+05:30'),
        'Asia/Kolkata',
      );
      expect(
        LocalScheduleDateService.normalizeTimezoneId('UTC+05:30'),
        'Asia/Kolkata',
      );
      expect(
        LocalScheduleDateService.normalizeTimezoneId('+05:30'),
        'Asia/Kolkata',
      );
      expect(
        LocalScheduleDateService.normalizeTimezoneId('Asia/Katmandu'),
        'Asia/Kathmandu',
      );
      expect(
        LocalScheduleDateService.normalizeTimezoneId('US/Pacific'),
        'America/Los_Angeles',
      );
      expect(
        LocalScheduleDateService.normalizeTimezoneId('US/Eastern'),
        'America/New_York',
      );
      expect(LocalScheduleDateService.normalizeTimezoneId('UTC'), 'UTC');
    });

    test('locationFor resolves Aliases smoothly without throwing', () {
      final dates = LocalScheduleDateService();
      expect(dates.locationFor('Asia/Calcutta').name, 'Asia/Kolkata');
      expect(dates.locationFor('IST').name, 'Asia/Kolkata');
      expect(dates.locationFor('GMT+05:30').name, 'Asia/Kolkata');
      expect(dates.locationFor('US/Pacific').name, 'America/Los_Angeles');
      expect(dates.locationFor('Europe/London').name, 'Europe/London');
    });
  });

  group('LocalTimezoneService platform resilience', () {
    test('resolves Asia/Calcutta to Asia/Kolkata', () async {
      final service = LocalTimezoneService(
        read: () async => 'Asia/Calcutta',
        dates: LocalScheduleDateService(),
      );
      final id = await service.currentTimezoneId();
      expect(id, 'Asia/Kolkata');
    });

    test('resolves IST to Asia/Kolkata', () async {
      final service = LocalTimezoneService(
        read: () async => 'IST',
        dates: LocalScheduleDateService(),
      );
      final id = await service.currentTimezoneId();
      expect(id, 'Asia/Kolkata');
    });

    test(
      'falls back gracefully on empty or whitespace platform string',
      () async {
        final service = LocalTimezoneService(
          read: () async => '   ',
          dates: LocalScheduleDateService(),
        );
        final id = await service.currentTimezoneId();
        expect(id.isNotEmpty, true);
      },
    );

    test('falls back gracefully on arbitrary invalid OEM string', () async {
      final service = LocalTimezoneService(
        read: () async => 'CUSTOM_OEM_ROM_TIMEZONE_STRING',
        dates: LocalScheduleDateService(),
      );
      final id = await service.currentTimezoneId();
      expect(id.isNotEmpty, true);
    });
  });

  group('Provider resilience with Asia/Calcutta', () {
    test(
      'todaySurfaceSnapshotProvider succeeds when platform reports Asia/Calcutta',
      () async {
        final db = AppDatabase.memory();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(
                read: () async => 'Asia/Calcutta',
                dates: LocalScheduleDateService(),
              ),
            ),
          ],
        );

        final snapshot = await container.read(
          todaySurfaceSnapshotProvider(DateTime.now()).future,
        );

        expect(snapshot, isNotNull);
        expect(snapshot.timezoneId, 'Asia/Kolkata');
        await db.close();
      },
    );

    test(
      'trainingLandingSnapshotProvider succeeds when platform reports Asia/Calcutta',
      () async {
        final db = AppDatabase.memory();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(
                read: () async => 'Asia/Calcutta',
                dates: LocalScheduleDateService(),
              ),
            ),
          ],
        );

        final snapshot = await container.read(
          trainingLandingSnapshotProvider.future,
        );

        expect(snapshot, isNotNull);
        await db.close();
      },
    );
  });
}
