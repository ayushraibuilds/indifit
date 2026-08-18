import 'package:drift/drift.dart';

import 'workout_tables.dart';

/// Stable program identity. Program content lives on immutable versions.
class Programs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get goal => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get archivedAtUtc => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A version is editable only while it is a draft. Repository guards enforce
/// that lifecycle rule; the database restricts values to the accepted states.
class ProgramVersions extends Table {
  TextColumn get id => text()();
  TextColumn get programId => text().references(Programs, #id)();
  IntColumn get versionNumber => integer()();
  TextColumn get status => text()();
  TextColumn get origin => text().withDefault(const Constant('user'))();
  TextColumn get sourceVersionId =>
      text().nullable().references(ProgramVersions, #id)();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get publishedAtUtc => dateTime().nullable()();
  DateTimeColumn get archivedAtUtc => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {programId, versionNumber},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('draft', 'published', 'archived'))",
    "CHECK (origin IN ('user', 'legacyImport'))",
  ];
}

class ProgramBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get programVersionId => text().references(ProgramVersions, #id)();
  IntColumn get ordinal => integer()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {programVersionId, ordinal},
  ];
}

/// Program-week ordinal is denormalized from the block so calendar queries and
/// progression ordering can be constrained without a join.
class ProgramWeeks extends Table {
  TextColumn get id => text()();
  TextColumn get programVersionId => text().references(ProgramVersions, #id)();
  TextColumn get programBlockId => text().references(ProgramBlocks, #id)();
  IntColumn get ordinalInBlock => integer()();
  IntColumn get programWeekOrdinal => integer()();
  TextColumn get name => text().nullable()();
  BoolColumn get isDeload => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {programBlockId, ordinalInBlock},
    {programVersionId, programWeekOrdinal},
  ];
}

class SessionTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get programWeekId => text().references(ProgramWeeks, #id)();
  IntColumn get ordinal => integer()();
  TextColumn get name => text()();
  IntColumn get plannedWeekday => integer()();
  IntColumn get plannedStartMinute => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get activityType =>
      text().withDefault(const Constant('strength'))();
  IntColumn get defaultRestSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {programWeekId, ordinal},
    {programWeekId, plannedWeekday, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (planned_weekday BETWEEN 1 AND 7)',
    'CHECK (planned_start_minute IS NULL OR planned_start_minute BETWEEN 0 AND 1439)',
    "CHECK (activity_type IN ('strength', 'running', 'cycling', 'walking', 'yoga', 'mobility'))",
    'CHECK (default_rest_seconds IS NULL OR default_rest_seconds >= 0)',
  ];
}

class ExercisePrescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get sessionTemplateId =>
      text().references(SessionTemplates, #id)();
  IntColumn get ordinal => integer()();

  /// A nullable stable ID preserves unresolved migration/import data.
  TextColumn get exerciseId =>
      text().nullable().references(Exercises, #stableId)();
  TextColumn get exerciseNameSnapshot => text()();
  IntColumn get plannedSets => integer()();
  TextColumn get repsRange => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionTemplateId, ordinal},
  ];
}

/// A dated calendar instance. Program order is retained separately from a
/// mutable effective date so rescheduling never changes progression ordinals.
class ScheduledSessionOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get programVersionId => text().references(ProgramVersions, #id)();
  TextColumn get sessionTemplateId =>
      text().references(SessionTemplates, #id)();
  IntColumn get programBlockOrdinal => integer()();
  IntColumn get programWeekOrdinal => integer()();
  IntColumn get sessionOrdinal => integer()();
  IntColumn get repeatOrdinal => integer().withDefault(const Constant(0))();
  TextColumn get originalLocalDate => text()();
  TextColumn get originalTimezoneId => text()();
  TextColumn get effectiveLocalDate => text()();
  TextColumn get effectiveTimezoneId => text()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get progressionDisposition =>
      text().withDefault(const Constant('pending'))();
  TextColumn get skipMode => text().nullable()();
  TextColumn get repeatPurpose => text().nullable()();
  TextColumn get repeatedFromOccurrenceId =>
      text().nullable().references(ScheduledSessionOccurrences, #id)();
  TextColumn get executionSnapshotJson => text().nullable()();
  DateTimeColumn get startedAtUtc => dateTime().nullable()();
  DateTimeColumn get terminalAtUtc => dateTime().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {programVersionId, programWeekOrdinal, sessionTemplateId, repeatOrdinal},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('planned', 'rescheduled', 'inProgress', 'completed', 'partiallyCompleted', 'skipped', 'cancelled'))",
    "CHECK (progression_disposition IN ('pending', 'satisfied', 'bypassed'))",
    "CHECK (skip_mode IS NULL OR skip_mode IN ('keepPending', 'advance'))",
    "CHECK (repeat_purpose IS NULL OR repeat_purpose IN ('makeUp', 'extra'))",
  ];
}

