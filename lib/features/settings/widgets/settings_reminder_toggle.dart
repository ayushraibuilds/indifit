import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class SettingsReminderToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Future<void> Function()? onRequestPermission;
  final bool requestNotificationPermission;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SettingsReminderToggle({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onRequestPermission,
    this.requestNotificationPermission = true,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return B05Surface(
      tone: B05SurfaceTone.section,
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space16,
        vertical: B05Layout.space12,
      ),
      child: Semantics(
        container: true,
        label: '$title, $subtitle',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(B05Layout.space8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: B05Radii.mediumRadius,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: B05Layout.iconMedium,
                  ),
                ),
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: B05Typography.label(context)),
                      const SizedBox(height: B05Layout.space4),
                      Text(subtitle, style: B05Typography.caption(context)),
                    ],
                  ),
                ),
                const SizedBox(width: B05Layout.space8),
                B05TouchTarget(
                  child: Semantics(
                    label: '$title notifications',
                    child: Switch.adaptive(
                      value: value,
                      activeTrackColor: colors.action,
                      onChanged: (newVal) {
                        onChanged(newVal);
                        if (newVal) {
                          final request = onRequestPermission?.call();
                          if (request != null) {
                            unawaited(request);
                          } else if (requestNotificationPermission) {
                            unawaited(NotificationService.requestPermissions());
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: B05Layout.space4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: B05TouchTarget(
                  child: TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: Text(actionLabel!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
