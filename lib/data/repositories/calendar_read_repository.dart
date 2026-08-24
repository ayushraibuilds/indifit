import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';

/// Immutable, hydrated calendar data. It deliberately contains no mutation
/// methods: [CalendarRepository] remains the sole occurrence transition owner.
class CalendarOccurrenceReadItem {
  final ScheduledSessionOccurrence occurrence;
  final SessionTemplate template;
  final ProgramWeek week;
  final ProgramBlock block;
  final ProgramVersion version;
  final Program program;
  final List<ExercisePrescription> prescriptions;
  final bool isOverdue;
  final bool isDeload;
  final bool isNextRequired;

  const CalendarOccurrenceReadItem({
    required this.occurrence,
    required this.template,
    required this.week,
    required this.block,
    required this.version,
    required this.program,
    required this.prescriptions,
    required this.isOverdue,
    required this.isDeload,
    required this.isNextRequired,
  });
}

class CalendarReadSnapshot {
  final List<CalendarOccurrenceReadItem> rangeOccurrences;
  final List<CalendarOccurrenceReadItem> overdueOccurrences;
  final String? activeProgramVersionId;
  final String? activeProgramName;
  final String? lastEndedProgramVersionId;
  final String? lastEndedProgramName;
  final String? lastEndedOutcome;
  final DateTime? lastEndedAtUtc;

  const CalendarReadSnapshot({
    required this.rangeOccurrences,
    required this.overdueOccurrences,
    required this.activeProgramVersionId,
    required this.activeProgramName,
    this.lastEndedProgramVersionId,
    this.lastEndedProgramName,
    this.lastEndedOutcome,
    this.lastEndedAtUtc,
  });
}

/// Read-only Drift owner for B01 calendar aggregation. Keeping joins and
/// derived progression flags here ensures the controller contains no SQL and
/// cannot invent scheduling rules.
class CalendarReadRepository {
  final AppDatabase _db;
  final LocalScheduleDateService _dates;

  CalendarReadRepository(this._db, {LocalScheduleDateService? dates})
    : _dates = dates ?? LocalScheduleDateService();

