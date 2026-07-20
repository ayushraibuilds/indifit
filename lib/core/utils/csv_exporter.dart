import '../../data/database/app_database.dart';

class CsvExporter {
  static String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      final escaped = val.replaceAll('"', '""');
      return '"$escaped"';
    }
    return val;
  }

  static String exportFoodLogsToCsv(List<FoodLog> logs) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Meal Type,Food Name,Calories (kcal),Protein (g),Carbs (g),Fat (g),Serving Size,Serving Unit');

    for (final item in logs) {
      final dateStr = item.loggedAt.toIso8601String();
      buffer.writeln([
        item.id,
        _escapeCsv(dateStr),
        _escapeCsv(item.mealType),
        _escapeCsv(item.name),
        item.calories,
        item.proteinG.toStringAsFixed(1),
        item.carbsG.toStringAsFixed(1),
        item.fatG.toStringAsFixed(1),
        item.servingLogged.toStringAsFixed(1),
        _escapeCsv(item.servingUnit),
      ].join(','));
    }

    return buffer.toString();
  }

  static String exportWorkoutSessionsToCsv(List<WorkoutSession> sessions, List<WorkoutSet> sets) {
    final buffer = StringBuffer();
    buffer.writeln('Session ID,Routine Name,Completed Date,Exercise Name,Set Number,Weight (kg),Reps,Is PR,Is Warmup,RPE');

    final setMap = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      setMap.putIfAbsent(s.sessionId, () => []).add(s);
    }

    for (final session in sessions) {
      final sessionSets = setMap[session.id] ?? [];
      final dateStr = session.completedAt.toIso8601String();

      if (sessionSets.isEmpty) {
        buffer.writeln([
          session.id,
          _escapeCsv(session.name),
          _escapeCsv(dateStr),
          '',
          '',
          '',
          '',
          'false',
          'false',
          '',
        ].join(','));
      } else {
        for (final s in sessionSets) {
          buffer.writeln([
            session.id,
            _escapeCsv(session.name),
            _escapeCsv(dateStr),
            _escapeCsv(s.exerciseName),
            s.setNumber,
            s.weight.toStringAsFixed(1),
            s.reps,
            s.isPr ? 'true' : 'false',
            s.isWarmUp ? 'true' : 'false',
            s.rpe ?? '',
          ].join(','));
        }
      }
    }

    return buffer.toString();
  }

  static String exportBodyMeasurementsToCsv(List<BodyMeasurement> measurements) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Weight (kg),Waist (cm),Chest (cm),Arms (cm)');

    for (final m in measurements) {
      final dateStr = m.recordedAt.toIso8601String();
      buffer.writeln([
        m.id,
        _escapeCsv(dateStr),
        m.weight?.toStringAsFixed(1) ?? '',
        m.waist?.toStringAsFixed(1) ?? '',
        m.chest?.toStringAsFixed(1) ?? '',
        m.arms?.toStringAsFixed(1) ?? '',
      ].join(','));
    }

    return buffer.toString();
  }
}
