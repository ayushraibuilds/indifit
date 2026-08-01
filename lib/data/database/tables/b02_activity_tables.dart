import 'package:drift/drift.dart';

import 'training_program_tables.dart';
import 'workout_tables.dart';

/// Ordered, immutable-in-history group planning data. B02-02 stores the
/// graph only; authoring and execution validation land in later tasks.
class ExerciseGroups extends Table {
  TextColumn get id => text()();
  TextColumn get sessionTemplateId =>
      text().references(SessionTemplates, #id)();
  IntColumn get ordinal => integer()();
  TextColumn get groupType => text()();
  IntColumn get roundCount => integer()();
  IntColumn get restAfterRoundSeconds => integer().nullable()();
  TextColumn get label => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionTemplateId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (group_type IN ('superset', 'circuit', 'giantSet'))",
    'CHECK (round_count >= 1)',
    'CHECK (rest_after_round_seconds IS NULL OR rest_after_round_seconds >= 0)',
  ];
}

class ExerciseGroupMembers extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseGroupId => text().references(ExerciseGroups, #id)();
  TextColumn get exercisePrescriptionId =>
      text().references(ExercisePrescriptions, #id)();
  IntColumn get ordinal => integer()();
  IntColumn get transitionRestSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseGroupId, ordinal},
    {exercisePrescriptionId},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (ordinal >= 0)',
    'CHECK (transition_rest_seconds IS NULL OR transition_rest_seconds >= 0)',
  ];
}

/// Typed B02 prescription fields. Values remain nullable when the plan has no
/// known load/technique fact; B02-03 provides richer domain validation.
class StrengthSetPrescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get exercisePrescriptionId =>
      text().references(ExercisePrescriptions, #id)();
  IntColumn get ordinal => integer()();
  RealColumn get targetLoadKg => real().nullable()();
  TextColumn get loadBasis => text().nullable()();
  IntColumn get targetRepsMin => integer().nullable()();
  IntColumn get targetRepsMax => integer().nullable()();
  IntColumn get targetRpe => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  TextColumn get effortMode => text().nullable()();
  IntColumn get tempoEccentricSeconds => integer().nullable()();
  IntColumn get tempoBottomPauseSeconds => integer().nullable()();
  IntColumn get tempoConcentricSeconds => integer().nullable()();
  IntColumn get tempoLockoutPauseSeconds => integer().nullable()();
  TextColumn get pausedRepPosition => text().nullable()();
  IntColumn get pausedRepSeconds => integer().nullable()();
  TextColumn get assistanceMode => text().nullable()();
  RealColumn get assistanceKg => real().nullable()();
  TextColumn get techniquePlanJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exercisePrescriptionId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (ordinal >= 0)',
    'CHECK (target_load_kg IS NULL OR target_load_kg >= 0)',
    "CHECK (load_basis IS NULL OR load_basis IN ('totalExternal', 'perImplement', 'perSide', 'bodyweight'))",
    'CHECK (target_reps_min IS NULL OR target_reps_min >= 1)',
    'CHECK (target_reps_max IS NULL OR target_reps_max >= 1)',
    'CHECK (target_reps_min IS NULL OR target_reps_max IS NULL OR target_reps_min <= target_reps_max)',
    'CHECK (target_rpe IS NULL OR target_rpe BETWEEN 1 AND 10)',
    'CHECK (rest_seconds IS NULL OR rest_seconds >= 0)',
    "CHECK (effort_mode IS NULL OR effort_mode IN ('standard', 'amrap', 'toFailure'))",
    'CHECK (tempo_eccentric_seconds IS NULL OR tempo_eccentric_seconds >= 0)',
    'CHECK (tempo_bottom_pause_seconds IS NULL OR tempo_bottom_pause_seconds >= 0)',
    'CHECK (tempo_concentric_seconds IS NULL OR tempo_concentric_seconds >= 0)',
    'CHECK (tempo_lockout_pause_seconds IS NULL OR tempo_lockout_pause_seconds >= 0)',
    'CHECK (paused_rep_seconds IS NULL OR paused_rep_seconds >= 1)',
    'CHECK (assistance_kg IS NULL OR assistance_kg > 0)',
  ];
}

