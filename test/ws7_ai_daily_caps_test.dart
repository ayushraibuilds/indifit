import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/ai/ai_daily_caps.dart';
import 'package:indifit/core/ai/ai_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingGateway implements AiGateway {
  int calls = 0;
  AiGatewayException? failure;

  Future<Map<String, dynamic>> _answer() async {
    calls++;
    if (failure != null) throw failure!;
    return {'items': <Object>[], 'total_calories': 0};
  }

  @override
  Future<Map<String, dynamic>> decomposeMealText(String text) => _answer();

  @override
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg) => _answer();

  @override
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg) => _answer();
}

Matcher _limitReached() => throwsA(
  isA<AiGatewayException>().having(
    (e) => e.failure,
    'failure',
    AiGatewayFailure.dailyLimitReached,
  ),
);

void main() {
  group('AiDailyCaps.parse', () {
    test('reads each feature and falls back per key', () {
      final caps = AiDailyCaps.parse('{"text": 5, "photo": 0}');
      expect(caps.text, 5);
      expect(caps.photo, 0);
      expect(caps.label, AiDailyCaps.defaults.label);
    });

    test('malformed, empty or negative values use the defaults', () {
      for (final raw in [null, '', 'not json', '[1,2]', '{"text": -3}']) {
        expect(AiDailyCaps.parse(raw).text, 30, reason: '$raw');
      }
    });

    test('the Remote Config default matches the code defaults', () {
      final parsed = AiDailyCaps.parse(AiDailyCaps.defaultsJson);
      expect(
        [parsed.text, parsed.photo, parsed.label],
        [
          AiDailyCaps.defaults.text,
          AiDailyCaps.defaults.photo,
          AiDailyCaps.defaults.label,
        ],
      );
    });
  });

  group('DailyCapAiGateway', () {
    late SharedPreferences preferences;
    late _CountingGateway inner;
    late DateTime now;
    var caps = const AiDailyCaps(text: 2, photo: 1, label: 0);

    DailyCapAiGateway gateway() => DailyCapAiGateway(
      inner: inner,
      caps: () async => caps,
      preferences: preferences,
      now: () => now,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      inner = _CountingGateway();
      now = DateTime(2026, 10, 3, 21);
      caps = const AiDailyCaps(text: 2, photo: 1, label: 0);
    });

    test(
      'blocks the request after the cap, without calling the model',
      () async {
        final ai = gateway();
        await ai.decomposeMealText('dal');
        await ai.decomposeMealText('roti');
        await expectLater(ai.decomposeMealText('rice'), _limitReached());
        expect(inner.calls, 2);
      },
    );

    test('the message names the feature and the cap', () async {
      final ai = gateway();
      await ai.decomposeMealPhoto(Uint8List(0));
      await expectLater(
        ai.decomposeMealPhoto(Uint8List(0)),
        throwsA(
          isA<AiGatewayException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains("today's 1 AI photo estimates"),
              contains('food search'),
            ),
          ),
        ),
      );
    });

    test('features are counted separately; 0 pauses a feature', () async {
      final ai = gateway();
      await ai.decomposeMealPhoto(Uint8List(0));
      await ai.decomposeMealText('dal');
      await expectLater(ai.readNutritionLabel(Uint8List(0)), _limitReached());
      expect(ai.usedToday(AiFeature.text), 1);
      expect(ai.usedToday(AiFeature.photo), 1);
    });

    test('counts reset on the next local day', () async {
      final ai = gateway();
      await ai.decomposeMealText('dal');
      await ai.decomposeMealText('roti');
      now = DateTime(2026, 10, 4, 0, 1);
      await ai.decomposeMealText('poha');
      expect(ai.usedToday(AiFeature.text), 1);
    });

    test('usage survives a new gateway (app restart)', () async {
      await gateway().decomposeMealText('dal');
      await gateway().decomposeMealText('roti');
      await expectLater(gateway().decomposeMealText('rice'), _limitReached());
    });

    test('requests that were never sent are given back', () async {
      final ai = gateway();
      for (final failure in [
        AiGatewayFailure.offline,
        AiGatewayFailure.disabled,
      ]) {
        inner.failure = AiGatewayException(failure, 'x');
        await expectLater(ai.decomposeMealText('dal'), throwsA(anything));
      }
      expect(ai.usedToday(AiFeature.text), 0);
    });

    test(
      'provider failures still count: the request may have been billed',
      () async {
        final ai = gateway();
        inner.failure = const AiGatewayException(
          AiGatewayFailure.unusableResponse,
          'x',
        );
        await expectLater(ai.decomposeMealText('dal'), throwsA(anything));
        expect(ai.usedToday(AiFeature.text), 1);
      },
    );

    test('a lowered cap applies immediately', () async {
      final ai = gateway();
      await ai.decomposeMealText('dal');
      caps = const AiDailyCaps(text: 1);
      await expectLater(ai.decomposeMealText('roti'), _limitReached());
    });
  });
}
