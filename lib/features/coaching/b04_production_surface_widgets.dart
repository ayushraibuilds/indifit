import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/theme/colors.dart';
import '../../data/models/b04_briefing_read_models.dart';
import '../../data/models/b04_current_food_models.dart';
import '../../data/models/b04_recommendation_context_models.dart';
import '../../data/models/b04_recommendation_history_models.dart';
import '../../data/models/b04_recommendation_models.dart';
import '../dashboard/b04_daily_briefing_controller.dart';
import '../nutrition/current_food_controller.dart';
import '../progress/b04_weekly_review_controller.dart';
import 'b04_production_surface_controller.dart';

class B04DailyBriefingCard extends ConsumerStatefulWidget {
  const B04DailyBriefingCard({super.key});

  @override
  ConsumerState<B04DailyBriefingCard> createState() =>
      _B04DailyBriefingCardState();
}

class _B04DailyBriefingCardState extends ConsumerState<B04DailyBriefingCard> {
  String? _loadedKey;

  void _load(B04ProductionUserContext context) {
    final key = '${context.userId}:${context.localDate}:${context.timezoneId}';
    if (_loadedKey == key) return;
    _loadedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(b04DailyBriefingControllerProvider.notifier)
          .load(
            userId: context.userId,
            localDate: context.localDate,
            timezoneId: context.timezoneId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(b04ProductionUserContextProvider);
    final state = ref.watch(b04DailyBriefingControllerProvider);
    return userContext.when(
      loading: () => const B04LoadingCard(label: 'Daily guidance'),
      error: (_, _) => B04ReadStatusCard(
        title: 'Daily guidance unavailable',
        message:
            'Your profile is not ready for this local view. Try again later.',
        action: TextButton(
          onPressed: () => ref.invalidate(b04ProductionUserContextProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (value) {
        _load(value);
        return B04DailyBriefingContent(
          state: state,
          onRetry: () =>
              ref.read(b04DailyBriefingControllerProvider.notifier).retry(),
          onAction: (recommendation, action) =>
              action == B04RecommendationFeedbackAction.accept
              ? ref
                    .read(b04DailyBriefingControllerProvider.notifier)
                    .acceptTarget(recommendation)
              : ref
                    .read(b04DailyBriefingControllerProvider.notifier)
                    .recordFeedback(
                      recommendationId: recommendation.id,
                      action: action,
                    ),
        );
      },
    );
  }
}

class B04DailyBriefingContent extends StatelessWidget {
  final B04DailyBriefingState state;
  final VoidCallback onRetry;
  final Future<void> Function(
    B04BriefingRecommendation recommendation,
    B04RecommendationFeedbackAction action,
  )
  onAction;

  const B04DailyBriefingContent({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => _B04BriefingContent(
    title: 'Today’s coaching',
    state: state.status,
    briefing: state.briefing,
    errorMessage: state.errorMessage,
    onRetry: onRetry,
    onAction: onAction,
  );
}

class B04WeeklyReviewCard extends ConsumerStatefulWidget {
  const B04WeeklyReviewCard({super.key});

  @override
  ConsumerState<B04WeeklyReviewCard> createState() =>
      _B04WeeklyReviewCardState();
}

class _B04WeeklyReviewCardState extends ConsumerState<B04WeeklyReviewCard> {
  String? _loadedKey;

  void _load(B04ProductionUserContext context) {
    final key = '${context.userId}:${context.localDate}:${context.timezoneId}';
    if (_loadedKey == key) return;
    _loadedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final end = context.localDate;
      final first = ref
          .read(localScheduleDateServiceProvider)
          .addCalendarDays(context.localDate, context.timezoneId, -6);
      ref
          .read(b04WeeklyReviewControllerProvider.notifier)
          .load(
            userId: context.userId,
            startLocalDate: first,
            endLocalDate: end,
            timezoneId: context.timezoneId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(b04ProductionUserContextProvider);
    final state = ref.watch(b04WeeklyReviewControllerProvider);
    return userContext.when(
      loading: () => const B04LoadingCard(label: 'Weekly review'),
      error: (_, _) => B04ReadStatusCard(
        title: 'Weekly review unavailable',
        message:
            'Your profile is not ready for this local view. Try again later.',
        action: TextButton(
          onPressed: () => ref.invalidate(b04ProductionUserContextProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (value) {
        _load(value);
        return B04WeeklyReviewContent(
          state: state,
          onRetry: () =>
              ref.read(b04WeeklyReviewControllerProvider.notifier).retry(),
          onAction: (recommendation, action) =>
              action == B04RecommendationFeedbackAction.accept
              ? ref
                    .read(b04WeeklyReviewControllerProvider.notifier)
                    .acceptTarget(recommendation)
              : ref
                    .read(b04WeeklyReviewControllerProvider.notifier)
                    .recordFeedback(
                      recommendationId: recommendation.id,
                      action: action,
                    ),
        );
      },
    );
  }
}

class B04WeeklyReviewContent extends StatelessWidget {
  final B04WeeklyReviewState state;
  final VoidCallback onRetry;
  final Future<void> Function(
    B04BriefingRecommendation recommendation,
    B04RecommendationFeedbackAction action,
  )
  onAction;

  const B04WeeklyReviewContent({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => _B04BriefingContent(
    title: 'Weekly coaching review',
    state: state.status,
    briefing: state.review,
    errorMessage: state.errorMessage,
    onRetry: onRetry,
    onAction: onAction,
  );
}

class _B04BriefingContent extends StatelessWidget {
  final String title;
  final Enum state;
  final B04BriefingReadModel? briefing;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Future<void> Function(
    B04BriefingRecommendation recommendation,
    B04RecommendationFeedbackAction action,
  )
  onAction;

  const _B04BriefingContent({
    required this.title,
    required this.state,
    required this.briefing,
    required this.errorMessage,
    required this.onRetry,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (state.toString().endsWith('.loading')) {
      return B04LoadingCard(label: title);
    }
    if (state.toString().endsWith('.failure')) {
      return B04ReadStatusCard(
        title: title,
        message:
            errorMessage ?? 'This view could not be loaded. You can retry.',
        action: TextButton(onPressed: onRetry, child: const Text('Retry')),
      );
    }
    final read = briefing;
    if (read == null) {
      return B04ReadStatusCard(
        title: title,
        message: 'No read model is available for this period.',
      );
    }
    if (read.status == B04BriefingReadStatus.noData) {
      return B04ReadStatusCard(
        title: title,
        message: 'No guidance has been recorded for this local period yet.',
        detail: _briefingDetail(read),
      );
    }
    if (read.status == B04BriefingReadStatus.unavailable) {
      return B04ReadStatusCard(
        title: title,
        message: read.unavailableReasons.isEmpty
            ? 'This guidance is unavailable because the required evidence is incomplete.'
            : read.unavailableReasons.map(b04ProductionStateCopy).join(' '),
        detail: _briefingDetail(read),
      );
    }
    if (read.visibleRecommendations.isEmpty) {
      return B04ReadStatusCard(
        title: title,
        message:
            'No current guidance is visible. Dismissed guidance remains in history.',
        detail: _briefingDetail(read),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          label: read.accessibilityLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                _periodLabel(read),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (read.policyState != null ||
                  read.consentState != null ||
                  read.eligibilityState != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (read.policyState != null)
                      _B04Pill(
                        label:
                            'Policy: ${b04ProductionStateLabel(read.policyState!.stableId)}',
                      ),
                    if (read.consentState != null)
                      _B04Pill(
                        label:
                            'Consent: ${b04ProductionStateLabel(read.consentState!.stableId)}',
                      ),
                    if (read.eligibilityState != null)
                      _B04Pill(
                        label:
                            'Eligibility: ${b04ProductionStateLabel(read.eligibilityState!.stableId)}',
                      ),
                  ],
                ),
              ],
              if (read.missingEvidence.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Evidence limits: ${read.missingEvidence.join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              ...read.visibleRecommendations.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _B04RecommendationTile(
                    recommendation: item,
                    onAction: onAction,
                  ),
                ),
              ),
              if (read.lowRiskWarnings.isNotEmpty)
                _B04WarningList(warnings: read.lowRiskWarnings),
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(B04BriefingReadModel read) =>
      read.scope == B04RecommendationHistoryScope.daily
      ? '${read.startLocalDate} · ${read.timezoneId}'
      : '${read.startLocalDate} – ${read.endLocalDate} · ${read.timezoneId}';

  String _briefingDetail(B04BriefingReadModel read) {
    final values = <String>[_periodLabel(read)];
    if (read.policyState != null) {
      values.add(
        'Policy: ${b04ProductionStateLabel(read.policyState!.stableId)}',
      );
    }
    if (read.consentState != null) {
      values.add(
        'Consent: ${b04ProductionStateLabel(read.consentState!.stableId)}',
      );
    }
    if (read.eligibilityState != null) {
      values.add(
        'Eligibility: ${b04ProductionStateLabel(read.eligibilityState!.stableId)}',
      );
    }
    if (read.missingEvidence.isNotEmpty) {
      values.add('Evidence limits: ${read.missingEvidence.join(', ')}');
    }
    return values.join(' · ');
  }
}

class B04CurrentFoodCard extends ConsumerStatefulWidget {
  const B04CurrentFoodCard({super.key});

  @override
  ConsumerState<B04CurrentFoodCard> createState() => _B04CurrentFoodCardState();
}

class _B04CurrentFoodCardState extends ConsumerState<B04CurrentFoodCard> {
  String? _loadedContextId;

  void _load(B04RecommendationContext context) {
    if (_loadedContextId == context.contextId) return;
    _loadedContextId = context.contextId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(b04CurrentFoodControllerProvider.notifier)
          .loadProduction(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(b04ProductionRecommendationContextProvider);
    final state = ref.watch(b04CurrentFoodControllerProvider);
    return contextAsync.when(
      loading: () => const B04LoadingCard(label: 'What can I eat now?'),
      error: (_, _) => B04ReadStatusCard(
        title: 'What can I eat now?',
        message:
            'Current-food guidance is unavailable until local evidence is ready.',
        action: TextButton(
          onPressed: () =>
              ref.invalidate(b04ProductionRecommendationContextProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (value) {
        _load(value);
        return B04CurrentFoodContent(
          state: state,
          onRetry: () =>
              ref.read(b04CurrentFoodControllerProvider.notifier).retry(),
        );
      },
    );
  }
}

class B04CurrentFoodContent extends StatelessWidget {
  final B04CurrentFoodState state;
  final VoidCallback? onRetry;

  const B04CurrentFoodContent({super.key, required this.state, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (state.status == B04CurrentFoodControllerStatus.loading ||
        state.status == B04CurrentFoodControllerStatus.idle) {
      return const B04LoadingCard(label: 'What can I eat now?');
    }
    final guidance = state.guidance;
    if (guidance == null || !guidance.isAvailable) {
      final reasons = guidance?.reasonCodes ?? const <String>[];
      return B04ReadStatusCard(
        title: 'What can I eat now?',
        message: reasons.isEmpty
            ? state.errorMessage ??
                  'Current-food guidance is unavailable until nutrition and safety evidence is complete.'
            : reasons.map(b04ProductionStateCopy).join(' '),
        detail: guidance == null ? null : _currentFoodDetail(guidance),
        action:
            state.status == B04CurrentFoodControllerStatus.failure &&
                onRetry != null
            ? TextButton(onPressed: onRetry, child: const Text('Retry'))
            : null,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          label: 'What can I eat now? ${guidance.status.stableId}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What can I eat now?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Candidates are filtered through B03 evidence. No-known-conflict is not a safety guarantee.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _B04EvidenceLines(
                title: 'Remaining targets and evidence',
                lines: _currentFoodTargetLines(guidance.remainingTargets),
              ),
              const SizedBox(height: 12),
              for (final card in guidance.cards)
                _B04CurrentFoodCandidateTile(card: card),
              if (guidance.excludedCandidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Candidates not shown as guidance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final excluded in guidance.excludedCandidates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(excluded.displayLabel),
                    subtitle: Text(
                      excluded.reasonCodes
                          .map(b04ProductionStateCopy)
                          .join(' '),
                    ),
                  ),
              ],
              if (guidance.lowRiskWarnings.isNotEmpty)
                _B04WarningList(warnings: guidance.lowRiskWarnings),
            ],
          ),
        ),
      ),
    );
  }
}

class _B04CurrentFoodCandidateTile extends StatelessWidget {
  final B04CurrentFoodCandidateCard card;

  const _B04CurrentFoodCandidateTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final facts = card.nutrientFacts.map(_currentFoodValueLabel).join(' · ');
    final evidence = card.recommendation.evidenceIds.join(', ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(card.displayLabel),
      subtitle: Text(
        [
          card.recommendation.explanation,
          'Target fit: ${b04ProductionStateLabel(card.targetFit.state.stableId)}',
          if (facts.isNotEmpty) 'Nutrient evidence: $facts',
          if (evidence.isNotEmpty) 'Evidence: $evidence',
        ].join('\n'),
      ),
      trailing: Text(b04ProductionStateLabel(card.targetFit.state.stableId)),
    );
  }
}

class _B04RecommendationTile extends StatelessWidget {
  final B04BriefingRecommendation recommendation;
  final Future<void> Function(
    B04BriefingRecommendation recommendation,
    B04RecommendationFeedbackAction action,
  )
  onAction;

  const _B04RecommendationTile({
    required this.recommendation,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isSafetyUnavailable =
        recommendation.state == B04RecommendationState.unavailable;
    final hasCanonicalProposal =
        recommendation
            .engineRecommendation
            ?.canonicalAdaptiveTarget
            ?.proposal !=
        null;
    final result = recommendation.canonicalResult;
    return Semantics(
      container: true,
      label: recommendation.accessibilityLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      b04ProductionStateLabel(recommendation.action),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _B04Pill(
                    label: b04ProductionStateLabel(
                      recommendation.state.stableId,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(recommendation.explanation),
              if (result != null && result.hasCanonicalResult) ...[
                const SizedBox(height: 8),
                Text(
                  _canonicalResultLabel(result),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (recommendation.uncertainty.isNotEmpty ||
                  recommendation.missingEvidence.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Evidence limits: ${[...recommendation.uncertainty, ...recommendation.missingEvidence].join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (recommendation.evidenceIds.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Evidence: ${recommendation.evidenceIds.join(', ')}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (recommendation.targetAcceptanceState !=
                  B04BriefingTargetAcceptanceState.notApplicable) ...[
                const SizedBox(height: 6),
                Text(
                  'Target: ${b04ProductionStateLabel(recommendation.targetAcceptanceState.stableId)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (!isSafetyUnavailable)
                    _B04ActionButton(
                      label: 'Acknowledge',
                      onPressed: () => onAction(
                        recommendation,
                        B04RecommendationFeedbackAction.acknowledge,
                      ),
                    ),
                  if (!isSafetyUnavailable &&
                      hasCanonicalProposal &&
                      recommendation.targetAcceptanceState ==
                          B04BriefingTargetAcceptanceState.proposalAvailable)
                    _B04ActionButton(
                      label: 'Accept target',
                      onPressed: () => onAction(
                        recommendation,
                        B04RecommendationFeedbackAction.accept,
                      ),
                    ),
                  if (!isSafetyUnavailable)
                    _B04ActionButton(
                      label: 'Record override',
                      onPressed: () => onAction(
                        recommendation,
                        B04RecommendationFeedbackAction.override,
                      ),
                    ),
                  _B04ActionButton(
                    label: 'Dismiss',
                    onPressed: () => onAction(
                      recommendation,
                      B04RecommendationFeedbackAction.dismiss,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _canonicalResultLabel(B04BriefingNumericalResult result) {
    final values = <String>[];
    if (result.proposedDeltaKcal != null) {
      values.add('Canonical delta: ${result.proposedDeltaKcal} kcal/day');
    }
    if (result.normalizedMaintenanceKcal != null) {
      values.add('Maintenance: ${result.normalizedMaintenanceKcal} kcal/day');
    }
    if (result.exactResultNumerator != null &&
        result.exactResultDenominator != null) {
      values.add(
        'Exact result: ${result.exactResultNumerator}/${result.exactResultDenominator}',
      );
    }
    return values.join(' · ');
  }
}

class _B04WarningList extends StatelessWidget {
  final List<B04RecommendationWarning> warnings;

  const _B04WarningList({required this.warnings});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Logging-only warnings',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      for (final warning in warnings)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline, color: AppColors.warning),
          title: Text(warning.wording),
          subtitle: const Text(
            'This warning is not a recommendation safety approval.',
          ),
        ),
    ],
  );
}

class _B04EvidenceLines extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _B04EvidenceLines({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      for (final line in lines)
        Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(line)),
    ],
  );
}

List<String> _currentFoodTargetLines(B04RemainingTargetReadModel targets) {
  final lines = <String>[
    if (targets.goalVersionId != null)
      'Goal: ${targets.goalSource ?? 'unknown'} · ${targets.goalVersionId}',
    for (final value in targets.targets) _currentFoodValueLabel(value),
    if (targets.missingEvidence.isNotEmpty)
      'Missing evidence: ${targets.missingEvidence.join(', ')}',
  ];
  if (lines.isEmpty) lines.add('No remaining target values are available.');
  return lines;
}

String _currentFoodDetail(B04CurrentFoodGuidance guidance) => [
  '${guidance.localDate} · ${guidance.timezoneId}',
  ..._currentFoodTargetLines(guidance.remainingTargets),
].join(' · ');

String _currentFoodValueLabel(B04CurrentFoodNutrientValue value) {
  final amount = switch (value.state) {
    B04CurrentFoodValueState.known => value.point ?? 'unknown',
    B04CurrentFoodValueState.range =>
      '${value.lower ?? 'at least'}–${value.upper ?? 'at most'}',
    B04CurrentFoodValueState.unknown => 'unknown',
    B04CurrentFoodValueState.missing => 'missing',
    B04CurrentFoodValueState.invalid => 'invalid',
  };
  final reason = value.reasonCode == null ? '' : ' (${value.reasonCode})';
  return '${value.nutrientId}: $amount ${value.unit.symbol} · ${value.state.stableId}$reason · evidence ${value.sourceIds.join(', ')}';
}

class B04LoadingCard extends StatelessWidget {
  final String label;

  const B04LoadingCard({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Card(
    child: Semantics(
      container: true,
      label: '$label loading',
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
}

class B04ReadStatusCard extends StatelessWidget {
  final String title;
  final String message;
  final String? detail;
  final Widget? action;

  const B04ReadStatusCard({
    super.key,
    required this.title,
    required this.message,
    this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Semantics(
      container: true,
      label: '$title. $message${detail == null ? '' : ' $detail'}',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 4), action!],
          ],
        ),
      ),
    ),
  );
}

class _B04Pill extends StatelessWidget {
  final String label;

  const _B04Pill({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}

class _B04ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _B04ActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: const Size(0, 36),
    ),
    child: Text(label),
  );
}
