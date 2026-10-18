import 'package:drift/drift.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import 'plan_schedule_reader.dart';
import 'program_activation_coordinator.dart';
import 'program_lifecycle_repository.dart';
import 'program_repository.dart';

/// The planned weight step for a repeated block's main lifts. A rule the
/// user chooses, never an estimate.
const nextBlockMainLiftStepKg = 2.5;

/// A main lift's planned target for the next block: last block's heaviest
/// logged working set plus [nextBlockMainLiftStepKg].
class MainLiftIncrease {
  const MainLiftIncrease({
    required this.exerciseId,
    required this.name,
    required this.lastTopKg,
    required this.loadBasis,
  });

  final String exerciseId;
  final String name;
  final double lastTopKg;
  final String? loadBasis;

  double get nextTargetKg => lastTopKg + nextBlockMainLiftStepKg;
}

/// The active plan once its last scheduled workout is behind it (UF-13).
class FinishedPlanState {
  const FinishedPlanState({
    required this.programVersionId,
    required this.planName,
    required this.completedCount,
    required this.increases,
    required this.schedule,
  });

  final String programVersionId;
  final String planName;
  final int completedCount;

  /// Main lifts with a logged weight. Lifts without one keep their target.
  final List<MainLiftIncrease> increases;
  final PlanScheduleShape? schedule;

  /// "+2.5 kg on squat, bench, row from last block's top sets", or null
  /// when no main lift has a logged weight.
  String? get increaseRule {
    if (increases.isEmpty) return null;
    final names = increases.map((lift) => lift.name.toLowerCase()).join(', ');
    return '+${_kg(nextBlockMainLiftStepKg)} kg on $names from last '
        'block\'s top sets';
  }

