import '../database/app_database.dart';
import 'program_repository.dart';

/// Consumer-safe metadata derived from one persisted program version graph.
///
/// This is a read model only. Program/version identity and lifecycle remain
/// owned by [ProgramRepository] and the B01 tables; activation remains owned
/// by [ProgramActivationCoordinator].
class PlanLibraryMetadata {
  const PlanLibraryMetadata({
    required this.weekCount,
    required this.sessionCount,
    required this.exerciseCount,
    required this.trainingDaysPerWeek,
    required this.blockNames,
  });

  final int weekCount;
  final int sessionCount;
  final int exerciseCount;
  final int? trainingDaysPerWeek;
  final List<String> blockNames;

  String get scheduleLabel {
    final days = trainingDaysPerWeek;
    if (days != null) {
      return '$days ${days == 1 ? 'day' : 'days'}/week';
    }
    return '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'}';
  }

  String get durationLabel => '$weekCount ${weekCount == 1 ? 'week' : 'weeks'}';
}

class PlanLibraryEntry {
  const PlanLibraryEntry({
    required this.detail,
    required this.metadata,
    required this.isActive,
  });

  final ProgramDetailAggregate detail;
  final PlanLibraryMetadata metadata;
  final bool isActive;

  Program get program => detail.program;

  ProgramVersion get version => detail.version;

  bool get isDraft => version.status == 'draft';

  /// Drafts are intentionally visible when they are the only usable version
  /// of a saved plan, but they are not presented as ready-to-use plans.
  bool get isReadyToUse => version.status == 'published';
}

class PlanLibrarySnapshot {
  const PlanLibrarySnapshot({
    required this.entries,
    required this.activeProgramVersionId,
  });

  final List<PlanLibraryEntry> entries;
  final String? activeProgramVersionId;

  PlanLibraryEntry? entryForVersion(String versionId) {
    for (final entry in entries) {
      if (entry.version.id == versionId) return entry;
    }
    return null;
  }

  PlanLibraryEntry? entryForProgram(String programId) {
    for (final entry in entries) {
      if (entry.program.id == programId) return entry;
    }
    return null;
  }
}

/// Read boundary for the Plan Library.
///
/// The library presents one best display version per non-archived program:
/// the exact active version when selected, otherwise the newest published
/// version, otherwise the newest draft. It never infers a plan from history,
/// names, or scheduled occurrences.
class PlanLibraryReadRepository {
  PlanLibraryReadRepository(this.db, {ProgramRepository? programs})
    : programs = programs ?? ProgramRepository(db);

  final AppDatabase db;
  final ProgramRepository programs;

  Future<PlanLibrarySnapshot> read() async {
    final settings = await (db.select(
      db.trainingPlanSettings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    final activeVersionId = settings?.activeProgramVersionId;
    await _validateActivePointer(activeVersionId);

    final programRows = await programs.getAllPrograms();
    final entries = <PlanLibraryEntry>[];
    for (final program in programRows) {
      final versions = await programs.getVersionsForProgram(program.id);
      final version = _preferredVersion(
        versions,
        activeVersionId: activeVersionId,
      );
      if (version == null) continue;

      final detail = await programs.getProgramVersionDetail(version.id);
      if (detail == null) continue;
      entries.add(
        PlanLibraryEntry(
          detail: detail,
          metadata: _metadataFor(detail),
          isActive: version.id == activeVersionId,
        ),
      );
    }

    if (activeVersionId != null && !entries.any((entry) => entry.isActive)) {
      throw StateError(
        'The active training plan is unavailable. Choose a different plan.',
      );
    }

    entries.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }
      return second.program.createdAtUtc.compareTo(first.program.createdAtUtc);
    });

    return PlanLibrarySnapshot(
      entries: List<PlanLibraryEntry>.unmodifiable(entries),
      activeProgramVersionId: activeVersionId,
    );
  }

  /// Reads one exact version for version-scoped overview/history surfaces.
  ///
  /// The library list intentionally chooses one display version per program;
  /// an overview must not repeat that preference after a route has already
  /// carried an immutable version identity.
  Future<PlanLibraryEntry?> readVersion(String versionId) async {
    final cleanVersionId = versionId.trim();
    if (cleanVersionId.isEmpty) return null;

    final settings = await (db.select(
      db.trainingPlanSettings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    final activeVersionId = settings?.activeProgramVersionId;
    await _validateActivePointer(activeVersionId);

    final version = await (db.select(
      db.programVersions,
    )..where((table) => table.id.equals(cleanVersionId))).getSingleOrNull();
    if (version == null || version.status == 'archived') return null;

    final detail = await programs.getProgramVersionDetail(cleanVersionId);
    if (detail == null || detail.program.archivedAtUtc != null) return null;
    return PlanLibraryEntry(
      detail: detail,
      metadata: _metadataFor(detail),
      isActive: cleanVersionId == activeVersionId,
    );
  }

  Future<void> _validateActivePointer(String? activeVersionId) async {
    if (activeVersionId == null) return;
    final version = await (db.select(
      db.programVersions,
    )..where((table) => table.id.equals(activeVersionId))).getSingleOrNull();
    if (version == null || version.status != 'published') {
      throw StateError(
        'The active training plan is unavailable. Choose a different plan.',
      );
    }
    final program = await (db.select(
      db.programs,
    )..where((table) => table.id.equals(version.programId))).getSingleOrNull();
    if (program == null || program.archivedAtUtc != null) {
      throw StateError(
        'The active training plan is unavailable. Choose a different plan.',
      );
    }
  }

  static ProgramVersion? _preferredVersion(
    List<ProgramVersion> versions, {
    required String? activeVersionId,
  }) {
    for (final version in versions) {
      if (version.id == activeVersionId && version.status == 'published') {
        return version;
      }
    }

    final published = versions
        .where((version) => version.status == 'published')
        .toList(growable: false);
    if (published.isNotEmpty) return published.last;

    final drafts = versions
        .where((version) => version.status == 'draft')
        .toList(growable: false);
    return drafts.isEmpty ? null : drafts.last;
  }

  static PlanLibraryMetadata _metadataFor(ProgramDetailAggregate detail) {
    final templatesByWeek = <String, List<SessionTemplate>>{};
    for (final template in detail.sessionTemplates) {
      templatesByWeek
          .putIfAbsent(template.programWeekId, () => <SessionTemplate>[])
          .add(template);
    }

    final daysPerWeek = <int>[];
    for (final week in detail.weeks) {
      final templates = templatesByWeek[week.id] ?? const <SessionTemplate>[];
      final weekdays = templates
          .map((template) => template.plannedWeekday)
          .toSet();
      if (weekdays.isEmpty) {
        daysPerWeek.clear();
        break;
      }
      daysPerWeek.add(weekdays.length);
    }
    final trainingDaysPerWeek =
        daysPerWeek.isEmpty ||
            daysPerWeek.any((count) => count != daysPerWeek.first)
        ? null
        : daysPerWeek.first;

    return PlanLibraryMetadata(
      weekCount: detail.weeks.length,
      sessionCount: detail.sessionTemplates.length,
      exerciseCount: detail.exercisePrescriptions.length,
      trainingDaysPerWeek: trainingDaysPerWeek,
      blockNames: detail.blocks
          .map((block) => block.name.trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
    );
  }
}
