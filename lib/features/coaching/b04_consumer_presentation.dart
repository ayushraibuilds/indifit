import '../../core/nutrients.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../data/models/b04_briefing_read_models.dart';
import '../../data/models/b04_current_food_models.dart';
import '../../data/models/b04_recommendation_history_models.dart';
import '../../data/models/b04_recommendation_models.dart';

/// Display-ready B04 recommendation text. It deliberately omits identifiers,
/// evidence rows, policy versions and other engine metadata.
class B04RecommendationPresentation {
  final String title;
  final String status;
  final String explanation;
  final String? result;
  final String? why;
  final bool showWhy;

  const B04RecommendationPresentation({
    required this.title,
    required this.status,
    required this.explanation,
    this.result,
    this.why,
    this.showWhy = false,
  });

  factory B04RecommendationPresentation.from(
    B04BriefingRecommendation recommendation,
  ) {
    final hasLimits =
        recommendation.missingEvidence.isNotEmpty ||
        recommendation.uncertainty.isNotEmpty ||
        recommendation.state == B04RecommendationState.unavailable;
    return B04RecommendationPresentation(
      title: ConsumerCopy.action(recommendation.action),
      status: ConsumerCopy.state(recommendation.state.stableId),
      explanation: ConsumerCopy.explanation(recommendation.explanation),
      result: _result(recommendation.canonicalResult),
      why: hasLimits
          ? 'I don’t have enough nutrition information to make this suggestion yet.'
          : null,
      showWhy: hasLimits,
    );
  }

  static String? _result(B04BriefingNumericalResult? result) {
    if (result == null || !result.hasCanonicalResult) return null;
    final values = <String>[];
    if (result.proposedDeltaKcal != null) {
      final delta = result.proposedDeltaKcal!;
      values.add(
        delta == 0
            ? 'Suggested change: no change'
            : 'Suggested change: ${delta > 0 ? '+' : ''}$delta kcal/day',
      );
    }
    if (result.normalizedMaintenanceKcal != null) {
      values.add('Daily estimate: ${result.normalizedMaintenanceKcal} kcal');
    }
    // The exact fraction is useful only to the domain audit trail. Showing it
    // here adds no consumer value and can expose implementation vocabulary.
    return values.isEmpty ? null : values.join(' · ');
  }
}

class B04CurrentFoodPresentation {
  final String periodLabel;
  final String status;
  final String explanation;
  final String? why;
  final List<String> targetValues;
  final String? suggestion;
  final String? fit;

  const B04CurrentFoodPresentation({
    required this.periodLabel,
    required this.status,
    required this.explanation,
    required this.targetValues,
    this.why,
    this.suggestion,
    this.fit,
  });

  factory B04CurrentFoodPresentation.from(B04CurrentFoodGuidance guidance) {
    final unavailable = !guidance.isAvailable || guidance.cards.isEmpty;
    final suggestion = guidance.cards.isEmpty ? null : guidance.cards.first;
    return B04CurrentFoodPresentation(
      periodLabel: ConsumerDateLabel.day(guidance.localDate),
      status: guidance.isAvailable && guidance.cards.isNotEmpty
          ? 'Suggestions for you'
          : 'Nothing to recommend yet',
      explanation: guidance.isAvailable && guidance.cards.isNotEmpty
          ? 'These ideas fit the information you have logged today.'
          : 'Log a meal and I’ll suggest something that fits your day.',
      why: unavailable
          ? 'I don’t have enough nutrition information for today yet.'
          : null,
      targetValues: [
        for (final value in guidance.remainingTargets.targets)
          B03NutritionPresentation.value(value),
      ],
      suggestion: suggestion == null
          ? null
          : ConsumerCopy.label(
              suggestion.displayLabel,
              fallback: 'A meal idea',
            ),
      fit: suggestion == null
          ? null
          : B03NutritionPresentation.fit(suggestion.targetFit.state),
    );
  }
}

/// B03 facts are formatted here so B04 widgets do not stringify nutrient
/// models or expose source IDs/reason codes.
abstract final class B03NutritionPresentation {
  static String value(B04CurrentFoodNutrientValue value) {
    final amount = switch (value.state) {
      B04CurrentFoodValueState.known => value.point ?? 'Not available',
      B04CurrentFoodValueState.range =>
        '${value.lower ?? 'At least'}–${value.upper ?? 'At most'}',
      B04CurrentFoodValueState.unknown ||
      B04CurrentFoodValueState.missing ||
      B04CurrentFoodValueState.invalid => 'Not available',
    };
    return '${ConsumerCopy.nutrient(value.nutrientId)}: $amount ${value.unit.symbol}';
  }

  static String fit(B04CurrentFoodTargetFitState state) => switch (state) {
    B04CurrentFoodTargetFitState.fits => 'Fits today’s target',
    B04CurrentFoodTargetFitState.uncertain => 'Needs more information',
    B04CurrentFoodTargetFitState.exceeds => 'Above today’s target',
    B04CurrentFoodTargetFitState.unavailable => 'Can’t assess yet',
  };
}

abstract final class B04DatePresentation {
  static String period(B04BriefingReadModel read) =>
      read.scope == B04RecommendationHistoryScope.daily
      ? ConsumerDateLabel.day(read.startLocalDate)
      : ConsumerDateLabel.range(read.startLocalDate, read.endLocalDate);
}
