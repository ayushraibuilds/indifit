import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_execution_compatibility_read_repository.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import 'b02_strength_execution_controller.dart';
import 'widgets/r07c_workout_presentation.dart';
import 'workout_execution_context.dart';

final b02StrengthHistoryDetailProvider = FutureProvider.autoDispose
    .family<B02StrengthHistoryDetail?, int>(
      (ref, sessionId) => B02ExecutionCompatibilityReadRepository(
        ref.watch(databaseProvider),
      ).readStrengthSession(sessionId),
    );

/// Final review for B02 strength execution. Full and partial completion are
/// explicit actions; a failed finalization keeps the linked draft visible.
class B02StrengthSummaryScreen extends ConsumerStatefulWidget {
  final B02StrengthExecutionLaunch launch;
  final WorkoutExecutionContext? executionContext;

  const B02StrengthSummaryScreen({
    super.key,
    required this.launch,
    this.executionContext,
  });

  @override
  ConsumerState<B02StrengthSummaryScreen> createState() =>
      _B02StrengthSummaryScreenState();
}

class _B02StrengthSummaryScreenState
    extends ConsumerState<B02StrengthSummaryScreen> {
  late final String _completionCommandId;
  var _isFinalizing = false;
  B02StrengthExecutionLaunch? _completionLaunch;
  CompletionKind? _pendingCompletionKind;
  String? _pendingCompletionReason;

  @override
  void initState() {
    super.initState();
    _completionCommandId = const Uuid().v4();
  }

  @override
  Widget build(BuildContext context) {
    final provider = b02StrengthExecutionScreenControllerProvider(
      widget.launch,
    );
    final ui = ref.watch(provider);
    final current = ui.launch ?? widget.launch;
    final execution =
        (widget.executionContext ?? WorkoutExecutionContext.fromLaunch(current))
            .rebind(current);
    final completed =
        ui.status == B02StrengthExecutionStatus.ready && ui.launch == null;
    if (completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout saved')),
        body: B02WorkoutCompletionSuccess(
          launch: _completionLaunch ?? widget.launch,
          sessionId: ui.completedSessionId,
          completionKind: ui.completedCompletionKind ?? CompletionKind.full,
          onDone: () => goToTrainingTab(context),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review workout')),
      body: _Body(
        launch: current,
        executionContext: execution,
        ui: ui,
        onRetry: ui.launch == null || _pendingCompletionKind == null
            ? null
            : () => _complete(
                context,
                provider,
                _pendingCompletionKind!,
                reason: _pendingCompletionReason,
              ),
        onFull: ui.isBusy || _isFinalizing
            ? null
            : () => _complete(context, provider, CompletionKind.full),
        onPartial: ui.isBusy || _isFinalizing
            ? null
            : () => _confirmPartial(context, provider),
        onBack: () => context.pop(),
      ),
    );
  }

  Future<void> _confirmPartial(BuildContext context, dynamic provider) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Finish partially?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'For example: time or equipment limit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Keep training'),
            ),
            FilledButton(
              onPressed: () => context.pop(controller.text.trim()),
              child: const Text('Confirm partial finish'),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;
    await _complete(context, provider, CompletionKind.partial, reason: reason);
  }

  Future<void> _complete(
    BuildContext context,
    dynamic provider,
    CompletionKind kind, {
    String? reason,
  }) async {
    if (_isFinalizing) return;
    setState(() {
      _isFinalizing = true;
      _pendingCompletionKind = kind;
      _pendingCompletionReason = reason?.isEmpty == true ? null : reason;
    });
    final controller = ref.read(provider.notifier);
    try {
      await controller.pauseElapsed();
      if (!mounted) return;
      _completionLaunch = ref.read(provider).launch ?? widget.launch;
      final finalized = await controller.finalize(
        commandId: _completionCommandId,
        completionKind: kind,
        reason: _pendingCompletionReason,
      );
      if (finalized && mounted) {
        unawaited(IndiFitHaptics.confirmation());
      }
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }
}

