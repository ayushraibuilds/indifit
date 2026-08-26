import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.action.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: colors.action,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications & reminders',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
        const SizedBox(height: 16),
        _buildPermissionCard(context),
        const SizedBox(height: 16),
        Text('Reminders', style: B05Typography.title(context)),
        const SizedBox(height: 8),
        SettingsReminderToggle(
          icon: Icons.fitness_center_rounded,
          iconColor: colors.warning.indicator,
          title: 'Workout Reminder',
          subtitle: 'Every day · 7:30 AM · Start your training',
          value: state.remindWorkout,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindWorkout,
            val,
          ),
        ),
        const SizedBox(height: B05Layout.space12),

        SettingsReminderToggle(
          icon: Icons.restaurant_rounded,
          iconColor: colors.success.indicator,
          title: 'Meal Logging',
          subtitle: 'Lunch 1:30 PM · dinner 8:30 PM',
          value: state.remindMeals,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindMeals,
            val,
          ),
        ),
        const SizedBox(height: B05Layout.space12),

        SettingsReminderToggle(
          icon: Icons.bedtime_rounded,
          iconColor: colors.info.indicator,
          title: 'Evening Log Nudge',
          subtitle: 'Every day · 9:15 PM · Review missed meals or workouts',
          value: state.remindEvening,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindEvening,
            val,
          ),
        ),
        const SizedBox(height: 12),
        SettingsReminderToggle(
          icon: Icons.auto_awesome_rounded,
          iconColor: colors.action,
          title: 'Weekly Progress Report',
          subtitle: 'Every Sunday · 10:00 AM · Review your week',
          value: state.remindWeekly,
          onRequestPermission: _requestNotificationPermission,
          onChanged: (val) => controller.toggleReminder(
            NotificationService.prefRemindWeekly,
            val,
          ),
        ),
        const SizedBox(height: 16),
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
}