/// Immutable command/event log. Command ID makes a retried transition
/// idempotent without relying on a screen-local guard.
class OccurrenceEvents extends Table {
  TextColumn get id => text()();
  TextColumn get occurrenceId =>
      text().references(ScheduledSessionOccurrences, #id)();
  TextColumn get commandId => text()();
  TextColumn get eventType => text()();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text().nullable()();
  TextColumn get beforeLocalDate => text().nullable()();
  TextColumn get beforeTimezoneId => text().nullable()();
  TextColumn get afterLocalDate => text().nullable()();
  TextColumn get afterTimezoneId => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get metadataJson => text().nullable()();
  DateTimeColumn get occurredAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {occurrenceId, commandId},
  ];
}

/// Singleton typed owner of the current version and normal equipment profile.
/// End metadata is bounded retry/history context, not a second active-plan
/// authority. The active pointer remains the only current-plan source.
class TrainingPlanSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get activeProgramVersionId =>
      text().nullable().references(ProgramVersions, #id)();
  TextColumn get activeSinceLocalDate => text().nullable()();
  TextColumn get activeSinceTimezoneId => text().nullable()();
  TextColumn get lastEndedProgramVersionId =>
      text().nullable().references(ProgramVersions, #id)();
  TextColumn get lastEndedOutcome => text().nullable()();
  DateTimeColumn get lastEndedAtUtc => dateTime().nullable()();
  TextColumn get lastEndedCommandId => text().nullable()();
  TextColumn get defaultEquipmentProfileId =>
      text().nullable().references(EquipmentProfiles, #id)();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    "CHECK (last_ended_outcome IS NULL OR last_ended_outcome IN ('finished', 'left'))",
  ];
}

class EquipmentProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get defaultWeightIncrementKg => real().nullable()();
  TextColumn get legacyAccessCode => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get archivedAtUtc => dateTime().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class EquipmentProfileItems extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentProfileId =>
      text().references(EquipmentProfiles, #id)();
  TextColumn get equipmentCode => text()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  RealColumn get weightIncrementKg => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {equipmentProfileId, equipmentCode},
  ];
}

/// A durable travel override never rewrites normal dates or program structure.
class TravelContexts extends Table {
  TextColumn get id => text()();
  TextColumn get startLocalDate => text()();
  TextColumn get endLocalDate => text()();
  TextColumn get timezoneId => text()();
  TextColumn get equipmentProfileId =>
      text().references(EquipmentProfiles, #id)();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get endedAtUtc => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('active', 'cancelled', 'ended'))",
  ];
}

/// Explicit preview membership prevents timezone conversion from implicitly
/// changing which date-only occurrences a travel context affects.
class TravelContextOccurrences extends Table {
  TextColumn get travelContextId => text().references(TravelContexts, #id)();
  TextColumn get occurrenceId =>
      text().references(ScheduledSessionOccurrences, #id)();
  DateTimeColumn get confirmedAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {travelContextId, occurrenceId};
}

/// One non-overlapping personal preference aggregate per stable identity or
/// unresolved raw fallback key.
class ExerciseUserPreferences extends Table {
  TextColumn get id => text()();
  TextColumn get identityKey => text()();
  TextColumn get exerciseId =>
      text().nullable().references(Exercises, #stableId)();
  TextColumn get exerciseNameFallback => text().nullable()();
  TextColumn get generalNote => text().nullable()();
  TextColumn get warmupPreference => text().nullable()();
  IntColumn get warmupSetCount => integer().nullable()();
  IntColumn get customRestSeconds => integer().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {identityKey},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (warmup_preference IS NULL OR warmup_preference IN ('off', 'ask', 'automatic'))",
    'CHECK (warmup_set_count IS NULL OR warmup_set_count BETWEEN 1 AND 4)',
    'CHECK (custom_rest_seconds IS NULL OR custom_rest_seconds >= 0)',
  ];
}

class ExerciseSetupValues extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseUserPreferenceId =>
      text().references(ExerciseUserPreferences, #id)();
  IntColumn get ordinal => integer()();
  TextColumn get label => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseUserPreferenceId, ordinal},
  ];
}

class ExercisePersonalCues extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseUserPreferenceId =>
      text().references(ExerciseUserPreferences, #id)();
  IntColumn get ordinal => integer()();
  TextColumn get cueText => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseUserPreferenceId, ordinal},
  ];
}

/// Records exactly which retained v14 routine supplied each immutable
/// legacy-import version. It prevents a compatibility adapter from becoming a
/// second mutable owner of program structure.
class LegacyRoutineProgramMappings extends Table {
  IntColumn get legacyRoutineId => integer().references(WorkoutRoutines, #id)();
  TextColumn get programId => text().references(Programs, #id)();
  TextColumn get programVersionId => text().references(ProgramVersions, #id)();
  DateTimeColumn get importedAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {legacyRoutineId};

  @override
  List<Set<Column>> get uniqueKeys => [
    {programId},
    {programVersionId},
  ];
}
