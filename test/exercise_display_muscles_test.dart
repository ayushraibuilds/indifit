import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/exercise_display_muscles.dart';

void main() {
  group('ExerciseDisplayMuscles Unit Tests (R08-0.4)', () {
    test('1. Resolves primary and multiple secondary display muscles', () {
      final muscles = ExerciseDisplayMuscles.fromMuscleGroups(
        'Chest,Triceps,Shoulders',
      );

      expect(muscles.hasPrimary, isTrue);
      expect(muscles.primary, equals('Chest'));
      expect(muscles.secondary, equals(['Triceps', 'Shoulders']));
      expect(muscles.all, equals(['Chest', 'Triceps', 'Shoulders']));
      expect(muscles.isEmpty, isFalse);
      expect(muscles.isNotEmpty, isTrue);
    });

    test('2. Resolves single muscle with empty secondary list', () {
      final muscles = ExerciseDisplayMuscles.fromMuscleGroups('Triceps');

      expect(muscles.hasPrimary, isTrue);
      expect(muscles.primary, equals('Triceps'));
      expect(muscles.secondary, isEmpty);
      expect(muscles.all, equals(['Triceps']));
    });

    test('3. Safely trims and normalizes arbitrary whitespace', () {
      final muscles = ExerciseDisplayMuscles.fromMuscleGroups(
        '   Chest  ,   Triceps  ,   Shoulders   ',
      );

      expect(muscles.primary, equals('Chest'));
      expect(muscles.secondary, equals(['Triceps', 'Shoulders']));
      expect(muscles.all, equals(['Chest', 'Triceps', 'Shoulders']));
    });

    test(
      '4. Deduplicates repeated tokens case-insensitively without renaming initial display casing',
      () {
        final muscles = ExerciseDisplayMuscles.fromMuscleGroups(
          'Chest, Triceps, chest, TRICEPS, Shoulders, chest',
        );

        expect(muscles.primary, equals('Chest'));
        expect(muscles.secondary, equals(['Triceps', 'Shoulders']));
        expect(muscles.all, equals(['Chest', 'Triceps', 'Shoulders']));
      },
    );

    test(
      '5. Handles empty, null, whitespace, and malformed strings safely',
      () {
        expect(
          ExerciseDisplayMuscles.fromMuscleGroups(null),
          equals(ExerciseDisplayMuscles.empty),
        );
        expect(
          ExerciseDisplayMuscles.fromMuscleGroups(''),
          equals(ExerciseDisplayMuscles.empty),
        );
        expect(
          ExerciseDisplayMuscles.fromMuscleGroups('    '),
          equals(ExerciseDisplayMuscles.empty),
        );
        expect(
          ExerciseDisplayMuscles.fromMuscleGroups(',,,,  ,,'),
          equals(ExerciseDisplayMuscles.empty),
        );

        final empty = ExerciseDisplayMuscles.empty;
        expect(empty.hasPrimary, isFalse);
        expect(empty.hasSecondary, isFalse);
        expect(empty.isEmpty, isTrue);
        expect(empty.primary, isNull);
        expect(empty.secondary, isEmpty);
        expect(empty.all, isEmpty);
      },
    );

    test(
      '6. Handles custom / unknown muscle strings without guessing or crashing',
      () {
        final muscles = ExerciseDisplayMuscles.fromMuscleGroups(
          'Custom Grip, Secondary Rotary Focus',
        );

        expect(muscles.primary, equals('Custom Grip'));
        expect(muscles.secondary, equals(['Secondary Rotary Focus']));
        expect(muscles.matchesPrimary('Custom Grip'), isTrue);
        expect(muscles.matchesPrimary('custom grip'), isTrue);
        expect(muscles.matchesPrimary('Other'), isFalse);
      },
    );

    test('7. matchesPrimary checks exact primary token case-insensitively', () {
      final bench = ExerciseDisplayMuscles.fromMuscleGroups(
        'Chest,Triceps,Shoulders',
      );

      expect(bench.matchesPrimary('Chest'), isTrue);
      expect(bench.matchesPrimary('chest'), isTrue);
      expect(bench.matchesPrimary('CHEST'), isTrue);
      expect(bench.matchesPrimary('  chest  '), isTrue);
      expect(bench.matchesPrimary('All'), isTrue);
      expect(bench.matchesPrimary('all'), isTrue);

      // Bench press primary is Chest, so it MUST NOT match Triceps or Shoulders
      expect(bench.matchesPrimary('Triceps'), isFalse);
      expect(bench.matchesPrimary('Shoulders'), isFalse);
      expect(bench.matchesPrimary('Back'), isFalse);
      expect(bench.matchesPrimary(''), isFalse);
      expect(bench.matchesPrimary(null), isFalse);
    });

    test('8. containsMuscle checks both primary and secondary tokens', () {
      final bench = ExerciseDisplayMuscles.fromMuscleGroups(
        'Chest,Triceps,Shoulders',
      );

      expect(bench.containsMuscle('Chest'), isTrue);
      expect(bench.containsMuscle('Triceps'), isTrue);
      expect(bench.containsMuscle('Shoulders'), isTrue);
      expect(bench.containsMuscle('biceps'), isFalse);
      expect(bench.containsMuscle(''), isFalse);
      expect(bench.containsMuscle(null), isFalse);
    });

    test('9. Equality and hashCode consistency', () {
      final a = ExerciseDisplayMuscles.fromMuscleGroups('Chest,Triceps');
      final b = ExerciseDisplayMuscles.fromMuscleGroups('Chest, Triceps');
      final c = ExerciseDisplayMuscles.fromMuscleGroups('Chest,Shoulders');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
