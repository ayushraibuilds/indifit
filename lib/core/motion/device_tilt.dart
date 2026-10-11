import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:sensors_plus/sensors_plus.dart';

/// A stream of how far the phone leans, as (x, y) radians clamped to
/// ±[maxRadians], for art that tilts with the phone (badges in V7).
///
/// The lean is relative to how the phone was held when listening started and
/// comes from gravity, so it never drifts the way integrated gyroscope rates
/// would. Off phones (desktop, widget tests) the stream is empty and the art
/// stays level.
Stream<Offset> deviceTiltStream({required double maxRadians}) {
  // Widget tests have no sensor plugin, and the plugin reports that through
  // the global error handler rather than the stream.
  if (!(Platform.isIOS || Platform.isAndroid) ||
      Platform.environment.containsKey('FLUTTER_TEST')) {
    return const Stream.empty();
  }
  Offset? baseline;
  var smoothed = Offset.zero;
  return accelerometerEventStream(
    samplingPeriod: SensorInterval.uiInterval,
  ).map((event) {
    double angle(double g) => math.asin((g / 9.81).clamp(-1.0, 1.0));
    final raw = Offset(angle(event.x), angle(event.y));
    baseline ??= raw;
    final lean = raw - baseline!;
    smoothed = Offset.lerp(smoothed, lean, 0.15)!;
    return Offset(
      (smoothed.dx * 0.5).clamp(-maxRadians, maxRadians),
      (-smoothed.dy * 0.5).clamp(-maxRadians, maxRadians),
    );
  });
}
