import 'dart:io';
import 'dart:math' as math;

/// Policy controlling exponential backoff, retry ceilings, and transient error
/// discrimination for durable outbox operations.
class OutboxRetryPolicy {
  const OutboxRetryPolicy({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(hours: 24),
    this.backoffMultiplier = 2.0,
    this.jitterFraction = 0.1,
  });

  /// Maximum total attempts before permanently abandoning the operation.
  final int maxAttempts;

  /// Delay before the first retry attempt.
  final Duration initialDelay;

  /// Hard cap on retry delay.
  final Duration maxDelay;

  /// Multiplier for subsequent attempts.
  final double backoffMultiplier;

  /// Percentage of random jitter added to prevent thundering herd.
  final double jitterFraction;

  /// Computes the delay before attempt [attemptCount] (1-indexed).
  Duration computeDelay(int attemptCount, {math.Random? random}) {
    if (attemptCount <= 0) return Duration.zero;

    final baseSeconds = initialDelay.inSeconds *
        math.pow(backoffMultiplier, attemptCount - 1).toDouble();
    final clampedSeconds = math.min(baseSeconds, maxDelay.inSeconds.toDouble());

    // Add jitter
    final rng = random ?? math.Random();
    final jitterDelta = clampedSeconds * jitterFraction * (rng.nextDouble() * 2 - 1);
    final finalSeconds = math.max(1.0, clampedSeconds + jitterDelta);

    return Duration(seconds: finalSeconds.round());
  }

  /// Calculates next UTC execution timestamp for attempt [attemptCount].
  DateTime calculateNextSchedule(int attemptCount, {DateTime? fromUtc, math.Random? random}) {
    final base = fromUtc ?? DateTime.now().toUtc();
    return base.add(computeDelay(attemptCount, random: random));
  }

  /// Evaluates whether an execution exception is transient and eligible for retry.
  bool isRetryable(Object error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is HandshakeException) return true;

    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('temporarily unavailable') ||
        errorStr.contains('503') ||
        errorStr.contains('502') ||
        errorStr.contains('504') ||
        errorStr.contains('429')) {
      return true;
    }

    // Schema mismatch, invalid JSON, 400 Bad Request, auth revocation are permanent
    return false;
  }
}
