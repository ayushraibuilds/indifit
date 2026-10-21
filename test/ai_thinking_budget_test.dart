// N14-07: every Gemini request caps thinking, and token use is counted
// locally per day.
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/ai/ai_daily_caps.dart';
import 'package:indifit/core/ai/ai_token_usage.dart';
import 'package:indifit/core/ai/gemini_requests.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GeminiRequests.config', () {
    for (final kind in GeminiRequestKind.values) {
      test('${kind.name} uses the minimal thinking level on the default '
          'model', () {
        final json = GeminiRequests.config(kind).toJson();
        expect(json['thinkingConfig'], {'thinkingLevel': 'MINIMAL'});
        expect(json['responseMimeType'], 'application/json');
        expect(json['temperature'], 0.2);
      });
    }

    test('each kind keeps its schema', () {
      Object? schema(GeminiRequestKind kind) =>
          GeminiRequests.config(kind).toJson()['responseSchema'];
      expect(
        schema(GeminiRequestKind.describe),
        GeminiRequests.mealSchema.toJson(),
      );
      expect(
        schema(GeminiRequestKind.photo),
        GeminiRequests.mealSchema.toJson(),
      );
      expect(
        schema(GeminiRequestKind.label),
        GeminiRequests.labelSchema.toJson(),
      );
    });

    test('Gemini 2.5 models get a budget instead of a level', () {
      Object? thinking(String model) => GeminiRequests.config(
        GeminiRequestKind.describe,
        model: model,
      ).toJson()['thinkingConfig'];
      expect(thinking('gemini-2.5-flash'), {'thinkingBudget': 0});
      expect(thinking('gemini-2.5-flash-lite'), {'thinkingBudget': 0});
      expect(thinking('gemini-2.5-pro'), {'thinkingBudget': 128});
      expect(thinking('gemini-3.8-flash'), {'thinkingLevel': 'MINIMAL'});
    });
  });

  group('AiTokenUsageCounter', () {
    late SharedPreferences prefs;
    var now = DateTime(2026, 10, 20, 9);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 10, 20, 9);
    });

    test('adds each request to today', () async {
      final counter = AiTokenUsageCounter(prefs, now: () => now);
      await counter.add(
        const AiTokenUsage(
          prompt: 100,
          candidates: 40,
          thoughts: 5,
          total: 145,
        ),
      );
      await counter.add(
        const AiTokenUsage(prompt: 50, candidates: 10, total: 60),
      );
      expect(counter.today(), {
        'prompt': 150,
        'candidates': 50,
        'thoughts': 5,
        'total': 205,
        'requests': 2,
      });
    });

    test('resets on a new day', () async {
      final counter = AiTokenUsageCounter(prefs, now: () => now);
      await counter.add(const AiTokenUsage(prompt: 100, total: 100));
      now = DateTime(2026, 10, 21, 0, 1);
      expect(counter.today(), isEmpty);
      await counter.add(const AiTokenUsage(prompt: 7, total: 7));
      expect(counter.today()['prompt'], 7);
      expect(counter.today()['requests'], 1);
    });

    test('lives next to, not inside, the request counter', () async {
      final counter = AiTokenUsageCounter(prefs, now: () => now);
      await counter.add(const AiTokenUsage(total: 1));
      expect(AiTokenUsageCounter.usageKey, isNot(DailyCapAiGateway.usageKey));
      expect(prefs.getString(DailyCapAiGateway.usageKey), isNull);
    });

    test('missing usage metadata counts as zero', () {
      expect(AiTokenUsage.fromMetadata(null).toMap().values, everyElement(0));
    });
  });
}
