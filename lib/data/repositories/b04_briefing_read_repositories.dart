import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../models/b04_briefing_read_models.dart';
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recommendation_history_models.dart';
import '../models/b04_recommendation_models.dart';
import '../services/b04_recommendation_engine.dart';
import 'b04_recommendation_history_repository.dart';

class B04BriefingReadRepositoryError implements Exception {
  final String code;
  final String message;

  const B04BriefingReadRepositoryError(this.code, this.message);

  @override
  String toString() => 'B04BriefingReadRepositoryError($code): $message';
}

/// Shared projection/orchestration implementation for the two B04-13
/// consumers. It is deliberately not a new recommendation calculator: all
/// live recommendations are evaluated by [B04RecommendationEngine].
class _B04BriefingReadProjection {
  final B04BriefingHistorySource history;
  final B04RecommendationEngine engine;
  final LocalScheduleDateService dates;

  const _B04BriefingReadProjection({
    required this.history,
    required this.engine,
    required this.dates,
  });

  Future<B04BriefingReadModel> readHistory({
    required B04RecommendationHistoryScope scope,
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async {
    final owner = _owner(userId);
    final window = _validateWindow(
      scope: scope,
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      timezoneId: timezoneId,
    );
    final rows = await history.listHistory(userId: owner, scope: scope);
    final matching = <B04HistoricalRecommendation>[];
    for (final row in rows) {
      if (row.userId != owner) {
        throw const B04BriefingReadRepositoryError(
          'cross_user_history',
          'A briefing cannot project another user’s recommendation history.',
        );
      }
      if (row.scope != scope ||
          row.localPeriodStart != window.startLocalDate ||
          row.localPeriodEnd != window.endLocalDate ||
          row.timezoneId != window.timezoneId) {
        continue;
      }
      matching.add(row);
    }
    return _fromHistory(
      scope: scope,
      userId: owner,
      window: window,
      rows: matching,
    );
  }

  B04BriefingReadModel evaluate({
    required B04RecommendationHistoryScope scope,
    required B04RecommendationContext context,
    required Iterable<B04RecommendationCandidate> candidates,
    Iterable<B04HistoricalRecommendation> historyRows = const [],
  }) {
    _validateEvaluationWindow(scope, context.window);
    final evaluation = engine.evaluate(
      context: context,
      candidates: candidates,
    );
    final feedbackById = <String, List<B04RecommendationFeedbackRecord>>{};
    for (final row in historyRows) {
      if (row.userId != evaluation.userId) {
        throw const B04BriefingReadRepositoryError(
          'cross_user_history',
          'A briefing cannot project another user’s recommendation history.',
        );
      }
      feedbackById[row.id] = row.feedback;
    }
    return _fromEvaluation(
      scope: scope,
      evaluation: evaluation,
      feedbackById: feedbackById,
    );
  }

  B04BriefingReadModel projectEvaluation({
    required B04RecommendationHistoryScope scope,
    required B04RecommendationEvaluation evaluation,
    Iterable<B04HistoricalRecommendation> historyRows = const [],
  }) {
    _validateEvaluationWindow(
      scope,
      B04RecommendationWindow(
        period: evaluation.period,
        startLocalDate: evaluation.startLocalDate,
        endLocalDate: evaluation.endLocalDate,
        timezoneId: evaluation.timezoneId,
        targetEvaluationWindowDays: 0,
        aggregateWindowDays: 0,
      ),
    );
    final feedbackById = <String, List<B04RecommendationFeedbackRecord>>{};
    for (final row in historyRows) {
      if (row.userId != evaluation.userId) {
        throw const B04BriefingReadRepositoryError(
          'cross_user_history',
          'A briefing cannot project another user’s recommendation history.',
        );
      }
      feedbackById[row.id] = row.feedback;
    }
    return _fromEvaluation(
      scope: scope,
      evaluation: evaluation,
      feedbackById: feedbackById,
    );
  }

  B04BriefingReadModel _fromHistory({
    required B04RecommendationHistoryScope scope,
    required String userId,
    required B04RecommendationWindow window,
    required List<B04HistoricalRecommendation> rows,
  }) {
    final recommendations = [
      for (final row in rows) B04BriefingRecommendation.fromHistory(row),
    ]..sort(_compareItems);
    final missing = <String>{
      for (final item in recommendations) ...item.missingEvidence,
    }..removeWhere((item) => item.trim().isEmpty);
    final reasons = <String>{
      for (final item in recommendations)
        if (item.state == B04RecommendationState.unavailable)
          ...item.missingEvidence,
    }..removeWhere((item) => item.trim().isEmpty);
    final unavailable =
        recommendations.isNotEmpty &&
        recommendations.every(
          (item) => item.state == B04RecommendationState.unavailable,
        );
    final policyState = _historyPolicyState(rows);
    if (policyState == B04RecommendationPolicyState.hold) {
      reasons.add('adaptive_policy_hold');
    }
    return B04BriefingReadModel(
      scope: scope,
      userId: userId,
      startLocalDate: window.startLocalDate,
      endLocalDate: window.endLocalDate,
      timezoneId: window.timezoneId,
      status: rows.isEmpty
          ? B04BriefingReadStatus.noData
          : unavailable
          ? B04BriefingReadStatus.unavailable
          : B04BriefingReadStatus.available,
      unavailableReasons: List.unmodifiable(reasons.toList()..sort()),
      eligibilityState: _historyEligibilityState(rows),
      consentState: _historyConsentState(rows),
      policyState: policyState,
      missingEvidence: List.unmodifiable(missing.toList()..sort()),
      recommendations: List.unmodifiable(recommendations),
      lowRiskWarnings: const [],
    );
  }

  B04BriefingReadModel _fromEvaluation({
    required B04RecommendationHistoryScope scope,
    required B04RecommendationEvaluation evaluation,
    required Map<String, List<B04RecommendationFeedbackRecord>> feedbackById,
  }) {
    final recommendations = [
      for (final item in evaluation.recommendations)
        B04BriefingRecommendation.fromEngine(
          item,
          feedback: feedbackById[item.id] ?? const [],
        ),
    ]..sort(_compareItems);
    final missing = <String>{
      for (final item in recommendations) ...item.missingEvidence,
    };
    final reasons = <String>{
      ...missing,
      if (evaluation.policyState == B04RecommendationPolicyState.hold)
        'adaptive_policy_hold',
    };
    final unavailable =
        recommendations.isNotEmpty &&
        recommendations.every(
          (item) => item.state == B04RecommendationState.unavailable,
        );
    return B04BriefingReadModel(
      scope: scope,
      userId: evaluation.userId,
      startLocalDate: evaluation.startLocalDate,
      endLocalDate: evaluation.endLocalDate,
      timezoneId: evaluation.timezoneId,
      status: recommendations.isEmpty
          ? B04BriefingReadStatus.noData
          : unavailable
          ? B04BriefingReadStatus.unavailable
          : B04BriefingReadStatus.available,
      unavailableReasons: List.unmodifiable(reasons.toList()..sort()),
      eligibilityState: evaluation.eligibilityState,
      consentState: evaluation.consentState,
      policyState: evaluation.policyState,
      missingEvidence: List.unmodifiable(missing.toList()..sort()),
      recommendations: List.unmodifiable(recommendations),
      lowRiskWarnings: evaluation.lowRiskWarnings,
    );
  }

  B04RecommendationWindow _validateWindow({
    required B04RecommendationHistoryScope scope,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) {
    final period = switch (scope) {
      B04RecommendationHistoryScope.daily => B04RecommendationPeriod.daily,
      B04RecommendationHistoryScope.weekly => B04RecommendationPeriod.weekly,
      _ => throw const B04BriefingReadRepositoryError(
        'invalid_briefing_scope',
        'Only daily and weekly recommendation history can be projected.',
      ),
    };
    final zone = timezoneId.trim();
    dates.validateTimezone(zone);
    final start = dates.normalizeLocalDate(startLocalDate);
    final end = dates.normalizeLocalDate(endLocalDate);
    if (period == B04RecommendationPeriod.daily && start != end) {
      throw const B04BriefingReadRepositoryError(
        'invalid_daily_period',
        'A daily briefing must cover exactly one local civil date.',
      );
    }
    if (period == B04RecommendationPeriod.weekly &&
        dates.addCalendarDays(start, zone, 6) != end) {
      throw const B04BriefingReadRepositoryError(
        'invalid_weekly_period',
        'A weekly review must cover exactly seven local civil dates.',
      );
    }
    return B04RecommendationWindow(
      period: period,
      startLocalDate: start,
      endLocalDate: end,
      timezoneId: zone,
      targetEvaluationWindowDays: 0,
      aggregateWindowDays: 0,
    );
  }

  void _validateEvaluationWindow(
    B04RecommendationHistoryScope scope,
    B04RecommendationWindow window,
  ) {
    final expectedScope = switch (window.period) {
      B04RecommendationPeriod.daily => B04RecommendationHistoryScope.daily,
      B04RecommendationPeriod.weekly => B04RecommendationHistoryScope.weekly,
    };
    if (expectedScope != scope) {
      throw const B04BriefingReadRepositoryError(
        'period_scope_mismatch',
        'A daily and weekly projection must use the matching engine period.',
      );
    }
    _validateWindow(
      scope: scope,
      startLocalDate: window.startLocalDate,
      endLocalDate: window.endLocalDate,
      timezoneId: window.timezoneId,
    );
  }

  int _compareItems(
    B04BriefingRecommendation left,
    B04BriefingRecommendation right,
  ) {
    final priority = left.priority.rank.compareTo(right.priority.rank);
    if (priority != 0) return priority;
    return left.id.compareTo(right.id);
  }

  B04RecommendationPolicyState? _historyPolicyState(
    Iterable<B04HistoricalRecommendation> rows,
  ) {
    if (rows.any((item) => item.policyVersion == kB04HoldPolicyVersion)) {
      return B04RecommendationPolicyState.hold;
    }
    if (rows.any((item) => item.policyVersion == kB04EnabledPolicyVersion)) {
      return B04RecommendationPolicyState.enabled;
    }
    return null;
  }

  B04RecommendationConsentState? _historyConsentState(
    Iterable<B04HistoricalRecommendation> rows,
  ) {
    final events =
        [
          for (final row in rows)
            for (final item in row.evidence)
              if (item.evidenceKind == 'consent') item,
        ]..sort((left, right) {
          final time = left.createdAtUtc.compareTo(right.createdAtUtc);
          return time == 0 ? left.id.compareTo(right.id) : time;
        });
    if (events.isEmpty) return null;
    return events.last.status == 'enable'
        ? B04RecommendationConsentState.enabled
        : B04RecommendationConsentState.disabled;
  }

  B04RecommendationEligibilityState? _historyEligibilityState(
    Iterable<B04HistoricalRecommendation> rows,
  ) {
    final events =
        [
          for (final row in rows)
            for (final item in row.evidence)
              if (item.evidenceKind == 'eligibility') item,
        ]..sort((left, right) {
          final time = left.createdAtUtc.compareTo(right.createdAtUtc);
          return time == 0 ? left.id.compareTo(right.id) : time;
        });
    if (events.isEmpty) return null;
    return switch (events.last.status) {
      'eligible' => B04RecommendationEligibilityState.eligible,
      'underage' => B04RecommendationEligibilityState.underage,
      'unknown_age' => B04RecommendationEligibilityState.unknownAge,
      'conflicting_age' => B04RecommendationEligibilityState.conflictingAge,
      'withheld_age' => B04RecommendationEligibilityState.withheldAge,
      'invalid_evidence' => B04RecommendationEligibilityState.invalidEvidence,
      'policy_unavailable' =>
        B04RecommendationEligibilityState.policyUnavailable,
      _ => B04RecommendationEligibilityState.missing,
    };
  }

  String _owner(String userId) {
    final owner = userId.trim();
    if (owner.isEmpty) {
      throw const B04BriefingReadRepositoryError(
        'missing_user_id',
        'A briefing requires a user ID.',
      );
    }
    return owner;
  }
}

/// Daily projection over one explicit local civil date.
class B04DailyBriefingReadRepository {
  final _B04BriefingReadProjection _projection;

  B04DailyBriefingReadRepository({
    required B04BriefingHistorySource history,
    B04RecommendationEngine engine = const B04RecommendationEngine(),
    LocalScheduleDateService? dates,
  }) : _projection = _B04BriefingReadProjection(
         history: history,
         engine: engine,
         dates: dates ?? LocalScheduleDateService(),
       );

  Future<B04DailyBriefingReadModel> read({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) => _projection.readHistory(
    scope: B04RecommendationHistoryScope.daily,
    userId: userId,
    startLocalDate: localDate,
    endLocalDate: localDate,
    timezoneId: timezoneId,
  );

  B04DailyBriefingReadModel evaluate({
    required B04RecommendationContext context,
    required Iterable<B04RecommendationCandidate> candidates,
    Iterable<B04HistoricalRecommendation> historyRows = const [],
  }) => _projection.evaluate(
    scope: B04RecommendationHistoryScope.daily,
    context: context,
    candidates: candidates,
    historyRows: historyRows,
  );

  B04DailyBriefingReadModel projectEvaluation({
    required B04RecommendationEvaluation evaluation,
    Iterable<B04HistoricalRecommendation> historyRows = const [],
  }) => _projection.projectEvaluation(
    scope: B04RecommendationHistoryScope.daily,
    evaluation: evaluation,
    historyRows: historyRows,
  );
}

/// Weekly projection over one caller-supplied seven-civil-day period. It does
/// not choose Monday/Sunday or a rolling seven-day window.
class B04WeeklyReviewReadRepository {
  final _B04BriefingReadProjection _projection;

  B04WeeklyReviewReadRepository({
    required B04BriefingHistorySource history,
    B04RecommendationEngine engine = const B04RecommendationEngine(),
    LocalScheduleDateService? dates,
  }) : _projection = _B04BriefingReadProjection(
         history: history,
         engine: engine,
         dates: dates ?? LocalScheduleDateService(),
       );

  Future<B04WeeklyReviewReadModel> read({
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) => _projection.readHistory(
    scope: B04RecommendationHistoryScope.weekly,
    userId: userId,
    startLocalDate: startLocalDate,
    endLocalDate: endLocalDate,
    timezoneId: timezoneId,
  );

  B04WeeklyReviewReadModel evaluate({
    required B04RecommendationContext context,
    required Iterable<B04RecommendationCandidate> candidates,
    Iterable<B04HistoricalRecommendation> historyRows = const [],
  }) => _projection.evaluate(
    scope: B04RecommendationHistoryScope.weekly,
    context: context,
    candidates: candidates,
    historyRows: historyRows,
  );

  B04WeeklyReviewReadModel projectEvaluation({
    required B04RecommendationEvaluation evaluation,
    Iterable<B04HistoricalRecommendation> historyRows = const [],
  }) => _projection.projectEvaluation(
    scope: B04RecommendationHistoryScope.weekly,
    evaluation: evaluation,
    historyRows: historyRows,
  );
}
