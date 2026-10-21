import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token counts Gemini reported for one request (N14-07).
class AiTokenUsage {
  const AiTokenUsage({
    this.prompt = 0,
    this.candidates = 0,
    this.thoughts = 0,
    this.total = 0,
  });

  factory AiTokenUsage.fromMetadata(UsageMetadata? metadata) => AiTokenUsage(
    prompt: metadata?.promptTokenCount ?? 0,
    candidates: metadata?.candidatesTokenCount ?? 0,
    thoughts: metadata?.thoughtsTokenCount ?? 0,
    total: metadata?.totalTokenCount ?? 0,
  );

  final int prompt;
  final int candidates;
  final int thoughts;
  final int total;

  Map<String, int> toMap() => {
    'prompt': prompt,
    'candidates': candidates,
    'thoughts': thoughts,
    'total': total,
  };

  @override
  String toString() =>
      'prompt=$prompt candidates=$candidates thoughts=$thoughts total=$total';
}

/// Today's Gemini token totals on this device, stored next to
/// `ai_daily_usage_v1` and reset the same way, by local date. Local only:
/// never sent anywhere and not part of analytics. It shows what a day of
/// use costs while testing the thinking settings.
class AiTokenUsageCounter {
  AiTokenUsageCounter(this._preferences, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const usageKey = 'ai_daily_tokens_v1';

  final SharedPreferences _preferences;
  final DateTime Function() _now;

  String _today() {
    final now = _now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// Today's totals plus a request count; empty on a new day.
  Map<String, int> today() {
    final raw = _preferences.getString(usageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['date'] != _today()) return {};
      final tokens = decoded['tokens'];
      if (tokens is! Map) return {};
      return {
        for (final entry in tokens.entries)
          if (entry.value is int) entry.key as String: entry.value as int,
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> add(AiTokenUsage usage) async {
    final totals = today();
    for (final entry in usage.toMap().entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
    }
    totals['requests'] = (totals['requests'] ?? 0) + 1;
    await _preferences.setString(
      usageKey,
      jsonEncode({'date': _today(), 'tokens': totals}),
    );
  }
}
