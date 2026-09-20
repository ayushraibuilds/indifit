import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/models/plan_analytics_models.dart';
import '../../data/repositories/b02_execution_compatibility_read_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/offline_starter_plan_catalog.dart';
import '../../data/repositories/plan_library_read_repository.dart';
import '../../data/repositories/plan_overview_read_repository.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/workout_repository.dart';
import '../calendar/calendar_controller.dart';
import '../settings/unit_preference.dart';
import 'training_workout_customization.dart';
import 'training_workout_preview.dart';

/// Consumer destination for choosing among the canonical saved training plans.
/// Training Home owns the entry point; this screen owns the library itself.
class PlanLibraryScreen extends ConsumerStatefulWidget {
  const PlanLibraryScreen({super.key});

  @override
  ConsumerState<PlanLibraryScreen> createState() => _PlanLibraryScreenState();
}

class _PlanLibraryScreenState extends ConsumerState<PlanLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  StarterPlanEnvironment? _environment;
  int? _dayFilter;
  StarterPlanExperience? _experience;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(planLibrarySnapshotProvider);
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan Library')),
      body: plans.when(
        loading: () => const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(B05Layout.space16),
            child: SkeletonList(count: 4),
          ),
        ),
        error: (error, _) => _PlanLibraryError(
          onRetry: () => ref.invalidate(planLibrarySnapshotProvider),
        ),
        data: (snapshot) => _buildContent(context, snapshot, profile),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PlanLibrarySnapshot snapshot,
    UserProfileState profile,
  ) {
    final visibleEntries = snapshot.entries
        .where(
          (entry) => _matchesQuery(entry, _query) && _matchesFilters(entry),
        )
        .toList(growable: false);
    final activeEntries = visibleEntries
        .where((entry) => entry.isActive)
        .toList(growable: false);
    final active = activeEntries.isEmpty ? null : activeEntries.first;
    final recommendation = _showsRecommendation
        ? _recommendedEntry(snapshot, profile)
        : null;
    final available = visibleEntries
        .where(
          (entry) =>
              !entry.isActive && entry.version.id != recommendation?.version.id,
        )
        .toList(growable: false);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, _) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space16,
            B05Layout.space16,
            B05Layout.space16,
            B05Layout.space32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LibraryIntro(hasPlans: snapshot.entries.isNotEmpty),
                  if (snapshot.entries.length > 1) ...[
                    const SizedBox(height: B05Layout.space16),
                    _PlanSearchField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                    const SizedBox(height: B05Layout.space16),
                    _PlanLibraryFilters(
                      environment: _environment,
                      dayFilter: _dayFilter,
                      experience: _experience,
                      onEnvironmentChanged: (value) =>
                          setState(() => _environment = value),
                      onDayChanged: (value) =>
                          setState(() => _dayFilter = value),
                      onExperienceChanged: (value) =>
                          setState(() => _experience = value),
                    ),
                  ],
                  const SizedBox(height: B05Layout.space24),
                  if (visibleEntries.isEmpty && snapshot.entries.isNotEmpty)
                    _NoMatchingPlans(
                      query: _query,
                      onClear: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _environment = null;
                          _dayFilter = null;
                          _experience = null;
                        });
                      },
                    )
                  else ...[
                    if (active != null) ...[
                      _SectionHeading(
                        title: 'Current plan',
                        detail: 'This is the plan Training uses now.',
                      ),
                      const SizedBox(height: B05Layout.space8),
                      PlanLibraryCard(
                        entry: active,
                        onTap: () => _openPlan(context, active),
                      ),
                      if (recommendation != null || available.isNotEmpty)
                        const SizedBox(height: B05Layout.space24),
                    ],
                    if (recommendation != null) ...[
                      _SectionHeading(
                        title: 'Recommended for you',
                        detail:
                            'Based on the equipment saved in your profile. You can choose any plan.',
                      ),
                      const SizedBox(height: B05Layout.space8),
                      PlanLibraryCard(
                        entry: recommendation,
                        onTap: () => _openPlan(context, recommendation),
                      ),
                      if (available.isNotEmpty)
                        const SizedBox(height: B05Layout.space24),
                    ],
                    if (available.isNotEmpty) ...[
                      _SectionHeading(
                        title: 'Browse plans',
                        detail: active == null
                            ? 'Open a plan to see its schedule before using it.'
                            : 'Your completed history stays saved when you switch.',
                      ),
                      const SizedBox(height: B05Layout.space8),
                      ...available.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: B05Layout.space8,
                          ),
                          child: PlanLibraryCard(
                            entry: entry,
                            onTap: () => _openPlan(context, entry),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (snapshot.entries.isEmpty) ...[
                    _EmptyPlanLibrary(
                      onBuildPlan: () => context.push('/program-author'),
                    ),
                  ] else ...[
                    const SizedBox(height: B05Layout.space24),
                    _BuildPlanPrompt(
                      onBuildPlan: () => context.push('/program-author'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPlan(BuildContext context, PlanLibraryEntry entry) {
    context.push('/plan-overview/${entry.version.id}');
  }

  bool get _showsRecommendation =>
      _query.trim().isEmpty &&
      _environment == null &&
      _dayFilter == null &&
      _experience == null;

  bool _matchesFilters(PlanLibraryEntry entry) {
    final starter = entry.starterPlan;
    if (_environment != null && starter?.environment != _environment) {
      return false;
    }
    if (_experience != null && starter?.experience != _experience) {
      return false;
    }
    final days = starter?.daysPerWeek ?? entry.metadata.trainingDaysPerWeek;
    if (_dayFilter == 5) {
      return days != null && days >= 5;
    }
    if (_dayFilter != null && days != _dayFilter) return false;
    return true;
  }

  PlanLibraryEntry? _recommendedEntry(
    PlanLibrarySnapshot snapshot,
    UserProfileState profile,
  ) {
    if (!profile.isLoaded || !profile.hasProfile) return null;
    final targetId = switch (profile.equipmentAccess.trim().toLowerCase()) {
      'dumbbells' => 'dumbbell-full-body-3-day',
      'bodyweight' => 'bodyweight-basics-3-day',
      'full_gym' || 'gym' => 'beginner-full-body-3-day',
      _ => null,
    };
    if (targetId == null) return null;
    for (final entry in snapshot.entries) {
      if (!entry.isActive && entry.starterPlan?.id == targetId) return entry;
    }
    return null;
  }
}

/// Read-only orientation for one exact canonical program version.
class PlanOverviewScreen extends ConsumerStatefulWidget {
  const PlanOverviewScreen({this.programId, this.versionId, super.key})
    : assert(programId != null || versionId != null);

  /// [programId] is retained only for the pre-C.9 compatibility route and
  /// existing callers. New navigation must carry [versionId].
  final String? programId;
  final String? versionId;

  @override
  ConsumerState<PlanOverviewScreen> createState() => _PlanOverviewScreenState();
}

/// Compatibility surface for C.3 callers that still identify a library entry
/// by program. It renders the same overview body while the route migrates to
/// exact version identity.
class PlanLibraryDetailScreen extends PlanOverviewScreen {
  const PlanLibraryDetailScreen({required String programId, super.key})
    : super(programId: programId);
}

class _PlanOverviewScreenState extends ConsumerState<PlanOverviewScreen> {
  final Uuid _uuid = const Uuid();
  var _isActivating = false;
  String? _activationError;
  String? _activationCommandId;
  String? _workingVersionId;

  @override
  Widget build(BuildContext context) {
    if (widget.versionId case final versionId?) {
      final overview = ref.watch(planOverviewSnapshotProvider(versionId));
      return Scaffold(
        appBar: AppBar(title: const Text('Plan overview')),
        body: overview.when(
          loading: () => _planLoadingBody(),
          error: (_, _) => _PlanLibraryError(
            onRetry: () =>
                ref.invalidate(planOverviewSnapshotProvider(versionId)),
          ),
          data: (value) {
            if (value == null) return const _PlanDetailsUnavailable();
            return _buildEntryBody(context, value.entry, overview: value);
          },
        ),
      );
    }

    final snapshot = ref.watch(planLibrarySnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan details')),
      body: snapshot.when(
        loading: _planLoadingBody,
        error: (error, _) => _PlanLibraryError(
          onRetry: () => ref.invalidate(planLibrarySnapshotProvider),
        ),
        data: (library) {
          final entry = library.entryForProgram(widget.programId!);
          if (entry == null) {
            return const _PlanDetailsUnavailable();
          }
          return _buildEntryBody(context, entry);
        },
      ),
    );
  }

  Widget _planLoadingBody() => const SafeArea(
    child: Padding(
      padding: EdgeInsets.all(B05Layout.space16),
      child: SkeletonList(count: 3),
    ),
  );

  Widget _buildEntryBody(
    BuildContext context,
    PlanLibraryEntry entry, {
    PlanOverviewSnapshot? overview,
  }) {
    return _PlanDetailsBody(
      entry: entry,
      overview: overview,
      isActivating: _isActivating,
      activationError: _activationError,
      onUsePlan: entry.isReadyToUse && !entry.isActive
          ? () => _activatePlan(entry)
          : null,
      onEditPlan: () => context.push(
        Uri(
          path: '/program-author',
          queryParameters: {'versionId': entry.version.id},
        ).toString(),
      ),
      onContinueSetup: entry.isDraft
          ? () => context.push(
              Uri(
                path: '/program-author',
                queryParameters: {'versionId': entry.version.id},
              ).toString(),
            )
          : null,
    );
  }

  Future<void> _activatePlan(PlanLibraryEntry entry) async {
    if (_isActivating || entry.isActive || !entry.isReadyToUse) {
      return;
    }
    setState(() {
      _isActivating = true;
      _activationError = null;
    });

    try {
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final dates = ref.read(localScheduleDateServiceProvider);
      final localDate = dates.todayIn(timezoneId);
      final activeDraft = await ref
          .read(workoutRepositoryProvider)
          .getActiveDraft();
      if (activeDraft != null) {
        throw const ActivationRejectedException(
          'Resolve the existing workout draft before activating a program.',
        );
      }
      final current = await ref
          .read(calendarReadRepositoryProvider)
          .readSnapshot(
            startLocalDate: localDate,
            endLocalDate: localDate,
            timezoneId: timezoneId,
          );
      if (!mounted) return;
      if (current.activeProgramVersionId != null &&
          current.activeProgramVersionId != entry.version.id) {
        final shouldSwitch = await _confirmSwitch(
          context,
          current.activeProgramName ?? 'your current plan',
          entry.program.name,
        );
        if (!shouldSwitch || !mounted) {
          setState(() => _isActivating = false);
          return;
        }
      }

      _activationCommandId ??= 'plan-library::${_uuid.v4()}';
      var versionId = _workingVersionId ?? entry.version.id;
      if (_workingVersionId == null && entry.version.status == 'published') {
        versionId = await ref
            .read(programRepositoryProvider)
            .copyToNewDraftVersion(entry.version.id);
        _workingVersionId = versionId;
      }
      await ref
          .read(programActivationCoordinatorProvider)
          .activate(
            ActivateProgramVersionCommand(
              programVersionId: versionId,
              commandId: _activationCommandId!,
              activationLocalDate: localDate,
              timezoneId: timezoneId,
            ),
          );
      if (!mounted) return;
      ref.invalidate(planLibrarySnapshotProvider);
      setState(() {
        _isActivating = false;
        _activationError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is now your current plan.')),
      );
    } catch (error) {
      if (!mounted) return;
      final failure = ProductFailurePresentation.fromError(
        error,
        title: 'Plan not changed',
      );
      setState(() {
        _isActivating = false;
        _activationError = failure.message;
      });
    }
  }

  Future<bool> _confirmSwitch(
    BuildContext context,
    String currentPlanName,
    String nextPlanName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch current plan?'),
        content: Text(
          'Switch from $currentPlanName to $nextPlanName? Completed history stays saved, and existing scheduled workouts remain in place unless you change them separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep current plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Switch plan'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class PlanLibraryCard extends StatelessWidget {
  const PlanLibraryCard({required this.entry, required this.onTap, super.key});

  final PlanLibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = _planDescription(entry);
    final status = entry.isActive
        ? 'Current plan'
        : entry.isDraft
        ? 'Continue setup'
        : entry.isBundled
        ? 'Starter plan'
        : 'Available';
    final semanticLabel = [
      entry.program.name,
      status,
      entry.metadata.durationLabel,
      entry.metadata.scheduleLabel,
      description ?? '',
    ].where((part) => part.isNotEmpty).join('. ');

    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      hint: 'Open plan details.',
      onTap: onTap,
      child: B05Surface(
        tone: entry.isActive
            ? B05SurfaceTone.selected
            : B05SurfaceTone.interactive,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: B05Radii.mediumRadius,
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: B05Layout.space8,
                        runSpacing: B05Layout.space4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            entry.program.name,
                            style: B05Typography.title(context),
                          ),
                          _PlanStatusChip(label: status),
                        ],
                      ),
                      if (description != null) ...[
                        const SizedBox(height: B05Layout.space8),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: B05Typography.body(context),
                        ),
                      ],
                      const SizedBox(height: B05Layout.space12),
                      _PlanMetadataLine(entry: entry),
                    ],
                  ),
                ),
                const SizedBox(width: B05Layout.space8),
                Padding(
                  padding: const EdgeInsets.only(top: B05Layout.space4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: context.b05Colors.textSecondary,
                    semanticLabel: 'Open plan details',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanDetailsBody extends StatelessWidget {
  const _PlanDetailsBody({
    required this.entry,
    this.overview,
    required this.isActivating,
    required this.activationError,
    required this.onUsePlan,
    required this.onEditPlan,
    required this.onContinueSetup,
  });

  final PlanLibraryEntry entry;
  final PlanOverviewSnapshot? overview;
  final bool isActivating;
  final String? activationError;
  final VoidCallback? onUsePlan;
  final VoidCallback onEditPlan;
  final VoidCallback? onContinueSetup;

  @override
  Widget build(BuildContext context) {
    final description = _planDescription(entry);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, _) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space16,
            B05Layout.space16,
            B05Layout.space16,
            B05Layout.space32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    header: true,
                    label: entry.program.name,
                    child: Text(
                      entry.program.name,
                      style: B05Typography.pageTitle(context),
                    ),
                  ),
                  const SizedBox(height: B05Layout.space8),
                  if (entry.isActive)
                    const _CurrentPlanBanner()
                  else if (entry.isDraft)
                    const _PlanStatusBanner(
                      icon: Icons.edit_outlined,
                      title: 'This plan is still being set up',
                      message:
                          'Finish the plan before making it your current plan.',
                    ),
                  if (description != null) ...[
                    const SizedBox(height: B05Layout.space16),
                    Text(description, style: B05Typography.body(context)),
                  ],
                  if (_planGoal(entry) != null) ...[
                    const SizedBox(height: B05Layout.space12),
                    _DetailFact(label: 'Focus', value: _planGoal(entry)!),
                  ],
                  const SizedBox(height: B05Layout.space16),
                  _PlanMetadataPanel(entry: entry),
                  const SizedBox(height: B05Layout.space16),
                  if (activationError != null) ...[
                    ConsumerStatusRow(
                      label: 'Plan not changed',
                      detail: activationError,
                      error: true,
                    ),
                    const SizedBox(height: B05Layout.space12),
                  ],
                  if (entry.isActive)
                    const _CurrentPlanAction()
                  else if (onUsePlan != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isActivating ? null : onUsePlan,
                        icon: isActivating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          isActivating ? 'Using this plan…' : 'Use this plan',
                        ),
                      ),
                    )
                  else if (onContinueSetup != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onContinueSetup,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Continue setup'),
                      ),
                    ),
                  if (overview != null && !entry.isDraft) ...[
                    const SizedBox(height: B05Layout.space12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onEditPlan,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          entry.isBundled ? 'Customize a copy' : 'Edit plan',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: B05Layout.space24),
                  if (overview != null) ...[
                    _PlanScheduleAndHistory(overview: overview!),
                    const SizedBox(height: B05Layout.space24),
                  ],
                  _PlanStructure(entry: entry, overview: overview),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanScheduleAndHistory extends ConsumerWidget {
  const _PlanScheduleAndHistory({required this.overview});

  final PlanOverviewSnapshot overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitPreferenceProvider);
    final occurrences = overview.occurrences;
    CalendarOccurrenceReadItem? nextOccurrence;
    if (overview.isCurrent) {
      for (final item in occurrences) {
        if (item.isNextRequired) {
          nextOccurrence = item;
          break;
        }
      }
    }
    final completedCount = occurrences
        .where((item) => item.occurrence.status == 'completed')
        .length;
    final partialCount = occurrences
        .where((item) => item.occurrence.status == 'partiallyCompleted')
        .length;
    final progressMessage = occurrences.isEmpty
        ? 'This plan has no scheduled workouts yet.'
        : '$completedCount completed, $partialCount partially completed of ${occurrences.length} scheduled workouts.${nextOccurrence == null ? '' : ' Next: ${nextOccurrence.template.name} on ${ConsumerDateLabel.day(nextOccurrence.occurrence.effectiveLocalDate)}.'}';
    final historyByOccurrence = {
      for (final item in overview.history)
        if (item.scheduledOccurrenceId != null)
          item.scheduledOccurrenceId!: item,
    };
    final visibleOccurrences = occurrences.take(6).toList(growable: false);
    final visibleHistory = overview.history.take(6).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plan progress', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          tone: B05SurfaceTone.inset,
          child: Semantics(
            container: true,
            label: progressMessage,
            child: Text(progressMessage, style: B05Typography.body(context)),
          ),
        ),
        if (occurrences.isNotEmpty) ...[
          const SizedBox(height: B05Layout.space16),
          _PlanAnalyticsSummaryCards(
            analytics: overview.analytics,
            units: units,
          ),
          if (overview.weekAnalytics.isNotEmpty) ...[
            const SizedBox(height: B05Layout.space20),
            _PlanWeekProgressList(
              weeks: overview.weekAnalytics,
              units: units,
            ),
          ],
          const SizedBox(height: B05Layout.space20),
          Text('Schedule', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space8),
          for (final item in visibleOccurrences) ...[
            _PlanOccurrenceRow(
              item: item,
              history: historyByOccurrence[item.occurrence.id],
            ),
            const SizedBox(height: B05Layout.space8),
          ],
          if (occurrences.length > visibleOccurrences.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/calendar'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('View full calendar'),
              ),
            ),
        ],
        const SizedBox(height: B05Layout.space20),
        Text('Workouts from this plan', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space8),
        if (visibleHistory.isEmpty)
          const _PlanOverviewEmpty(
            message: 'No saved workouts from this plan yet.',
          )
        else ...[
          for (final item in visibleHistory) ...[
            _PlanHistoryRow(item: item),
            const SizedBox(height: B05Layout.space8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/workout-history'),
              icon: const Icon(Icons.history_rounded),
              label: const Text('View all training history'),
            ),
          ),
        ],
        if (overview.concurrentIndependentHistory.isNotEmpty) ...[
          const SizedBox(height: B05Layout.space20),
          Text(
            'Independent workouts during this plan',
            style: B05Typography.title(context),
          ),
          const SizedBox(height: B05Layout.space8),
          B05Surface(
            tone: B05SurfaceTone.inset,
            child: Text(
              'These ${overview.totalIndependentCount > 100 ? 'latest 100 of ${overview.totalIndependentCount}' : '${overview.totalIndependentCount}'} workouts were logged outside this plan. They are preserved for durable history and are never counted toward plan adherence.',
              style: B05Typography.caption(context),
            ),
          ),
          const SizedBox(height: B05Layout.space8),
          for (final item in overview.concurrentIndependentHistory.take(6)) ...[
            _PlanHistoryRow(item: item),
            const SizedBox(height: B05Layout.space8),
          ],
        ],
      ],
    );
  }
}

