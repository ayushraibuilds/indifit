import 'b02_execution_models.dart';
import 'b02_muscle_volume_models.dart';

/// Civil-date query shared by every B02 progress card.  The query is kept
/// separate from presentation so a card cannot accidentally choose a
/// different range or timezone than its sibling cards.
class B02ProgressQuery {
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final int historyLimit;

  const B02ProgressQuery({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    this.historyLimit = 100,
  });

  static B02ProgressQuery recentUtc({
    DateTime? nowUtc,
    int days = 84,
    int historyLimit = 100,
  }) {
    if (days < 1) {
      throw ArgumentError.value(days, 'days', 'Must be positive.');
    }
    final now = (nowUtc ?? DateTime.now()).toUtc();
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    return B02ProgressQuery(
      startLocalDate: date(now.subtract(Duration(days: days - 1))),
      endLocalDate: date(now),
      timezoneId: 'UTC',
      historyLimit: historyLimit,
    );
  }
}

/// A history row retains the source contract that produced it.  Legacy rows
/// intentionally have no typed detail and are never upgraded based on names.
class B02ProgressActivityRecord {
  final int sessionId;
  final String name;
  final B02ActivityType activityType;
  final B02HistoryRecordKind recordKind;
  final DateTime completedAtUtc;
  final int durationSeconds;
  final B02ActivitySource? source;
  final int legacySetCount;
  final int performedExerciseCount;
  final int performedGroupCount;
  final int cardioIntervalCount;
  final bool hasCardioDetail;
  final bool hasMobilityDetail;
  final B02CardioSessionDetail? cardioDetail;
  final B02MobilitySessionDetail? mobilityDetail;

  const B02ProgressActivityRecord({
    required this.sessionId,
    required this.name,
    required this.activityType,
    required this.recordKind,
    required this.completedAtUtc,
    required this.durationSeconds,
    required this.source,
    required this.legacySetCount,
    required this.performedExerciseCount,
    required this.performedGroupCount,
    required this.cardioIntervalCount,
    required this.hasCardioDetail,
    required this.hasMobilityDetail,
    required this.cardioDetail,
    required this.mobilityDetail,
  });

  bool get isLegacy => recordKind == B02HistoryRecordKind.legacyProjection;

  bool get isCanonical => !isLegacy;
}

class B02ProgressGroupMember {
  final String performedExerciseId;
  final String? expectedExerciseId;
  final String? expectedExerciseName;
  final String actualExerciseId;
  final String actualExerciseName;
  final int ordinal;
  final int? memberOrdinal;
  final int? roundOrdinal;
  final String status;
  final String? substitutionReason;
  final int workingSetCount;
  final int totalSetCount;

  const B02ProgressGroupMember({
    required this.performedExerciseId,
    required this.expectedExerciseId,
    required this.expectedExerciseName,
    required this.actualExerciseId,
    required this.actualExerciseName,
    required this.ordinal,
    required this.memberOrdinal,
    required this.roundOrdinal,
    required this.status,
    required this.substitutionReason,
    required this.workingSetCount,
    required this.totalSetCount,
  });

  bool get wasSubstituted =>
      expectedExerciseId != null && expectedExerciseId != actualExerciseId;
}

class B02ProgressGroupHistory {
  final int sessionId;
  final String sessionName;
  final DateTime completedAtUtc;
  final String groupId;
  final B02GroupType groupType;
  final String? label;
  final int ordinal;
  final int plannedRounds;
  final int completedRounds;
  final String status;
  final List<B02ProgressGroupMember> members;

  const B02ProgressGroupHistory({
    required this.sessionId,
    required this.sessionName,
    required this.completedAtUtc,
    required this.groupId,
    required this.groupType,
    required this.label,
    required this.ordinal,
    required this.plannedRounds,
    required this.completedRounds,
    required this.status,
    required this.members,
  });

  bool get isPartial => status == 'partial' || completedRounds < plannedRounds;
}

class B02ProgressTargetEvidence {
  final int sessionId;
  final DateTime completedAtUtc;
  final String performedExerciseId;
  final String actualExerciseId;
  final String actualExerciseName;
  final String status;
  final String? expectedExerciseName;
  final String? substitutionReason;
  final int workingSetCount;
  final int totalSetCount;
  final B02TargetRecommendation? recommendation;

  const B02ProgressTargetEvidence({
    required this.sessionId,
    required this.completedAtUtc,
    required this.performedExerciseId,
    required this.actualExerciseId,
    required this.actualExerciseName,
    required this.status,
    required this.expectedExerciseName,
    required this.substitutionReason,
    required this.workingSetCount,
    required this.totalSetCount,
    required this.recommendation,
  });

  bool get hasRecommendation => recommendation != null;

  bool get wasOverridden => recommendation?.wasOverridden ?? false;
}

/// Read-only aggregate used by the progress controller. Nullable components
/// mean that a component failed to load; an empty list is a valid, known-empty
/// result. This distinction is what allows the UI to render partial/recovery
/// states without treating an unavailable metric as zero.
class B02ProgressReadModel {
  final B02ProgressQuery query;
  final List<B02ProgressActivityRecord>? activityHistory;
  final List<B02ProgressGroupHistory>? groupHistory;
  final List<B02ProgressTargetEvidence>? targetEvidence;
  final B02MuscleVolumeReadModel? muscleVolume;

  const B02ProgressReadModel({
    required this.query,
    required this.activityHistory,
    required this.groupHistory,
    required this.targetEvidence,
    required this.muscleVolume,
  });

  bool get hasAnyComponent =>
      activityHistory != null ||
      groupHistory != null ||
      targetEvidence != null ||
      muscleVolume != null;
}
