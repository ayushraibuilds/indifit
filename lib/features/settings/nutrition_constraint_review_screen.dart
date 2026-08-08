import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/presentation/consumer_copy.dart';
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
      appBar: AppBar(title: const Text('Dietary check')),
      body: switch (state.status) {
        NutritionConstraintEvaluationReviewStatus.idle => const Center(
          child: Text('Choose a food or recipe to review.'),
        ),
        NutritionConstraintEvaluationReviewStatus.loading => Center(
          child: Semantics(
            label: 'Loading dietary check',
            child: const CircularProgressIndicator(),
          ),
        ),
        NutritionConstraintEvaluationReviewStatus.failure => _ReviewFailure(
          message: state.message ?? 'Could not complete the dietary check.',
          onRetry: controller.retry,
        ),
        NutritionConstraintEvaluationReviewStatus.success =>
          state.evaluation == null
              ? const Center(child: Text('The dietary check is unavailable.'))
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
                    'This check uses the information available for this item. No known conflict is not a safety guarantee.',
                  ),
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
          Text('Item: ${_targetLabel(evaluation.targetKey)}'),
          Text('Result: ${_outcomeLabel(evaluation.outcome)}'),
          if (evaluation.acknowledged)
            const Text('Your acknowledgement does not change the check.'),
          const SizedBox(height: 8),
          if (evaluation.evidence.isEmpty)
            const Text('More information is needed to complete this check.')
          else ...[
            Text(
              '${evaluation.evidence.length} ${evaluation.evidence.length == 1 ? 'check' : 'checks'} completed.',
            ),
          ],
          if (evaluation.affectedComponentIds.isNotEmpty)
            const Text(
              'This check covers more than one ingredient or component.',
            ),
          if (evaluation.missingEvidence.isNotEmpty ||
              evaluation.reasonCodes.isNotEmpty)
            const Text(
              'Why? I need a little more information before I can show this safely.',
            ),
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
          const Text('The dietary check is unavailable.'),
          const SizedBox(height: 8),
          const Text(
            'We couldn’t complete this check right now. Try again.',
            textAlign: TextAlign.center,
          ),
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
    'More information needed',
};

String _targetLabel(String key) {
  try {
    final target = NutritionConstraintTarget.fromStableKey(key);
    return '${ConsumerCopy.targetType(target.type.stableId)}: ${ConsumerCopy.target(target.id)}';
  } on Object {
    return 'Selected item';
  }
}
