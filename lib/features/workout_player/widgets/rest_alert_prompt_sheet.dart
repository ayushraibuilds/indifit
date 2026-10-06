import 'package:flutter/material.dart';

import '../../../core/services/rest_alert_permission_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';

/// The short explanation shown once before a rest-alert permission ask.
/// Returns true when the user chose to continue to the system prompt or
/// setting.
class RestAlertPromptSheet extends StatelessWidget {
  const RestAlertPromptSheet({required this.prompt, super.key});

  final RestAlertPrompt prompt;

  static Future<bool> show(BuildContext context, RestAlertPrompt prompt) async {
    final result = await showIndiFitBottomSheet<bool>(
      context: context,
      semanticLabel: 'Rest alerts',
      builder: (_) => RestAlertPromptSheet(prompt: prompt),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final precise = prompt == RestAlertPrompt.preciseAlarms;
    final title = precise
        ? 'Allow precise rest alerts'
        : 'Get an alert when rest ends';
    final body = precise
        ? 'Android can delay rest alerts by a few minutes. Turn on '
              '"Alarms & reminders" for IndiFit so the alert comes on time.'
        : 'Lock your phone between sets and IndiFit will tell you when it\'s '
              'time for the next one. Your phone will ask for permission '
              'next. You can change this later in your phone\'s settings.';
    return SingleChildScrollView(
      key: Key(precise ? 'rest_alert_precise_sheet' : 'rest_alert_sheet'),
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space20,
        B05Layout.space12,
        B05Layout.space20,
        B05Layout.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(B05Layout.space8),
                decoration: BoxDecoration(
                  color: colors.info.container,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  precise
                      ? Icons.alarm_rounded
                      : Icons.notifications_active_outlined,
                  color: colors.info.indicator,
                  size: B05Layout.iconMedium,
                ),
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(child: Text(title, style: B05Typography.title(context))),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          Text(body, style: B05Typography.body(context)),
          const SizedBox(height: B05Layout.space24),
          Row(
            children: [
              Expanded(
                child: B05ActionButton(
                  label: 'Not now',
                  emphasis: B05ActionEmphasis.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: B05ActionButton(
                  label: precise ? 'Open settings' : 'Allow alerts',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
