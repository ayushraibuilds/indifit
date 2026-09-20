import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/plan_analytics_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';

final _now = DateTime.utc(2026, 8, 24, 10);

void main() {
  late LocalScheduleDateService dates;

  setUp(() {
    dates = LocalScheduleDateService(nowUtc: () => _now);
  });

  test('empty occurrences yields zeroed summary and empty weeks', () {
    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: const [],
      history: const [],
      concurrentIndependentCount: 0,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );
    expect(summary.totalScheduled, 0);
    expect(summary.completedCount, 0);
    expect(summary.partiallyCompletedCount, 0);
    expect(summary.strictAdherenceRate, isNull);
    expect(summary.compositeAdherenceRate, isNull);
    expect(summary.totalVolumeKg, 0.0);
    expect(summary.totalDurationSeconds, 0);
    expect(summary.hasActiveOccurrences, isFalse);

    final weeks = PlanAnalyticsCalculator.calculateWeeks(
      occurrences: const [],
      history: const [],
      todayLocalDate: '2026-08-24',
      dates: dates,
    );
    expect(weeks, isEmpty);
  });

  test('fully completed plan calculates 100% adherence, volume, and duration', () {
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      date: '2026-08-17',
      status: 'completed',
    );
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      date: '2026-08-19',
      status: 'completed',
    );
    final h1 = _mockHistory(
      occurrenceId: 'occ-1',
      volumeKg: 5000.0,
      durationSec: 3600,
    );
    final h2 = _mockHistory(
      occurrenceId: 'occ-2',
      volumeKg: 4500.0,
      durationSec: 3000,
    );

    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: [occ1, occ2],
      history: [h1, h2],
      concurrentIndependentCount: 0,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(summary.totalScheduled, 2);
    expect(summary.completedCount, 2);
    expect(summary.partiallyCompletedCount, 0);
    expect(summary.strictAdherenceRate, 1.0);
    expect(summary.compositeAdherenceRate, 1.0);
    expect(summary.totalVolumeKg, 9500.0);
    expect(summary.totalDurationSeconds, 6600);
    expect(summary.hasStrengthSessions, isTrue);
  });

  test('discloses half weight for partials: strict vs composite adherence', () {
    // 2 elapsed occurrences: 1 completed, 1 partial
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      date: '2026-08-17',
      status: 'completed',
    );
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      date: '2026-08-19',
      status: 'partiallyCompleted',
    );
    final h1 = _mockHistory(
      occurrenceId: 'occ-1',
      volumeKg: 3000.0,
      durationSec: 2000,
    );
    final h2 = _mockHistory(
      occurrenceId: 'occ-2',
      volumeKg: 1500.0,
      durationSec: 1000,
      completionKind: 'partial',
    );

    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: [occ1, occ2],
      history: [h1, h2],
      concurrentIndependentCount: 0,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(summary.completedCount, 1);
    expect(summary.partiallyCompletedCount, 1);
    expect(summary.elapsedEligibleCount, 2);
    // Strict adherence: 1 / 2 = 50%
    expect(summary.strictAdherenceRate, 0.5);
    // Composite adherence (partials count half): (1 + 0.5) / 2 = 75%
    expect(summary.compositeAdherenceRate, 0.75);
    expect(summary.totalVolumeKg, 4500.0);
    expect(summary.totalDurationSeconds, 3000);
  });

  test('cancelled occurrences are excluded from adherence denominator and counted explicitly', () {
    // 3 past occurrences: 1 completed, 1 cancelled, 1 planned (overdue)
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      date: '2026-08-17',
      status: 'completed',
    );
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      date: '2026-08-19',
      status: 'cancelled',
    );
    final occ3 = _mockOccurrence(
      id: 'occ-3',
      date: '2026-08-21',
      status: 'planned',
    );
    final h1 = _mockHistory(occurrenceId: 'occ-1', volumeKg: 2000.0);

    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: [occ1, occ2, occ3],
      history: [h1],
      concurrentIndependentCount: 0,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(summary.totalScheduled, 3);
    expect(summary.cancelledCount, 1);
    expect(summary.completedCount, 1);
    expect(summary.overdueCount, 1);
    expect(summary.elapsedCount, 3);
    // Denominator excludes cancelled: 3 - 1 = 2
    expect(summary.elapsedEligibleCount, 2);
    // Strict adherence: 1 / 2 = 50%
    expect(summary.strictAdherenceRate, 0.5);
  });

  test('inProgress occurrences are tracked distinctly', () {
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      date: '2026-08-24',
      status: 'inProgress',
    );

    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: [occ1],
      history: const [],
      concurrentIndependentCount: 0,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(summary.inProgressCount, 1);
    expect(summary.completedCount, 0);
  });

  test('skipped occurrences distinguish advance from keepPending', () {
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      date: '2026-08-17',
      status: 'skipped',
      skipMode: 'advance',
    );
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      date: '2026-08-19',
      status: 'skipped',
      skipMode: 'keepPending',
    );

    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: [occ1, occ2],
      history: const [],
      concurrentIndependentCount: 0,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(summary.skippedCount, 2);
    expect(summary.skippedAdvanceCount, 1);
    expect(summary.skippedKeepPendingCount, 1);
  });

  test('rescheduled occurrences are identified by date shift or status', () {
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      originalDate: '2026-08-17',
      date: '2026-08-18',
      status: 'completed',
    );
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      originalDate: '2026-08-19',
      date: '2026-08-19',
      status: 'rescheduled',
    );

    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: [occ1, occ2],
      history: const [],
      concurrentIndependentCount: 0,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(summary.rescheduledCount, 2);
  });

  test('concurrent independent workouts are tallied but excluded from plan adherence', () {
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      date: '2026-08-17',
      status: 'completed',
    );

    final summary = PlanAnalyticsCalculator.calculateSummary(
      occurrences: [occ1],
      history: const [],
      concurrentIndependentCount: 5,
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(summary.concurrentIndependentCount, 5);
    expect(summary.completedCount, 1);
    expect(summary.totalScheduled, 1);
    expect(summary.strictAdherenceRate, 1.0);
  });

  test('week analytics indexes displayWeekNumber from 1 (ordinal + 1)', () {
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      weekOrdinal: 0,
      date: '2026-08-17',
      status: 'completed',
    );
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      weekOrdinal: 1,
      date: '2026-08-24',
      status: 'planned',
    );

    final weeks = PlanAnalyticsCalculator.calculateWeeks(
      occurrences: [occ1, occ2],
      history: const [],
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(weeks, hasLength(2));
    expect(weeks[0].weekOrdinal, 0);
    expect(weeks[0].displayWeekNumber, 1);
    expect(weeks[1].weekOrdinal, 1);
    expect(weeks[1].displayWeekNumber, 2);
  });

  test('modality-aware week volume: cardio weeks do not produce false 0 kg comparison against strength weeks', () {
    // Week 1: Strength week (5000 kg, 3600 sec)
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      weekOrdinal: 0,
      date: '2026-08-10',
      status: 'completed',
    );
    final h1 = _mockHistory(
      occurrenceId: 'occ-1',
      volumeKg: 5000.0,
      durationSec: 3600,
      activityType: B02ActivityType.strength,
    );

    // Week 2: Running week (0 kg, 2400 sec)
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      weekOrdinal: 1,
      date: '2026-08-17',
      status: 'completed',
      activityType: 'running',
    );
    final h2 = _mockHistory(
      occurrenceId: 'occ-2',
      volumeKg: 0.0,
      durationSec: 2400,
      activityType: B02ActivityType.running,
    );

    final weeks = PlanAnalyticsCalculator.calculateWeeks(
      occurrences: [occ1, occ2],
      history: [h1, h2],
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(weeks[0].hasStrengthSessions, isTrue);
    expect(weeks[0].totalVolumeKg, 5000.0);
    expect(weeks[0].totalDurationSeconds, 3600);

    expect(weeks[1].hasStrengthSessions, isFalse);
    expect(weeks[1].totalVolumeKg, 0.0);
    expect(weeks[1].totalDurationSeconds, 2400);

    // Comparison across modalities:
    final comp = weeks[1].comparisonWithPrevious!;
    expect(comp.isCardioOrMobilityComparison, isTrue);
    expect(comp.volumeDeltaKg, isNull);
    expect(comp.volumeDeltaPercentage, isNull);
    // Duration is universal:
    expect(comp.durationDeltaSeconds, -1200);
    expect(comp.durationDeltaPercentage, closeTo(-33.33, 0.01));
  });

  test('week-over-week strength volume delta handles deload flags and zero volume safely', () {
    // Week 1: 4000 kg, 3000 sec
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      weekOrdinal: 0,
      date: '2026-08-10',
      status: 'completed',
    );
    final h1 = _mockHistory(occurrenceId: 'occ-1', volumeKg: 4000.0, durationSec: 3000);

    // Week 2: Deload week (2000 kg, 2000 sec)
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      weekOrdinal: 1,
      date: '2026-08-17',
      status: 'completed',
      isDeload: true,
    );
    final h2 = _mockHistory(occurrenceId: 'occ-2', volumeKg: 2000.0, durationSec: 2000);

    final weeks = PlanAnalyticsCalculator.calculateWeeks(
      occurrences: [occ1, occ2],
      history: [h1, h2],
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    final comp = weeks[1].comparisonWithPrevious!;
    expect(comp.isDeloadComparison, isTrue);
    expect(comp.volumeDeltaKg, -2000.0);
    expect(comp.volumeDeltaPercentage, -50.0);
    expect(comp.durationDeltaSeconds, -1000);
  });

  test('future strength week derives strength modality from template and does not produce comparison against previous week', () {
    // Week 1: Elapsed strength week (completed, 5000 kg, 3600 sec)
    final occ1 = _mockOccurrence(
      id: 'occ-1',
      weekOrdinal: 0,
      date: '2026-08-10',
      status: 'completed',
      activityType: 'strength',
    );
    final h1 = _mockHistory(
      occurrenceId: 'occ-1',
      volumeKg: 5000.0,
      durationSec: 3600,
      activityType: B02ActivityType.strength,
    );

    // Week 2: Future strength week (planned, 0 completed, template is strength)
    final occ2 = _mockOccurrence(
      id: 'occ-2',
      weekOrdinal: 1,
      date: '2026-08-31',
      status: 'planned',
      activityType: 'strength',
    );

    final weeks = PlanAnalyticsCalculator.calculateWeeks(
      occurrences: [occ1, occ2],
      history: [h1],
      todayLocalDate: '2026-08-24',
      dates: dates,
    );

    expect(weeks, hasLength(2));

    // Week 1 is elapsed
    expect(weeks[0].isElapsed, isTrue);
    expect(weeks[0].hasStrengthSessions, isTrue);

    // Week 2 is in the future:
    // 1. Modality is strength because planned template is strength (not cardio/mobility)
    expect(weeks[1].hasStrengthSessions, isTrue);
    expect(weeks[1].strengthSessionCount, 0);
    expect(weeks[1].totalVolumeKg, 0.0);
    expect(weeks[1].isElapsed, isFalse);
    expect(weeks[1].pendingSessions, 1);
    expect(weeks[1].upcomingSessions, 1);
    expect(weeks[1].overdueSessions, 0);

    // 2. Future weeks must NEVER produce week-over-week comparisons (no zero-deltas or false captions)
    expect(weeks[1].comparisonWithPrevious, isNull);
  });
}