class CardioSessionDetails extends Table {
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  IntColumn get distanceMetres => integer().nullable()();
  RealColumn get observedPaceSecondsPerKm => real().nullable()();
  RealColumn get observedSpeedKph => real().nullable()();
  RealColumn get inclinePercentage => real().nullable()();
  RealColumn get elevationMetres => real().nullable()();
  IntColumn get averageHeartRate => integer().nullable()();
  IntColumn get perceivedExertion => integer().nullable()();
  BoolColumn get isIntervalWorkout =>
      boolean().withDefault(const Constant(false))();
  TextColumn get inputMode => text().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};

  @override
  List<String> get customConstraints => [
    'CHECK (distance_metres IS NULL OR distance_metres > 0)',
    'CHECK (observed_pace_seconds_per_km IS NULL OR observed_pace_seconds_per_km > 0)',
    'CHECK (observed_speed_kph IS NULL OR observed_speed_kph > 0)',
    'CHECK (average_heart_rate IS NULL OR average_heart_rate > 0)',
    'CHECK (perceived_exertion IS NULL OR perceived_exertion BETWEEN 1 AND 10)',
    "CHECK (input_mode IS NULL OR input_mode IN ('manual', 'healthImport'))",
  ];
}

class CardioIntervals extends Table {
  TextColumn get id => text()();
  IntColumn get cardioSessionId =>
      integer().references(CardioSessionDetails, #sessionId)();
  IntColumn get ordinal => integer()();
  TextColumn get segmentType => text()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get distanceMetres => integer().nullable()();
  RealColumn get targetPaceSecondsPerKm => real().nullable()();
  RealColumn get actualPaceSecondsPerKm => real().nullable()();
  TextColumn get targetIntensity => text().nullable()();
  TextColumn get actualIntensity => text().nullable()();
  IntColumn get averageHeartRate => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {cardioSessionId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (ordinal >= 0)',
    "CHECK (segment_type IN ('work', 'recovery'))",
    'CHECK (duration_seconds IS NULL OR duration_seconds > 0)',
    'CHECK (distance_metres IS NULL OR distance_metres > 0)',
    'CHECK (target_pace_seconds_per_km IS NULL OR target_pace_seconds_per_km > 0)',
    'CHECK (actual_pace_seconds_per_km IS NULL OR actual_pace_seconds_per_km > 0)',
    'CHECK (average_heart_rate IS NULL OR average_heart_rate > 0)',
  ];
}

class MobilitySessionDetails extends Table {
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  TextColumn get practiceType => text()();
  TextColumn get style => text().nullable()();
  TextColumn get intensity => text().nullable()();
  TextColumn get focusNote => text().nullable()();
  IntColumn get averageHeartRate => integer().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};

  @override
  List<String> get customConstraints => [
    "CHECK (practice_type IN ('yoga', 'mobility'))",
    'CHECK (average_heart_rate IS NULL OR average_heart_rate > 0)',
  ];
}