class _PlanAnalyticsSummaryCards extends StatelessWidget {
  const _PlanAnalyticsSummaryCards({
    required this.analytics,
    required this.units,
  });

  final PlanAnalyticsSummary analytics;
  final String units;

  @override
  Widget build(BuildContext context) {
    final adherenceLabel = analytics.strictAdherenceRate != null
        ? '${(analytics.strictAdherenceRate! * 100).round()}%'
        : '—';
    final compositeLabel = analytics.partiallyCompletedCount > 0 &&
            analytics.compositeAdherenceRate != null
        ? '${(analytics.compositeAdherenceRate! * 100).round()}% composite (partials count half)'
        : (analytics.elapsedEligibleCount > 0
            ? '${analytics.completedCount} of ${analytics.elapsedEligibleCount} elapsed'
            : 'No elapsed sessions');

    final weightSymbol = UnitPreferencePresentation.weightSymbol(units);
    final volumeLabel = analytics.hasStrengthSessions
        ? '${UnitPreferencePresentation.weightForDisplay(analytics.totalVolumeKg, units).round()} $weightSymbol'
        : '—';
    final volumeSubtitle = analytics.hasStrengthSessions
        ? 'Total weight lifted'
        : 'Cardio / mobility (no load)';

    final durationLabel = _formatDuration(analytics.totalDurationSeconds);
    final durationSubtitle =
        '${analytics.completedCount + analytics.partiallyCompletedCount} completed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Adherence',
                value: adherenceLabel,
                subtitle: compositeLabel,
              ),
            ),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: _MetricCard(
                title: 'Volume',
                value: volumeLabel,
                subtitle: volumeSubtitle,
              ),
            ),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: _MetricCard(
                title: 'Time',
                value: durationLabel,
                subtitle: durationSubtitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: B05Layout.space12),
        Wrap(
          spacing: B05Layout.space8,
          runSpacing: B05Layout.space4,
          children: [
            _PlanStatusChip(label: '${analytics.completedCount} completed'),
            if (analytics.partiallyCompletedCount > 0)
              _PlanStatusChip(
                label:
                    '${analytics.partiallyCompletedCount} partially completed',
              ),
            if (analytics.skippedCount > 0)
              _PlanStatusChip(
                label:
                    '${analytics.skippedCount} skipped (${analytics.skippedAdvanceCount} advance, ${analytics.skippedKeepPendingCount} keep pending)',
              ),
            if (analytics.rescheduledCount > 0)
              _PlanStatusChip(
                label: '${analytics.rescheduledCount} rescheduled',
              ),
            if (analytics.cancelledCount > 0)
              _PlanStatusChip(
                label:
                    '${analytics.cancelledCount} cancelled (excluded from adherence)',
              ),
            if (analytics.inProgressCount > 0)
              _PlanStatusChip(
                label: '${analytics.inProgressCount} in progress',
              ),
            if (analytics.overdueCount > 0)
              _PlanStatusChip(
                label: '${analytics.overdueCount} overdue',
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.all(B05Layout.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: B05Typography.caption(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            value,
            style: B05Typography.title(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            subtitle,
            style: B05Typography.caption(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PlanWeekProgressList extends StatelessWidget {
  const _PlanWeekProgressList({
    required this.weeks,
    required this.units,
  });

  final List<PlanWeekAnalytics> weeks;
  final String units;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phase & week progress', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space8),
        for (final week in weeks) ...[
          _PlanWeekCard(week: week, units: units),
          const SizedBox(height: B05Layout.space8),
        ],
      ],
    );
  }
}

class _PlanWeekCard extends StatelessWidget {
  const _PlanWeekCard({
    required this.week,
    required this.units,
  });

  final PlanWeekAnalytics week;
  final String units;

  @override
  Widget build(BuildContext context) {
    final title = week.weekName?.trim().isNotEmpty == true
        ? week.weekName!.trim()
        : 'Week ${week.displayWeekNumber}';
    final weightSymbol = UnitPreferencePresentation.weightSymbol(units);
    final volumeText = week.hasStrengthSessions
        ? '${UnitPreferencePresentation.weightForDisplay(week.totalVolumeKg, units).round()} $weightSymbol'
        : '— (Cardio/mobility)';
    final durationText = _formatDuration(week.totalDurationSeconds);

    final statusSummary = [
      '${week.completedSessions} of ${week.plannedSessions} completed',
      if (week.partiallyCompletedSessions > 0)
        '${week.partiallyCompletedSessions} partial',
      if (week.skippedSessions > 0) '${week.skippedSessions} skipped',
      if (week.cancelledSessions > 0) '${week.cancelledSessions} cancelled',
      if (week.overdueSessions > 0) '${week.overdueSessions} overdue',
    ].join(' · ');

    final comp = week.comparisonWithPrevious;

    return B05Surface(
      tone: B05SurfaceTone.interactive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: B05Typography.label(context)),
              ),
              if (week.isDeload) ...[
                const SizedBox(width: B05Layout.space8),
                const _PlanStatusChip(label: 'Deload'),
              ],
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          Text(statusSummary, style: B05Typography.caption(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            '$volumeText · $durationText',
            style: B05Typography.body(context),
          ),
          if (comp != null && week.isElapsed) ...[
            const SizedBox(height: B05Layout.space4),
            Text(
              _comparisonText(comp, weightSymbol),
              style: B05Typography.caption(context),
            ),
          ],
        ],
      ),
    );
  }

  String _comparisonText(PlanWeekComparison comp, String weightSymbol) {
    final parts = <String>[];
    if (comp.isCardioOrMobilityComparison) {
      parts.add('Cardio/mobility week');
    } else if (comp.volumeDeltaKg != null) {
      final sign = comp.volumeDeltaKg! >= 0 ? '+' : '';
      final dispVol = UnitPreferencePresentation.weightForDisplay(
        comp.volumeDeltaKg!,
        units,
      ).round();
      final pct = comp.volumeDeltaPercentage != null
          ? ' ($sign${comp.volumeDeltaPercentage!.toStringAsFixed(1)}%)'
          : '';
      parts.add('$sign$dispVol $weightSymbol$pct volume');
    }

    final durDelta = _formatDeltaDuration(comp.durationDeltaSeconds);
    final durSign = comp.durationDeltaSeconds >= 0 ? '+' : '';
    final durPct = comp.durationDeltaPercentage != null
        ? ' ($durSign${comp.durationDeltaPercentage!.toStringAsFixed(1)}%)'
        : '';
    parts.add('$durDelta$durPct time');

    if (comp.isDeloadComparison) {
      parts.add('Deload context');
    }

    return 'vs previous week: ${parts.join(' · ')}';
  }
}

class _PlanOccurrenceRow extends StatelessWidget {
  const _PlanOccurrenceRow({required this.item, this.history});

  final CalendarOccurrenceReadItem item;
  final B02ActivityHistoryItem? history;

  @override
  Widget build(BuildContext context) {
    final occurrence = item.occurrence;
    final status = _occurrenceStatusLabel(occurrence.status);
    final date = ConsumerDateLabel.day(occurrence.effectiveLocalDate);
    final isRescheduled =
        occurrence.effectiveLocalDate != occurrence.originalLocalDate ||
        occurrence.status == 'rescheduled';

    final detailsParts = <String>[
      date,
      item.week.name?.trim().isNotEmpty == true
          ? item.week.name!.trim()
          : 'Week ${item.week.programWeekOrdinal + 1}',
      status,
      if (isRescheduled)
        'Rescheduled from ${ConsumerDateLabel.day(occurrence.originalLocalDate)}',
      if (occurrence.status == 'skipped' && occurrence.skipMode != null)
        occurrence.skipMode == 'advance' ? 'Advance' : 'Keep pending',
    ];

    return B05Surface(
      tone: B05SurfaceTone.interactive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: '${item.template.name}, $date, $status',
            child: Text(
              item.template.name,
              style: B05Typography.label(context),
            ),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            detailsParts.join(' · '),
            style: B05Typography.caption(context),
          ),
          if (history != null) ...[
            const SizedBox(height: B05Layout.space4),
            Text(
              history!.isPartial
                  ? 'Saved as partially completed'
                  : 'Saved to history',
              style: B05Typography.caption(context),
            ),
          ],
          const SizedBox(height: B05Layout.space4),
          Wrap(
            spacing: B05Layout.space8,
            children: [
              TextButton(
                onPressed: () => context.push(
                  Uri(
                    path: '/calendar',
                    queryParameters: {'date': occurrence.effectiveLocalDate},
                  ).toString(),
                ),
                child: const Text('Open in calendar'),
              ),
              if (history != null)
                TextButton(
                  onPressed: () => context.push(_historyDetailRoute(history!)),
                  child: const Text('View details'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int seconds) {
  if (seconds <= 0) return '0 min';
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours > 0) {
    return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
  }
  return '$minutes min';
}

String _formatDeltaDuration(int seconds) {
  final sign = seconds >= 0 ? '+' : '-';
  final absSec = seconds.abs();
  final minutes = absSec ~/ 60;
  return '$sign$minutes min';
}

class _PlanHistoryRow extends StatelessWidget {
  const _PlanHistoryRow({required this.item});

  final B02ActivityHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final status = item.isPartial ? 'Partially completed' : 'Completed';
    return Semantics(
      button: true,
      label:
          '${item.name}, ${ConsumerDateLabel.dateTime(item.completedAt)}, $status',
      child: B05Surface(
        tone: B05SurfaceTone.interactive,
        child: InkWell(
          onTap: () => context.push(_historyDetailRoute(item)),
          borderRadius: B05Radii.mediumRadius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, color: context.b05Colors.action),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: B05Typography.label(context)),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      '${ConsumerDateLabel.dateTime(item.completedAt)} · $status',
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanOverviewEmpty extends StatelessWidget {
  const _PlanOverviewEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    child: Text(message, style: B05Typography.body(context)),
  );
}

String _occurrenceStatusLabel(String status) => switch (status) {
  'planned' || 'rescheduled' => 'Scheduled',
  'completed' => 'Completed',
  'partiallyCompleted' => 'Partially completed',
  'skipped' => 'Skipped',
  'cancelled' => 'Cancelled',
  'inProgress' => 'In progress',
  _ => 'Unavailable',
};

String _historyDetailRoute(B02ActivityHistoryItem item) =>
    item.activityType == B02ActivityType.strength
    ? '/workout-history/${item.sessionId}'
    : '/activity-history/${item.sessionId}';

class _PlanStructure extends StatelessWidget {
  const _PlanStructure({required this.entry, this.overview});

  final PlanLibraryEntry entry;
  final PlanOverviewSnapshot? overview;

  @override
  Widget build(BuildContext context) {
    if (entry.detail.blocks.isEmpty) {
      return const ConsumerStatusRow(
        label: 'Plan details are not ready yet',
        detail: 'Finish setting up this plan to see its schedule.',
      );
    }

    final weeksByBlock = <String, List<ProgramWeek>>{};
    for (final week in entry.detail.weeks) {
      weeksByBlock.putIfAbsent(week.programBlockId, () => []).add(week);
    }
    final templatesByWeek = <String, List<SessionTemplate>>{};
    for (final template in entry.detail.sessionTemplates) {
      templatesByWeek
          .putIfAbsent(template.programWeekId, () => [])
          .add(template);
    }
    final prescriptionsByTemplate = <String, List<ExercisePrescription>>{};
    for (final prescription in entry.detail.exercisePrescriptions) {
      prescriptionsByTemplate
          .putIfAbsent(prescription.sessionTemplateId, () => [])
          .add(prescription);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plan structure', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space8),
        ...entry.detail.blocks.map(
          (block) => B05Surface(
            tone: B05SurfaceTone.inset,
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: B05Layout.space16,
              ),
              title: Text(block.name),
              subtitle: Text(
                '${(weeksByBlock[block.id] ?? const <ProgramWeek>[]).length} ${_pluralize('week', (weeksByBlock[block.id] ?? const <ProgramWeek>[]).length)}',
              ),
              children: [
                ...(weeksByBlock[block.id] ?? const <ProgramWeek>[]).map(
                  (week) => _PlanWeekSummary(
                    week: week,
                    templates: templatesByWeek[week.id] ?? const [],
                    prescriptionsByTemplate: prescriptionsByTemplate,
                    entry: entry,
                    overview: overview,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanWeekSummary extends StatelessWidget {
  const _PlanWeekSummary({
    required this.week,
    required this.templates,
    required this.prescriptionsByTemplate,
    this.entry,
    this.overview,
  });

  final ProgramWeek week;
  final List<SessionTemplate> templates;
  final Map<String, List<ExercisePrescription>> prescriptionsByTemplate;
  final PlanLibraryEntry? entry;
  final PlanOverviewSnapshot? overview;

  @override
  Widget build(BuildContext context) {
    final weekLabel = week.name?.trim().isNotEmpty == true
        ? week.name!.trim()
        : 'Week ${week.programWeekOrdinal + 1}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        0,
        B05Layout.space16,
        B05Layout.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(weekLabel, style: B05Typography.label(context)),
              ),
              if (week.isDeload) const _PlanStatusChip(label: 'Lighter week'),
            ],
          ),
          const SizedBox(height: B05Layout.space8),
          ...templates.map(
            (template) => Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space8),
              child: _SessionSummary(
                template: template,
                prescriptions: prescriptionsByTemplate[template.id] ?? const [],
                entry: entry,
                overview: overview,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSummary extends ConsumerWidget {
  const _SessionSummary({
    required this.template,
    required this.prescriptions,
    this.entry,
    this.overview,
  });

  final SessionTemplate template;
  final List<ExercisePrescription> prescriptions;
  final PlanLibraryEntry? entry;
  final PlanOverviewSnapshot? overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingOccurrences = overview != null && entry?.isActive == true
        ? (overview!.occurrences
            .where((item) =>
                item.occurrence.sessionTemplateId == template.id &&
                (item.occurrence.status == OccurrenceStatus.planned.dbValue ||
                    item.occurrence.status == OccurrenceStatus.rescheduled.dbValue))
            .toList()
          ..sort((a, b) =>
              a.occurrence.effectiveLocalDate.compareTo(b.occurrence.effectiveLocalDate)))
        : <CalendarOccurrenceReadItem>[];

    return Semantics(
      container: true,
      label: [
        template.name,
        '${prescriptions.length} ${_pluralize('exercise', prescriptions.length)}',
        for (final prescription in prescriptions)
          '${prescription.exerciseNameSnapshot}, ${prescription.plannedSets} ${_pluralize('set', prescription.plannedSets)}, ${prescription.repsRange} reps',
      ].join('. '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.name, style: B05Typography.label(context)),
          if (prescriptions.isEmpty)
            Text(
              'No exercises added yet.',
              style: B05Typography.caption(context),
            )
          else
            ...prescriptions.map(
              (prescription) => Padding(
                padding: const EdgeInsets.only(top: B05Layout.space4),
                child: Text(
                  '${prescription.exerciseNameSnapshot} · ${prescription.plannedSets} ${_pluralize('set', prescription.plannedSets)} · ${prescription.repsRange} reps',
                  style: B05Typography.caption(context),
                ),
              ),
            ),
          if (entry?.isActive == true && overview != null) ...[
            if (upcomingOccurrences.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: B05Layout.space8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(
                      'Customize upcoming workouts (${upcomingOccurrences.length})',
                    ),
                    onPressed: () => _openCustomizationFromOverview(
                      context,
                      ref,
                      entry!,
                      upcomingOccurrences.first,
                      upcomingOccurrences.length,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: B05Layout.space8),
                child: Text(
                  'All workouts completed for this session',
                  style: B05Typography.caption(context).copyWith(
                    color: context.b05Colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCustomizationFromOverview(
    BuildContext context,
    WidgetRef ref,
    PlanLibraryEntry entry,
    CalendarOccurrenceReadItem readItem,
    int futureCount,
  ) async {
    try {
      final calendarRepo = ref.read(calendarRepositoryProvider);
      final snapshot = await calendarRepo.readWorkoutPreviewSnapshot(
        readItem.occurrence.id,
      );
      final preview = TrainingWorkoutPreviewData.fromOccurrence(
        readItem,
        snapshotJson: snapshot,
      );

      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainingWorkoutCustomizationScreen(
            preview: preview,
            futureOccurrencesCount: futureCount,
            initialScope: WorkoutCustomizationScope.allFuture,
            onSave: ({
              required baseSnapshotJson,
              required changes,
              required scope,
            }) async {
              if (scope == WorkoutCustomizationScope.allFuture) {
                await ref
                    .read(calendarControllerProvider.notifier)
                    .customizeFutureOccurrences(
                      readItem.occurrence.id,
                      baseSnapshotJson: baseSnapshotJson,
                      changes: changes,
                    );
              } else {
                await ref
                    .read(calendarControllerProvider.notifier)
                    .customizeOccurrence(
                      readItem.occurrence.id,
                      baseSnapshotJson: baseSnapshotJson,
                      changes: changes,
                    );
              }
            },
            onReset: ({required allFuture}) async {
              await ref
                  .read(calendarControllerProvider.notifier)
                  .resetOccurrenceCustomization(
                    readItem.occurrence.id,
                    allFuture: allFuture,
                  );
            },
          ),
        ),
      );
      if (context.mounted) {
        ref.invalidate(planOverviewSnapshotProvider(entry.version.id));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open customization: $error')),
        );
      }
    }
  }
}

class _PlanMetadataLine extends StatelessWidget {
  const _PlanMetadataLine({required this.entry});

  final PlanLibraryEntry entry;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: B05Layout.space12,
    runSpacing: B05Layout.space4,
    children: [
      _InlineFact(
        icon: Icons.calendar_view_week_outlined,
        label: entry.metadata.durationLabel,
      ),
      _InlineFact(
        icon: Icons.event_available_outlined,
        label: entry.metadata.scheduleLabel,
      ),
      if (entry.starterPlan case final starter?)
        _InlineFact(
          icon: starter.environment == StarterPlanEnvironment.gym
              ? Icons.fitness_center_outlined
              : Icons.home_outlined,
          label: starter.environment.label,
        ),
      _InlineFact(
        icon: Icons.fitness_center_outlined,
        label:
            '${entry.metadata.exerciseCount} ${_pluralize('exercise', entry.metadata.exerciseCount)}',
      ),
    ],
  );
}

class _PlanMetadataPanel extends StatelessWidget {
  const _PlanMetadataPanel({required this.entry});

  final PlanLibraryEntry entry;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('At a glance', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space12),
        Wrap(
          spacing: B05Layout.space24,
          runSpacing: B05Layout.space12,
          children: [
            _DetailFact(label: 'Length', value: entry.metadata.durationLabel),
            _DetailFact(label: 'Schedule', value: entry.metadata.scheduleLabel),
            _DetailFact(
              label: 'Exercises',
              value:
                  '${entry.metadata.exerciseCount} ${_pluralize('exercise', entry.metadata.exerciseCount)}',
            ),
            if (entry.starterPlan case final starter?) ...[
              _DetailFact(label: 'Setting', value: starter.environment.label),
              _DetailFact(label: 'Level', value: starter.experience.label),
              _DetailFact(label: 'Equipment', value: starter.equipment),
            ],
          ],
        ),
      ],
    ),
  );
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label: $value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: B05Typography.caption(context)),
        const SizedBox(height: B05Layout.space4),
        Text(value, style: B05Typography.label(context)),
      ],
    ),
  );
}

class _InlineFact extends StatelessWidget {
  const _InlineFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: B05Layout.iconSmall, color: context.b05Colors.action),
      const SizedBox(width: B05Layout.space4),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: B05Typography.caption(context),
        ),
      ),
    ],
  );
}

class _PlanStatusChip extends StatelessWidget {
  const _PlanStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    labelStyle: B05Typography.caption(context).copyWith(
      color: context.b05Colors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner();

  @override
  Widget build(BuildContext context) => const _PlanStatusBanner(
    icon: Icons.check_circle_outline_rounded,
    title: 'Current plan',
    message: 'Training uses this plan for your scheduled workouts.',
  );
}

class _CurrentPlanAction extends StatelessWidget {
  const _CurrentPlanAction();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Current plan. No change needed.',
    child: B05Surface(
      tone: B05SurfaceTone.selected,
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space16,
        vertical: B05Layout.space12,
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: context.b05Colors.action),
          const SizedBox(width: B05Layout.space8),
          Expanded(
            child: Text(
              'This is your current plan',
              style: B05Typography.label(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlanStatusBanner extends StatelessWidget {
  const _PlanStatusBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title. $message',
    child: B05Surface(
      tone: B05SurfaceTone.selected,
      padding: const EdgeInsets.all(B05Layout.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.b05Colors.action),
          const SizedBox(width: B05Layout.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: B05Typography.label(context)),
                const SizedBox(height: B05Layout.space4),
                Text(message, style: B05Typography.body(context)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LibraryIntro extends StatelessWidget {
  const _LibraryIntro({required this.hasPlans});

  final bool hasPlans;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Choose your training plan',
        style: B05Typography.pageTitle(context),
      ),
      const SizedBox(height: B05Layout.space8),
      Text(
        hasPlans
            ? 'Open a plan to understand its schedule, then choose it when you’re ready.'
            : 'Choose a saved plan or build one around the way you train.',
        style: B05Typography.body(context),
      ),
    ],
  );
}

class _PlanLibraryFilters extends StatelessWidget {
  const _PlanLibraryFilters({
    required this.environment,
    required this.dayFilter,
    required this.experience,
    required this.onEnvironmentChanged,
    required this.onDayChanged,
    required this.onExperienceChanged,
  });

  final StarterPlanEnvironment? environment;
  final int? dayFilter;
  final StarterPlanExperience? experience;
  final ValueChanged<StarterPlanEnvironment?> onEnvironmentChanged;
  final ValueChanged<int?> onDayChanged;
  final ValueChanged<StarterPlanExperience?> onExperienceChanged;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Browse plans', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space8),
        _PlanFilterRow<StarterPlanEnvironment>(
          semanticLabel: 'Training setting filter',
          selected: environment,
          allLabel: 'All equipment',
          values: StarterPlanEnvironment.values,
          labelFor: (value) => value.label,
          onChanged: onEnvironmentChanged,
        ),
        const SizedBox(height: B05Layout.space8),
        _PlanFilterRow<int>(
          semanticLabel: 'Training days filter',
          selected: dayFilter,
          allLabel: 'All days',
          values: const [3, 4, 5],
          labelFor: (value) => value == 5 ? '5+ days' : '$value days',
          onChanged: onDayChanged,
        ),
        const SizedBox(height: B05Layout.space8),
        _PlanFilterRow<StarterPlanExperience>(
          semanticLabel: 'Experience filter',
          selected: experience,
          allLabel: 'All levels',
          values: StarterPlanExperience.values,
          labelFor: (value) => value.label,
          onChanged: onExperienceChanged,
        ),
      ],
    ),
  );
}

class _PlanFilterRow<T> extends StatelessWidget {
  const _PlanFilterRow({
    required this.semanticLabel,
    required this.selected,
    required this.allLabel,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String semanticLabel;
  final T? selected;
  final String allLabel;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: Wrap(
      spacing: B05Layout.space8,
      runSpacing: B05Layout.space4,
      children: [
        ChoiceChip(
          label: Text(allLabel),
          selected: selected == null,
          showCheckmark: false,
          onSelected: (_) => onChanged(null),
        ),
        for (final value in values)
          ChoiceChip(
            label: Text(labelFor(value)),
            selected: selected == value,
            showCheckmark: false,
            onSelected: (_) => onChanged(value),
          ),
      ],
    ),
  );
}

class _BuildPlanPrompt extends StatelessWidget {
  const _BuildPlanPrompt({required this.onBuildPlan});

  final VoidCallback onBuildPlan;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Want something more personal?',
          style: B05Typography.title(context),
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Create your own schedule and exercises.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space8),
        B05ActionButton(
          label: 'Build your own plan',
          icon: Icons.edit_outlined,
          emphasis: B05ActionEmphasis.secondary,
          onPressed: onBuildPlan,
        ),
      ],
    ),
  );
}

class _PlanSearchField extends StatelessWidget {
  const _PlanSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: 'Search plans',
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Search plans',
        hintText: 'Name, focus, or schedule',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear_rounded),
              ),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: B05Typography.title(context)),
      const SizedBox(height: B05Layout.space4),
      Text(detail, style: B05Typography.caption(context)),
    ],
  );
}