/// Consumer-facing evidence shown only after canonical B02 finalization
/// succeeds. When [sessionId] is present, all post-completion facts come from
/// the immutable saved session. The launch fallback exists for compatibility
/// callers/tests that render this presentation without a database handoff.
class B02WorkoutCompletionSuccess extends ConsumerWidget {
  const B02WorkoutCompletionSuccess({
    super.key,
    required this.launch,
    this.sessionId,
    this.completionKind = CompletionKind.full,
    required this.onDone,
  });

  final B02StrengthExecutionLaunch launch;
  final int? sessionId;
  final CompletionKind completionKind;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessionId case final savedSessionId?) {
      final detail = ref.watch(
        b02StrengthHistoryDetailProvider(savedSessionId),
      );
      return detail.when(
        loading: () => _SavedDetailsLoading(
          onDone: onDone,
          isPartial: completionKind == CompletionKind.partial,
        ),
        error: (_, _) => _CompletionEvidence(
          // Once the canonical session ID exists, the pre-finalization draft
          // is not a valid fallback for the saved result. Keep the saved
          // shell truthful and explain that detail loading failed.
          launch: null,
          completionKind: completionKind,
          onDone: onDone,
          detailsUnavailable: true,
        ),
        data: (history) => _CompletionEvidence(
          // A null read is treated like unavailable persisted detail rather
          // than silently presenting stale draft values after finalization.
          launch: history == null ? null : launch,
          completionKind: completionKind,
          history: history,
          onDone: onDone,
          detailsUnavailable: history == null,
        ),
      );
    }
    return _CompletionEvidence(launch: launch, onDone: onDone);
  }
}

/// Reopens the same factual result from persisted history. It has no route
/// back to an active draft and cannot finalize or resume a workout.
class B02StrengthHistoryDetailScreen extends ConsumerWidget {
  const B02StrengthHistoryDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(b02StrengthHistoryDetailProvider(sessionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Workout details')),
      body: detail.when(
        loading: () => Center(
          child: Semantics(
            label: 'Loading workout details',
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Some saved workout details are unavailable.'),
          ),
        ),
        data: (history) => history == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Some saved workout details are unavailable.'),
                ),
              )
            : _CompletionEvidence(
                history: history,
                onDone: () => context.pop(),
              ),
      ),
    );
  }
}

class _SavedDetailsLoading extends StatelessWidget {
  const _SavedDetailsLoading({required this.onDone, required this.isPartial});

  final VoidCallback onDone;
  final bool isPartial;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Loading saved workout details',
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Text(
              isPartial ? 'Workout partially completed' : 'Workout complete',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text('Loading your saved results…'),
            const SizedBox(height: 20),
            TextButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    ),
  );
}

class _CompletionEvidence extends StatelessWidget {
  const _CompletionEvidence({
    this.launch,
    required this.onDone,
    this.completionKind = CompletionKind.full,
    this.history,
    this.detailsUnavailable = false,
  });

  final B02StrengthExecutionLaunch? launch;
  final B02StrengthHistoryDetail? history;
  final VoidCallback onDone;
  final CompletionKind completionKind;
  final bool detailsUnavailable;

