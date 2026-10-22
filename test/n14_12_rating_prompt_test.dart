import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/rating/rating_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReview implements StoreReviewClient {
  int requests = 0;
  bool available = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;
}

/// N14-12: once per version, after a good moment, never at a bad one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeReview review;
  var version = '1.0.0 (12)';
  var offline = false;
  var workouts = 0;
  var days = 0;
  var inWorkout = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppPreferenceKeys.ratingPromptOpenedBefore: true,
    });
    review = _FakeReview();
    version = '1.0.0 (12)';
    offline = false;
    workouts = 0;
    days = 0;
    inWorkout = false;
  });

  Future<RatingPrompt> prompt() async {
    final rating = RatingPrompt(
      review: review,
      preferences: SharedPreferences.getInstance,
      appVersion: () async => version,
      offlineOnly: () => offline,
      savedWorkouts: () async => workouts,
      loggedDays: () async => days,
      workoutInProgress: () async => inWorkout,
    );
    await rating.startSession();
    return rating;
  }

  group('good moments', () {
    test('not before the 3rd workout or 7th day', () async {
      workouts = 2;
      days = 6;
      expect(await (await prompt()).maybeAsk(), isFalse);
      expect(review.requests, 0);
    });

    test('the 3rd saved workout', () async {
      workouts = 3;
      expect(await (await prompt()).maybeAsk(), isTrue);
      expect(review.requests, 1);
    });

    test('the 7th logged day', () async {
      days = 7;
      expect(await (await prompt()).maybeAsk(), isTrue);
      expect(review.requests, 1);
    });
  });

  group('once per app version', () {
    test('a second good moment in the same version does not ask', () async {
      workouts = 3;
      final rating = await prompt();
      await rating.maybeAsk();
      workouts = 4;
      expect(await rating.maybeAsk(), isFalse);
      expect(await (await prompt()).maybeAsk(), isFalse, reason: 'relaunch');
      expect(review.requests, 1);
    });

    test('a new version asks again once', () async {
      workouts = 3;
      await (await prompt()).maybeAsk();
      version = '1.0.1 (13)';
      expect(await (await prompt()).maybeAsk(), isTrue);
      expect(review.requests, 2);
    });

    test('the asked version is not in backups', () async {
      workouts = 3;
      await (await prompt()).maybeAsk();
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final prefs = await SharedPreferences.getInstance();
      final backup = jsonEncode(
        (await BackupData.createFromDatabase(db, prefs)).toJson(),
      );
      expect(backup, isNot(contains('rating_prompt')));
    });
  });

  group('never', () {
    setUp(() => workouts = 3);

    test('in the first session', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await prompt();
      expect(await first.maybeAsk(), isFalse);
      expect(await (await prompt()).maybeAsk(), isTrue, reason: 'next launch');
    });

    test('during a workout', () async {
      inWorkout = true;
      expect(await (await prompt()).maybeAsk(), isFalse);
      expect(review.requests, 0);
    });

    test('after an error toast in this session', () async {
      final rating = await prompt();
      rating.noteErrorShown();
      expect(await rating.maybeAsk(), isFalse);
      expect(review.requests, 0);
    });

    test('in Offline Mode', () async {
      offline = true;
      expect(await (await prompt()).maybeAsk(), isFalse);
    });

    test(
      'when the store cannot show it, without using up the version',
      () async {
        review.available = false;
        expect(await (await prompt()).maybeAsk(), isFalse);
        review.available = true;
        expect(await (await prompt()).maybeAsk(), isTrue);
      },
    );

    test('without an app version', () async {
      final rating = RatingPrompt(
        review: review,
        preferences: SharedPreferences.getInstance,
        appVersion: () async => null,
        offlineOnly: () => false,
        savedWorkouts: () async => 3,
        loggedDays: () async => 0,
        workoutInProgress: () async => false,
      );
      await rating.startSession();
      expect(await rating.maybeAsk(), isFalse);
    });
  });

  testWidgets('an error snack bar marks the session', (tester) async {
    var errors = 0;
    late BuildContext inner;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => ErrorAwareScaffoldMessenger(
          onErrorShown: () => errors++,
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final messenger = ScaffoldMessenger.of(inner);
    messenger.showSnackBar(const SnackBar(content: Text('Meal logged')));
    expect(errors, 0);
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't save the workout. Try again.")),
    );
    expect(errors, 1);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });
}