class _EmptyPlanLibrary extends StatelessWidget {
  const _EmptyPlanLibrary({required this.onBuildPlan});

  final VoidCallback onBuildPlan;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: B05Layout.space16),
    child: B05Surface(
      tone: B05SurfaceTone.inset,
      child: Column(
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 36,
            color: context.b05Colors.action,
          ),
          const SizedBox(height: B05Layout.space12),
          Text('No saved plans yet', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Build a plan to start scheduling structured workouts.',
            textAlign: TextAlign.center,
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space16),
          B05ActionButton(
            label: 'Build your own plan',
            icon: Icons.edit_outlined,
            onPressed: onBuildPlan,
          ),
        ],
      ),
    ),
  );
}

class _NoMatchingPlans extends StatelessWidget {
  const _NoMatchingPlans({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          query.trim().isEmpty
              ? 'No plans match these filters'
              : 'No plans match “$query”',
          style: B05Typography.title(context),
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Try another search or show all plans.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space8),
        B05ActionButton(
          label: 'Show all plans',
          icon: Icons.clear_rounded,
          emphasis: B05ActionEmphasis.secondary,
          onPressed: onClear,
        ),
      ],
    ),
  );
}

class _PlanLibraryError extends StatelessWidget {
  const _PlanLibraryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: ProductEmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: 'Plans are unavailable',
        message: 'We couldn’t load your plans right now. Try again.',
        action: onRetry,
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
      ),
    ),
  );
}