  @override
  Widget build(BuildContext context) {
    final saved = history != null;
    final exercises = saved
        ? history!.exercises
              .map(
                (exercise) => _HistoryExerciseEvidence.fromHistory(
                  exercise,
                  showTargets: history!.scheduledOccurrenceId != null,
                ),
              )
              .toList()
        : (launch?.state.performedExercises ??
                  const <B02PerformedExerciseDraft>[])
              .map(
                (exercise) => _HistoryExerciseEvidence.fromDraft(
                  exercise,
                  showTargets: launch?.occurrenceId != null,
                ),
              )
              .toList();
    final setCount = exercises.fold<int>(
      0,
      (count, exercise) => count + exercise.sets.length,
    );
    final knownReps = exercises
        .expand((exercise) => exercise.sets)
        .where((set) => set.actualReps != null)
        .fold<int>(0, (sum, set) => sum + set.actualReps!);
    final fallbackVolume = _draftVolume(exercises);
    final volume = history?.totalVolumeKg ?? fallbackVolume;
    final hasVolume = volume > 0;
    final isPartial =
        history?.isPartial ?? completionKind == CompletionKind.partial;
    final routineName = history?.name ?? launch?.state.routineName ?? 'Workout';
    final durationSeconds =
        history?.durationSeconds ?? launch?.state.elapsedSeconds ?? 0;
    final groupById = {
      for (final group
          in history?.groups ?? const <B02PerformedExerciseGroupHistory>[])
        group.id: group,
    };
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                children: [
                  Icon(
                    isPartial
                        ? Icons.check_circle_outline_rounded
                        : Icons.check_circle_rounded,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPartial
                        ? 'Workout partially completed'
                        : 'Workout complete',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    routineName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detailsUnavailable
                        ? 'Your workout is saved. Some result details are unavailable.'
                        : 'Your workout is saved to history.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final metrics = <Widget>[
                        if (durationSeconds > 0)
                          R07CMetricTile(
                            label: 'Duration',
                            value: formatB02WorkoutDuration(durationSeconds),
                          ),
                        R07CMetricTile(
                          label: 'Exercises',
                          value: '${exercises.length}',
                        ),
                        R07CMetricTile(label: 'Sets', value: '$setCount'),
                        if (knownReps > 0)
                          R07CMetricTile(label: 'Reps', value: '$knownReps'),
                        if (hasVolume)
                          R07CMetricTile(
                            label: 'External volume',
                            value: '${r07cFormatNumber(volume)} kg',
                          ),
                      ];
                      final width = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final metric in metrics)
                            SizedBox(width: width, child: metric),
                        ],
                      );
                    },
                  ),
                  if (exercises.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'What you logged',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final group
                        in history?.groups ??
                            const <B02PerformedExerciseGroupHistory>[])
                      _HistoryGroupEvidence(
                        group: group,
                        exercises: exercises
                            .where((exercise) => exercise.groupId == group.id)
                            .toList(),
                      ),
                    for (final exercise in exercises.where(
                      (exercise) =>
                          exercise.groupId == null ||
                          !groupById.containsKey(exercise.groupId),
                    ))
                      _CompletionExerciseEvidence(exercise: exercise),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onDone, child: const Text('Done')),
            ),
          ),
        ],
      ),
    );
  }

  static double _draftVolume(List<_HistoryExerciseEvidence> exercises) {
    var total = 0.0;
    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        if (set.role != B02SetRole.working ||
            set.actualReps == null ||
            set.actualLoadKg == null) {
          continue;
        }
        if (set.technique.segments.isEmpty) {
          total += set.actualLoadKg! * set.actualReps!;
        } else {
          for (final segment in set.technique.segments) {
            if (segment.externalLoadKg != null) {
              total += segment.externalLoadKg! * segment.reps;
            }
          }
        }
      }
    }
    return total;
  }
}

class _HistoryExerciseEvidence {
  const _HistoryExerciseEvidence({
    required this.id,
    required this.groupId,
    required this.groupMemberOrdinal,
    required this.groupRoundOrdinal,
    required this.ordinal,
    required this.expectedName,
    required this.expectedId,
    required this.actualId,
    required this.actualName,
    required this.status,
    required this.substitutionReason,
    required this.sets,
    required this.segmentsBySetId,
    required this.showTargets,
  });

