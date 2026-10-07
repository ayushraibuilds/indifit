import 'package:flutter/services.dart';

/// v1 ships iPhone-only and portrait-only (launch roadmap SC-06). The iOS
/// project and `Info.plist` say the same; this also holds Android phones in
/// portrait.
const List<DeviceOrientation> appOrientations = [DeviceOrientation.portraitUp];

/// Locks the app to [appOrientations]. Called once from `bootstrap()`.
Future<void> lockAppOrientation() =>
    SystemChrome.setPreferredOrientations(appOrientations);