class _PlanDetailsUnavailable extends StatelessWidget {
  const _PlanDetailsUnavailable();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: ProductEmptyState(
        icon: Icons.route_outlined,
        title: 'Plan unavailable',
        message: 'This plan is no longer available. Return to the library.',
        action: () => Navigator.of(context).maybePop(),
        actionLabel: 'Back to library',
        actionIcon: Icons.arrow_back_rounded,
      ),
    ),
  );
}

String? _planDescription(PlanLibraryEntry entry) {
  final notes = entry.program.notes?.trim();
  if (notes != null && notes.isNotEmpty) return notes;
  return null;
}

String? _planGoal(PlanLibraryEntry entry) {
  final goal = entry.program.goal?.trim();
  if (goal != null && goal.isNotEmpty) return goal;
  return null;
}

bool _matchesQuery(PlanLibraryEntry entry, String rawQuery) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return true;
  final searchable = <String>[
    entry.program.name,
    if (entry.program.goal != null) entry.program.goal!,
    if (entry.program.notes != null) entry.program.notes!,
    if (entry.starterPlan case final starter?) ...[
      starter.environment.label,
      starter.experience.label,
      starter.equipment,
      starter.purpose,
    ],
    ...entry.metadata.blockNames,
    for (final template in entry.detail.sessionTemplates) template.name,
  ].join(' ').toLowerCase();
  return searchable.contains(query);
}

String _pluralize(String noun, int count) => count == 1 ? noun : '${noun}s';
