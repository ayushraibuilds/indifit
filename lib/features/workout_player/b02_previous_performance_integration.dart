import 'package:flutter/foundation.dart';

import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_previous_performance_models.dart';

/// The exact current execution context used for a B.3 history read.
///
/// This is presentation state, not a history identity. The canonical B.3
/// repository remains the only authority for eligibility and safe prefill.
@immutable
class B02PreviousPerformanceRequestKey {
  const B02PreviousPerformanceRequestKey({
    required this.slotId,
    required this.actualExerciseId,
    required this.role,
    required this.loadBasis,
    required this.effortMode,
    required this.endedAtFailure,
  });

  final String slotId;
  final String actualExerciseId;
  final B02SetRole role;
  final B02LoadBasis loadBasis;
  final B02EffortMode effortMode;
  final bool endedAtFailure;

  @override
  bool operator ==(Object other) {
    return other is B02PreviousPerformanceRequestKey &&
        other.slotId == slotId &&
        other.actualExerciseId == actualExerciseId &&
        other.role == role &&
        other.loadBasis == loadBasis &&
        other.effortMode == effortMode &&
        other.endedAtFailure == endedAtFailure;
  }

  @override
  int get hashCode => Object.hash(
    slotId,
    actualExerciseId,
    role,
    loadBasis,
    effortMode,
    endedAtFailure,
  );
}

/// The two editable fields that can receive a factual B.3 safe prefill.
enum B02PreviousPerformanceInputField { load, reps }

/// Coordinates asynchronous B.3 reads without allowing stale results to
/// change the current exercise or overwrite a user's current input.
///
/// The coordinator caches only by the typed request key. It owns no history,
/// draft, timer, or persistence authority; it is a small player-presentation
/// boundary over [B02PreviousPerformanceRepository.resolve].
class B02PreviousPerformanceLookupCoordinator {
  B02PreviousPerformanceLookupCoordinator({required this.resolve});

  final Future<B02PreviousExercisePerformance> Function(
    B02PreviousPerformanceQuery query,
  )
  resolve;

  final _results =
      <B02PreviousPerformanceRequestKey, B02PreviousExercisePerformance>{};
  final _inFlight = <B02PreviousPerformanceRequestKey>{};
  final _requestTokens = <B02PreviousPerformanceRequestKey, int>{};
  final _prefillClaims = <B02PreviousPerformanceRequestKey>{};
  B02PreviousPerformanceRequestKey? activeKey;
  B02PreviousExercisePerformance? activeResult;
  var _generation = 0;

  /// Starts a read for [key] when it is not already cached or in flight.
  /// Returns a generation token for the caller's asynchronous completion.
  int? begin(B02PreviousPerformanceRequestKey key) {
    activeKey = key;
    activeResult = _results[key];
    if (_results.containsKey(key) || !_inFlight.add(key)) return null;
    final token = ++_generation;
    _requestTokens[key] = token;
    return token;
  }

  Future<void> complete({
    required B02PreviousPerformanceRequestKey key,
    required int generation,
    required B02PreviousExercisePerformance result,
    required void Function(B02PreviousExercisePerformance result) onAccepted,
  }) async {
    _inFlight.remove(key);
    if (_requestTokens[key] != generation || activeKey != key) return;
    _results[key] = result;
    activeResult = result;
    onAccepted(result);
  }

  /// Reads B.3 and converts a read failure into an unavailable factual state.
  /// A history lookup failure never becomes a player-blocking error.
  Future<void> request({
    required B02PreviousPerformanceRequestKey key,
    required B02PreviousPerformanceQuery query,
    required void Function(B02PreviousExercisePerformance result) onAccepted,
  }) async {
    final generation = begin(key);
    if (generation == null) return;
    late final B02PreviousExercisePerformance result;
    try {
      result = await resolve(query);
    } catch (_) {
      result = B02PreviousExercisePerformance.unavailable(
        status: B02PreviousPerformanceStatus.queryFailure,
        canonicalExerciseId: query.canonicalExerciseId,
        reasonCode: 'query_failure',
      );
    }
    await complete(
      key: key,
      generation: generation,
      result: result,
      onAccepted: onAccepted,
    );
  }

  /// Claims one-time initialization for the current typed request. A claim
  /// is made even when no safe prefill exists, so rebuilds cannot reapply a
  /// later value to an input the user has already considered.
  bool claimPrefill(B02PreviousPerformanceRequestKey key) {
    return _prefillClaims.add(key);
  }

  bool hasCachedResult(B02PreviousPerformanceRequestKey key) {
    return _results.containsKey(key);
  }

  void invalidate() {
    _generation++;
    _requestTokens.clear();
    activeKey = null;
    activeResult = null;
  }
}

/// Compact factual language for B.3 evidence. It intentionally does not
/// describe a target, recommendation, progression, PR, or e1RM.
abstract final class B02PreviousPerformancePresentation {
  static String? lastTime(B02PreviousExercisePerformance? result) {
    if (result?.status != B02PreviousPerformanceStatus.available) return null;
    final facts = [
      for (final occurrence in result!.occurrences)
        for (final set in occurrence.sets) _formatSet(set),
    ];
    if (facts.isEmpty) return null;
    return facts.join('  ·  ');
  }

  static String _formatSet(B02PreviousPerformanceSet set) {
    final load = switch (set.loadBasis) {
      B02LoadBasis.bodyweight => 'Bodyweight',
      _ when set.actualLoadKg != null => '${_number(set.actualLoadKg!)} kg',
      _ => 'Load not recorded',
    };
    final role = set.role == B02SetRole.warmup ? 'Warm-up · ' : '';
    return '$role$load × ${set.actualReps} reps'
        '${set.actualRpe == null ? '' : ' · RPE ${set.actualRpe}'}';
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}
