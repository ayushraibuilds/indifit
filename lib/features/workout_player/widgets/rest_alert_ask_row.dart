import 'package:flutter/material.dart';

import '../../../core/services/rest_alert_permission_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// The one-time rest-alert ask, as a quiet row inside the rest timer rather
/// than a sheet over it. The system prompt (or setting) opens only from
/// [onAllow].
class RestAlertAskRow extends StatelessWidget {
  const RestAlertAskRow({
    required this.prompt,
    required this.onAllow,
    required this.onDismiss,
    super.key,
  });

  final RestAlertPrompt prompt;
  final VoidCallback onAllow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final precise = prompt == RestAlertPrompt.preciseAlarms;
    final title = precise
        ? 'Rest alerts may arrive late'
        : 'Alert me when rest ends';
    final detail = precise
        ? 'Turn on "Alarms & reminders" for IndiFit.'
        : 'Lock your phone between sets.';
    return B05Surface(
      key: Key(precise ? 'rest_alert_precise_row' : 'rest_alert_row'),
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space12,
        B05Layout.space4,
        B05Layout.space4,
        B05Layout.space4,
      ),
      child: Row(
        children: [
          Icon(
            precise ? Icons.alarm_rounded : Icons.notifications_active_outlined,
            color: colors.info.indicator,
            size: B05Layout.iconMedium,
          ),
          const SizedBox(width: B05Layout.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: B05Typography.label(context)),
                Text(
                  detail,
                  style: B05Typography.caption(
                    context,
                  ).copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAllow,
            child: Text(precise ? 'Open settings' : 'Allow'),
          ),
          IconButton(
            tooltip: 'Not now',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
