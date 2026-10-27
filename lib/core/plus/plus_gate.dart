import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';

/// Remote Config key that lets Plus features show without an app release.
abstract final class PlusRemoteConfigKeys {
  /// Defaults to false; Plus stays hidden until it is set true remotely.
  static const enabled = 'plus_enabled';
}

/// Whether this install has bought Plus.
abstract class PlusEntitlement {
  bool get isActive;
}

/// Stub until real purchases exist: nobody has Plus.
class LocalPlusEntitlementStub implements PlusEntitlement {
  const LocalPlusEntitlementStub();

  @override
  bool get isActive => false;
}

final plusEntitlementProvider = Provider<PlusEntitlement>(
  (ref) => const LocalPlusEntitlementStub(),
);

/// The `plus_enabled` Remote Config value as last activated. False when
/// Firebase hasn't started (the app never starts it just for this) or the
/// key isn't set.
final plusRemoteEnabledProvider = Provider<bool>((ref) {
  try {
    if (Firebase.apps.isEmpty) return false;
    return FirebaseRemoteConfig.instance.getBool(PlusRemoteConfigKeys.enabled);
  } on Object catch (error) {
    AppLogger.warning('Remote Config plus_enabled unreadable: $error');
    return false;
  }
});

/// Plus features show only when the purchase AND the remote switch are on.
final plusEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(plusEntitlementProvider).isActive) return false;
  return ref.watch(plusRemoteEnabledProvider);
});

/// Renders [child] only when Plus is on, and nothing at all otherwise: no
/// paywall, no locked placeholder.
class PlusGate extends ConsumerWidget {
  const PlusGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(plusEnabledProvider)) return const SizedBox.shrink();
    return child;
  }
}