  /// Emits only a bounded invalidation signal. Hydration remains a separate
  /// awaited read so a cancelled controller cannot leave an async database
  /// read running after its provider/database has been disposed.
  Stream<void> watchInvalidation({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) {
    final start = _dates.normalizeLocalDate(startLocalDate);
    final end = _dates.normalizeLocalDate(endLocalDate);
    _dates.validateTimezone(timezoneId);
    if (_dates.compare(start, end) > 0) {
      throw ArgumentError('Start local date must not be after end local date.');
    }

    // The read includes a separately queried overdue set (dates before
    // [start]). A date-bounded watch would therefore miss a completion,
    // reschedule, or skip on an overdue occurrence even though that mutation
    // can change B01's next-required result. The table is local and small;
    // watch the canonical occurrence source and let each read project its
    // requested date range.
    final occurrenceWatch = _db.select(_db.scheduledSessionOccurrences);

    // The active plan pointer is a separate canonical row from occurrences.
    // Watching only the date-bounded occurrence query leaves an already
    // mounted Training tab showing "No training plan yet" after activation.
    // Merge the small identity/settings watches so all consumers reconcile from
    // the same read repository without inferring a plan from Calendar rows.
    late final StreamController<void> controller;
    final subscriptions = <StreamSubscription<void>>[];
    controller = StreamController<void>(
      onListen: () {
        final streams = <Stream<void>>[
          occurrenceWatch.watch().map<void>((_) {}),
          _db.select(_db.trainingPlanSettings).watch().map<void>((_) {}),
          _db.select(_db.programVersions).watch().map<void>((_) {}),
          _db.select(_db.programs).watch().map<void>((_) {}),
        ];
        for (final stream in streams) {
          subscriptions.add(
            // Drift watches emit their current snapshot immediately. That
            // first value establishes the watch and must not invalidate the
            // provider that just created it, otherwise the subscription can
            // continuously recreate itself without a database change.
            stream.skip(1).listen(controller.add, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  Future<CalendarReadSnapshot> readSnapshot({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async {
    final start = _dates.normalizeLocalDate(startLocalDate);
    final end = _dates.normalizeLocalDate(endLocalDate);
    _dates.validateTimezone(timezoneId);
    if (_dates.compare(start, end) > 0) {
      throw ArgumentError('Start local date must not be after end local date.');
    }
    final today = _dates.todayIn(timezoneId);
    final settings = await (_db.select(
      _db.trainingPlanSettings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    final activeVersionId = settings?.activeProgramVersionId;
    final terminalStatuses = const [
      'completed',
      'partiallyCompleted',
      'skipped',
      'cancelled',
    ];
    final range =
        await (_db.select(_db.scheduledSessionOccurrences)
              ..where((table) {
                final dateRange =
                    table.effectiveLocalDate.isBiggerOrEqualValue(start) &
                    table.effectiveLocalDate.isSmallerOrEqualValue(end);
                final planFilter = activeVersionId == null
                    ? table.status.isIn(terminalStatuses)
                    : (table.programVersionId.equals(activeVersionId) |
                          table.status.isIn(terminalStatuses));
                return dateRange & planFilter;
              })
              ..orderBy([
                (table) => OrderingTerm(expression: table.effectiveLocalDate),
                (table) => OrderingTerm(expression: table.programWeekOrdinal),
                (table) => OrderingTerm(expression: table.sessionOrdinal),
                (table) => OrderingTerm(expression: table.repeatOrdinal),
              ]))
            .get();
    final overdue = activeVersionId == null
        ? <ScheduledSessionOccurrence>[]
        : await (_db.select(_db.scheduledSessionOccurrences)
                ..where(
                  (table) =>
                      table.programVersionId.equals(activeVersionId) &
                      table.effectiveLocalDate.isSmallerThanValue(today) &
                      table.status.isIn(const ['planned', 'rescheduled']) &
                      table.progressionDisposition.equals('pending'),
                )
                ..orderBy([
                  (table) => OrderingTerm(expression: table.effectiveLocalDate),
                  (table) => OrderingTerm(expression: table.programWeekOrdinal),
                  (table) => OrderingTerm(expression: table.sessionOrdinal),
                ]))
              .get();
    final nextRequiredIds = await _nextRequiredIds([
      ...range.map((row) => row.programVersionId),
      ...overdue.map((row) => row.programVersionId),
    ]);
    final items = await _hydrate(
      occurrences: [...range, ...overdue],
      today: today,
      nextRequiredIds: nextRequiredIds,
    );
    final byId = {for (final item in items) item.occurrence.id: item};
    final namedVersionIds = <String>{
      ?settings?.activeProgramVersionId,
      ?settings?.lastEndedProgramVersionId,
    };
    final namedVersions = namedVersionIds.isEmpty
        ? const <ProgramVersion>[]
        : await (_db.select(
            _db.programVersions,
          )..where((table) => table.id.isIn(namedVersionIds.toList()))).get();
    final namedProgramIds = namedVersions
        .map((version) => version.programId)
        .toSet();
    final namedPrograms = namedProgramIds.isEmpty
        ? const <Program>[]
        : await (_db.select(
            _db.programs,
          )..where((table) => table.id.isIn(namedProgramIds.toList()))).get();
    final versionsById = {
      for (final version in namedVersions) version.id: version,
    };
    final programsById = {
      for (final program in namedPrograms) program.id: program,
    };
    String? nameForVersion(String? versionId) {
      final version = versionId == null ? null : versionsById[versionId];
      return version == null ? null : programsById[version.programId]?.name;
    }

    return CalendarReadSnapshot(
      rangeOccurrences: range.map((row) => byId[row.id]!).toList(),
      overdueOccurrences: overdue.map((row) => byId[row.id]!).toList(),
      activeProgramVersionId: activeVersionId,
      activeProgramName: nameForVersion(activeVersionId),
      lastEndedProgramVersionId: settings?.lastEndedProgramVersionId,
      lastEndedProgramName: nameForVersion(settings?.lastEndedProgramVersionId),
      lastEndedOutcome: settings?.lastEndedOutcome,
      lastEndedAtUtc: settings?.lastEndedAtUtc,
    );
  }

  /// Reads every materialized occurrence for one exact program version.
  ///
  /// This is a read-only extension for version-scoped plan surfaces. It does
  /// not replace the active-plan/current-action resolver used by Training and
  /// Today, and it never reconstructs occurrences from the plan graph.
  Future<List<CalendarOccurrenceReadItem>> readOccurrencesForVersion({
    required String programVersionId,
    required String timezoneId,
  }) async {
    final versionId = programVersionId.trim();
    if (versionId.isEmpty) {
      throw ArgumentError.value(
        programVersionId,
        'programVersionId',
        'A program version is required.',
      );
    }
    _dates.validateTimezone(timezoneId);
    final today = _dates.todayIn(timezoneId);
    final occurrences =
        await (_db.select(_db.scheduledSessionOccurrences)
              ..where((table) => table.programVersionId.equals(versionId))
              ..orderBy([
                (table) => OrderingTerm(expression: table.effectiveLocalDate),
                (table) => OrderingTerm(expression: table.programWeekOrdinal),
                (table) => OrderingTerm(expression: table.sessionOrdinal),
                (table) => OrderingTerm(expression: table.repeatOrdinal),
              ]))
            .get();
    final nextRequiredIds = await _nextRequiredIds([versionId]);
    return _hydrate(
      occurrences: occurrences,
      today: today,
      nextRequiredIds: nextRequiredIds,
    );
  }

  Future<Set<String>> _nextRequiredIds(Iterable<String> versionIds) async {
    final ids = versionIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final roots =
        await (_db.select(_db.scheduledSessionOccurrences)
              ..where(
                (table) =>
                    table.programVersionId.isIn(ids) &
                    table.repeatOrdinal.equals(0) &
                    table.status.isIn(const ['planned', 'rescheduled']) &
                    table.progressionDisposition.equals('pending'),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.programWeekOrdinal),
                (table) => OrderingTerm(expression: table.sessionOrdinal),
              ]))
            .get();
    final next = <String, ScheduledSessionOccurrence>{};
    for (final root in roots) {
      next.putIfAbsent(root.programVersionId, () => root);
    }
    return next.values.map((row) => row.id).toSet();
  }

  Future<List<CalendarOccurrenceReadItem>> _hydrate({
    required List<ScheduledSessionOccurrence> occurrences,
    required String today,
    required Set<String> nextRequiredIds,
  }) async {
    if (occurrences.isEmpty) return const [];
    final templateIds = occurrences
        .map((row) => row.sessionTemplateId)
        .toSet()
        .toList();
    final versionIds = occurrences
        .map((row) => row.programVersionId)
        .toSet()
        .toList();
    final templates = await (_db.select(
      _db.sessionTemplates,
    )..where((table) => table.id.isIn(templateIds))).get();
    final templatesById = {for (final row in templates) row.id: row};
    final weeks =
        await (_db.select(_db.programWeeks)..where(
              (table) => table.id.isIn(
                templates.map((row) => row.programWeekId).toSet().toList(),
              ),
            ))
            .get();
    final weeksById = {for (final row in weeks) row.id: row};
    final blocks =
        await (_db.select(_db.programBlocks)..where(
              (table) => table.id.isIn(
                weeks.map((row) => row.programBlockId).toSet().toList(),
              ),
            ))
            .get();
    final blocksById = {for (final row in blocks) row.id: row};
    final versions = await (_db.select(
      _db.programVersions,
    )..where((table) => table.id.isIn(versionIds))).get();
    final versionsById = {for (final row in versions) row.id: row};
    final programs =
        await (_db.select(_db.programs)..where(
              (table) => table.id.isIn(
                versions.map((row) => row.programId).toSet().toList(),
              ),
            ))
            .get();
    final programsById = {for (final row in programs) row.id: row};
    final prescriptions =
        await (_db.select(_db.exercisePrescriptions)
              ..where((table) => table.sessionTemplateId.isIn(templateIds))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    final prescriptionsByTemplate = <String, List<ExercisePrescription>>{};
    for (final prescription in prescriptions) {
      (prescriptionsByTemplate[prescription.sessionTemplateId] ??= []).add(
        prescription,
      );
    }

    final items = <CalendarOccurrenceReadItem>[];
    for (final occurrence in occurrences) {
      final template = templatesById[occurrence.sessionTemplateId];
      final version = versionsById[occurrence.programVersionId];
      final week = template == null ? null : weeksById[template.programWeekId];
      final block = week == null ? null : blocksById[week.programBlockId];
      final program = version == null ? null : programsById[version.programId];
      if (template == null ||
          week == null ||
          block == null ||
          version == null ||
          program == null) {
        throw StateError(
          'Scheduled occurrence ${occurrence.id} has incomplete ancestry.',
        );
      }
      items.add(
        CalendarOccurrenceReadItem(
          occurrence: occurrence,
          template: template,
          week: week,
          block: block,
          version: version,
          program: program,
          prescriptions: prescriptionsByTemplate[template.id] ?? const [],
          isOverdue:
              occurrence.status == 'planned' ||
                  occurrence.status == 'rescheduled'
              ? occurrence.progressionDisposition == 'pending' &&
                    _dates.compare(occurrence.effectiveLocalDate, today) < 0
              : false,
          isDeload: week.isDeload,
          isNextRequired: nextRequiredIds.contains(occurrence.id),
        ),
      );
    }
    return items;
  }
}
