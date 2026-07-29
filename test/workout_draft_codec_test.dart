import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/workout_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B01-04 WorkoutDraftCodec Unit Tests', () {
    test('1. Current draft round trip preserves all supported fields', () {
      final set1 = WorkoutSetsCompanion.insert(
        sessionId: 0,
        exerciseName: 'Flat Barbell Bench Press',
        weight: 85.5,
        reps: 8,
        setNumber: 1,
        isPr: const Value(true),
        rpe: const Value(9),
        isWarmUp: const Value(false),
        setType: const Value('working'),
        setNotes: const Value('Heavy set, clean form! 💪'),
        uuid: const Value('550e8400-e29b-41d4-a716-446655440000'),
        durationSeconds: const Value(45),
        distanceKm: const Value(null),
        inclinePercentage: const Value(null),
      );

      final encoded = WorkoutDraftCodec.encode(
        routineName: 'Push Day',
        currentExerciseIndex: 1,
        currentSetIndex: 2,
        elapsedSeconds: 300,
        loggedSets: [set1],
      );

      expect(encoded, contains('"version":1'));
      expect(encoded, contains('Heavy set, clean form! 💪'));

      final decoded = WorkoutDraftCodec.decodeLoggedSets(encoded);
      expect(decoded.length, equals(1));

      final restored = decoded.first;
      expect(restored.sessionId.value, equals(0));
      expect(restored.exerciseName.value, equals('Flat Barbell Bench Press'));
      expect(restored.weight.value, equals(85.5));
      expect(restored.reps.value, equals(8));
      expect(restored.setNumber.value, equals(1));
      expect(restored.isPr.value, isTrue);
      expect(restored.rpe.value, equals(9));
      expect(restored.isWarmUp.value, isFalse);
      expect(restored.setType.value, equals('working'));
      expect(restored.setNotes.value, equals('Heavy set, clean form! 💪'));
      expect(
        restored.uuid.value,
        equals('550e8400-e29b-41d4-a716-446655440000'),
      );
      expect(restored.durationSeconds.value, equals(45));
    });

    test('2. Legacy draft JSON remains readable', () {
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

      final decoded = WorkoutDraftCodec.decodeLoggedSets(legacyJson);
      expect(decoded.length, equals(1));

      final restored = decoded.first;
      expect(restored.exerciseName.value, equals('Barbell Squat'));
      expect(restored.weight.value, equals(100.0));
      expect(restored.reps.value, equals(5));
      expect(restored.isPr.value, isFalse);
    });

    test('3. Missing optional legacy fields receive documented defaults', () {
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
      expect(restored.rpe.value, isNull);
      expect(restored.isWarmUp.value, isFalse);
      expect(restored.setType.value, equals('working'));
      expect(restored.setNotes.value, isNull);
      expect(restored.uuid.value, isNull);
      expect(restored.durationSeconds.value, isNull);
      expect(restored.distanceKm.value, isNull);
      expect(restored.inclinePercentage.value, isNull);
    });

    test('4. Null optional fields survive round trip', () {
      final setWithNulls = WorkoutSetsCompanion.insert(
        sessionId: 0,
        exerciseName: 'Overhead Press',
        weight: 50.0,
        reps: 10,
        setNumber: 1,
        isPr: const Value(false),
        rpe: const Value(null),
        isWarmUp: const Value(false),
        setType: const Value('working'),
        setNotes: const Value(null),
        uuid: const Value(null),
      );

      final encoded = WorkoutDraftCodec.encode(
        routineName: 'Shoulders',
        currentExerciseIndex: 0,
        currentSetIndex: 0,
        elapsedSeconds: 60,
        loggedSets: [setWithNulls],
      );

      final restored = WorkoutDraftCodec.decodeLoggedSets(encoded).first;
      expect(restored.rpe.value, isNull);
      expect(restored.setNotes.value, isNull);
      expect(restored.uuid.value, isNull);
    });

    test('5. Unicode set notes survive round trip', () {
      final setWithEmoji = WorkoutSetsCompanion.insert(
        sessionId: 0,
        exerciseName: 'Lat Pulldown',
        weight: 60.0,
        reps: 12,
        setNumber: 2,
        isPr: const Value(true),
        setNotes: const Value('Hindi note: बहुत बढ़िया सेट 🔥🏋️‍♂️'),
      );

      final encoded = WorkoutDraftCodec.encode(
        routineName: 'Pull',
        currentExerciseIndex: 0,
        currentSetIndex: 1,
        elapsedSeconds: 150,
        loggedSets: [setWithEmoji],
      );

      final restored = WorkoutDraftCodec.decodeLoggedSets(encoded).first;
      expect(
        restored.setNotes.value,
        equals('Hindi note: बहुत बढ़िया सेट 🔥🏋️‍♂️'),
      );
    });

    test('6. Invalid JSON fails safely', () {
      expect(
        () => WorkoutDraftCodec.decodeLoggedSets('{invalid json...'),
        throwsA(isA<FormatException>()),
      );
    });

    test('7. Invalid field types fail safely', () {
      final badTypeJson = jsonEncode([
        {
          'sessionId': 'not-an-int',
          'exerciseName': 'Bench',
          'weight': 80.0,
          'reps': 8,
          'setNumber': 1,
          'isPr': true,
        },
      ]);

      expect(
        () => WorkoutDraftCodec.decodeLoggedSets(badTypeJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('14. Active draft empty payload returns empty list', () {
      final decoded = WorkoutDraftCodec.decodeLoggedSets('');
      expect(decoded, isEmpty);
    });

    test(
      '15. Existing session logging companion conversion remains intact',
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
