import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_estimates.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/typed_quantities.dart';
import 'nutrition_estimate_review_controller.dart';

/// Small provider-neutral review surface for an estimate already created by
/// the estimate boundary. It displays stored facts and delegates every
/// mutation to the controller/repository.
class NutritionEstimateReviewScreen extends ConsumerStatefulWidget {
  final String estimateId;

  const NutritionEstimateReviewScreen({super.key, required this.estimateId});

  @override
  ConsumerState<NutritionEstimateReviewScreen> createState() =>
      _NutritionEstimateReviewScreenState();
}

class _NutritionEstimateReviewScreenState
    extends ConsumerState<NutritionEstimateReviewScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _quantityController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(nutritionEstimateRepositoryProvider);
    return repository.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Review estimate')),
        body: _ErrorBody(
          message: 'Nutrition estimates aren’t ready right now. Try again.',
          onRetry: () => ref.invalidate(nutritionEstimateRepositoryProvider),
        ),
      ),
      data: (_) => _buildReview(context),
    );
  }

  Widget _buildReview(BuildContext context) {
    final state = ref.watch(
      nutritionEstimateReviewControllerProvider(widget.estimateId),
    );
    final controller = ref.read(
      nutritionEstimateReviewControllerProvider(widget.estimateId).notifier,
    );
    final estimate = state.estimate;
    if (estimate != null && _labelController.text.isEmpty) {
      _labelController.text = estimate.displayLabel;
    }
    if (estimate != null &&
        _quantityController.text.isEmpty &&
        estimate.quantity?.unit == QuantityUnit.serving) {
      _quantityController.text = estimate.quantity!.amount.toString();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review nutrition estimate')),
      body: switch (state.status) {
        NutritionEstimateReviewControllerStatus.idle ||
        NutritionEstimateReviewControllerStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        NutritionEstimateReviewControllerStatus.failure when estimate == null =>
          _ErrorBody(
            message: state.errorMessage ?? 'The estimate could not be loaded.',
            onRetry: state.retryable ? controller.retry : null,
          ),
        _ => _ReviewBody(
          state: state,
          labelController: _labelController,
          quantityController: _quantityController,
          onAccept: state.isBusy ? null : () => controller.accept(),
          onReject: state.isBusy ? null : () => controller.reject(),
          onCorrect: state.isBusy || estimate == null
              ? null
              : () => _correct(context, controller, estimate),
          onRetry: state.retryable ? controller.retry : null,
        ),
      },
    );
  }

  Future<void> _correct(
    BuildContext context,
    NutritionEstimateReviewController controller,
    NutritionEstimate estimate,
  ) async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    final rawQuantity = _quantityController.text.trim();
    Quantity? quantity;
    var replaceQuantity = false;
    if (rawQuantity.isNotEmpty) {
      try {
        quantity = Quantity.serving(
          amount: rawQuantity,
          definition:
              estimate.quantity?.context.servingDefinition ??
              const ServingDefinitionReference(
                id: 'user-review-serving-v1',
                revision: '1',
              ),
          source: 'user-review-v1',
        );
        NutritionQuantityService.validatePositiveUserEnteredPortion(quantity);
        replaceQuantity =
            estimate.quantity == null ||
            estimate.quantity!.unit != QuantityUnit.serving ||
            estimate.quantity!.amount.toString() != rawQuantity;
      } on QuantityError {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ProductFailurePresentation.fromCode('invalid_amount').message,
            ),
          ),
        );
        return;
      }
    }
    final replaceLabel = label != estimate.displayLabel;
    if (!replaceLabel && !replaceQuantity) return;
    await controller.correct(
      correction: NutritionEstimateCorrection(
        commandId: 'estimate-correction::${estimate.id}',
        reason: 'User corrected estimate details.',
        displayLabel: replaceLabel ? label : null,
        replaceQuantity: replaceQuantity,
        quantity: replaceQuantity ? quantity : null,
        fieldUpdates: replaceLabel
            ? const {'food_identity': 'user_corrected'}
            : const {},
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  final NutritionEstimateReviewControllerState state;
  final TextEditingController labelController;
  final TextEditingController quantityController;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCorrect;
  final VoidCallback? onRetry;

  const _ReviewBody({
    required this.state,
    required this.labelController,
    required this.quantityController,
    required this.onAccept,
    required this.onReject,
    required this.onCorrect,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final estimate = state.estimate;
    if (estimate == null) {
      return _ErrorBody(
        message: state.errorMessage ?? 'No estimate selected.',
        onRetry: onRetry,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Semantics(
          header: true,
          child: Text(
            estimate.displayLabel,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This is an estimate, not a verified food identity or medical measurement.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _MetadataCard(estimate: estimate),
        const SizedBox(height: 12),
        if (estimate.completeness.state == NutrientCompletenessState.partial ||
            estimate.completeness.state == NutrientCompletenessState.unknown)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                estimate.completeness.missingNutrientIds.isEmpty
                    ? 'Nutrition details are not available yet.'
                    : 'Some nutrition details are not available yet.',
              ),
            ),
          ),
        const SizedBox(height: 12),
        ...estimate.requestedNutrientIds.map(
          (id) => _NutrientRow(
            nutrientId: id,
            fact: estimate.facts[id],
            registry: estimate.registry,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: labelController,
          enabled:
              !state.isBusy &&
              estimate.reviewState != NutritionEstimateReviewState.rejected,
          decoration: const InputDecoration(
            labelText: 'Food or meal label correction',
            helperText: 'Changing this creates a new correction record.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled:
              !state.isBusy &&
              estimate.reviewState != NutritionEstimateReviewState.rejected,
          decoration: const InputDecoration(
            labelText: 'Serving count correction',
            helperText: 'Positive servings only; a serving count is not grams.',
          ),
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.errorMessage!),
            ),
          ),
        if (state.status == NutritionEstimateReviewControllerStatus.accepted ||
            state.status == NutritionEstimateReviewControllerStatus.corrected)
          const Text(
            'Saved. Previously logged meals keep their original estimate.',
          ),
        const Text(
          'Temporary photos are deleted after processing, cancellation, or failure. Photos are not included in backups.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: onReject,
              child: const Text('Reject estimate'),
            ),
            OutlinedButton(
              onPressed: onCorrect,
              child: const Text('Save correction'),
            ),
            FilledButton(
              onPressed: onAccept,
              child: const Text('Accept estimate'),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ],
    );
  }
}

class _MetadataCard extends StatelessWidget {
  final NutritionEstimate estimate;

  const _MetadataCard({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'Confidence: ${ConsumerCopy.state(estimate.confidence.stableId)}',
      estimate.completeness.missingNutrientIds.isEmpty
          ? 'All requested nutrition details are available.'
          : 'Some nutrition details are not available yet.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About this estimate',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
          ],
        ),
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String nutrientId;
  final NutrientFact? fact;
  final NutrientRegistry? registry;

  const _NutrientRow({
    required this.nutrientId,
    required this.fact,
    required this.registry,
  });

  @override
  Widget build(BuildContext context) {
    final label = registry?.definitionFor(nutrientId).displayName ?? nutrientId;
    final value = fact == null || !fact!.hasNumericValue
        ? 'Unknown'
        : _rangeText(fact!);
    return Semantics(
      label: '$label: $value',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(value),
        trailing: Text(
          fact == null
              ? 'Not available'
              : ConsumerCopy.state(fact!.status.stableId),
        ),
      ),
    );
  }

  String _rangeText(NutrientFact fact) {
    String format(NutrientAmount? amount) =>
        amount == null ? 'unknown' : '${amount.value} ${amount.unit.symbol}';
    final lower = format(fact.lower);
    final point = format(fact.point);
    final upper = format(fact.upper);
    if (fact.lower == null && fact.upper == null) return point;
    return '$lower ≤ point $point ≤ $upper';
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    ),
  );
}
