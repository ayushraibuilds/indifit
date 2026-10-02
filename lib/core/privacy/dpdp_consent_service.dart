import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_preferences_keys.dart';
import 'dpdp_consent_dialog.dart';

/// Consent for sending meal text and photos to a third-party AI, as required
/// by India's DPDP Act and App Store Review Guideline 5.1.2(i).
///
/// Consent is tied to [currentVersion] of the disclosure. Bump it whenever
/// [DpdpConsentDialog] changes what is sent or to whom, so people who agreed
/// to older wording are asked again.
class DpdpConsentService {
  const DpdpConsentService._();

  /// v1 covered photos only and did not name the AI provider.
  /// v2 covers typed descriptions too and names Google Gemini via Firebase.
  static const int currentVersion = 2;

  /// Returns true if consent to the current disclosure exists or is granted
  /// now via [DpdpConsentDialog]; false if the user declines or [context] is
  /// gone.
  static Future<bool> ensureConsent({
    required BuildContext context,
    required SharedPreferences prefs,
  }) async {
    if (hasConsent(prefs)) return true;
    if (!context.mounted) return false;

    final accepted = await DpdpConsentDialog.show(context);
    if (accepted != true) return false;

    await prefs.setBool(AppPreferenceKeys.dpdpAiConsentAccepted, true);
    await prefs.setInt(AppPreferenceKeys.dpdpAiConsentVersion, currentVersion);
    await prefs.setString(
      AppPreferenceKeys.dpdpAiConsentAcceptedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    return true;
  }

  /// Whether the user has agreed to the current disclosure, without prompting.
  static bool hasConsent(SharedPreferences prefs) =>
      (prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted) ?? false) &&
      prefs.getInt(AppPreferenceKeys.dpdpAiConsentVersion) == currentVersion;

  /// Withdraws consent. DPDP requires withdrawing to be as easy as giving it;
  /// the next AI action asks again.
  static Future<void> withdraw(SharedPreferences prefs) async {
    await prefs.remove(AppPreferenceKeys.dpdpAiConsentAccepted);
    await prefs.remove(AppPreferenceKeys.dpdpAiConsentVersion);
    await prefs.remove(AppPreferenceKeys.dpdpAiConsentAcceptedAt);
  }
}
