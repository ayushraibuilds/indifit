import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_preferences_keys.dart';
import 'dpdp_consent_dialog.dart';

/// Service managing user consent under the Digital Personal Data Protection (DPDP) Act
/// and Apple App Store Review Guideline 5.1.1.
class DpdpConsentService {
  const DpdpConsentService._();

  /// Verifies whether the user has consented to cloud AI processing.
  /// If not yet accepted, displays [DpdpConsentDialog].
  ///
  /// Returns `true` if consent is granted or was previously granted.
  /// Returns `false` if the user cancels, dismisses, or if context is unmounted.
  static Future<bool> ensureConsent({
    required BuildContext context,
    required SharedPreferences prefs,
  }) async {
    final alreadyAccepted =
        prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted) ?? false;
    if (alreadyAccepted) {
      return true;
    }

    if (!context.mounted) return false;

    final accepted = await DpdpConsentDialog.show(context);
    if (accepted == true) {
      await prefs.setBool(AppPreferenceKeys.dpdpAiConsentAccepted, true);
      await prefs.setString(
        AppPreferenceKeys.dpdpAiConsentAcceptedAt,
        DateTime.now().toUtc().toIso8601String(),
      );
      return true;
    }

    return false;
  }

  /// Checks if consent is currently active without prompting.
  static bool hasConsent(SharedPreferences prefs) {
    return prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted) ?? false;
  }
}
