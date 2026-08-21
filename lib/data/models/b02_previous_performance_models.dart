import 'b02_execution_models.dart';

/// Availability of canonical previous-performance evidence.
///
/// [noHistory] is a normal first-use state. [incompatible] means exact
/// exercise history exists but no row can be compared to the requested B02
/// set semantics. [queryFailure] is reserved for a database/read failure.
enum B02PreviousPerformanceStatus {
  available,
  noHistory,
  incompatible,
  invalidQuery,
  queryFailure,
}

/// The current set semantics that a historical set must match before it can
/// be exposed as comparable evidence or copied into editable fields.
///
/// B.3 intentionally defaults to a plain standard set. The
/// [hasTechniqueSegments] flag is retained as an explicit boundary marker,
/// but B.3 currently rejects segmented history because this query does not
/// carry the complete persisted drop-set/rest-pause intent needed to prove
/// equivalence. This type never infers compatibility from an exercise name.
class B02PreviousPerformanceSetContext {
  final B02SetRole role;
  final B02LoadBasis loadBasis;
  final B02EffortMode effortMode;
  final bool endedAtFailure;
  final B02AssistanceMode? assistanceMode;
  final double? assistanceKg;
  final int? tempoEccentricSeconds;
  final int? tempoBottomPauseSeconds;
  final int? tempoConcentricSeconds;
  final int? tempoLockoutPauseSeconds;
  final B02PausedRepPosition? pausedRepPosition;
  final int? pausedRepSeconds;

  /// Set to true only when the caller is explicitly asking for segmented
  /// technique semantics. The B.3 repository returns typed incompatible for
  /// that request until an exact segment model is added.
  final bool hasTechniqueSegments;

  const B02PreviousPerformanceSetContext({
    required this.role,
    required this.loadBasis,
    this.effortMode = B02EffortMode.standard,
    this.endedAtFailure = false,
    this.assistanceMode,
    this.assistanceKg,
    this.tempoEccentricSeconds,
    this.tempoBottomPauseSeconds,
    this.tempoConcentricSeconds,
    this.tempoLockoutPauseSeconds,
    this.pausedRepPosition,
    this.pausedRepSeconds,
    this.hasTechniqueSegments = false,
  });

  const B02PreviousPerformanceSetContext.working({
    required B02LoadBasis loadBasis,
  }) : this(role: B02SetRole.working, loadBasis: loadBasis);

  bool get hasTempo =>
      tempoEccentricSeconds != null ||
      tempoBottomPauseSeconds != null ||
      tempoConcentricSeconds != null ||
      tempoLockoutPauseSeconds != null;
}

/// Canonical query boundary for B.2 and later consumers.
///
/// [asOfUtc] is required so the result is deterministic and future-dated
/// malformed/imported rows cannot become historical evidence. An active B02
/// draft has no canonical WorkoutSessions row, but [excludeSessionId] also
/// supports callers reading from a just-completed/review flow.
class B02PreviousPerformanceQuery {
  final String? canonicalExerciseId;
  final B02ActivityType activityType;
  final B02PreviousPerformanceSetContext setContext;
  final DateTime asOfUtc;
  final int? excludeSessionId;

  const B02PreviousPerformanceQuery({
    required this.canonicalExerciseId,
    required this.setContext,
    required this.asOfUtc,
    this.activityType = B02ActivityType.strength,
    this.excludeSessionId,
  });
}

/// One actual persisted set that passed the B.3 eligibility checks.
class B02PreviousPerformanceSet {
  final String performedSetId;
  final int ordinal;
  final B02SetRole role;
  final B02LoadBasis loadBasis;
  final double? actualLoadKg;
  final int actualReps;
  final int? actualRpe;
  final B02EffortMode effortMode;
  final bool endedAtFailure;
  final B02AssistanceMode? assistanceMode;
  final double? assistanceKg;
  final int? tempoEccentricSeconds;
  final int? tempoBottomPauseSeconds;
  final int? tempoConcentricSeconds;
  final int? tempoLockoutPauseSeconds;
  final B02PausedRepPosition? pausedRepPosition;
  final int? pausedRepSeconds;
  final bool hasTechniqueSegments;

  const B02PreviousPerformanceSet({
    required this.performedSetId,
    required this.ordinal,
    required this.role,
    required this.loadBasis,
    required this.actualLoadKg,
    required this.actualReps,
    required this.actualRpe,
    required this.effortMode,
    required this.endedAtFailure,
    required this.assistanceMode,
    required this.assistanceKg,
    required this.tempoEccentricSeconds,
    required this.tempoBottomPauseSeconds,
    required this.tempoConcentricSeconds,
    required this.tempoLockoutPauseSeconds,
    required this.pausedRepPosition,
    required this.pausedRepSeconds,
    required this.hasTechniqueSegments,
  });

