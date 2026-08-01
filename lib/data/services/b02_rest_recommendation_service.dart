import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/b02_execution_models.dart';

class B02RestSelectionRequest {
  final B02RestScope scope;
  final int? userSelectedSeconds;
  final int? prescribedSeconds;
  final int? memberTransitionRestSeconds;
  final int? groupRestAfterRoundSeconds;
  final int? exercisePreferenceSeconds;
  final int? templateDefaultRestSeconds;
  final int? rpe;
  final B02EffortMode effortMode;
  final bool endedAtFailure;

  const B02RestSelectionRequest({
    required this.scope,
    this.userSelectedSeconds,
    this.prescribedSeconds,
    this.memberTransitionRestSeconds,
    this.groupRestAfterRoundSeconds,
    this.exercisePreferenceSeconds,
    this.templateDefaultRestSeconds,
    this.rpe,
    this.effortMode = B02EffortMode.standard,
    this.endedAtFailure = false,
  });
}

class B02RestRecommendation {
  static const String ruleVersion = 'b02-rest-v1';

  final B02RestScope scope;
  final int? recommendedSeconds;
  final int? selectedSeconds;
  final B02RestSource source;
  final String explanation;
  final int? automaticAdjustmentSeconds;

  const B02RestRecommendation({
    required this.scope,
    required this.recommendedSeconds,
    required this.selectedSeconds,
    required this.source,
    required this.explanation,
    required this.automaticAdjustmentSeconds,
  });

  bool get isAvailable => selectedSeconds != null;
}

/// Pure B02-D08 rest selection. It chooses a value and explanation but never
/// starts a timer, mutates preferences or silently replaces an explicit value.
class RestRecommendationService {
  static const String ruleVersion = B02RestRecommendation.ruleVersion;
  static const int defaultSeconds = 90;
  static const int minimumSeconds = 45;
  static const int maximumSeconds = 240;
  static const int ruleAdjustmentSeconds = 30;
  static const int lowRpeAdjustmentSeconds = -15;
  static const int amrapAdjustmentSeconds = 15;

  const RestRecommendationService();

  B02RestRecommendation recommend(B02RestSelectionRequest request) {
    if (request.userSelectedSeconds != null) {
      if (request.userSelectedSeconds! < 0) {
        return _unavailable(
          request,
          'Configured rest is invalid: user selection.',
        );
      }
      return B02RestRecommendation(
        scope: request.scope,
        recommendedSeconds: request.userSelectedSeconds,
        selectedSeconds: request.userSelectedSeconds,
        source: B02RestSource.user,
        explanation: 'Using the current-session user selection.',
        automaticAdjustmentSeconds: null,
      );
    }

    final invalidExplicit = _firstInvalidValue(request);
    if (invalidExplicit != null) {
      return _unavailable(
        request,
        'Configured rest is invalid: $invalidExplicit.',
      );
    }

    switch (request.scope) {
      case B02RestScope.restPause:
        if (request.prescribedSeconds != null) {
          return _configured(
            request,
            request.prescribedSeconds!,
            B02RestSource.prescription,
            'Using the prescribed rest-pause interval.',
          );
        }
        return _unavailable(
          request,
          'Rest-pause rest has no user selection or prescribed interval.',
        );
      case B02RestScope.groupTransition:
        if (request.memberTransitionRestSeconds != null) {
          return _configured(
            request,
            request.memberTransitionRestSeconds!,
            B02RestSource.prescription,
            'Using the configured member-transition rest.',
          );
        }
        return _configured(
          request,
          0,
          B02RestSource.none,
          'No member-transition rest is configured.',
        );
      case B02RestScope.groupRound:
        if (request.groupRestAfterRoundSeconds != null) {
          return _configured(
            request,
            request.groupRestAfterRoundSeconds!,
            B02RestSource.prescription,
            'Using the configured group round rest.',
          );
        }
        if (request.templateDefaultRestSeconds != null) {
          return _configured(
            request,
            request.templateDefaultRestSeconds!,
            B02RestSource.template,
            'Using the session-template rest default.',
          );
        }
        return _automatic(request);
      case B02RestScope.exerciseSet:
        if (request.prescribedSeconds != null) {
          return _configured(
            request,
            request.prescribedSeconds!,
            B02RestSource.prescription,
            'Using the strength-set prescription rest.',
          );
        }
        if (request.exercisePreferenceSeconds != null) {
          return _configured(
            request,
            request.exercisePreferenceSeconds!,
            B02RestSource.exercisePreference,
            'Using the explicit exercise rest preference.',
          );
        }
        if (request.templateDefaultRestSeconds != null) {
          return _configured(
            request,
            request.templateDefaultRestSeconds!,
            B02RestSource.template,
            'Using the session-template rest default.',
          );
        }
        return _automatic(request);
    }
  }