class PerformedExerciseGroups extends Table {
  TextColumn get id => text()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  TextColumn get sourceExerciseGroupId =>
      text().nullable().references(ExerciseGroups, #id)();
  TextColumn get groupTypeSnapshot => text()();
  TextColumn get labelSnapshot => text().nullable()();
  IntColumn get ordinal => integer()();
  IntColumn get plannedRounds => integer()();
  IntColumn get completedRounds => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('inProgress'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (group_type_snapshot IN ('superset', 'circuit', 'giantSet'))",
    'CHECK (ordinal >= 0)',
    'CHECK (planned_rounds >= 1)',
    'CHECK (completed_rounds BETWEEN 0 AND planned_rounds)',
    "CHECK (status IN ('inProgress', 'completed', 'partial'))",
  ];
}

class PerformedExercises extends Table {
  TextColumn get id => text()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  TextColumn get performedExerciseGroupId =>
      text().nullable().references(PerformedExerciseGroups, #id)();
  TextColumn get sourceExercisePrescriptionId =>
      text().nullable().references(ExercisePrescriptions, #id)();
  IntColumn get groupMemberOrdinal => integer().nullable()();
  IntColumn get groupRoundOrdinal => integer().nullable()();
  IntColumn get ordinal => integer()();
  TextColumn get expectedExerciseId =>
      text().nullable().references(Exercises, #stableId)();
  TextColumn get expectedExerciseNameSnapshot => text().nullable()();
  TextColumn get actualExerciseId => text().references(Exercises, #stableId)();
  TextColumn get actualExerciseNameSnapshot => text()();
  TextColumn get status => text().withDefault(const Constant('inProgress'))();
  TextColumn get substitutionReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (ordinal >= 0)',
    'CHECK (group_member_ordinal IS NULL OR group_member_ordinal >= 0)',
    'CHECK (group_round_ordinal IS NULL OR group_round_ordinal >= 0)',
    "CHECK (status IN ('inProgress', 'completed', 'partial', 'skipped'))",
  ];
}

class ExerciseTargetRecommendations extends Table {
  TextColumn get id => text()();
  TextColumn get performedExerciseId =>
      text().references(PerformedExercises, #id)();
  TextColumn get ruleVersion => text()();
  TextColumn get confidence => text()();
  TextColumn get completenessJson => text()();
  RealColumn get recommendedLoadKg => real().nullable()();
  TextColumn get loadBasis => text().nullable()();
  IntColumn get targetRepsMin => integer().nullable()();
  IntColumn get targetRepsMax => integer().nullable()();
  IntColumn get targetRpe => integer().nullable()();
  RealColumn get incrementKg => real().nullable()();
  DateTimeColumn get evidenceCutoffUtc => dateTime().nullable()();
  IntColumn get comparatorCount => integer().withDefault(const Constant(0))();
  TextColumn get rationaleCodesJson => text()();
  BoolColumn get wasOverridden =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {performedExerciseId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (confidence IN ('high', 'medium', 'low', 'insufficient'))",
    'CHECK (recommended_load_kg IS NULL OR recommended_load_kg >= 0)',
    "CHECK (load_basis IS NULL OR load_basis IN ('totalExternal', 'perImplement', 'perSide', 'bodyweight'))",
    'CHECK (target_reps_min IS NULL OR target_reps_min >= 1)',
    'CHECK (target_reps_max IS NULL OR target_reps_max >= 1)',
    'CHECK (target_reps_min IS NULL OR target_reps_max IS NULL OR target_reps_min <= target_reps_max)',
    'CHECK (target_rpe IS NULL OR target_rpe BETWEEN 1 AND 10)',
    'CHECK (increment_kg IS NULL OR increment_kg > 0)',
    'CHECK (comparator_count >= 0)',
  ];
}

class PerformedSets extends Table {
  TextColumn get id => text()();
  TextColumn get performedExerciseId =>
      text().references(PerformedExercises, #id)();
  IntColumn get ordinal => integer()();
  TextColumn get role => text()();
  RealColumn get targetLoadKg => real().nullable()();
  TextColumn get targetLoadBasis => text().nullable()();
  IntColumn get targetRepsMin => integer().nullable()();
  IntColumn get targetRepsMax => integer().nullable()();
  IntColumn get targetRpe => integer().nullable()();
  RealColumn get actualLoadKg => real().nullable()();
  TextColumn get actualLoadBasis => text().nullable()();
  IntColumn get actualReps => integer().nullable()();
  IntColumn get actualRpe => integer().nullable()();
  TextColumn get effortMode => text().nullable()();
  BoolColumn get endedAtFailure =>
      boolean().withDefault(const Constant(false))();
  IntColumn get tempoEccentricSeconds => integer().nullable()();
  IntColumn get tempoBottomPauseSeconds => integer().nullable()();
  IntColumn get tempoConcentricSeconds => integer().nullable()();
  IntColumn get tempoLockoutPauseSeconds => integer().nullable()();
  TextColumn get pausedRepPosition => text().nullable()();
  IntColumn get pausedRepSeconds => integer().nullable()();
  TextColumn get assistanceMode => text().nullable()();
  RealColumn get assistanceKg => real().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {performedExerciseId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (ordinal >= 0)',
    "CHECK (role IN ('warmup', 'working'))",
    'CHECK (target_load_kg IS NULL OR target_load_kg >= 0)',
    "CHECK (target_load_basis IS NULL OR target_load_basis IN ('totalExternal', 'perImplement', 'perSide', 'bodyweight'))",
    'CHECK (target_reps_min IS NULL OR target_reps_min >= 1)',
    'CHECK (target_reps_max IS NULL OR target_reps_max >= 1)',
    'CHECK (target_reps_min IS NULL OR target_reps_max IS NULL OR target_reps_min <= target_reps_max)',
    'CHECK (target_rpe IS NULL OR target_rpe BETWEEN 1 AND 10)',
    'CHECK (actual_load_kg IS NULL OR actual_load_kg >= 0)',
    "CHECK (actual_load_basis IS NULL OR actual_load_basis IN ('totalExternal', 'perImplement', 'perSide', 'bodyweight'))",
    'CHECK (actual_reps IS NULL OR actual_reps >= 0)',
    'CHECK (actual_rpe IS NULL OR actual_rpe BETWEEN 1 AND 10)',
    "CHECK (effort_mode IS NULL OR effort_mode IN ('standard', 'amrap', 'toFailure'))",
    'CHECK (tempo_eccentric_seconds IS NULL OR tempo_eccentric_seconds >= 0)',
    'CHECK (tempo_bottom_pause_seconds IS NULL OR tempo_bottom_pause_seconds >= 0)',
    'CHECK (tempo_concentric_seconds IS NULL OR tempo_concentric_seconds >= 0)',
    'CHECK (tempo_lockout_pause_seconds IS NULL OR tempo_lockout_pause_seconds >= 0)',
    'CHECK (paused_rep_seconds IS NULL OR paused_rep_seconds >= 1)',
    'CHECK (assistance_kg IS NULL OR assistance_kg > 0)',
  ];
}

class PerformedSetSegments extends Table {
  TextColumn get id => text()();
  TextColumn get performedSetId => text().references(PerformedSets, #id)();
  IntColumn get ordinal => integer()();
  IntColumn get reps => integer()();
  RealColumn get externalLoadKg => real().nullable()();
  TextColumn get loadBasis => text().nullable()();
  RealColumn get assistanceKg => real().nullable()();
  IntColumn get restBeforeSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {performedSetId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (ordinal >= 0)',
    'CHECK (reps >= 1)',
    'CHECK (external_load_kg IS NULL OR external_load_kg >= 0)',
    "CHECK (load_basis IS NULL OR load_basis IN ('totalExternal', 'perImplement', 'perSide', 'bodyweight'))",
    'CHECK (assistance_kg IS NULL OR assistance_kg > 0)',
    'CHECK (rest_before_seconds IS NULL OR rest_before_seconds >= 0)',
  ];
}

class PerformedRestPeriods extends Table {
  TextColumn get id => text()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  TextColumn get performedSetId =>
      text().nullable().references(PerformedSets, #id)();
  TextColumn get performedExerciseGroupId =>
      text().nullable().references(PerformedExerciseGroups, #id)();
  TextColumn get scope => text()();
  IntColumn get recommendedSeconds => integer().nullable()();
  IntColumn get selectedSeconds => integer().nullable()();
  IntColumn get actualSeconds => integer().nullable()();
  TextColumn get source => text()();
  DateTimeColumn get startedAtUtc => dateTime()();
  DateTimeColumn get endedAtUtc => dateTime().nullable()();
  TextColumn get endReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (scope IN ('exerciseSet', 'groupTransition', 'groupRound', 'restPause'))",
    'CHECK (recommended_seconds IS NULL OR recommended_seconds >= 0)',
    'CHECK (selected_seconds IS NULL OR selected_seconds >= 0)',
    'CHECK (actual_seconds IS NULL OR actual_seconds >= 0)',
    "CHECK (source IN ('user', 'prescription', 'exercisePreference', 'template', 'automatic', 'none'))",
    "CHECK (end_reason IS NULL OR end_reason IN ('elapsed', 'skipped', 'nextAction', 'cancelled'))",
  ];
}

class Muscles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get region => text()();
  IntColumn get catalogVersion => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {displayName, catalogVersion},
  ];

  @override
  List<String> get customConstraints => ['CHECK (catalog_version >= 1)'];
}

class ExerciseMuscleMappings extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseId => text().references(Exercises, #stableId)();
  TextColumn get muscleId => text().references(Muscles, #id)();
  TextColumn get role => text()();
  IntColumn get contributionBasisPoints => integer()();
  TextColumn get mappingStatus => text()();
  TextColumn get source => text().nullable()();
  IntColumn get catalogVersion => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseId, muscleId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (role IN ('primary', 'secondary', 'stabilizing'))",
    'CHECK (contribution_basis_points BETWEEN 1 AND 10000)',
    "CHECK (mapping_status IN ('reviewed', 'unknown'))",
    'CHECK (catalog_version >= 1)',
  ];
}
