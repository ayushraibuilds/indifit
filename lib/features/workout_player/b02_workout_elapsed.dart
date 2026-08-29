import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/b02_execution_models.dart';

/// Returns the authoritative elapsed foreground duration at [nowUtc].
///
/// The persisted integer is the accumulated duration at the last durable
/// boundary. The active segment is derived from its persisted start timestamp;
/// a repaint ticker never increments this value or becomes a second clock.
@visibleForTesting
int b02ElapsedSecondsAt(B02ExecutionDraftState state, DateTime nowUtc) =>
    b02ElapsedSecondsFromValues(
      accumulatedSeconds: state.elapsedSeconds,
      activeSegmentStartedAtUtc: state.activeSegmentStartedAtUtc,
      nowUtc: nowUtc,
    );

@visibleForTesting
int b02ElapsedSecondsFromValues({
  required int accumulatedSeconds,
  required DateTime? activeSegmentStartedAtUtc,
  required DateTime nowUtc,
}) {
  if (activeSegmentStartedAtUtc == null) return accumulatedSeconds;
  final additional = nowUtc
      .toUtc()
      .difference(activeSegmentStartedAtUtc)
      .inSeconds;
  return accumulatedSeconds + (additional < 0 ? 0 : additional);
}

DateTime _systemNowUtc() => DateTime.now().toUtc();

/// Small presentation-only elapsed view used by the workout header.
///
/// It owns one short-lived repaint timer for its own subtree. It never writes
/// draft state, and it stops the timer whenever the persisted state is paused
/// or the widget is disposed.
class B02LiveElapsedText extends StatefulWidget {
  final int accumulatedSeconds;
  final DateTime? activeSegmentStartedAtUtc;
  final TextStyle? style;
  final DateTime Function() nowUtc;
  final Duration tickInterval;

  const B02LiveElapsedText({
    super.key,
    required this.accumulatedSeconds,
    required this.activeSegmentStartedAtUtc,
    this.style,
    this.nowUtc = _systemNowUtc,
    this.tickInterval = const Duration(seconds: 1),
  });

  @override
  State<B02LiveElapsedText> createState() => _B02LiveElapsedTextState();
}

class _B02LiveElapsedTextState extends State<B02LiveElapsedText> {
  Timer? _ticker;
  late DateTime _nowUtc;

  @override
  void initState() {
    super.initState();
    _nowUtc = widget.nowUtc().toUtc();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant B02LiveElapsedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _nowUtc = widget.nowUtc().toUtc();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _elapsedSeconds();
    return Text(_formatElapsed(seconds), style: widget.style);
  }

  int _elapsedSeconds() {
    return b02ElapsedSecondsFromValues(
      accumulatedSeconds: widget.accumulatedSeconds,
      activeSegmentStartedAtUtc: widget.activeSegmentStartedAtUtc,
      nowUtc: _nowUtc,
    );
  }

  void _syncTicker() {
    if (widget.activeSegmentStartedAtUtc != null && _ticker == null) {
      _ticker = Timer.periodic(widget.tickInterval, (_) {
        if (!mounted) return;
        setState(() => _nowUtc = widget.nowUtc().toUtc());
      });
      return;
    }
    if (widget.activeSegmentStartedAtUtc == null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  static String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}