  B02RestRecommendation _configured(
    B02RestSelectionRequest request,
    int seconds,
    B02RestSource source,
    String explanation,
  ) {
    return B02RestRecommendation(
      scope: request.scope,
      recommendedSeconds: seconds,
      selectedSeconds: seconds,
      source: source,
      explanation: explanation,
      automaticAdjustmentSeconds: null,
    );
  }

  B02RestRecommendation _automatic(B02RestSelectionRequest request) {
    var adjustment = 0;
    String reason;
    if (request.endedAtFailure || (request.rpe != null && request.rpe! >= 9)) {
      adjustment = ruleAdjustmentSeconds;
      reason = 'high effort or failure';
    } else if (request.rpe != null && request.rpe! >= 6 && request.rpe! <= 7) {
      adjustment = lowRpeAdjustmentSeconds;
      reason = 'moderate RPE';
    } else if (request.effortMode == B02EffortMode.amrap) {
      adjustment = amrapAdjustmentSeconds;
      reason = 'AMRAP effort';
    } else {
      reason = 'default fallback';
    }
    final selected = (defaultSeconds + adjustment).clamp(
      minimumSeconds,
      maximumSeconds,
    );
    return B02RestRecommendation(
      scope: request.scope,
      recommendedSeconds: selected,
      selectedSeconds: selected,
      source: B02RestSource.automatic,
      explanation: 'Automatic rest: $reason ($selected seconds).',
      automaticAdjustmentSeconds: adjustment == 0 ? null : adjustment,
    );
  }

  B02RestRecommendation _unavailable(
    B02RestSelectionRequest request,
    String explanation,
  ) {
    return B02RestRecommendation(
      scope: request.scope,
      recommendedSeconds: null,
      selectedSeconds: null,
      source: B02RestSource.none,
      explanation: explanation,
      automaticAdjustmentSeconds: null,
    );
  }

  String? _firstInvalidValue(B02RestSelectionRequest request) {
    final values = <String, int?>{
      'user selection': request.userSelectedSeconds,
      'prescription': request.prescribedSeconds,
      'member transition': request.memberTransitionRestSeconds,
      'group rest': request.groupRestAfterRoundSeconds,
      'exercise preference': request.exercisePreferenceSeconds,
      'template default': request.templateDefaultRestSeconds,
    };
    for (final entry in values.entries) {
      if (entry.value != null && entry.value! < 0) return entry.key;
    }
    if (request.rpe != null && (request.rpe! < 1 || request.rpe! > 10)) {
      return 'RPE';
    }
    return null;
  }
}

class B02RestDraftCoordinator {
  const B02RestDraftCoordinator();

  B02ExecutionDraftState begin(
    B02ExecutionDraftState draft,
    B02RestPeriod period,
  ) {
    if (draft.restPeriods.any((rest) => rest.endedAtUtc == null)) {
      throw B02ValidationException(
        'Only one rest period may be open in a draft.',
      );
    }
    if (draft.restPeriods.any((rest) => rest.id == period.id)) {
      throw B02ValidationException(
        'Rest period ID already exists in the draft.',
      );
    }
    if (period.endedAtUtc != null) {
      throw B02ValidationException('A new rest period must be open.');
    }
    return draft.copyWith(restPeriods: [...draft.restPeriods, period]);
  }

  B02ExecutionDraftState select(
    B02ExecutionDraftState draft,
    String periodId,
    int selectedSeconds,
  ) {
    if (selectedSeconds < 0) {
      throw B02ValidationException('Selected rest must not be negative.');
    }
    final period = _find(draft, periodId);
    if (period.endedAtUtc != null) {
      throw B02ValidationException('Completed rest periods are immutable.');
    }
    return draft.copyWith(
      restPeriods: [
        for (final value in draft.restPeriods)
          value.id == periodId
              ? _copyPeriod(value, selectedSeconds: selectedSeconds)
              : value,
      ],
    );
  }

