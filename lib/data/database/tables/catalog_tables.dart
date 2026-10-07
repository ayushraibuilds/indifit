import 'package:drift/drift.dart';

/// The food catalogue pack applied to this device (CAT-1).
///
/// One row per applied pack version; the highest version is the installed
/// catalogue. Device-local: never synced or backed up, because the pack is
/// re-applied from the app bundle (or downloaded again) on any device.
class CatalogState extends Table {
  IntColumn get version => integer()();
  TextColumn get sha256 => text()();
  TextColumn get source => text()();
  IntColumn get foodCount => integer()();
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {version};

  @override
  List<String> get customConstraints => [
    'CHECK (version >= 1)',
    "CHECK (source IN ('bundled', 'download'))",
    'CHECK (food_count >= 0)',
  ];
}
