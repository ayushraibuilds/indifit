import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/features/progress/widgets/badge_medal.dart';
import 'package:indifit/features/workout_player/widgets/achievement_celebration_sheet.dart';

Achievement _achievement({String id = 'first_workout', bool unlocked = true}) =>
    Achievement(
      id: id,
      title: 'First Sweat',
      description: 'Complete your 1st workout session.',
      icon: Icons.fitness_center_rounded,
      color: const Color(0xFFCD7F32),
      currentProgress: unlocked ? 1 : 0,
      maxProgress: 1,
      isUnlocked: unlocked,
      evidence: unlocked ? '1 of 1 workout logged' : '0 of 1 workout logged',
      unlockedAt: unlocked ? DateTime.utc(2026, 10, 9) : null,
    );

Widget _wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: ThemeData.dark().copyWith(extensions: const [B05SemanticColors.dark]),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

/// A tilt source that records whether anything listened.
class _FakeTilt {
  final controller = StreamController<Offset>.broadcast();
  var listened = false;

  Stream<Offset> call() {
    listened = true;
    return controller.stream;
  }
}

void main() {
  group('art and provenance', () {
    test('every achievement has art, and every file matches SOURCE.md', () {
      final ids = AchievementService.evaluateAchievements(
        completedWorkoutsCount: 0,
        currentStreakDays: 0,
        totalVolumeKg: 0,
        totalLoggedMealsCount: 0,
      ).map((a) => a.id).toSet();
      expect(kBadgeArtIds, ids);

      final source = File('assets/badges/SOURCE.md').readAsStringSync();
      for (final id in kBadgeArtIds) {
        final file = File(badgeArtAsset(id)!);
        expect(file.existsSync(), isTrue, reason: id);
        final digest = sha256.convert(file.readAsBytesSync()).toString();
        expect(
          source,
          contains('| $id.png |'),
          reason: '$id is listed in SOURCE.md',
        );
        expect(
          RegExp('\\| $id\\.png \\|.*\\| $digest \\|').hasMatch(source),
          isTrue,
          reason: '$id checksum matches SOURCE.md',
        );
      }
      final art = Directory('assets/badges')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.png'))
          .toSet();
      expect(art, {for (final id in kBadgeArtIds) '$id.png'});
    });

    test('unknown ids have no art and fall back to the icon', () {
      expect(badgeArtAsset('not_a_badge'), isNull);
    });
  });

  group('BadgeMedal', () {
    testWidgets('unlocked shows the full-colour art', (tester) async {
      await tester.pumpWidget(_wrap(BadgeMedal(achievement: _achievement())));
      expect(
        find.byKey(const Key('badge_medal_art_first_workout')),
        findsOneWidget,
      );
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('locked shows the same art desaturated', (tester) async {
      await tester.pumpWidget(
        _wrap(BadgeMedal(achievement: _achievement(unlocked: false))),
      );
      expect(
        find.byKey(const Key('badge_medal_art_first_workout')),
        findsOneWidget,
      );
      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('art is decorative and adds no semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          Semantics(
            label: 'First Sweat badge',
            child: BadgeMedal(achievement: _achievement()),
          ),
        ),
      );
      expect(find.bySemanticsLabel('First Sweat badge'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tilt follows the source while unlocked', (tester) async {
      final tilt = _FakeTilt();
      await tester.pumpWidget(
        _wrap(
          BadgeMedal(achievement: _achievement(), tilt: true, tiltSource: tilt),
        ),
      );
      expect(tilt.listened, isTrue);

      tilt.controller.add(const Offset(0.1, -0.05));
      await tester.pump();
      final transform = tester.widget<Transform>(
        find.byKey(const Key('badge_medal_tilt')),
      );
      expect(transform.transform.isIdentity(), isFalse);
      await tilt.controller.close();
    });

    testWidgets('no tilt when locked or under Reduce Motion', (tester) async {
      final locked = _FakeTilt();
      await tester.pumpWidget(
        _wrap(
          BadgeMedal(
            achievement: _achievement(unlocked: false),
            tilt: true,
            tiltSource: locked,
          ),
        ),
      );
      expect(locked.listened, isFalse);

      final reduced = _FakeTilt();
      await tester.pumpWidget(
        _wrap(
          BadgeMedal(
            key: const Key('reduced'),
            achievement: _achievement(),
            tilt: true,
            tiltSource: reduced,
          ),
          reduceMotion: true,
        ),
      );
      expect(reduced.listened, isFalse);
    });

    testWidgets('sheen sweeps once, then is gone', (tester) async {
      await tester.pumpWidget(
        _wrap(BadgeMedal(achievement: _achievement(), sheen: true)),
      );
      expect(find.byKey(const Key('badge_medal_sheen')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('badge_medal_sheen')), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('no sheen when locked or under Reduce Motion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BadgeMedal(achievement: _achievement(unlocked: false), sheen: true),
        ),
      );
      expect(find.byKey(const Key('badge_medal_sheen')), findsNothing);

      await tester.pumpWidget(
        _wrap(
          BadgeMedal(
            key: const Key('reduced'),
            achievement: _achievement(),
            sheen: true,
          ),
          reduceMotion: true,
        ),
      );
      expect(find.byKey(const Key('badge_medal_sheen')), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    test('art is capped at 85 pt', () {
      expect(
        () => BadgeMedal(achievement: _achievement(), size: 120),
        throwsAssertionError,
      );
    });
  });

  group('celebration sheet', () {
    tearDown(() => IndiFitHaptics.debugHandler = null);

    testWidgets('one success haptic and the badge art', (tester) async {
      final events = <IndiFitHapticType>[];
      IndiFitHaptics.debugHandler = events.add;

      await tester.pumpWidget(
        _wrap(AchievementCelebrationSheet(achievements: [_achievement()])),
      );
      await tester.pumpAndSettle();

      expect(events, [IndiFitHapticType.success]);
      expect(
        find.byKey(const Key('badge_medal_art_first_workout')),
        findsOneWidget,
      );
    });
  });
}
