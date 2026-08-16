import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_protein_distribution.dart';
import 'protein_distribution_controller.dart';

class ProteinDistributionScreen extends ConsumerWidget {
  final String localDate;

  const ProteinDistributionScreen({super.key, required this.localDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      nutritionProteinDistributionControllerProvider(localDate),
    );
    final controller = ref.read(
      nutritionProteinDistributionControllerProvider(localDate).notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Protein logged by meal')),
      body: SafeArea(
        child: switch (state.status) {
          NutritionProteinDistributionStatus.idle ||
          NutritionProteinDistributionStatus.loading => Center(
            child: Semantics(
              label: 'Loading protein distribution',
              child: CircularProgressIndicator(),
            ),
          ),
          NutritionProteinDistributionStatus.empty => _EmptyState(
            localDate: localDate,
          ),
          NutritionProteinDistributionStatus.failure => _FailureState(
            message:
                state.errorMessage ?? 'Protein distribution is unavailable.',
            onRetry: state.retryable ? controller.retry : null,
          ),
          NutritionProteinDistributionStatus.ready => _DistributionView(
            distribution: state.distribution!,
          ),
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String localDate;

  const _EmptyState({required this.localDate});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'No protein logged for $localDate.',
        textAlign: TextAlign.center,
        semanticsLabel: 'No protein logged for $localDate',
      ),
    ),
  );
}

class _FailureState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _FailureState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Protein distribution could not be loaded.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DistributionView extends StatelessWidget {
  final NutritionProteinDistribution distribution;

