import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';

class SettingsReminderToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Future<void> Function()? onRequestPermission;
  final bool requestNotificationPermission;

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
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.b05Colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: '$title notifications',
              child: Switch(
                value: value,
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
                activeThumbColor: context.b05Colors.action,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
