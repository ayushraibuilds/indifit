import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/workout_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B01-04 WorkoutDraftCodec Remediation Unit Tests', () {
    test(
      '1. Full-field draft round trip explicitly asserts all supported fields',
      () {
        final set1 = WorkoutSetsCompanion.insert(
          sessionId: 0,
          exerciseName: 'Treadmill Incline Run',
          weight: 0.0,
          reps: 0,
          setNumber: 1,
          isPr: const Value(true),
          rpe: const Value(9),
          isWarmUp: const Value(false),
          setType: const Value('working'),
          setNotes: const Value('High intensity interval 🔥'),
          uuid: const Value('550e8400-e29b-41d4-a716-446655440000'),
          durationSeconds: const Value(1200),
          distanceKm: const Value(3.5),
          inclinePercentage: const Value(5.0),
        );

        final encoded = WorkoutDraftCodec.encode(
          routineName: 'Cardio Blast',
          currentExerciseIndex: 0,
          currentSetIndex: 0,
          elapsedSeconds: 1200,
          loggedSets: [set1],
        );

        expect(encoded, contains('"version":1'));
        expect(encoded, contains('High intensity interval 🔥'));

        final decoded = WorkoutDraftCodec.decodeLoggedSets(encoded);
        expect(decoded.length, equals(1));

        final restored = decoded.first;
        expect(restored.sessionId.value, equals(0));
        expect(restored.exerciseName.value, equals('Treadmill Incline Run'));
        expect(restored.weight.value, equals(0.0));
        expect(restored.reps.value, equals(0));
        expect(restored.setNumber.value, equals(1));
        expect(restored.isPr.value, isTrue);
        expect(restored.rpe.value, equals(9));
        expect(restored.isWarmUp.value, isFalse);
        expect(restored.setType.value, equals('working'));
        expect(restored.setNotes.value, equals('High intensity interval 🔥'));
        expect(
          restored.uuid.value,
          equals('550e8400-e29b-41d4-a716-446655440000'),
        );
        expect(restored.durationSeconds.value, equals(1200));
        expect(restored.distanceKm.value, equals(3.5));
        expect(restored.inclinePercentage.value, equals(5.0));
      },
    );

    test(
      '2. Unsupported future codec version throws UnsupportedDraftVersionException',
      () {
        final futureEnvelope = jsonEncode({
          'version': 99,
          'routineName': 'Future Workout',
          'loggedSets': [],
        });

        expect(
          () => WorkoutDraftCodec.decodeLoggedSets(futureEnvelope),
          throwsA(isA<UnsupportedDraftVersionException>()),
        );
      },
    );

    test('3. Missing version in envelope object throws FormatException', () {
      final missingVersionEnvelope = jsonEncode({
        'routineName': 'No Version Workout',
        'loggedSets': [],
      });

      expect(
        () => WorkoutDraftCodec.decodeLoggedSets(missingVersionEnvelope),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      '4. Missing or null loggedSets in envelope throws FormatException',
      () {
        final missingSetsEnvelope = jsonEncode({
          'version': 1,
          'routineName': 'No Sets Workout',
        });

        final nullSetsEnvelope = jsonEncode({
          'version': 1,
          'routineName': 'Null Sets Workout',
          'loggedSets': null,
        });

        expect(
          () => WorkoutDraftCodec.decodeLoggedSets(missingSetsEnvelope),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => WorkoutDraftCodec.decodeLoggedSets(nullSetsEnvelope),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('5. Corrupt empty object throws FormatException', () {
      final emptyObject = jsonEncode({});

      expect(
        () => WorkoutDraftCodec.decodeLoggedSets(emptyObject),
        throwsA(isA<FormatException>()),
      );
    });

    test('6. Invalid setType throws FormatException', () {
      final invalidSetTypeJson = jsonEncode([
        {
          'sessionId': 0,
          'exerciseName': 'Bench Press',
          'weight': 80.0,
          'reps': 8,
          'setNumber': 1,
          'isPr': false,
          'setType': 'super_ultra_invalid_set',
        },
      ]);

      expect(
        () => WorkoutDraftCodec.decodeLoggedSets(invalidSetTypeJson),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      '7. Allowed setTypes (working, warmup, drop, failure, amrap) pass validation',
      () {
        for (final type in ['working', 'warmup', 'drop', 'failure', 'amrap']) {
          final json = jsonEncode([
            {
              'sessionId': 0,
              'exerciseName': 'Squat',
              'weight': 100.0,
              'reps': 5,
              'setNumber': 1,
              'isPr': false,
              'setType': type,
            },
          ]);

          final restored = WorkoutDraftCodec.decodeLoggedSets(json).first;
          expect(restored.setType.value, equals(type));
        }
      },
    );

    test(
      '8. Legacy bare array format remains readable with documented defaults',
      () {
        final legacyJson = jsonEncode([
          {
            'sessionId': 0,
            'exerciseName': 'Barbell Squat',
            'weight': 100.0,
            'reps': 5,
            'setNumber': 1,
            'isPr': false,
          },
        ]);

        final restored = WorkoutDraftCodec.decodeLoggedSets(legacyJson).first;
        expect(restored.exerciseName.value, equals('Barbell Squat'));
        expect(restored.weight.value, equals(100.0));
        expect(restored.reps.value, equals(5));
        expect(restored.isPr.value, isFalse);
        expect(restored.rpe.value, isNull);
        expect(restored.isWarmUp.value, isFalse);
        expect(restored.setType.value, equals('working'));
        expect(restored.setNotes.value, isNull);
        expect(restored.uuid.value, isNull);
        expect(restored.durationSeconds.value, isNull);
        expect(restored.distanceKm.value, isNull);
        expect(restored.inclinePercentage.value, isNull);
      },
    );

    test('9. Active draft empty payload returns empty list', () {
      final decoded = WorkoutDraftCodec.decodeLoggedSets('');
      expect(decoded, isEmpty);
    });

    test(
      '10. Existing session logging companion conversion remains intact',
      () async {
        SharedPreferences.setMockInitialValues({});
        final db = AppDatabase.memory();

        try {
          final setCompanion = WorkoutSetsCompanion.insert(
            sessionId: 0,
            exerciseName: 'Flat Barbell Bench Press',
            weight: 100.0,
            reps: 5,
            setNumber: 1,
            isPr: const Value(true),
            rpe: const Value(8),
            setNotes: const Value('Solid 1RM test'),
          );

          final encoded = WorkoutDraftCodec.encode(
            routineName: 'Strength',
            currentExerciseIndex: 0,
            currentSetIndex: 0,
            elapsedSeconds: 120,
            loggedSets: [setCompanion],
          );

          final decodedCompanions = WorkoutDraftCodec.decodeLoggedSets(encoded);
          expect(decodedCompanions.length, equals(1));
          expect(
            decodedCompanions.first.exerciseName.value,
            equals('Flat Barbell Bench Press'),
          );
        } finally {
          await db.close();
        }
      },
    );
  });
}
