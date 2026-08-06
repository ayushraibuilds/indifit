import '../../core/nutrients.dart';
import '../models/b04_nutrition_safety_models.dart';
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recommendation_models.dart';

/// Versioned, ephemeral read-model contracts for B04-12.
const String kB04RemainingTargetReadModelVersion = 'B04-12-REMAINING-TARGET-V1';
const String kB04CurrentFoodReadModelVersion = 'B04-12-CURRENT-FOOD-V1';

enum B04CurrentFoodGuidanceStatus { available, noCandidate, unavailable }

extension B04CurrentFoodGuidanceStatusId on B04CurrentFoodGuidanceStatus {
  String get stableId => name;
}

/// A numeric state that can be rendered without turning missing or estimated
/// evidence into an exact point.
enum B04CurrentFoodValueState { known, range, unknown, missing, invalid }

extension B04CurrentFoodValueStateId on B04CurrentFoodValueState {
  String get stableId => name;
}

enum B04CurrentFoodTargetFitState { fits, uncertain, exceeds, unavailable }

extension B04CurrentFoodTargetFitStateId on B04CurrentFoodTargetFitState {
  String get stableId => name;
}

/// A presentation-safe nutrient value. Numeric text is retained so the
/// current-food path does not create a new floating-point authority for B03
/// facts or the stored goal target.
class B04CurrentFoodNutrientValue {
  final String nutrientId;
  final NutrientUnit unit;
  final B04CurrentFoodValueState state;
  final String? point;
  final String? lower;
  final String? upper;
  final String sourceType;
  final String? sourceVersion;
  final List<String> sourceIds;
  final String? reasonCode;

  B04CurrentFoodNutrientValue({
    required String nutrientId,
    required this.unit,
    required this.state,
    this.point,
    this.lower,
    this.upper,
    required String sourceType,
    this.sourceVersion,
    Iterable<String> sourceIds = const [],
    String? reasonCode,
  }) : nutrientId = nutrientId.trim(),
       sourceType = sourceType.trim(),
       sourceIds = _sortedUnique(sourceIds),
       reasonCode = reasonCode?.trim() {
    if (this.nutrientId.isEmpty || this.sourceType.isEmpty) {
      throw ArgumentError(
        'Current-food nutrient values require nutrient and source identity.',
      );
    }
    if (this.sourceIds.isEmpty) {
      throw ArgumentError(
        'Current-food nutrient values require source evidence.',
      );
    }
    for (final value in [point, lower, upper]) {
      if (value != null && !_isDecimal(value)) {
        throw ArgumentError.value(
          value,
          'value',
          'must be finite decimal text',
        );
      }
    }
    if (state == B04CurrentFoodValueState.known && point == null) {
      throw ArgumentError('Known current-food values require a point.');
    }
    if (state == B04CurrentFoodValueState.range &&
        lower == null &&
        upper == null) {
      throw ArgumentError('Range current-food values require a bound.');
    }
  }

  bool get isKnown => state == B04CurrentFoodValueState.known;

  bool get isRange => state == B04CurrentFoodValueState.range;

  bool get hasNumericValue => point != null || lower != null || upper != null;

  double? get pointValue => point == null ? null : double.parse(point!);

  double? get lowerValue => lower == null ? null : double.parse(lower!);

  double? get upperValue => upper == null ? null : double.parse(upper!);

  Map<String, dynamic> toRedactedMap() => {
    'nutrient_id': nutrientId,
    'unit': unit.stableId,
    'state': state.stableId,
    if (point != null) 'point': point,
    if (lower != null) 'lower': lower,
    if (upper != null) 'upper': upper,
    'source_type': sourceType,
    if (sourceVersion != null) 'source_version': sourceVersion,
    'source_ids': sourceIds,
    if (reasonCode != null) 'reason_code': reasonCode,
  };
}

/// Remaining target evidence for one explicit local meal opportunity.
///
/// The goal version and B03 daily read model remain separate authorities. The
/// values are a derived read model and are never written back as a target.
class B04RemainingTargetReadModel {
  final String userId;
  final String localDate;
  final String timezoneId;
  final String? goalVersionId;
  final String? goalSource;
  final String? goalEffectiveFromLocalDate;
  final String readModelVersion;
  final List<B04CurrentFoodNutrientValue> targets;
  final List<String> consumedRecordIds;
  final List<String> consumedEstimateIds;
  final List<String> consumedIssueIds;
  final List<String> consumedFactVersions;
  final List<String> missingEvidence;

