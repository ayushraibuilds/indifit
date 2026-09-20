import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

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
  ///
  /// Uses millisecond precision so sub-second [initialDelay] configs are
  /// honored (previous seconds-truncation is fixed). Minimum 1s floor prevents
  /// hot-loop retries. Pass [random] in tests for deterministic delays.
  Duration computeDelay(int attemptCount, {math.Random? random}) {
    if (attemptCount <= 0) return Duration.zero;

    final baseMillis = initialDelay.inMilliseconds *
        math.pow(backoffMultiplier, attemptCount - 1).toDouble();
    final clampedMillis =
        math.min(baseMillis, maxDelay.inMilliseconds.toDouble());

    // Add jitter
    final rng = random ?? math.Random();
    final jitterDelta =
        clampedMillis * jitterFraction * (rng.nextDouble() * 2 - 1);
    final finalMillis = math.max(1000.0, clampedMillis + jitterDelta);

    return Duration(milliseconds: finalMillis.round());
  }

  /// Calculates next UTC execution timestamp for attempt [attemptCount].
  DateTime calculateNextSchedule(int attemptCount, {DateTime? fromUtc, math.Random? random}) {
    final base = fromUtc ?? DateTime.now().toUtc();
    return base.add(computeDelay(attemptCount, random: random));
  }

  /// Evaluates whether an execution exception is transient and eligible for retry.
  ///
  /// Retryable: socket/HTTP/TLS transport failures, timeouts, 502/503/504/429,
  /// 408 (request timeout), connection resets ([OSError], [DioException] with
  /// timeout/cancel-adjacent types). Permanent (by design): HTTP 500 (server
  /// bug, retry won't help without deploy), 400/401/403/404/409/422, schema
  /// mismatches, auth revocation.
  bool isRetryable(Object error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is HandshakeException) return true;
    if (error is TimeoutException) return true;
    if (error is OSError) return true;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          return code == 408 ||
              code == 429 ||
              code == 502 ||
              code == 503 ||
              code == 504;
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
        case DioExceptionType.badCertificate:
        case DioExceptionType.transformTimeout:
          break;
      }
    }

    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('connection reset') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('temporarily unavailable') ||
        errorStr.contains('408') ||
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
