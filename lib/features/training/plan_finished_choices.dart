import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/core_providers.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/repositories/plan_next_block_repository.dart';
import 'plan_start_sheet.dart';
import 'training_plan_lifecycle_controller.dart';
import 'training_providers.dart';

final planNextBlockRepositoryProvider = Provider<PlanNextBlockRepository>((
  ref,
) {
  return PlanNextBlockRepository(
    ref.watch(databaseProvider),
    programs: ref.watch(programRepositoryProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

/// The active plan once it is finished (UF-13), else null. A one-shot read
/// for the summary right after a save; Training reads the same repository
/// from its landing snapshot, which already refreshes on changes.
final finishedPlanProvider = FutureProvider.autoDispose<FinishedPlanState?>((
  ref,
) async {
  ref.watch(civilDateRevisionProvider);
  final timezoneId = await ref
      .watch(localTimezoneServiceProvider)
      .currentTimezoneId();
  final today = ref.watch(localScheduleDateServiceProvider).todayIn(timezoneId);
  return ref
      .watch(planNextBlockRepositoryProvider)
      .readFinished(todayLocalDate: today);
});

/// "Plan finished" with its three choices: repeat as it is, repeat with
/// +2.5 kg on the main lifts, or pick the next plan. Repeats reuse the plan
/// start sheet; the finished block stays in history as finished.
class PlanFinishedChoices extends ConsumerStatefulWidget {
  const PlanFinishedChoices({
    super.key,
    required this.finished,
    required this.onChanged,
  });

  final FinishedPlanState finished;

  /// Called after a new block starts or the plan is finished for the next.
  final VoidCallback onChanged;

  @override
  ConsumerState<PlanFinishedChoices> createState() =>
      _PlanFinishedChoicesState();
}

class _PlanFinishedChoicesState extends ConsumerState<PlanFinishedChoices> {
  var _busy = false;

  FinishedPlanState get _finished => widget.finished;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final failure = ProductFailurePresentation.fromError(
        error,
        title: 'Plan not changed',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repeat({required bool heavier}) => _run(() async {
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final dates = ref.read(localScheduleDateServiceProvider);
    final today = dates.todayIn(timezoneId);
    if (!mounted) return;
    final schedule = _finished.schedule;
    final choice = await showPlanStartSheet(
      context,
      planName: _finished.planName,
      todayLocalDate: today,
      timezoneId: timezoneId,
      dates: dates,
      planWeekdays: schedule?.trainingWeekdays ?? const [],
      sessionsPerWeek: schedule?.sessionsPerWeek,
    );
    if (choice == null) return;
    final repository = ref.read(planNextBlockRepositoryProvider);
    final draftId = await repository.prepareNextBlock(
      finishedVersionId: _finished.programVersionId,
      increases: heavier ? _finished.increases : const [],
    );
    await repository.startNextBlock(
      lifecycle: ref.read(programLifecycleRepositoryProvider),
      activation: ref.read(programActivationCoordinatorProvider),
      draftVersionId: draftId,
      commandId: 'next-block::${const Uuid().v4()}',
      startLocalDate: choice.startLocalDate,
      timezoneId: timezoneId,
      trainingWeekdays: choice.trainingWeekdays,
    );
    _changed();
  });

  Future<void> _pickNext() => _run(() async {
    final entry = await ref
        .read(planLibraryReadRepositoryProvider)
        .readVersion(_finished.programVersionId);
    await ref.read(trainingPlanLifecycleControllerProvider).finishPlan();
    if (!mounted) return;
    final starter = entry?.starterPlan;
    final days = _finished.schedule?.sessionsPerWeek;
    final query = <String, String>{
      'equipment': ?starter?.environment.name,
      if (days != null) 'days': '${days >= 5 ? 5 : days}',
      'level': ?starter?.experience.name,
    };
    final router = GoRouter.of(context);
    _changed();
    await router.push(
      Uri(path: '/plan-library', queryParameters: query).toString(),
    );
  });

  void _changed() {
    ref.invalidate(finishedPlanProvider);
    ref.invalidate(planLibrarySnapshotProvider);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final rule = _finished.increaseRule;
    final count = _finished.completedCount;
    return B05Surface(
      tone: B05SurfaceTone.selected,
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan finished', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            '${_finished.planName} · $count ${count == 1 ? 'workout' : 'workouts'} done. '
            'Choose what comes next.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('plan_finished_repeat'),
              onPressed: _busy ? null : () => _repeat(heavier: false),
              child: const Text('Repeat as it is'),
            ),
          ),
          const SizedBox(height: B05Layout.space8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('plan_finished_repeat_heavier'),
              onPressed: _busy || rule == null
                  ? null
                  : () => _repeat(heavier: true),
              child: const Text('Repeat with +2.5 kg on main lifts'),
            ),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            rule ?? 'Needs a logged weight on a main lift.',
            style: B05Typography.caption(context),
          ),
          const SizedBox(height: B05Layout.space8),
          TextButton(
            key: const ValueKey('plan_finished_pick_next'),
            onPressed: _busy ? null : _pickNext,
            child: const Text('Pick the next plan'),
          ),
        ],
      ),
    );
  }
}