  B04RemainingTargetReadModel({
    required String userId,
    required String localDate,
    required String timezoneId,
    required this.goalVersionId,
    required this.goalSource,
    required this.goalEffectiveFromLocalDate,
    this.readModelVersion = kB04RemainingTargetReadModelVersion,
    required Iterable<B04CurrentFoodNutrientValue> targets,
    Iterable<String> consumedRecordIds = const [],
    Iterable<String> consumedEstimateIds = const [],
    Iterable<String> consumedIssueIds = const [],
    Iterable<String> consumedFactVersions = const [],
    Iterable<String> missingEvidence = const [],
  }) : userId = userId.trim(),
       localDate = localDate.trim(),
       timezoneId = timezoneId.trim(),
       targets = List.unmodifiable(targets),
       consumedRecordIds = _sortedUnique(consumedRecordIds),
       consumedEstimateIds = _sortedUnique(consumedEstimateIds),
       consumedIssueIds = _sortedUnique(consumedIssueIds),
       consumedFactVersions = _sortedUnique(consumedFactVersions),
       missingEvidence = _sortedUnique(missingEvidence) {
    if (this.userId.isEmpty ||
        this.localDate.isEmpty ||
        this.timezoneId.isEmpty) {
      throw ArgumentError(
        'Remaining targets require user, local date, and timezone.',
      );
    }
    if (this.targets.map((item) => item.nutrientId).toSet().length !=
        this.targets.length) {
      throw ArgumentError('Remaining target nutrients must be unique.');
    }
  }

  B04CurrentFoodNutrientValue? forNutrient(String nutrientId) {
    for (final target in targets) {
      if (target.nutrientId == nutrientId) return target;
    }
    return null;
  }

  B04CurrentFoodNutrientValue? get energy => forNutrient('energy');

  bool get hasUnknownValues => targets.any(
    (value) =>
        value.state == B04CurrentFoodValueState.unknown ||
        value.state == B04CurrentFoodValueState.missing ||
        value.state == B04CurrentFoodValueState.invalid,
  );

  Map<String, dynamic> toRedactedMap() => {
    'local_date': localDate,
    'timezone_id': timezoneId,
    if (goalVersionId != null) 'goal_version_id': goalVersionId,
    if (goalSource != null) 'goal_source': goalSource,
    if (goalEffectiveFromLocalDate != null)
      'goal_effective_from_local_date': goalEffectiveFromLocalDate,
    'read_model_version': readModelVersion,
    'targets': targets.map((item) => item.toRedactedMap()).toList(),
    'consumed_record_ids': consumedRecordIds,
    'consumed_estimate_ids': consumedEstimateIds,
    'consumed_issue_ids': consumedIssueIds,
    'consumed_fact_versions': consumedFactVersions,
    'missing_evidence': missingEvidence,
  };
}

/// B03-derived facts and safety evaluation attached to one explicitly
/// selected local candidate. The current-food service never looks up a
/// candidate by name and never replaces these facts with catalogue values.
class B04CurrentFoodCandidateInput {
  final B04MealCandidate selection;
  final String displayLabel;
  final NutrientAggregationResult? nutrientEvidence;
  final B04NutritionSafetyResult? safety;
  final List<String> evidenceIds;

  B04CurrentFoodCandidateInput({
    required this.selection,
    required String displayLabel,
    required this.nutrientEvidence,
    required this.safety,
    Iterable<String> evidenceIds = const [],
  }) : displayLabel = displayLabel.trim(),
       evidenceIds = _sortedUnique(evidenceIds) {
    if (this.displayLabel.isEmpty) {
      throw ArgumentError('Current-food candidates require a display label.');
    }
    if (safety != null &&
        (safety!.userId.trim().isEmpty ||
            safety!.subjectId != selection.subjectId)) {
      throw ArgumentError(
        'Candidate safety identity must match the selected subject.',
      );
    }
  }
}

class B04CurrentFoodTargetFit {
  final B04CurrentFoodTargetFitState state;
  final int rank;
  final String reasonCode;
  final String? nutrientId;
  final List<String> evidenceIds;

  B04CurrentFoodTargetFit({
    required this.state,
    required this.rank,
    required String reasonCode,
    this.nutrientId,
    Iterable<String> evidenceIds = const [],
  }) : reasonCode = reasonCode.trim(),
       evidenceIds = _sortedUnique(evidenceIds) {
    if (rank < 0 || this.reasonCode.isEmpty) {
      throw ArgumentError('Current-food target fit requires a valid reason.');
    }
  }

  Map<String, dynamic> toRedactedMap() => {
    'state': state.stableId,
    'rank': rank,
    'reason_code': reasonCode,
    if (nutrientId != null) 'nutrient_id': nutrientId,
    'evidence_ids': evidenceIds,
  };
}

class B04CurrentFoodCandidateCard {
  final String selectionId;
  final String subjectId;
  final B04MealCandidateSource source;
  final String displayLabel;
  final B04Recommendation recommendation;
  final B04CurrentFoodTargetFit targetFit;
  final List<B04CurrentFoodNutrientValue> nutrientFacts;

  B04CurrentFoodCandidateCard({
    required String selectionId,
    required String subjectId,
    required this.source,
    required String displayLabel,
    required this.recommendation,
    required this.targetFit,
    Iterable<B04CurrentFoodNutrientValue> nutrientFacts = const [],
  }) : selectionId = selectionId.trim(),
       subjectId = subjectId.trim(),
       displayLabel = displayLabel.trim(),
       nutrientFacts = List.unmodifiable(nutrientFacts) {
    if (this.selectionId.isEmpty ||
        this.subjectId.isEmpty ||
        this.displayLabel.isEmpty) {
      throw ArgumentError('Current-food cards require candidate identity.');
    }
  }