  B02ExecutionDraftState finish(
    B02ExecutionDraftState draft,
    String periodId, {
    required DateTime endedAtUtc,
    required B02RestEndReason endReason,
  }) {
    final period = _find(draft, periodId);
    if (period.endedAtUtc != null) {
      throw B02ValidationException('Completed rest periods are immutable.');
    }
    final ended = endedAtUtc.toUtc();
    final actualSeconds = math.max(
      0,
      ended.difference(period.startedAtUtc).inSeconds,
    );
    return draft.copyWith(
      restPeriods: [
        for (final value in draft.restPeriods)
          value.id == periodId
              ? _copyPeriod(
                  value,
                  actualSeconds: actualSeconds,
                  endedAtUtc: ended,
                  endReason: endReason,
                )
              : value,
      ],
    );
  }

  B02ExecutionDraftState extend(
    B02ExecutionDraftState draft,
    String periodId, {
    int seconds = 30,
  }) {
    if (seconds <= 0) {
      throw B02ValidationException('Rest extension must be positive.');
    }
    final period = _find(draft, periodId);
    final current = period.selectedSeconds ?? period.recommendedSeconds ?? 0;
    return select(draft, periodId, current + seconds);
  }

  B02ExecutionDraftState skip(
    B02ExecutionDraftState draft,
    String periodId, {
    required DateTime endedAtUtc,
  }) {
    return finish(
      draft,
      periodId,
      endedAtUtc: endedAtUtc,
      endReason: B02RestEndReason.skipped,
    );
  }

  B02RestPeriod _find(B02ExecutionDraftState draft, String periodId) {
    for (final period in draft.restPeriods) {
      if (period.id == periodId) return period;
    }
    throw B02ValidationException('Rest period $periodId was not found.');
  }

  B02RestPeriod _copyPeriod(
    B02RestPeriod period, {
    int? selectedSeconds,
    int? actualSeconds,
    DateTime? endedAtUtc,
    B02RestEndReason? endReason,
  }) {
    return B02RestPeriod(
      id: period.id,
      performedSetId: period.performedSetId,
      performedExerciseGroupId: period.performedExerciseGroupId,
      scope: period.scope,
      recommendedSeconds: period.recommendedSeconds,
      selectedSeconds: selectedSeconds ?? period.selectedSeconds,
      actualSeconds: actualSeconds ?? period.actualSeconds,
      source: period.source,
      startedAtUtc: period.startedAtUtc,
      endedAtUtc: endedAtUtc ?? period.endedAtUtc,
      endReason: endReason ?? period.endReason,
    );
  }
}

class B02RestTimerSnapshot {
  final B02RestPeriod period;

  const B02RestTimerSnapshot(this.period);

  int get durationSeconds =>
      period.selectedSeconds ?? period.recommendedSeconds ?? 0;

  int remainingSeconds(DateTime nowUtc) {
    if (period.endedAtUtc != null) return 0;
    final elapsed = nowUtc.toUtc().difference(period.startedAtUtc).inSeconds;
    return math.max(0, durationSeconds - elapsed);
  }

  bool hasElapsed(DateTime nowUtc) => remainingSeconds(nowUtc) == 0;
}

class B02RestPeriodPersistence {
  const B02RestPeriodPersistence._();

  static PerformedRestPeriodsCompanion toCompanion(
    B02RestPeriod period, {
    required int sessionId,
  }) {
    return PerformedRestPeriodsCompanion.insert(
      id: period.id,
      sessionId: sessionId,
      performedSetId: Value(period.performedSetId),
      performedExerciseGroupId: Value(period.performedExerciseGroupId),
      scope: period.scope.dbValue,
      recommendedSeconds: Value(period.recommendedSeconds),
      selectedSeconds: Value(period.selectedSeconds),
      actualSeconds: Value(period.actualSeconds),
      source: period.source.dbValue,
      startedAtUtc: period.startedAtUtc,
      endedAtUtc: Value(period.endedAtUtc),
      endReason: Value(period.endReason?.dbValue),
    );
  }

  static B02RestPeriod fromRow(PerformedRestPeriod row) {
    return B02RestPeriod(
      id: row.id,
      performedSetId: row.performedSetId,
      performedExerciseGroupId: row.performedExerciseGroupId,
      scope: B02RestScope.parse(row.scope),
      recommendedSeconds: row.recommendedSeconds,
      selectedSeconds: row.selectedSeconds,
      actualSeconds: row.actualSeconds,
      source: B02RestSource.parse(row.source),
      startedAtUtc: row.startedAtUtc.toUtc(),
      endedAtUtc: row.endedAtUtc?.toUtc(),
      endReason: row.endReason == null
          ? null
          : B02RestEndReason.parse(row.endReason),
    );
  }
}
