import '../../core/services/local_schedule_date_service.dart';
import '../models/b04_goal_models.dart';
import 'nutrition_goal_repository.dart';

/// The exact input identity for a date-scoped nutrition target read.
///
/// Consumers pass the user's civil date and the timezone in which that date
/// has meaning. Timestamps and the device's current UTC date are deliberately
/// not part of this authority's lookup key.
class NutritionTargetDateQuery {
  final String localDate;
  final String timezoneId;

  const NutritionTargetDateQuery({
    required this.localDate,
    required this.timezoneId,
  });

  @override
  bool operator ==(Object other) =>
      other is NutritionTargetDateQuery &&
      other.localDate == localDate &&
      other.timezoneId == timezoneId;

  @override
  int get hashCode => Object.hash(localDate, timezoneId);
}

/// Canonical nutrition targets for one user's local calendar date.
///
/// The nullable [goalVersion] is intentional. It means the durable B04 goal
/// history has no authoritative target for this date; callers must present an
/// unavailable/no-target state rather than borrowing today's target or
/// fabricating historical values.
class NutritionTargetsForDate {
  final String localDate;
  final String timezoneId;
  final NutritionGoalVersionReadModel? goalVersion;

  const NutritionTargetsForDate({
    required this.localDate,
    required this.timezoneId,
    required this.goalVersion,
  });

  int? get calorieTargetKcal => goalVersion?.calorieTargetKcal;

  double? get proteinTargetG => goalVersion?.proteinTargetG;

  double? get carbsTargetG => goalVersion?.carbsTargetG;

  double? get fatTargetG => goalVersion?.fatTargetG;

  NutritionGoalSource? get source => goalVersion?.source;

  String? get goalVersionId => goalVersion?.id;

  bool get hasAnyTarget =>
      calorieTargetKcal != null ||
      proteinTargetG != null ||
      carbsTargetG != null ||
      fatTargetG != null;
}

/// Consumer-facing date-scoped target authority for Today, Food, and
/// Progress.
///
/// This is a boundary over the existing B04 [NutritionGoalRepository], not a
/// competing target store or formula engine. All target values and historical
/// effective-date semantics remain owned by [NutritionGoalRepository] and its
/// persisted NutritionGoalVersions rows.
class NutritionTargetAuthority {
  final NutritionGoalRepository _goals;
  final LocalScheduleDateService _dates;

  const NutritionTargetAuthority({
    required NutritionGoalRepository goals,
    required LocalScheduleDateService dates,
  }) : _goals = goals,
       _dates = dates;

  Future<NutritionTargetsForDate> resolve(
    NutritionTargetDateQuery query,
  ) async {
    final localDate = _dates.normalizeLocalDate(query.localDate);
    _dates.validateTimezone(query.timezoneId);
    final goal = await _goals.activeGoalForPrimaryProfile(
      localDate: localDate,
      timezoneId: query.timezoneId,
    );
    return NutritionTargetsForDate(
      localDate: localDate,
      timezoneId: query.timezoneId,
      goalVersion: goal,
    );
  }

  Future<Map<String, NutritionTargetsForDate>> resolveMany({
    required Iterable<String> localDates,
    required String timezoneId,
  }) async {
    final normalizedDates = <String>{
      for (final localDate in localDates) _dates.normalizeLocalDate(localDate),
    };
    _dates.validateTimezone(timezoneId);
    final resolved = await Future.wait(
      normalizedDates.map(
        (localDate) => resolve(
          NutritionTargetDateQuery(
            localDate: localDate,
            timezoneId: timezoneId,
          ),
        ),
      ),
    );
    return {for (final target in resolved) target.localDate: target};
  }
}
