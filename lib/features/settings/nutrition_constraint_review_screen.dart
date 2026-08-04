import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_constraints.dart';
import 'nutrition_constraint_review_controller.dart';

class NutritionConstraintEvaluationReviewScreen extends ConsumerStatefulWidget {
  final String? foodId;
  final String? recipeVersionId;

  const NutritionConstraintEvaluationReviewScreen({
    super.key,
    this.foodId,
    this.recipeVersionId,
  });

  @override
  ConsumerState<NutritionConstraintEvaluationReviewScreen> createState() =>
      _NutritionConstraintEvaluationReviewScreenState();
}

class _NutritionConstraintEvaluationReviewScreenState
    extends ConsumerState<NutritionConstraintEvaluationReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(
        nutritionConstraintEvaluationReviewControllerProvider.notifier,
      );
      if (widget.foodId != null && widget.recipeVersionId == null) {
        controller.reviewFood(widget.foodId!);
      } else if (widget.recipeVersionId != null && widget.foodId == null) {
        controller.reviewRecipeVersion(widget.recipeVersionId!);
      } else {
        controller.retry();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      nutritionConstraintEvaluationReviewControllerProvider,
    );
    final controller = ref.read(
      nutritionConstraintEvaluationReviewControllerProvider.notifier,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Dietary evidence review')),
      body: switch (state.status) {
        NutritionConstraintEvaluationReviewStatus.idle => const Center(
          child: Text('Choose a resolved food or recipe version to review.'),
        ),
        NutritionConstraintEvaluationReviewStatus.loading => Center(
          child: Semantics(
            label: 'Loading dietary evidence',
            child: const CircularProgressIndicator(),
          ),
        ),
        NutritionConstraintEvaluationReviewStatus.failure => _ReviewFailure(
          message: state.message ?? 'Could not review dietary evidence.',
          onRetry: controller.retry,
        ),
        NutritionConstraintEvaluationReviewStatus.success =>
          state.evaluation == null
              ? const Center(child: Text('Dietary evidence is unavailable.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: NutritionConstraintEvaluationReviewCard(
                    evaluation: state.evaluation!,
                  ),
                ),
      },
    );
  }
}

class NutritionConstraintEvaluationReviewCard extends StatelessWidget {
  final NutritionConstraintEvaluationResult evaluation;

  const NutritionConstraintEvaluationReviewCard({
    super.key,
    required this.evaluation,
  });

  @override
  Widget build(BuildContext context) {
    final outcomeLabel = _outcomeLabel(evaluation.outcome);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              container: true,
              label:
                  'Overall dietary evaluation: $outcomeLabel. No known conflict is not guaranteed safety.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall result',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(outcomeLabel),
                  const SizedBox(height: 6),
                  const Text(
                    'This is an evidence-based check. No known conflict does not mean guaranteed safety.',
                  ),
                  const SizedBox(height: 6),
                  Text('Rule version: ${evaluation.ruleVersion}'),
                ],
              ),
            ),
          ),
        ),
        for (final item in evaluation.evaluations)
          _EvaluationDetail(evaluation: item),
        if (evaluation.evaluations.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No active dietary constraints were evaluated.'),
            ),
          ),
      ],
    );
  }
}

class _EvaluationDetail extends StatelessWidget {
  final NutritionConstraintEvaluation evaluation;

  const _EvaluationDetail({required this.evaluation});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evaluation.type.displayLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('Target: ${evaluation.targetKey}'),
          Text('Result: ${_outcomeLabel(evaluation.outcome)}'),
          if (evaluation.acknowledged)
            const Text('Acknowledged by the user; evidence is unchanged.'),
          const SizedBox(height: 8),
          if (evaluation.evidence.isEmpty)
            const Text('Evidence: none recorded; absence is not assumed.')
          else ...[
            const Text('Evidence:'),
            for (final evidence in evaluation.evidence)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${evidence.status.stableId} · ${evidence.source.stableId} · ${evidence.evidenceId}'
                  '${evidence.ingredientLineage == null ? '' : ' · line ${evidence.ingredientLineage}'}',
                ),
              ),
          ],
          if (evaluation.affectedComponentIds.isNotEmpty)
            Text(
              'Affected components: ${evaluation.affectedComponentIds.join(', ')}',
            ),
          if (evaluation.missingEvidence.isNotEmpty)
            Text('Missing evidence: ${evaluation.missingEvidence.join(', ')}'),
          if (evaluation.reasonCodes.isNotEmpty)
            Text('Reason: ${evaluation.reasonCodes.join(', ')}'),
        ],
      ),
    ),
  );
}

class _ReviewFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReviewFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Dietary evidence is unavailable.'),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _outcomeLabel(NutritionConstraintOutcome outcome) => switch (outcome) {
  NutritionConstraintOutcome.confirmedConflict => 'Confirmed conflict',
  NutritionConstraintOutcome.possibleConflict => 'Possible conflict',
  NutritionConstraintOutcome.noKnownConflict => 'No detected conflict',
  NutritionConstraintOutcome.insufficientInformation =>
    'Unknown or insufficient evidence',
};