  bool get hasLoad => actualLoadKg != null;
}

/// One actual performed-exercise occurrence. Repeated occurrences in one
/// session stay separate; B.3 never merges them by name or family.
class B02PreviousPerformanceOccurrence {
  final String performedExerciseId;
  final int exerciseOrdinal;
  final String actualExerciseId;
  final String actualExerciseNameSnapshot;
  final String status;
  final String? expectedExerciseId;
  final String? sourceExercisePrescriptionId;
  final String? substitutionReason;
  final List<B02PreviousPerformanceSet> sets;

  const B02PreviousPerformanceOccurrence({
    required this.performedExerciseId,
    required this.exerciseOrdinal,
    required this.actualExerciseId,
    required this.actualExerciseNameSnapshot,
    required this.status,
    required this.expectedExerciseId,
    required this.sourceExercisePrescriptionId,
    required this.substitutionReason,
    required this.sets,
  });

  bool get wasSubstituted =>
      substitutionReason != null ||
      (expectedExerciseId != null && expectedExerciseId != actualExerciseId);
}

/// Historical values that are safe to initialize into editable current fields.
/// This is factual prefill, not a recommendation or progression offer.
class B02PreviousPerformancePrefill {
  final int sessionId;
  final String performedExerciseId;
  final String performedSetId;
  final int setOrdinal;
  final B02SetRole role;
  final B02LoadBasis loadBasis;
  final double? loadKg;
  final int reps;
  final int? rpe;

  const B02PreviousPerformancePrefill({
    required this.sessionId,
    required this.performedExerciseId,
    required this.performedSetId,
    required this.setOrdinal,
    required this.role,
    required this.loadBasis,
    required this.loadKg,
    required this.reps,
    required this.rpe,
  });
}

/// The deterministic consumer-facing result for one previous comparable
/// performance. Only the most recent eligible session is exposed.
class B02PreviousExercisePerformance {
  final B02PreviousPerformanceStatus status;
  final String? canonicalExerciseId;
  final String? reasonCode;
  final int? sessionId;
  final String? sessionName;
  final DateTime? completedAtUtc;
  final List<B02PreviousPerformanceOccurrence> occurrences;
  final B02PreviousPerformancePrefill? safePrefill;

  const B02PreviousExercisePerformance._({
    required this.status,
    required this.canonicalExerciseId,
    required this.reasonCode,
    required this.sessionId,
    required this.sessionName,
    required this.completedAtUtc,
    required this.occurrences,
    required this.safePrefill,
  });

  const B02PreviousExercisePerformance.invalidQuery({
    required String? canonicalExerciseId,
    required String reasonCode,
  }) : this._(
         status: B02PreviousPerformanceStatus.invalidQuery,
         canonicalExerciseId: canonicalExerciseId,
         reasonCode: reasonCode,
         sessionId: null,
         sessionName: null,
         completedAtUtc: null,
         occurrences: const [],
         safePrefill: null,
       );

  const B02PreviousExercisePerformance.unavailable({
    required B02PreviousPerformanceStatus status,
    required String? canonicalExerciseId,
    required String reasonCode,
  }) : this._(
         status: status,
         canonicalExerciseId: canonicalExerciseId,
         reasonCode: reasonCode,
         sessionId: null,
         sessionName: null,
         completedAtUtc: null,
         occurrences: const [],
         safePrefill: null,
       );

  const B02PreviousExercisePerformance.available({
    required String canonicalExerciseId,
    required int sessionId,
    required String sessionName,
    required DateTime completedAtUtc,
    required List<B02PreviousPerformanceOccurrence> occurrences,
    required B02PreviousPerformancePrefill? safePrefill,
  }) : this._(
         status: B02PreviousPerformanceStatus.available,
         canonicalExerciseId: canonicalExerciseId,
         reasonCode: null,
         sessionId: sessionId,
         sessionName: sessionName,
         completedAtUtc: completedAtUtc,
         occurrences: occurrences,
         safePrefill: safePrefill,
       );

  bool get isAvailable => status == B02PreviousPerformanceStatus.available;
  bool get hasHistory =>
      status == B02PreviousPerformanceStatus.available ||
      status == B02PreviousPerformanceStatus.incompatible;
}