  Map<String, dynamic> toRedactedMap() => {
    'selection_id': selectionId,
    'subject_id': subjectId,
    'source': source.stableId,
    'display_label': displayLabel,
    'recommendation': recommendation.toRedactedMap(),
    'target_fit': targetFit.toRedactedMap(),
    'nutrient_facts': nutrientFacts
        .map((item) => item.toRedactedMap())
        .toList(),
  };
}

class B04CurrentFoodExcludedCandidate {
  final String selectionId;
  final String displayLabel;
  final B04MealCandidateSource source;
  final List<String> reasonCodes;
  final B04NutritionSafetyDisposition? safetyDisposition;

  B04CurrentFoodExcludedCandidate({
    required String selectionId,
    required String displayLabel,
    required this.source,
    required Iterable<String> reasonCodes,
    this.safetyDisposition,
  }) : selectionId = selectionId.trim(),
       displayLabel = displayLabel.trim(),
       reasonCodes = _sortedUnique(reasonCodes) {
    if (this.selectionId.isEmpty ||
        this.displayLabel.isEmpty ||
        this.reasonCodes.isEmpty) {
      throw ArgumentError(
        'Excluded current-food candidates require identity and a reason.',
      );
    }
  }

  Map<String, dynamic> toRedactedMap() => {
    'selection_id': selectionId,
    'display_label': displayLabel,
    'source': source.stableId,
    'reason_codes': reasonCodes,
    if (safetyDisposition != null)
      'safety_disposition': safetyDisposition!.stableId,
  };
}

class B04CurrentFoodGuidance {
  final B04CurrentFoodGuidanceStatus status;
  final String userId;
  final String localDate;
  final String timezoneId;
  final DateTime evaluatedAtUtc;
  final B04RemainingTargetReadModel remainingTargets;
  final List<B04CurrentFoodCandidateCard> cards;
  final List<B04CurrentFoodExcludedCandidate> excludedCandidates;
  final List<B04RecommendationWarning> lowRiskWarnings;
  final B04RecommendationEvaluation? recommendationEvaluation;
  final List<String> reasonCodes;
  final String readModelVersion;

  B04CurrentFoodGuidance({
    required this.status,
    required String userId,
    required String localDate,
    required String timezoneId,
    required this.evaluatedAtUtc,
    required this.remainingTargets,
    Iterable<B04CurrentFoodCandidateCard> cards = const [],
    Iterable<B04CurrentFoodExcludedCandidate> excludedCandidates = const [],
    Iterable<B04RecommendationWarning> lowRiskWarnings = const [],
    required this.recommendationEvaluation,
    required Iterable<String> reasonCodes,
    this.readModelVersion = kB04CurrentFoodReadModelVersion,
  }) : userId = userId.trim(),
       localDate = localDate.trim(),
       timezoneId = timezoneId.trim(),
       cards = List.unmodifiable(cards),
       excludedCandidates = List.unmodifiable(excludedCandidates),
       lowRiskWarnings = List.unmodifiable(lowRiskWarnings),
       reasonCodes = _sortedUnique(reasonCodes) {
    if (this.userId.isEmpty ||
        this.localDate.isEmpty ||
        this.timezoneId.isEmpty ||
        !evaluatedAtUtc.isUtc) {
      throw ArgumentError(
        'Current-food guidance requires UTC evaluation and period identity.',
      );
    }
    if (this.reasonCodes.isEmpty) {
      throw ArgumentError('Current-food guidance requires a result reason.');
    }
  }

  bool get isAvailable => status == B04CurrentFoodGuidanceStatus.available;

  bool get isOfflineCapable => true;

  Map<String, dynamic> toRedactedMap() => {
    'status': status.stableId,
    'local_date': localDate,
    'timezone_id': timezoneId,
    'evaluated_at_utc': evaluatedAtUtc.toIso8601String(),
    'remaining_targets': remainingTargets.toRedactedMap(),
    'cards': cards.map((item) => item.toRedactedMap()).toList(),
    'excluded_candidates': excludedCandidates
        .map((item) => item.toRedactedMap())
        .toList(),
    'low_risk_warnings': lowRiskWarnings
        .map((item) => item.toRedactedMap())
        .toList(),
    if (recommendationEvaluation != null)
      'recommendation_evaluation': recommendationEvaluation!.toRedactedMap(),
    'reason_codes': reasonCodes,
    'read_model_version': readModelVersion,
    'n8': 'absent',
    'offline_capable': isOfflineCapable,
  };
}

class B04CurrentFoodError implements Exception {
  final String code;
  final String message;

  const B04CurrentFoodError(this.code, this.message);

  @override
  String toString() => 'B04CurrentFoodError($code): $message';
}

List<String> _sortedUnique(Iterable<String> values) {
  final result =
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return List.unmodifiable(result);
}

bool _isDecimal(String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(trimmed)) return false;
  return double.tryParse(trimmed)?.isFinite == true;
}
