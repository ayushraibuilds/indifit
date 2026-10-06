import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_logger.dart';

typedef ExternalLinkLauncher = Future<bool> Function(Uri uri);

/// Public links the app shows: the privacy policy (Apple 5.1.1(i) requires an
/// in-app link) and support email. The owner hosts the policy page and the
/// mailbox; these must match the store listings.
abstract final class AppLinks {
  static final Uri privacyPolicy = Uri.parse('https://indifit.app/privacy');
  static const String supportEmail = 'support@indifit.app';

  /// Replaced in tests. Opens outside the app so the policy page and the mail
  /// app keep their own back navigation.
  @visibleForTesting
  static ExternalLinkLauncher launcher = _launchExternally;

  /// Returns false when nothing could open [uri]; never throws.
  static Future<bool> open(Uri uri) async {
    try {
      return await launcher(uri);
    } catch (error) {
      AppLogger.warning('Could not open ${uri.scheme} link: $error', 'Links');
      return false;
    }
  }

  /// The "Contact support" email. Built by hand: `Uri(queryParameters:)`
  /// encodes spaces as `+`, which mail apps show literally.
  static Uri supportEmailUri({String? appVersion}) {
    String encode(String value) => Uri.encodeComponent(value);
    final version = appVersion == null || appVersion.trim().isEmpty
        ? 'unknown'
        : appVersion.trim();
    final body = encode(
      '\n\nApp version: $version\nPlatform: ${Platform.operatingSystem}',
    );
    return Uri.parse(
      'mailto:$supportEmail?subject=${encode('IndiFit support')}&body=$body',
    );
  }

  static Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// "1.0.0 (12)", or null when the platform can't say.
final appVersionLabelProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  } catch (error) {
    AppLogger.warning('App version unavailable: $error', 'Links');
    return null;
  }
});
