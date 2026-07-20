import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/csv_exporter.dart';
import 'package:indifit/data/database/app_database.dart';

void main() {
  group('CsvExporter Tests', () {
    test('exports food logs to CSV with valid header and escaped strings', () {
      final logs = [
        FoodLog(
          id: 1,
          foodItemId: 101,
          name: 'Chapati, Whole Wheat',
          calories: 120,
          proteinG: 3.1,
          carbsG: 20.4,
          fatG: 1.2,
          servingLogged: 1.0,
          servingUnit: 'piece',
          mealType: 'breakfast',
          loggedAt: DateTime(2026, 7, 20, 8, 30),
          mealGroupId: 'group_1',
          isSynced: false,
        ),
      ];

      final csv = CsvExporter.exportFoodLogsToCsv(logs);
      expect(csv, contains('ID,Date,Meal Type,Food Name,Calories (kcal)'));
      expect(csv, contains('"Chapati, Whole Wheat"'));
      expect(csv, contains('breakfast'));
      expect(csv, contains('120'));
    });

    test('exports workout sessions and sets to CSV', () {
      final sessions = [
        WorkoutSession(
          id: 1,
          name: 'Push Day A',
          totalVolume: 1200.0,
          durationSeconds: 2700,
          estimatedCalories: 250,
          completedAt: DateTime(2026, 7, 20, 10, 0),
          isSynced: false,
        ),
      ];

      final sets = [
        WorkoutSet(
          id: 1,
          sessionId: 1,
          exerciseName: 'Bench Press',
          weight: 80.0,
          reps: 8,
          setNumber: 1,
          isPr: true,
          isWarmUp: false,
          rpe: 8,
        ),
      ];

      final csv = CsvExporter.exportWorkoutSessionsToCsv(sessions, sets);
      expect(csv, contains('Session ID,Routine Name,Completed Date,Exercise Name'));
      expect(csv, contains('Push Day A'));
      expect(csv, contains('Bench Press'));
      expect(csv, contains('80.0'));
      expect(csv, contains('true'));
    });

    test('exports body measurements to CSV', () {
      final measurements = [
        BodyMeasurement(
          id: 1,
          recordedAt: DateTime(2026, 7, 20),
          weight: 74.5,
          waist: 81.0,
          chest: 102.0,
          arms: 38.0,
          isSynced: false,
        ),
      ];

      final csv = CsvExporter.exportBodyMeasurementsToCsv(measurements);
      expect(csv, contains('ID,Date,Weight (kg),Waist (cm)'));
      expect(csv, contains('74.5'));
      expect(csv, contains('81.0'));
    });
  });
}
