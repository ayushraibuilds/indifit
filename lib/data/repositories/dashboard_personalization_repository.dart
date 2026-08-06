import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/b05_foundation_registry.dart';
import '../../features/dashboard/dashboard_module_registry.dart';
import '../database/app_database.dart';

/// Drift owner for B05 dashboard layout preferences. It stores only values
/// permitted by the v19/B10 contract and always normalizes through the single
/// packaged descriptor registry.
class DashboardPersonalizationRepository {
  final AppDatabase _database;
  final DashboardModuleRegistry _registry;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  DashboardPersonalizationRepository({
    required AppDatabase database,
    required DashboardModuleRegistry registry,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _registry = registry,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  /// Reads a safe normalized projection without writing migrations, defaults,
  /// or repairs. Use [reconcile] only when a deliberate repair is requested.
  Future<List<DashboardModuleLayoutItem>> readLayout({
    required String userId,
  }) async {
    final rows = await _readRows(_owner(userId));
    return _normalizeRows(rows);
  }

  /// A passive stream for presentation consumers. Observing it never persists
  /// newly introduced descriptors or repairs stale data.
  Stream<List<DashboardModuleLayoutItem>> watchLayout({
    required String userId,
  }) {
    final owner = _owner(userId);
    return (_database.select(_database.dashboardModulePreferences)
          ..where((row) => row.userId.equals(owner))
          ..orderBy([
            (row) => OrderingTerm(expression: row.ordinal),
            (row) => OrderingTerm(expression: row.moduleId),
          ]))
        .watch()
        .map(_normalizeRows);
  }

  /// Persists exactly one normalized row per known descriptor. This explicit
  /// operation is the only read-side repair path; [readLayout] remains pure.
  Future<List<DashboardModuleLayoutItem>> reconcile({
    required String userId,
  }) async {
    final owner = _owner(userId);
    final rows = await _readRows(owner);
    final normalized = _renumber(_normalizeRows(rows));
    if (!_rowsMatchLayout(rows, normalized)) {
      await _replaceLayout(owner, normalized);
    }
    return normalized;
  }

  Future<List<DashboardModuleLayoutItem>> reorder({
    required String userId,
    required String moduleId,
    required int targetIndex,
  }) async {
    final owner = _owner(userId);
    _registry.require(moduleId);
    final current = await readLayout(userId: owner);
    if (targetIndex < 0 || targetIndex >= current.length) {
      throw DashboardPersonalizationValidationException(
        'invalid_target_index',
        'Dashboard target index must refer to a registered module.',
      );
    }
    final ordered = List<DashboardModuleLayoutItem>.of(current);
    final fromIndex = ordered.indexWhere((item) => item.moduleId == moduleId);
    final item = ordered.removeAt(fromIndex);
    ordered.insert(targetIndex, item);
    final next = _renumber(ordered);
    return _persistMutation(owner, next);
  }

  Future<List<DashboardModuleLayoutItem>> setVisible({
    required String userId,
    required String moduleId,
    required bool isVisible,
  }) => _mutateModule(
    userId: userId,
    moduleId: moduleId,
    transform: (item) => item.copyWith(isVisible: isVisible),
  );

  Future<List<DashboardModuleLayoutItem>> setCollapsed({
    required String userId,
    required String moduleId,
    required bool isCollapsed,
  }) => _mutateModule(
    userId: userId,
    moduleId: moduleId,
    transform: (item) => item.copyWith(
      isCollapsed: item.descriptor.collapsible ? isCollapsed : false,
    ),
  );

  Future<List<DashboardModuleLayoutItem>> _mutateModule({
    required String userId,
    required String moduleId,
    required DashboardModuleLayoutItem Function(DashboardModuleLayoutItem item)
    transform,
  }) async {
    final owner = _owner(userId);
    _registry.require(moduleId);
    final current = await readLayout(userId: owner);
    final next = List<DashboardModuleLayoutItem>.unmodifiable([
      for (final item in current)
        item.moduleId == moduleId ? transform(item) : item,
    ]);
    return _persistMutation(owner, next);
  }

  Future<List<DashboardModuleLayoutItem>> _persistMutation(
    String userId,
    List<DashboardModuleLayoutItem> next,
  ) async {
    // Stored ordinals are the sort authority on the next read. Explicit writes
    // therefore persist the displayed order as a compact sequence, ensuring a
    // newly appended descriptor remains appended after reconciliation.
    final persisted = _renumber(next);
    final rows = await _readRows(userId);
    if (!_rowsMatchLayout(rows, persisted)) {
      await _replaceLayout(userId, persisted);
    }
    return persisted;
  }

  Future<List<DashboardModulePreference>> _readRows(String userId) =>
      (_database.select(_database.dashboardModulePreferences)
            ..where((row) => row.userId.equals(userId))
            ..orderBy([
              (row) => OrderingTerm(expression: row.ordinal),
              (row) => OrderingTerm(expression: row.moduleId),
            ]))
          .get();

  List<DashboardModuleLayoutItem> _normalizeRows(
    Iterable<DashboardModulePreference> rows,
  ) => _registry.normalize([
    for (final row in rows)
      B05DashboardModulePreferenceValue(
        moduleId: row.moduleId,
        ordinal: row.ordinal,
        isVisible: row.isVisible,
        isCollapsed: row.isCollapsed,
      ),
  ]);

  bool _rowsMatchLayout(
    List<DashboardModulePreference> rows,
    List<DashboardModuleLayoutItem> layout,
  ) {
    if (rows.length != layout.length) return false;
    final byModuleId = {for (final row in rows) row.moduleId: row};
    if (byModuleId.length != layout.length) return false;
    for (final item in layout) {
      final row = byModuleId[item.moduleId];
      if (row == null ||
          row.ordinal != item.ordinal ||
          row.isVisible != item.isVisible ||
          row.isCollapsed != item.isCollapsed) {
        return false;
      }
    }
    return true;
  }

  Future<void> _replaceLayout(
    String userId,
    List<DashboardModuleLayoutItem> layout,
  ) => _database.transaction(() async {
    await (_database.delete(
      _database.dashboardModulePreferences,
    )..where((row) => row.userId.equals(userId))).go();
    final now = _nowUtc().toUtc();
    for (final item in layout) {
      await _database
          .into(_database.dashboardModulePreferences)
          .insert(
            DashboardModulePreferencesCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              moduleId: item.moduleId,
              ordinal: item.ordinal,
              isVisible: Value(item.isVisible),
              isCollapsed: Value(item.isCollapsed),
              updatedAtUtc: Value(now),
            ),
          );
    }
  });

  List<DashboardModuleLayoutItem> _renumber(
    List<DashboardModuleLayoutItem> ordered,
  ) => List.unmodifiable([
    for (var index = 0; index < ordered.length; index++)
      ordered[index].copyWith(ordinal: index),
  ]);

  String _owner(String userId) {
    final owner = userId.trim();
    if (owner.isEmpty) {
      throw DashboardPersonalizationValidationException(
        'invalid_user',
        'Dashboard preferences require a local user identity.',
      );
    }
    return owner;
  }
}
