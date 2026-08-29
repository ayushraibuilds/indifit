import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../settings_controller.dart';
import 'settings_reminder_toggle.dart';

class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({
    super.key,
    this.permissionStatusLoader,
    this.permissionRequester,
  });

  final Future<NotificationPermissionStatus> Function()? permissionStatusLoader;
  final Future<void> Function()? permissionRequester;

  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  NotificationPermissionStatus? _permissionStatus;
  bool _permissionRequestInProgress = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPermissionStatus());
  }

  Future<void> _loadPermissionStatus({bool clearError = true}) async {
    try {
      final loader =
          widget.permissionStatusLoader ??
          NotificationService.checkPermissionStatus;
      final status = await loader().timeout(
        const Duration(seconds: 1),
        onTimeout: () => NotificationPermissionStatus.unavailable,
      );
      if (!mounted) return;
      setState(() {
        _permissionStatus = status;
        if (clearError) {
          _permissionError = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _permissionStatus = NotificationPermissionStatus.unavailable;
        if (clearError || _permissionError == null) {
          _permissionError = 'Notification access could not be checked.';
        }
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_permissionRequestInProgress) return;
    setState(() {
      _permissionRequestInProgress = true;
      _permissionError = null;
    });

    try {
      final requester =
          widget.permissionRequester ?? NotificationService.requestPermissions;
      await requester();
    } catch (_) {
      if (mounted) {
        setState(() {
          _permissionError =
              'Notification access could not be requested. Try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _permissionRequestInProgress = false);
      }
      await _loadPermissionStatus(clearError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final colors = context.b05Colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(B05Layout.space8),
              decoration: BoxDecoration(
                color: colors.interactive,
                borderRadius: b05Radius(B05SurfaceRadius.small),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: colors.action,
                size: B05Layout.iconMedium,
              ),
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications & reminders',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose reminder types independently. Device notification access is separate.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: B05Layout.space16),
        _buildPermissionCard(context),
        const SizedBox(height: 16),
        Text('Reminders', style: B05Typography.title(context)),
        const SizedBox(height: 8),
        SettingsReminderToggle(
          icon: Icons.fitness_center_rounded,
          iconColor: colors.warning.indicator,
          title: 'Workout reminder',
          subtitle:
              '${_workoutDaysSummary(state.workoutReminderDays)} · ${_formatTime(context, state.workoutReminderHour, state.workoutReminderMinute)}',
          value: state.remindWorkout,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindWorkout,
            val,
          ),
          actionLabel: 'Edit schedule',
          onAction: () =>
              unawaited(_editWorkoutSchedule(context, state, controller)),
        ),
        const SizedBox(height: B05Layout.space12),
        SettingsReminderToggle(
          icon: Icons.restaurant_rounded,
          iconColor: colors.success.indicator,
          title: 'Meal logging',
          subtitle:
              'Lunch ${_formatTime(context, state.lunchReminderHour, state.lunchReminderMinute)} · Dinner ${_formatTime(context, state.dinnerReminderHour, state.dinnerReminderMinute)}',
          value: state.remindMeals,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindMeals,
            val,
          ),
          actionLabel: 'Edit times',
          onAction: () =>
              unawaited(_editMealSchedule(context, state, controller)),
        ),
        const SizedBox(height: B05Layout.space12),
        SettingsReminderToggle(
          icon: Icons.bedtime_rounded,
          iconColor: colors.info.indicator,
          title: 'Daily logging reminder',
          subtitle:
              'Every day · ${_formatTime(context, state.dailyLoggingReminderHour, state.dailyLoggingReminderMinute)} · Review meals or workouts you haven’t logged',
          value: state.remindEvening,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindEvening,
            val,
          ),
          actionLabel: 'Edit time',
          onAction: () =>
              unawaited(_editDailyLoggingSchedule(context, state, controller)),
        ),
        const SizedBox(height: B05Layout.space12),
        SettingsReminderToggle(
          icon: Icons.auto_awesome_rounded,
          iconColor: colors.action,
          title: 'Weekly progress report',
          subtitle:
              '${_weekdayName(state.weeklyProgressDay)} · ${_formatTime(context, state.weeklyProgressHour, state.weeklyProgressMinute)} · Review your week',
          value: state.remindWeekly,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindWeekly,
            val,
          ),
          actionLabel: 'Edit schedule',
          onAction: () => unawaited(
            _editWeeklyProgressSchedule(context, state, controller),
          ),
        ),
        const SizedBox(height: B05Layout.space16),
        _buildQuietHours(context, state, controller),
      ],
    );
  }

  Widget _buildPermissionCard(BuildContext context) {
    final colors = context.b05Colors;
    final status = _permissionStatus;

    if (status == null) {
      return B05Surface(
        showBorder: true,
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.action,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checking device notification access…',
                style: B05Typography.body(context),
              ),
            ),
          ],
        ),
      );
    }

    final semanticStatus = switch (status) {
      NotificationPermissionStatus.granted => B05SemanticStatus.success,
      NotificationPermissionStatus.denied => B05SemanticStatus.warning,
      NotificationPermissionStatus.unavailable => B05SemanticStatus.unavailable,
    };
    final statusLabel = switch (status) {
      NotificationPermissionStatus.granted => 'Allowed',
      NotificationPermissionStatus.denied => 'Not allowed',
      NotificationPermissionStatus.unavailable => 'Status unavailable',
    };
    final statusDetail = switch (status) {
      NotificationPermissionStatus.granted =>
        'Scheduled reminders can be delivered.',
      NotificationPermissionStatus.denied =>
        'Your reminder choices are saved, but the device is blocking notifications.',
      NotificationPermissionStatus.unavailable =>
        'This device does not expose notification permission status here.',
    };

    return B05Surface(
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device notification access',
            style: B05Typography.title(context),
          ),
          const SizedBox(height: 8),
          B05StatusMessage(
            status: semanticStatus,
            label: statusLabel,
            value: statusDetail,
          ),
          if (status == NotificationPermissionStatus.denied) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: B05TouchTarget(
                child: TextButton.icon(
                  onPressed: _permissionRequestInProgress
                      ? null
                      : () => unawaited(_requestNotificationPermission()),
                  icon: _permissionRequestInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: const Text('Allow notifications'),
                ),
              ),
            ),
          ],
          if (_permissionError != null) ...[
            const SizedBox(height: 4),
            Text(
              _permissionError!,
              style: B05Typography.caption(
                context,
              ).copyWith(color: colors.warning.foreground),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuietHours(
    BuildContext context,
    SettingsState state,
    SettingsController controller,
  ) {
    final colors = context.b05Colors;
    return B05Surface(
      tone: B05SurfaceTone.section,
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.do_not_disturb_on_rounded,
                color: colors.info.indicator,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quiet Hours', style: B05Typography.title(context)),
                    const SizedBox(height: 2),
                    Text(
                      state.quietHoursEnabled
                          ? _quietHoursSummary(state)
                          : 'Off',
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Quiet Hours',
                value: state.quietHoursEnabled ? 'On' : 'Off',
                child: B05TouchTarget(
                  child: Switch.adaptive(
                    value: state.quietHoursEnabled,
                    activeTrackColor: colors.action,
                    onChanged: (val) =>
                        controller.updateQuietHours(enabled: val),
                  ),
                ),
              ),
            ],
          ),
          if (state.quietHoursEnabled) ...[
            const SizedBox(height: 12),
            Text(
              'Reminders scheduled during these hours are deferred until the end of quiet hours.',
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _quietHourField(
                    context,
                    label: 'Start time',
                    value: state.quietHoursStart,
                    onChanged: (val) => controller.updateQuietHours(start: val),
                  ),
                  _quietHourField(
                    context,
                    label: 'End time',
                    value: state.quietHoursEnd,
                    onChanged: (val) => controller.updateQuietHours(end: val),
                  ),
                ];
                if (constraints.maxWidth < 360) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 12),
                      fields[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _quietHourField(
    BuildContext context, {
    required String label,
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: List.generate(
        24,
        (h) => DropdownMenuItem(value: h, child: Text(_formatHour(h))),
      ),
      onChanged: onChanged,
    );
  }

  String _quietHoursSummary(SettingsState state) {
    final range =
        '${_formatHour(state.quietHoursStart)} – ${_formatHour(state.quietHoursEnd)}';
    return state.quietHoursStart > state.quietHoursEnd
        ? '$range · overnight'
        : range;
  }

  String _formatHour(int h) {
    if (h == 0) return '12:00 AM';
    if (h == 12) return '12:00 PM';
    if (h < 12) return '$h:00 AM';
    return '${h - 12}:00 PM';
  }

  Future<void> _editWorkoutSchedule(
    BuildContext context,
    SettingsState state,
    SettingsController controller,
  ) async {
    await _showScheduleEditor(
      context,
      title: 'Workout reminder schedule',
      description: 'Choose the days and local time for your reminder.',
      initialDays: state.workoutReminderDays,
      allowMultipleDays: true,
      times: [
        _ReminderTimeDraft(
          label: 'Reminder time',
          value: TimeOfDay(
            hour: state.workoutReminderHour,
            minute: state.workoutReminderMinute,
          ),
        ),
      ],
      onSave: (days, times) => controller.updateWorkoutReminderSchedule(
        days: days,
        hour: times.single.hour,
        minute: times.single.minute,
      ),
    );
  }

  Future<void> _editMealSchedule(
    BuildContext context,
    SettingsState state,
    SettingsController controller,
  ) async {
    await _showScheduleEditor(
      context,
      title: 'Meal logging times',
      description: 'Choose when lunch and dinner logging reminders appear.',
      times: [
        _ReminderTimeDraft(
          label: 'Lunch',
          value: TimeOfDay(
            hour: state.lunchReminderHour,
            minute: state.lunchReminderMinute,
          ),
        ),
        _ReminderTimeDraft(
          label: 'Dinner',
          value: TimeOfDay(
            hour: state.dinnerReminderHour,
            minute: state.dinnerReminderMinute,
          ),
        ),
      ],
      onSave: (_, times) => controller.updateMealReminderSchedule(
        lunchHour: times[0].hour,
        lunchMinute: times[0].minute,
        dinnerHour: times[1].hour,
        dinnerMinute: times[1].minute,
      ),
    );
  }

  Future<void> _editDailyLoggingSchedule(
    BuildContext context,
    SettingsState state,
    SettingsController controller,
  ) async {
    await _showScheduleEditor(
      context,
      title: 'Daily logging reminder time',
      description:
          'This reminder appears when meals or workouts may still be missing.',
      times: [
        _ReminderTimeDraft(
          label: 'Reminder time',
          value: TimeOfDay(
            hour: state.dailyLoggingReminderHour,
            minute: state.dailyLoggingReminderMinute,
          ),
        ),
      ],
      onSave: (_, times) => controller.updateDailyLoggingReminderSchedule(
        hour: times.single.hour,
        minute: times.single.minute,
      ),
    );
  }

  Future<void> _editWeeklyProgressSchedule(
    BuildContext context,
    SettingsState state,
    SettingsController controller,
  ) async {
    await _showScheduleEditor(
      context,
      title: 'Weekly progress schedule',
      description: 'Choose one day and local time for your weekly reminder.',
      initialDays: [state.weeklyProgressDay],
      allowSingleDay: true,
      times: [
        _ReminderTimeDraft(
          label: 'Reminder time',
          value: TimeOfDay(
            hour: state.weeklyProgressHour,
            minute: state.weeklyProgressMinute,
          ),
        ),
      ],
      onSave: (days, times) => controller.updateWeeklyProgressSchedule(
        day: days.single,
        hour: times.single.hour,
        minute: times.single.minute,
      ),
    );
  }

  Future<void> _showScheduleEditor(
    BuildContext context, {
    required String title,
    required String description,
    required List<_ReminderTimeDraft> times,
    required Future<void> Function(List<int> days, List<TimeOfDay> times)
    onSave,
    List<int> initialDays = const [],
    bool allowMultipleDays = false,
    bool allowSingleDay = false,
  }) => showIndiFitBottomSheet<void>(
    context: context,
    semanticLabel: title,
    maxHeightFactor: 0.92,
    builder: (_) => _ReminderScheduleEditor(
      title: title,
      description: description,
      initialDays: initialDays,
      allowMultipleDays: allowMultipleDays,
      allowSingleDay: allowSingleDay,
      initialTimes: times,
      onSave: onSave,
    ),
  );

  String _formatTime(BuildContext context, int hour, int minute) =>
      MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));

  String _workoutDaysSummary(List<int> days) {
    if (days.length == 7) return 'Every day';
    return days.map(_weekdayShortName).join(' · ');
  }

  String _weekdayShortName(int day) => switch (day) {
    DateTime.monday => 'Mon',
    DateTime.tuesday => 'Tue',
    DateTime.wednesday => 'Wed',
    DateTime.thursday => 'Thu',
    DateTime.friday => 'Fri',
    DateTime.saturday => 'Sat',
    DateTime.sunday => 'Sun',
    _ => '',
  };

  String _weekdayName(int day) => switch (day) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Weekly',
  };
}

