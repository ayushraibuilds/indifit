import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/privacy/dpdp_consent_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import 'settings_reminder_toggle.dart';

/// Settings switch for AI meal assistance consent.
///
/// DPDP requires withdrawing consent to be as easy as giving it. Turning this
/// on shows the same disclosure as the AI screens; turning it off withdraws
/// consent immediately. Hidden in builds without connected AI.
class AiConsentToggle extends ConsumerStatefulWidget {
  const AiConsentToggle({super.key});

  @override
  ConsumerState<AiConsentToggle> createState() => _AiConsentToggleState();
}

class _AiConsentToggleState extends ConsumerState<AiConsentToggle> {
  @override
  Widget build(BuildContext context) {
    if (!AppConfig.connectedAiEnabled) return const SizedBox.shrink();
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsReminderToggle(
      icon: Icons.auto_awesome_outlined,
      iconColor: context.b05Colors.info.indicator,
      title: 'AI meal assistance',
      subtitle:
          'Lets describe-a-meal, photo and label scans send that text or '
          'photo to Google Gemini. Off withdraws consent.',
      value: DpdpConsentService.hasConsent(prefs),
      requestNotificationPermission: false,
      onChanged: (enable) async {
        if (enable) {
          await DpdpConsentService.ensureConsent(
            context: context,
            prefs: prefs,
          );
        } else {
          await DpdpConsentService.withdraw(prefs);
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'AI consent withdrawn. IndiFit will ask before using AI again.',
                ),
              ),
            );
          }
        }
        if (mounted) setState(() {});
      },
    );
  }
}