  factory _HistoryExerciseEvidence.fromHistory(
    B02PerformedExerciseHistory history, {
    required bool showTargets,
  }) {
    return _HistoryExerciseEvidence(
      id: history.id,
      groupId: history.performedExerciseGroupId,
      groupMemberOrdinal: history.groupMemberOrdinal,
      groupRoundOrdinal: history.groupRoundOrdinal,
      ordinal: history.ordinal,
      expectedName: history.expectedExerciseNameSnapshot,
      expectedId: history.expectedExerciseId,
      actualId: history.actualExerciseId,
      actualName: history.actualExerciseNameSnapshot,
      status: history.status,
      substitutionReason: history.substitutionReason,
      sets: history.sets,
      segmentsBySetId: history.segmentsBySetId,
      showTargets: showTargets && history.expectedExerciseId != null,
    );
  }

  factory _HistoryExerciseEvidence.fromDraft(
    B02PerformedExerciseDraft draft, {
    required bool showTargets,
  }) {
    return _HistoryExerciseEvidence(
      id: draft.id,
      groupId: draft.performedExerciseGroupId,
      groupMemberOrdinal: draft.groupMemberOrdinal,
      groupRoundOrdinal: draft.groupRoundOrdinal,
      ordinal: draft.ordinal,
      expectedName: draft.expectedExerciseNameSnapshot,
      expectedId: draft.expectedExerciseId,
      actualId: draft.actualExerciseId,
      actualName: draft.actualExerciseNameSnapshot,
      status: draft.status,
      substitutionReason: draft.substitutionReason,
      sets: draft.sets,
      segmentsBySetId: {
        for (final set in draft.sets)
          if (set.technique.segments.isNotEmpty) set.id: set.technique.segments,
      },
      showTargets: showTargets,
    );
  }

  final String id;
  final String? groupId;
  final int? groupMemberOrdinal;
  final int? groupRoundOrdinal;
  final int ordinal;
  final String? expectedName;
  final String? expectedId;
  final String actualId;
  final String actualName;
  final String status;
  final String? substitutionReason;
  final List<B02PerformedSet> sets;
  final Map<String, List<B02SetSegment>> segmentsBySetId;
  final bool showTargets;

  bool get wasSubstituted => expectedId != null && actualId != expectedId;

  List<B02SetSegment> segmentsFor(B02PerformedSet set) =>
      segmentsBySetId[set.id] ?? const [];
}

class _HistoryGroupEvidence extends StatelessWidget {
  const _HistoryGroupEvidence({required this.group, required this.exercises});

  final B02PerformedExerciseGroupHistory group;
  final List<_HistoryExerciseEvidence> exercises;

