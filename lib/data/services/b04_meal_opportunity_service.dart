import '../../core/services/local_schedule_date_service.dart';
import '../models/b04_recommendation_context_models.dart';

/// Creates an opportunity only from an explicit caller selection.
///
/// This service deliberately has no repository, clock, location, calendar,
/// restaurant, history, or pantry input. Consequently it cannot infer a meal
/// window or N8 context from those sources.
class B04MealOpportunityService {
  final LocalScheduleDateService _dates;

  B04MealOpportunityService({LocalScheduleDateService? dates})
    : _dates = dates ?? LocalScheduleDateService();

  B04MealOpportunity create({
    required DateTime currentInstantUtc,
    required String timezoneId,
    required B04MealOpportunityKind? kind,
    required List<B04MealCandidate> candidates,
    String? explicitMealCategory,
  }) {
    if (!currentInstantUtc.isUtc) {
      throw ArgumentError.value(
        currentInstantUtc,
        'currentInstantUtc',
        'The caller must provide a UTC instant.',
      );
    }
    _dates.validateTimezone(timezoneId);
    final localDate = _dates.localDateFor(currentInstantUtc, timezoneId);
    final category = explicitMealCategory?.trim();
    if (category != null && category.isEmpty) {
      throw ArgumentError.value(
        explicitMealCategory,
        'explicitMealCategory',
        'An explicit meal category cannot be blank.',
      );
    }
    final selected = List<B04MealCandidate>.unmodifiable(candidates);
    final selectionIds = <String>{};
    for (final candidate in selected) {
      if (candidate.selectionId.trim().isEmpty ||
          candidate.subjectId.trim().isEmpty) {
        throw ArgumentError(
          'Explicit meal candidates require selection and subject identity.',
        );
      }
      if (!selectionIds.add(candidate.selectionId)) {
        throw ArgumentError(
          'Explicit meal candidate selection IDs must be unique.',
        );
      }
      if (candidate.evidence.isComplete &&
          (candidate.evidence.identityReference?.trim().isEmpty != false ||
              candidate.evidence.nutrientReference?.trim().isEmpty != false ||
              candidate.evidence.constraintReference?.trim().isEmpty !=
                  false)) {
        throw ArgumentError(
          'Complete meal candidates require B03 identity, nutrient, and constraint evidence.',
        );
      }
    }
    if (kind == null) {
      return B04MealOpportunity(
        status: B04MealOpportunityStatus.unavailable,
        kind: null,
        currentInstantUtc: currentInstantUtc,
        localDate: localDate,
        timezoneId: timezoneId,
        explicitMealCategory: category,
        candidates: selected,
        reasonCode: 'explicit_opportunity_required',
      );
    }
    if (selected.isEmpty) {
      return B04MealOpportunity(
        status: B04MealOpportunityStatus.noCandidate,
        kind: kind,
        currentInstantUtc: currentInstantUtc,
        localDate: localDate,
        timezoneId: timezoneId,
        explicitMealCategory: category,
        candidates: selected,
        reasonCode: 'no_explicit_candidate',
      );
    }
    if (selected.every(
      (candidate) =>
          candidate.evidence.state == B04MealCandidateEvidenceState.unavailable,
    )) {
      return B04MealOpportunity(
        status: B04MealOpportunityStatus.unavailable,
        kind: kind,
        currentInstantUtc: currentInstantUtc,
        localDate: localDate,
        timezoneId: timezoneId,
        explicitMealCategory: category,
        candidates: selected,
        reasonCode: 'candidate_evidence_unavailable',
      );
    }
    final hasPartial = selected.any(
      (candidate) => !candidate.evidence.isComplete,
    );
    return B04MealOpportunity(
      status: B04MealOpportunityStatus.available,
      kind: kind,
      currentInstantUtc: currentInstantUtc,
      localDate: localDate,
      timezoneId: timezoneId,
      explicitMealCategory: category,
      candidates: selected,
      reasonCode: hasPartial
          ? 'explicit_candidate_partial_evidence'
          : 'explicit_candidate_selected',
    );
  }
}