  static String _kg(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// Reads whether the active plan is finished and starts its next block. The
/// finished block is ended as finished and stays in history unchanged.
class PlanNextBlockRepository {
  PlanNextBlockRepository(
    this._db, {
    required ProgramRepository programs,
    required LocalScheduleDateService dates,
  }) : _programs = programs,
       _dates = dates;

  final AppDatabase _db;
  final ProgramRepository _programs;
  final LocalScheduleDateService _dates;

  /// The active plan when nothing is in progress and no unstarted workout
  /// is dated [todayLocalDate] or later: its last workout is done, or its
  /// end date has passed. Null otherwise.
  Future<FinishedPlanState?> readFinished({
    required String todayLocalDate,
  }) async {
    final settings = await (_db.select(
      _db.trainingPlanSettings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    final versionId = settings?.activeProgramVersionId;
    if (versionId == null) return null;
    final occurrences = await (_db.select(
      _db.scheduledSessionOccurrences,
    )..where((table) => table.programVersionId.equals(versionId))).get();
    if (occurrences.isEmpty) return null;
    final stillAhead = occurrences.any(
      (occurrence) =>
          occurrence.status == 'inProgress' ||
          ((occurrence.status == 'planned' ||
                  occurrence.status == 'rescheduled') &&
              _dates.compare(occurrence.effectiveLocalDate, todayLocalDate) >=
                  0),
    );
    if (stillAhead) return null;

    final detail = await _programs.getProgramVersionDetail(versionId);
    if (detail == null) return null;
    return FinishedPlanState(
      programVersionId: versionId,
      planName: detail.program.name,
      completedCount: occurrences
          .where(
            (occurrence) =>
                occurrence.status == 'completed' ||
                occurrence.status == 'partiallyCompleted',
          )
          .length,
      increases: await _mainLiftIncreases(detail),
      schedule: await PlanScheduleReader(_db, _dates).read(versionId),
    );
  }

  /// Each session's first exercise is its main lift (owner decision for
  /// UF-13: the model has no main-lift flag).
  static List<ExercisePrescription> mainLiftPrescriptions(
    ProgramDetailAggregate detail,
  ) {
    final weekOrdinal = {
      for (final week in detail.weeks) week.id: week.programWeekOrdinal,
    };
    final templates = [...detail.sessionTemplates]
      ..sort((a, b) {
        final byWeek = weekOrdinal[a.programWeekId]!.compareTo(
          weekOrdinal[b.programWeekId]!,
        );
        return byWeek == 0 ? a.ordinal.compareTo(b.ordinal) : byWeek;
      });
    final mains = <ExercisePrescription>[];
    for (final template in templates) {
      final inSession =
          detail.exercisePrescriptions
              .where((p) => p.sessionTemplateId == template.id)
              .toList()
            ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      if (inSession.isNotEmpty) mains.add(inSession.first);
    }
    return mains;
  }

  Future<List<MainLiftIncrease>> _mainLiftIncreases(
    ProgramDetailAggregate detail,
  ) async {
    final prescriptionIds = detail.exercisePrescriptions
        .map((p) => p.id)
        .toList(growable: false);
    final increases = <MainLiftIncrease>[];
    final seen = <String>{};
    for (final main in mainLiftPrescriptions(detail)) {
      final exerciseId = main.exerciseId;
      if (exerciseId == null || !seen.add(exerciseId)) continue;
      final query =
          _db.select(_db.performedSets).join([
              innerJoin(
                _db.performedExercises,
                _db.performedExercises.id.equalsExp(
                  _db.performedSets.performedExerciseId,
                ),
              ),
            ])
            ..where(
              _db.performedExercises.sourceExercisePrescriptionId.isIn(
                    prescriptionIds,
                  ) &
                  _db.performedExercises.actualExerciseId.equals(exerciseId) &
                  _db.performedSets.role.equals('working') &
                  _db.performedSets.actualLoadKg.isNotNull() &
                  _db.performedSets.actualReps.isBiggerThanValue(0),
            )
            ..orderBy([OrderingTerm.desc(_db.performedSets.actualLoadKg)])
            ..limit(1);
      final top = await query.getSingleOrNull();
      final set = top?.readTable(_db.performedSets);
      if (set?.actualLoadKg == null || set!.actualLoadKg! <= 0) continue;
      increases.add(
        MainLiftIncrease(
          exerciseId: exerciseId,
          name: main.exerciseNameSnapshot,
          lastTopKg: set.actualLoadKg!,
          loadBasis: set.actualLoadBasis,
        ),
      );
    }
    return increases;
  }

  /// Copies the finished version into the next block's draft. With
  /// [increases], each main lift with a logged weight gets its planned
  /// target set to [MainLiftIncrease.nextTargetKg]; everything else keeps
  /// its prescription as it was.
  Future<String> prepareNextBlock({
    required String finishedVersionId,
    List<MainLiftIncrease> increases = const [],
  }) async {
    final draftId = await _programs.copyToNewDraftVersion(finishedVersionId);
    if (increases.isEmpty) return draftId;
    final detail = await _programs.getProgramVersionDetail(draftId);
    if (detail == null) return draftId;
    final byExercise = {for (final lift in increases) lift.exerciseId: lift};
    await _db.transaction(() async {
      for (final main in mainLiftPrescriptions(detail)) {
        final lift = byExercise[main.exerciseId];
        if (lift == null) continue;
        final existing = await (_db.select(
          _db.strengthSetPrescriptions,
        )..where((t) => t.exercisePrescriptionId.equals(main.id))).get();
        if (existing.isNotEmpty) {
          await (_db.update(
            _db.strengthSetPrescriptions,
          )..where((t) => t.exercisePrescriptionId.equals(main.id))).write(
            StrengthSetPrescriptionsCompanion(
              targetLoadKg: Value(lift.nextTargetKg),
              loadBasis: Value(lift.loadBasis),
            ),
          );
          continue;
        }
        for (var ordinal = 0; ordinal < main.plannedSets; ordinal++) {
          await _db
              .into(_db.strengthSetPrescriptions)
              .insert(
                StrengthSetPrescriptionsCompanion.insert(
                  id: '${main.id}::set-$ordinal',
                  exercisePrescriptionId: main.id,
                  ordinal: ordinal,
                  targetLoadKg: Value(lift.nextTargetKg),
                  loadBasis: Value(lift.loadBasis),
                ),
              );
        }
      }
    });
    return draftId;
  }

  /// Ends the finished block as finished and activates [draftVersionId] in
  /// one transaction, so a failure leaves the finished plan current.
  Future<ActivationResult> startNextBlock({
    required ProgramLifecycleRepository lifecycle,
    required ProgramActivationCoordinator activation,
    required String draftVersionId,
    required String commandId,
    required String startLocalDate,
    required String timezoneId,
    List<int>? trainingWeekdays,
  }) {
    return _db.transaction(() async {
      await lifecycle.endActivePlan(
        EndActivePlanCommand(
          outcome: PlanEndOutcome.finished,
          commandId: '$commandId::finish',
        ),
      );
      return activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: draftVersionId,
          commandId: commandId,
          activationLocalDate: startLocalDate,
          timezoneId: timezoneId,
          trainingWeekdays: trainingWeekdays,
        ),
      );
    });
  }
}
