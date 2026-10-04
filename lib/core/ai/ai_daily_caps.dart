import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import 'ai_gateway.dart';

/// The AI features that each get their own daily allowance.
enum AiFeature {
  text('meal descriptions'),
  photo('photo estimates'),
  label('label scans');

  const AiFeature(this.displayName);

  /// How the feature is named in the "daily limit reached" message.
  final String displayName;
}

/// Per-device daily allowances for each AI feature.
///
/// Held in Remote Config as JSON (`{"text": 30, "photo": 10, "label": 10}`)
/// so they can be tightened without a release. Missing, malformed or
/// negative values fall back to the defaults; 0 switches a feature off for
/// the day.
class AiDailyCaps {
  const AiDailyCaps({this.text = 30, this.photo = 10, this.label = 10});

  static const defaults = AiDailyCaps();

  /// The Remote Config default, kept in step with [defaults].
  static const defaultsJson = '{"text":30,"photo":10,"label":10}';

  final int text;
  final int photo;
  final int label;

  factory AiDailyCaps.parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return defaults;
      int read(String key, int fallback) {
        final value = decoded[key];
        return value is num && value >= 0 ? value.toInt() : fallback;
      }

      return AiDailyCaps(
        text: read('text', defaults.text),
        photo: read('photo', defaults.photo),
        label: read('label', defaults.label),
      );
    } on FormatException catch (error) {
      AppLogger.error('ai_daily_caps is not valid JSON', error);
      return defaults;
    }
  }

  int capFor(AiFeature feature) => switch (feature) {
    AiFeature.text => text,
    AiFeature.photo => photo,
    AiFeature.label => label,
  };
}

/// Wraps an [AiGateway] with a local daily soft cap per feature.
///
/// A soft cap: it keeps an ordinary user's spend predictable and is the
/// friendly first line. Firebase AI Logic's per-user rate limit and the
/// project budget are the hard limits. Each request that may reach the model
/// counts, successful or not; requests that were never sent (switched off,
/// offline) are given back.
class DailyCapAiGateway implements AiGateway {
  DailyCapAiGateway({
    required AiGateway inner,
    required Future<AiDailyCaps> Function() caps,
    required SharedPreferences preferences,
    DateTime Function()? now,
  }) : _inner = inner,
       _caps = caps,
       _preferences = preferences,
       _now = now ?? DateTime.now;

  static const usageKey = 'ai_daily_usage_v1';

  final AiGateway _inner;
  final Future<AiDailyCaps> Function() _caps;
  final SharedPreferences _preferences;
  final DateTime Function() _now;

  @override
  Future<Map<String, dynamic>> decomposeMealText(String text) =>
      _guard(AiFeature.text, () => _inner.decomposeMealText(text));

  @override
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg) =>
      _guard(AiFeature.photo, () => _inner.decomposeMealPhoto(jpeg));

  @override
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg) =>
      _guard(AiFeature.label, () => _inner.readNutritionLabel(jpeg));

  /// Requests of [feature] used today on this device.
  int usedToday(AiFeature feature) => _usage()[feature.name] ?? 0;

  Future<Map<String, dynamic>> _guard(
    AiFeature feature,
    Future<Map<String, dynamic>> Function() request,
  ) async {
    final cap = (await _caps()).capFor(feature);
    if (usedToday(feature) >= cap) {
      throw AiGatewayException(
        AiGatewayFailure.dailyLimitReached,
        cap == 0
            ? 'AI ${feature.displayName} are paused for today. '
                  'You can still log with food search.'
            : "You've used today's $cap AI ${feature.displayName}. They reset at "
                  'midnight. You can still log with food search.',
      );
    }
    await _add(feature, 1);
    try {
      return await request();
    } on AiGatewayException catch (error) {
      if (error.failure == AiGatewayFailure.disabled ||
          error.failure == AiGatewayFailure.offline) {
        await _add(feature, -1);
      }
      rethrow;
    }
  }

  String _today() {
    final now = _now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// Today's counts; anything stored for an earlier day reads as empty.
  Map<String, int> _usage() {
    final raw = _preferences.getString(usageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['date'] != _today()) return {};
      final counts = decoded['counts'];
      if (counts is! Map) return {};
      return {
        for (final entry in counts.entries)
          if (entry.value is int) entry.key as String: entry.value as int,
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _add(AiFeature feature, int delta) async {
    final counts = _usage();
    final next = (counts[feature.name] ?? 0) + delta;
    counts[feature.name] = next < 0 ? 0 : next;
    await _preferences.setString(
      usageKey,
      jsonEncode({'date': _today(), 'counts': counts}),
    );
  }
}