  @override
  Widget build(BuildContext context) {
    final label = _consumerGroupLabel(group.groupType, group.label);
    final rounds = '${group.completedRounds}/${group.plannedRounds} rounds';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: B05Surface(
        tone: B05SurfaceTone.section,
        child: Semantics(
          container: true,
          label: '$label, $rounds',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(rounds, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (exercises.isEmpty)
                const Text('No exercise details are available.')
              else
                for (final exercise in exercises)
                  _CompletionExerciseEvidence(exercise: exercise),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionExerciseEvidence extends StatelessWidget {
  const _CompletionExerciseEvidence({required this.exercise});

  final _HistoryExerciseEvidence exercise;

  @override
  Widget build(BuildContext context) {
    final subtitle = _exerciseSubtitle();
    final advanced = _advancedFacts();
    final targetSummary = exercise.showTargets ? _targetSummary() : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: B05Surface(
        tone: B05SurfaceTone.inset,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Semantics(
          container: true,
          label: [
            exercise.actualName,
            _statusLabel(exercise.status),
            ?subtitle,
          ].join(', '),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      exercise.actualName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel(exercise.status),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (exercise.sets.isNotEmpty) ...[
                const SizedBox(height: 8),
                _CompletionPerformedSetList(sets: exercise.sets),
              ],
              if (advanced.isNotEmpty)
                _AdvancedEvidenceDisclosure(facts: advanced),
              if (targetSummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  targetSummary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _exerciseSubtitle() {
    final groupContext = switch ((
      exercise.groupRoundOrdinal,
      exercise.groupMemberOrdinal,
    )) {
      (final round?, final member?) =>
        'Round ${round + 1} · Exercise ${member + 1}',
      _ => null,
    };
    final substitution = exercise.wasSubstituted
        ? 'Performed instead of ${exercise.expectedName ?? 'the planned exercise'}'
        : null;
    final parts = [?substitution, ?groupContext];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _targetSummary() {
    final targets = exercise.sets
        .map(
          (set) => r07cFormatTarget(
            loadKg: set.targetLoadKg,
            loadBasis: set.targetLoadBasis,
            minReps: set.targetRepsMin,
            maxReps: set.targetRepsMax,
            rpe: set.targetRpe,
          ),
        )
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    return targets.isEmpty ? null : 'Target · ${targets.join(' · ')}';
  }

  List<String> _advancedFacts() {
    final facts = <String>[];
    for (final set in exercise.sets) {
      final technique = set.technique;
      switch (technique.effortMode) {
        case B02EffortMode.standard:
          break;
        case B02EffortMode.amrap:
          facts.add('As many reps as possible');
        case B02EffortMode.toFailure:
          facts.add('To failure');
      }
      if (technique.endedAtFailure) facts.add('Ended at failure');
      if (technique.tempoEccentricSeconds != null) {
        facts.add(
          'Tempo ${technique.tempoEccentricSeconds}-'
          '${technique.tempoBottomPauseSeconds}-'
          '${technique.tempoConcentricSeconds}-'
          '${technique.tempoLockoutPauseSeconds}',
        );
      }
      if (technique.pausedRepPosition != null) {
        facts.add(
          'Paused reps: ${_pausedPositionLabel(technique.pausedRepPosition!)}'
          '${technique.pausedRepSeconds == null ? '' : ' · ${technique.pausedRepSeconds} sec'}',
        );
      }
      if (technique.assistanceMode != null) {
        facts.add(
          'Assisted reps: ${_assistanceLabel(technique.assistanceMode!)}'
          '${technique.assistanceKg == null ? '' : ' · ${r07cFormatNumber(technique.assistanceKg!)} kg'}',
        );
      }
      final segments = exercise.segmentsFor(set);
      if (segments.isNotEmpty) {
        facts.add(
          'Segmented set: ${segments.length} ${segments.length == 1 ? 'segment' : 'segments'}',
        );
      }
    }
    return facts.toSet().toList(growable: false);
  }

  static String _statusLabel(String status) => switch (status) {
    'completed' => 'Completed',
    'partial' => 'Partially complete',
    'skipped' => 'Skipped',
    'inProgress' => 'In progress',
    _ => 'Logged',
  };
}

/// Completion evidence uses a quieter per-set cue than the summary's primary
/// completion mark, keeping the result hierarchy unambiguous.
class _CompletionPerformedSetList extends StatelessWidget {
  const _CompletionPerformedSetList({required this.sets});

  final List<B02PerformedSet> sets;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const SizedBox.shrink();
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final set in sets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Semantics(
                label: 'Logged set ${r07cFormatPerformedSet(set)}',
                child: Row(
                  children: [
                    const Icon(Icons.done_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r07cFormatPerformedSet(set),
                        style: B05Typography.body(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdvancedEvidenceDisclosure extends StatelessWidget {
  const _AdvancedEvidenceDisclosure({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Additional exercise details',
    child: Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: const Text('Additional details'),
        children: [
          for (final fact in facts)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(fact),
              ),
            ),
        ],
      ),
    ),
  );
}

String _consumerGroupLabel(String type, String? label) {
  final named = label?.trim();
  if (named != null && named.isNotEmpty) return named;
  return switch (type) {
    'superset' => 'Superset',
    'circuit' => 'Circuit',
    'giantSet' => 'Giant set',
    _ => 'Grouped exercises',
  };
}

String _pausedPositionLabel(B02PausedRepPosition position) =>
    switch (position) {
      B02PausedRepPosition.bottom => 'bottom',
      B02PausedRepPosition.top => 'top',
      B02PausedRepPosition.midpoint => 'midpoint',
      B02PausedRepPosition.custom => 'custom position',
    };

String _assistanceLabel(B02AssistanceMode mode) => switch (mode) {
  B02AssistanceMode.machine => 'machine',
  B02AssistanceMode.counterweight => 'counterweight',
  B02AssistanceMode.band => 'band',
  B02AssistanceMode.partner => 'partner',
  B02AssistanceMode.unknown => 'assistance',
};

String formatB02WorkoutDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes == 0) return '$remainingSeconds sec';
  if (remainingSeconds == 0) return '$minutes min';
  return '$minutes min $remainingSeconds sec';
}

class _Body extends StatelessWidget {
  final B02StrengthExecutionLaunch launch;
  final WorkoutExecutionContext executionContext;
  final B02StrengthExecutionUiState ui;
  final VoidCallback? onRetry;
  final VoidCallback? onFull;
  final VoidCallback? onPartial;
  final VoidCallback onBack;

  const _Body({
    required this.launch,
    required this.executionContext,
    required this.ui,
    required this.onRetry,
    required this.onFull,
    required this.onPartial,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (ui.status == B02StrengthExecutionStatus.failure ||
        ui.status == B02StrengthExecutionStatus.recovery) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 12),
              Text(
                ui.errorMessage ??
                    'Your workout could not be saved. Try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your workout is still here. Nothing was lost.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (onRetry != null)
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(
                onPressed: onBack,
                child: const Text('Return to workout'),
              ),
            ],
          ),
        ),
      );
    }
    final performed = launch.state.performedExercises;
    final totalActual = performed
        .expand((exercise) => exercise.sets)
        .where((set) => set.actualReps != null)
        .fold<int>(0, (sum, set) => sum + set.actualReps!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        B05Surface(
          tone: B05SurfaceTone.selected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                launch.state.routineName,
                semanticsLabel:
                    '${executionContext.modeLabel}: ${launch.state.routineName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                launch.state.elapsedSeconds > 0
                    ? formatB02WorkoutDuration(launch.state.elapsedSeconds)
                    : 'Duration unavailable',
              ),
              if (totalActual > 0) ...[
                const SizedBox(height: 4),
                Text('$totalActual reps completed'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final group in launch.state.groups)
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(_groupLabel(group)),
              subtitle: Text(
                '${group.roundCount} ${group.roundCount == 1 ? 'round' : 'rounds'} · ${group.members.length} ${group.members.length == 1 ? 'exercise' : 'exercises'}',
              ),
            ),
          ),
        if (performed.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No performed sets yet'),
              subtitle: Text('Log at least one set before finishing.'),
            ),
          ),
        for (final exercise in performed)
          _CompletionExerciseEvidence(
            exercise: _HistoryExerciseEvidence.fromDraft(
              exercise,
              // The pre-completion draft may contain factual target fields
              // even when it has no scheduled occurrence. Persisted Quick
              // summaries are still gated by scheduledOccurrenceId below.
              showTargets: true,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          launch.occurrenceId == null
              ? 'These completed sets will be saved with this workout.'
              : 'These completed sets and planned targets will be saved with this workout.',
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onFull, child: const Text('Complete workout')),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onPartial,
          child: const Text('Finish partially…'),
        ),
      ],
    );
  }

  static String _groupLabel(B02ExerciseGroup group) {
    final type = switch (group.groupType) {
      B02GroupType.superset => 'Superset',
      B02GroupType.circuit => 'Circuit',
      B02GroupType.giantSet => 'Giant set',
    };
    return group.label?.trim().isNotEmpty == true ? group.label!.trim() : type;
  }
}