class _ReminderTimeDraft {
  final String label;
  final TimeOfDay value;

  const _ReminderTimeDraft({required this.label, required this.value});
}

class _ReminderScheduleEditor extends StatefulWidget {
  final String title;
  final String description;
  final List<int> initialDays;
  final bool allowMultipleDays;
  final bool allowSingleDay;
  final List<_ReminderTimeDraft> initialTimes;
  final Future<void> Function(List<int> days, List<TimeOfDay> times) onSave;

  const _ReminderScheduleEditor({
    required this.title,
    required this.description,
    required this.initialDays,
    required this.allowMultipleDays,
    required this.allowSingleDay,
    required this.initialTimes,
    required this.onSave,
  });

  @override
  State<_ReminderScheduleEditor> createState() =>
      _ReminderScheduleEditorState();
}

class _ReminderScheduleEditorState extends State<_ReminderScheduleEditor> {
  late final Set<int> _days;
  late final List<TimeOfDay> _times;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays.toSet();
    _times = widget.initialTimes.map((item) => item.value).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space8,
        B05Layout.space16,
        B05Layout.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: B05Typography.pageTitle(context)),
          const SizedBox(height: B05Layout.space4),
          Text(widget.description, style: B05Typography.body(context)),
          if (widget.allowMultipleDays) ...[
            const SizedBox(height: B05Layout.space16),
            Text('Days', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space8),
            Wrap(
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space8,
              children: [
                for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                  FilterChip(
                    label: Text(_shortDay(day)),
                    selected: _days.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        selected ? _days.add(day) : _days.remove(day);
                        _error = null;
                      });
                    },
                  ),
              ],
            ),
          ],
          if (widget.allowSingleDay) ...[
            const SizedBox(height: B05Layout.space16),
            DropdownButtonFormField<int>(
              initialValue: _days.single,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [
                for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                  DropdownMenuItem(value: day, child: Text(_fullDay(day))),
              ],
              onChanged: (day) {
                if (day == null) return;
                setState(() {
                  _days
                    ..clear()
                    ..add(day);
                });
              },
            ),
          ],
          const SizedBox(height: B05Layout.space12),
          for (var index = 0; index < _times.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.initialTimes[index].label),
              subtitle: Text(
                MaterialLocalizations.of(
                  context,
                ).formatTimeOfDay(_times[index]),
              ),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: _saving ? null : () => _pickTime(index),
            ),
          if (_error != null) ...[
            const SizedBox(height: B05Layout.space8),
            Text(
              _error!,
              style: B05Typography.caption(
                context,
              ).copyWith(color: context.b05Colors.warning.foreground),
            ),
          ],
          const SizedBox(height: B05Layout.space16),
          B05ActionGroup(
            children: [
              B05ActionButton(
                label: _saving ? 'Saving…' : 'Save schedule',
                icon: Icons.check_rounded,
                onPressed: _saving ? null : _save,
              ),
              B05ActionButton(
                label: 'Cancel',
                emphasis: B05ActionEmphasis.secondary,
                onPressed: _saving ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(int index) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _times[index],
      helpText: widget.initialTimes[index].label,
    );
    if (selected == null || !mounted) return;
    setState(() => _times[index] = selected);
  }

  Future<void> _save() async {
    if ((widget.allowMultipleDays || widget.allowSingleDay) && _days.isEmpty) {
      setState(() => _error = 'Select at least one day.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final days = _days.toList()..sort();
      await widget.onSave(days, List.unmodifiable(_times));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'That schedule could not be saved. Try again.';
        });
      }
    }
  }

  static String _shortDay(int day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

  static String _fullDay(int day) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][day - 1];
}