  const _DistributionView({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total = distribution.totalProtein;
    final known = distribution.knownProtein;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Based on logged meals for ${distribution.localDate}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Protein logged',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NutrientValue(
                summary: total,
                label: 'Protein total',
                semanticPrefix: 'Protein total',
              ),
              const SizedBox(height: 8),
              _NutrientValue(
                summary: known,
                label: 'Known protein',
                semanticPrefix: 'Known protein',
              ),
              if (distribution.hasUnknownProtein) ...[
                const SizedBox(height: 8),
                Text(
                  'Some entries have unknown protein '
                  '(${distribution.unknownProteinItemCount} item${distribution.unknownProteinItemCount == 1 ? '' : 's'}).',
                  semanticsLabel:
                      'Some entries have unknown protein. '
                      '${distribution.unknownProteinItemCount} items have unknown protein.',
                ),
              ],
              if (distribution.hasEstimatedProtein) ...[
                const SizedBox(height: 8),
                const Text('Estimated protein remains labelled as estimated.'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Distribution across meals',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (distribution.percentagesAvailable)
                for (final meal in distribution.meals)
                  _MealDistributionRow(meal: meal)
              else
                Text(
                  distribution.percentageUnavailableReason == 'zero_known_total'
                      ? 'Percentages are unavailable because the known protein total is zero.'
                      : 'Percentages use known point values only and are unavailable while coverage is incomplete.',
                  semanticsLabel:
                      distribution.percentageUnavailableReason ==
                          'zero_known_total'
                      ? 'Percentages are unavailable because the known protein total is zero.'
                      : 'Percentages use known point values only and are unavailable while coverage is incomplete.',
                ),
              const SizedBox(height: 8),
              const Text(
                'Percentages describe known protein only; they do not include unknown entries.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Leucine data',
          child: _LeucineSummary(distribution: distribution),
        ),
        const SizedBox(height: 12),
        for (final meal in distribution.meals) ...[
          _MealCard(meal: meal),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SummaryCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _NutrientValue extends StatelessWidget {
  final NutritionDistributionNutrientSummary summary;
  final String label;
  final String semanticPrefix;

  const _NutrientValue({
    required this.summary,
    required this.label,
    required this.semanticPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final value = _valueText(summary);
    final status = summary.isEstimated
        ? 'Estimated'
        : summary.isKnownPoint
        ? 'Known'
        : summary.completeness.state == NutrientCompletenessState.partial
        ? 'Partial'
        : 'Unknown';
    return Text(
      '$label: $value · $status',
      semanticsLabel: '$semanticPrefix: $value. Status: $status.',
    );
  }
}

class _MealDistributionRow extends StatelessWidget {
  final NutritionProteinMealSummary meal;

  const _MealDistributionRow({required this.meal});

  @override
  Widget build(BuildContext context) {
    final percentage = meal.distributionPercentageText ?? 'unknown';
    final known = meal.knownProtein.pointText == null
        ? 'unknown'
        : '${meal.knownProtein.pointText} ${meal.knownProtein.unitSymbol ?? 'g'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${_mealLabel(meal)}: $known known protein · $percentage%',
        semanticsLabel:
            '${_mealLabel(meal)}: $known known protein; $percentage percent of known daily protein.',
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final NutritionProteinMealSummary meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _mealLabel(meal),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _NutrientValue(
            summary: meal.protein,
            label: 'Protein',
            semanticPrefix: '${_mealLabel(meal)} protein',
          ),
          if (meal.hasUnknownProtein)
            Text(
              '${meal.unknownProteinItemCount} item${meal.unknownProteinItemCount == 1 ? '' : 's'} have unknown protein.',
              semanticsLabel:
                  '${_mealLabel(meal)} has ${meal.unknownProteinItemCount} items with unknown protein.',
            ),
          const SizedBox(height: 8),
          _LeucineLine(meal: meal),
          if (meal.protein.sources.isNotEmpty)
            Text('Protein source: ${_sourcesLabel(meal.protein.sources)}'),
        ],
      ),
    ),
  );
}

class _LeucineSummary extends StatelessWidget {
  final NutritionProteinDistribution distribution;

  const _LeucineSummary({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final summary = distribution.totalLeucine;
    final text = switch (distribution.leucineAvailability) {
      NutritionLeucineAvailability.unavailable =>
        'Leucine data unavailable in the nutrient registry.',
      NutritionLeucineAvailability.unknown =>
        'Leucine data unavailable for these logged meals.',
      NutritionLeucineAvailability.measuredOrReviewed =>
        'Measured/reviewed leucine: ${_valueText(summary)}',
      NutritionLeucineAvailability.estimated =>
        'Estimated leucine: ${_valueText(summary)}',
      NutritionLeucineAvailability.mixed =>
        'Leucine includes measured/reviewed and estimated values: ${_valueText(summary)}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, semanticsLabel: text),
        if (summary.sources.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Source: ${_sourcesLabel(summary.sources)}'),
        ],
        if (summary.completeness.state != NutrientCompletenessState.complete)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Leucine coverage is partial or unknown.'),
          ),
      ],
    );
  }
}

class _LeucineLine extends StatelessWidget {
  final NutritionProteinMealSummary meal;

  const _LeucineLine({required this.meal});

  @override
  Widget build(BuildContext context) {
    final summary = meal.leucine;
    final text = switch (meal.leucineAvailability) {
      NutritionLeucineAvailability.unavailable => 'Leucine unavailable',
      NutritionLeucineAvailability.unknown => 'Leucine unknown',
      NutritionLeucineAvailability.measuredOrReviewed =>
        'Measured/reviewed leucine: ${_valueText(summary)}',
      NutritionLeucineAvailability.estimated =>
        'Estimated leucine: ${_valueText(summary)}',
      NutritionLeucineAvailability.mixed =>
        'Mixed leucine data: ${_valueText(summary)}',
    };
    return Text(text, semanticsLabel: '${_mealLabel(meal)} $text');
  }
}

String _valueText(NutritionDistributionNutrientSummary summary) {
  final unit = summary.unitSymbol == null ? '' : ' ${summary.unitSymbol}';
  if (summary.pointText == null &&
      summary.lowerText == null &&
      summary.upperText == null) {
    return 'unknown';
  }
  if (summary.lowerText != null || summary.upperText != null) {
    final lower = summary.lowerText ?? '?';
    final upper = summary.upperText ?? '?';
    final point = summary.pointText == null
        ? ''
        : ' (point ${summary.pointText})';
    return '$lower–$upper$unit$point';
  }
  return '${summary.pointText}$unit';
}

String _mealLabel(NutritionProteinMealSummary meal) {
  final category = meal.mealCategory.trim();
  if (category.isEmpty) return 'Logged meal';
  return category[0].toUpperCase() + category.substring(1);
}

String _sourcesLabel(List<NutrientSourceType> sources) =>
    sources.map(_sourceLabel).join(', ');

String _sourceLabel(NutrientSourceType source) => switch (source) {
  NutrientSourceType.bundledCatalogue => 'bundled catalogue',
  NutrientSourceType.regionalCatalogue => 'regional catalogue',
  NutrientSourceType.reviewedCatalogue => 'reviewed catalogue',
  NutrientSourceType.manufacturerLabel => 'manufacturer label',
  NutrientSourceType.userEntered => 'you entered',
  NutrientSourceType.importedProvider => 'imported',
  NutrientSourceType.recipeCalculation => 'recipe calculation',
  NutrientSourceType.aiEstimate => 'AI estimate',
  NutrientSourceType.heuristic => 'heuristic estimate',
  NutrientSourceType.legacy => 'earlier entry',
  NutrientSourceType.unknown => 'source unavailable',
};
