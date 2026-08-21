import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_count_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/program_repository.dart';
import '../../data/repositories/workout_repository.dart';

/// Screen for reviewing program graph, selecting start local date and timezone, and publishing/activating.
class ProgramReviewScreen extends ConsumerStatefulWidget {
  final String programVersionId;

  const ProgramReviewScreen({super.key, required this.programVersionId});

  @override
  ConsumerState<ProgramReviewScreen> createState() =>
      _ProgramReviewScreenState();
}

class _ProgramReviewScreenState extends ConsumerState<ProgramReviewScreen> {
  static const _timezoneOptions = <String>[
    'Asia/Kolkata',
    'UTC',
    'America/New_York',
    'Europe/London',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  late String _selectedDate;
  late String _selectedTimezone;

  bool _isLoading = true;
  ProgramDetailAggregate? _versionDetail;
  String? _errorMessage;
  String? _activationError;
  String? _activationCommandId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _selectedTimezone = 'Asia/Kolkata';
    _loadVersionDetail();
  }

  Future<void> _loadVersionDetail() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(programRepositoryProvider);
      final detail = await repo.getProgramVersionDetail(
        widget.programVersionId,
      );
      if (detail == null) {
        setState(() => _errorMessage = 'This program is no longer available.');
        return;
      }

      setState(() {
        _versionDetail = detail;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'This program could not be loaded. Try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _activateProgram() async {
    final detail = _versionDetail;
    if (detail == null) return;

    final canSwitch = await _confirmPlanSwitchIfNeeded(detail);
    if (!canSwitch || !mounted) return;

    setState(() {
      _isLoading = true;
      _activationError = null;
    });
    late final ActivationResult result;
    try {
      final coordinator = ref.read(programActivationCoordinatorProvider);
      _activationCommandId ??= 'program-activation::${const Uuid().v4()}';

      result = await coordinator.activate(
        ActivateProgramVersionCommand(
          programVersionId: detail.version.id,
          commandId: _activationCommandId!,
          activationLocalDate: _selectedDate,
          timezoneId: _selectedTimezone,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Program activation failed '
            '[programVersionId=${detail.version.id}, commandId=$_activationCommandId, '
            'errorType=${error.runtimeType}]',
        error,
        stackTrace,
        'ProgramActivation',
      );
      if (mounted) {
        setState(() {
          _activationError = _activationFailureMessage(error);
          _isLoading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.occurrences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Program activated, but no workouts were scheduled. Review the plan before leaving this screen.',
          ),
        ),
      );
      return;
    }
    final firstDate = result.occurrences
        .map((occurrence) => occurrence.effectiveLocalDate)
        .reduce((first, date) => date.compareTo(first) < 0 ? date : first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          '✓ Program activated · ${ConsumerCountLabel.format(result.occurrences.length, 'workout')} scheduled',
        ),
      ),
    );
    context.go(
      Uri(path: '/calendar', queryParameters: {'date': firstDate}).toString(),
    );
  }

  Future<bool> _confirmPlanSwitchIfNeeded(ProgramDetailAggregate detail) async {
    try {
      final workoutRepo = ref.read(workoutRepositoryProvider);
      final activeDraft = await workoutRepo.getActiveDraft();
      if (activeDraft != null) {
        if (!mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Workout in progress'),
            content: Text(
              'You have an active workout in progress (${activeDraft.routineName}). Resolve it before activating a new plan.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }
      final dates = ref.read(localScheduleDateServiceProvider);
      final timezoneId = await ref
          .read(localTimezoneServiceProvider)
          .currentTimezoneId();
      final localDate = dates.todayIn(timezoneId);
      final current = await ref
          .read(calendarReadRepositoryProvider)
          .readSnapshot(
            startLocalDate: localDate,
            endLocalDate: localDate,
            timezoneId: timezoneId,
          );
      final activeId = current.activeProgramVersionId;
      if (activeId == null || activeId == detail.version.id) return true;
      final activeName = current.activeProgramName ?? 'your current plan';
      if (!mounted) return false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Switch training plan?'),
          content: Text(
            'You are using $activeName. Switch to ${detail.program.name}? Completed history stays saved; the new plan becomes the one shown for upcoming workouts.',
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _activationError =
              'The current plan could not be checked. Try again before switching.';
        });
      }
      return false;
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        _activationCommandId = null;
        _activationError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _versionDetail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review & Activate',
          style: TextStyle(fontFamily: 'Outfit'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : detail == null
          ? const SizedBox()
          : SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: AppColors.cardBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.program.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ConsumerCountLabel.format(detail.blocks.length, 'block')} • ${ConsumerCountLabel.format(detail.weeks.length, 'week')}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Activation Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: const Text('Start Local Date'),
                    subtitle: Text(
                      DateFormat(
                        'd MMM y',
                      ).format(DateTime.parse('${_selectedDate}T12:00:00')),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: _selectDate,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTimezone,
                    decoration: const InputDecoration(
                      labelText: 'Program timezone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.public_rounded),
                    ),
                    items: _timezoneOptions
                        .map(
                          (timezone) => DropdownMenuItem(
                            value: timezone,
                            child: Text(timezone),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (timezone) {
                      if (timezone != null) {
                        setState(() {
                          _selectedTimezone = timezone;
                          _activationCommandId = null;
                          _activationError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Existing scheduled workouts from earlier versions stay on their original dates unless you explicitly cancel them.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Program Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...detail.blocks.map((b) {
                    return ExpansionTile(
                      title: Text(
                        b.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: detail.weeks.where((w) => w.programBlockId == b.id).map((
                        w,
                      ) {
                        final weekTemplates = detail.sessionTemplates
                            .where((st) => st.programWeekId == w.id)
                            .toList(growable: false);
                        final weekTemplateIds = weekTemplates
                            .map((template) => template.id)
                            .toSet();
                        final weekGroups = detail.groups
                            .where(
                              (group) => weekTemplateIds.contains(
                                group.sessionTemplateId,
                              ),
                            )
                            .toList(growable: false);
                        return ListTile(
                          title: Text(
                            'Week ${w.programWeekOrdinal + 1}${w.isDeload ? " (Deload)" : ""}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ConsumerCountLabel.format(weekTemplates.length, 'workout')} scheduled',
                              ),
                              ...weekGroups.map((group) {
                                final memberCount = detail.groupMembers
                                    .where(
                                      (member) =>
                                          member.exerciseGroupId == group.id,
                                    )
                                    .length;
                                return Text(
                                  '${group.groupType} • ${group.roundCount} rounds • $memberCount members',
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),
                  const SizedBox(height: 32),
                  if (_activationError != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('Program not activated'),
                        subtitle: Text(_activationError!),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _activateProgram,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: Text(
                        _activationError == null
                            ? 'Publish & Activate Program'
                            : 'Retry activation',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        textStyle: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

String _activationFailureMessage(Object error) {
  return ProductFailurePresentation.fromError(error).message;
}
