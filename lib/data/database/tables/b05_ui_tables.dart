import 'package:drift/drift.dart';

/// User-owned Today/dashboard layout state. The module ID is a packaged
/// descriptor key; it is never a widget/class name or executable config.
class DashboardModulePreferences extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get moduleId => text()();
  IntColumn get ordinal => integer()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  BoolColumn get isCollapsed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAtUtc =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, moduleId},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(id)) > 0)',
    'CHECK (length(trim(user_id)) > 0)',
    'CHECK (length(trim(module_id)) > 0)',
    'CHECK (ordinal >= 0)',
  ];
}

/// Explicit, versioned progress for bundled lessons/checklists. Content text
/// remains packaged registry data and is not copied into this table.
@DataClassName('EducationContentProgressRow')
class EducationContentProgress extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get contentId => text()();
  TextColumn get contentVersion => text()();
  TextColumn get state => text()();
  DateTimeColumn get updatedAtUtc =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    // Progress is intentionally versioned. A new lesson revision may request
    // re-read without overwriting the user's completed history for an older
    // packaged version.
    {userId, contentId, contentVersion},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(id)) > 0)',
    'CHECK (length(trim(user_id)) > 0)',
    'CHECK (length(trim(content_id)) > 0)',
    'CHECK (length(trim(content_version)) > 0)',
    "CHECK (state IN ('notStarted', 'inProgress', 'completed', 'dismissed'))",
  ];
}

/// Portable intent and manifest identity for an optional media pack. This
/// table deliberately does not contain physical availability, a file path,
/// downloaded bytes, verification-on-this-device state, progress, or cache
/// status. Those values are derived locally after restore.
class MediaPackPreferences extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get packId => text()();
  TextColumn get manifestIdentity => text()();
  TextColumn get lastKnownInstalledVersion => text().nullable()();
  TextColumn get downloadPreference =>
      text().withDefault(const Constant('manual'))();
  TextColumn get deletionChoice => text().nullable()();
  TextColumn get contentAcknowledgement => text().nullable()();
  DateTimeColumn get updatedAtUtc =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, packId},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(id)) > 0)',
    'CHECK (length(trim(user_id)) > 0)',
    'CHECK (length(trim(pack_id)) > 0)',
    'CHECK (length(trim(manifest_identity)) > 0)',
    "CHECK (download_preference IN ('manual', 'ask', 'automatic'))",
    "CHECK (deletion_choice IS NULL OR deletion_choice IN ('keep', 'delete', 'unset'))",
  ];
}

/// One normalized, provider-specific playlist reference for a local user.
/// The value is validated and normalized by the packaged provider registry
/// before persistence; arbitrary URLs and provider payloads are not a B05
/// contract.
class WorkoutPlaylistPreferences extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get providerId => text()();
  TextColumn get playlistReference => text()();
  TextColumn get displayLabel => text().nullable()();
  DateTimeColumn get updatedAtUtc =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(id)) > 0)',
    'CHECK (length(trim(user_id)) > 0)',
    'CHECK (length(trim(provider_id)) > 0)',
    'CHECK (length(trim(playlist_reference)) > 0)',
    'CHECK (length(playlist_reference) <= 512)',
    'CHECK (instr(playlist_reference, char(10)) = 0)',
    'CHECK (instr(playlist_reference, char(13)) = 0)',
  ];
}