CalendarOccurrenceReadItem _mockOccurrence({
  required String id,
  required String date,
  String? originalDate,
  required String status,
  String? skipMode,
  int weekOrdinal = 0,
  bool isDeload = false,
  String activityType = 'strength',
}) {
  final program = Program(
    id: 'prog-1',
    name: 'Test Program',
    createdAtUtc: _now,
  );
  final version = ProgramVersion(
    id: 'ver-1',
    programId: program.id,
    versionNumber: 1,
    status: 'published',
    origin: 'manual',
    createdAtUtc: _now,
  );
  final block = ProgramBlock(
    id: 'block-1',
    programVersionId: version.id,
    ordinal: 0,
    name: 'Base Block',
  );
  final week = ProgramWeek(
    id: 'week-$weekOrdinal',
    programVersionId: version.id,
    programBlockId: block.id,
    ordinalInBlock: weekOrdinal,
    programWeekOrdinal: weekOrdinal,
    isDeload: isDeload,
    name: 'Week ${weekOrdinal + 1}',
  );
  final template = SessionTemplate(
    id: 'tpl-$id',
    programWeekId: week.id,
    ordinal: 0,
    name: 'Day 1',
    plannedWeekday: DateTime.monday,
    activityType: activityType,
  );
  final occurrence = ScheduledSessionOccurrence(
    id: id,
    programVersionId: version.id,
    sessionTemplateId: template.id,
    programBlockOrdinal: 0,
    programWeekOrdinal: weekOrdinal,
    sessionOrdinal: 0,
    repeatOrdinal: 0,
    originalLocalDate: originalDate ?? date,
    originalTimezoneId: 'Asia/Kolkata',
    effectiveLocalDate: date,
    effectiveTimezoneId: 'Asia/Kolkata',
    status: status,
    progressionDisposition: status == 'completed' ? 'satisfied' : 'pending',
    skipMode: skipMode,
    createdAtUtc: _now,
  );

  return CalendarOccurrenceReadItem(
    occurrence: occurrence,
    template: template,
    week: week,
    block: block,
    version: version,
    program: program,
    prescriptions: const [],
    isOverdue: false,
    isDeload: isDeload,
    isNextRequired: false,
  );
}

B02ActivityHistoryItem _mockHistory({
  required String occurrenceId,
  double volumeKg = 0.0,
  int durationSec = 1800,
  String completionKind = 'full',
  B02ActivityType activityType = B02ActivityType.strength,
}) {
  return B02ActivityHistoryItem(
    sessionId: occurrenceId.hashCode,
    name: 'Workout Session',
    activityType: activityType,
    recordKind: B02HistoryRecordKind.canonical,
    completedAt: _now,
    durationSeconds: durationSec,
    completionKind: completionKind,
    scheduledOccurrenceId: occurrenceId,
    legacySetCount: 0,
    performedExerciseCount: 1,
    performedGroupCount: 0,
    cardioIntervalCount: 0,
    hasCardioDetail: false,
    hasMobilityDetail: false,
    totalVolumeKg: volumeKg,
  );
}
