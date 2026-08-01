import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/services/b02_activity_form_service.dart';

void main() {
  const service = B02ActivityFormService();

  test(
    'builds ordered cardio intervals and duration-only mobility details',
    () {
      final cardio = service.build(
        activityType: B02ActivityType.running,
        durationSeconds: 900,
        isIntervalWorkout: true,
        workSeconds: 120,
        recoverySeconds: 60,
      );
      expect(cardio.cardioDetail!.intervals, hasLength(2));
      expect(
        cardio.cardioDetail!.intervals.first.segmentType,
        B02CardioSegmentType.work,
      );

      final mobility = service.build(
        activityType: B02ActivityType.yoga,
        durationSeconds: 600,
        style: 'Flow',
        focusNote: 'Hips',
      );
      expect(mobility.mobilityDetail!.durationSeconds, 600);
      expect(mobility.mobilityDetail!.style, 'Flow');
      expect(mobility.cardioDetail, isNull);
    },
  );

  test('rejects interval cardio without a positive work segment', () {
    expect(
      () => service.build(
        activityType: B02ActivityType.cycling,
        durationSeconds: 300,
        isIntervalWorkout: true,
      ),
      throwsA(isA<B02ValidationException>()),
    );
  });
}
