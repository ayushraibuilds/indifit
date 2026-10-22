import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_links.dart';
import '../../core/config/app_preferences_keys.dart';
import '../../core/di/core_providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/app_logger.dart';
import '../nutrition/nutrition_providers.dart';

/// The store's own rating sheet. Replaced in tests.
abstract interface class StoreReviewClient {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class InAppStoreReviewClient implements StoreReviewClient {
  const InAppStoreReviewClient();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

/// Asks for a store rating once per app version, after a good moment: the
/// 3rd saved workout or the 7th logged day (N14-12). Never in the first
/// session, during a workout, after an error toast in this session, or in
/// Offline Mode.
class RatingPrompt {
  RatingPrompt({
    required StoreReviewClient review,
    required Future<SharedPreferences> Function() preferences,
    required Future<String?> Function() appVersion,
    required bool Function() offlineOnly,
    required Future<int> Function() savedWorkouts,
    required Future<int> Function() loggedDays,
    required Future<bool> Function() workoutInProgress,
  }) : _review = review,
       _preferences = preferences,
       _appVersion = appVersion,
       _offlineOnly = offlineOnly,
       _savedWorkouts = savedWorkouts,
       _loggedDays = loggedDays,
       _workoutInProgress = workoutInProgress;

  static const savedWorkoutsMoment = 3;
  static const loggedDaysMoment = 7;

  final StoreReviewClient _review;
  final Future<SharedPreferences> Function() _preferences;
  final Future<String?> Function() _appVersion;
  final bool Function() _offlineOnly;
  final Future<int> Function() _savedWorkouts;
  final Future<int> Function() _loggedDays;
  final Future<bool> Function() _workoutInProgress;

  bool? _firstSession;
  bool _errorShown = false;

  /// Call once per launch, before [maybeAsk].
  Future<void> startSession() async {
    if (_firstSession != null) return;
    final prefs = await _preferences();
    _firstSession =
        !(prefs.getBool(AppPreferenceKeys.ratingPromptOpenedBefore) ?? false);
    await prefs.setBool(AppPreferenceKeys.ratingPromptOpenedBefore, true);
  }

  /// An error toast was shown: no prompt for the rest of this session.
  void noteErrorShown() => _errorShown = true;

  /// Asks when every rule allows it; returns whether it asked.
  Future<bool> maybeAsk() async {
    try {
      if (_firstSession ?? true) return false;
      if (_errorShown || _offlineOnly()) return false;
      final version = await _appVersion();
      if (version == null) return false;
      final prefs = await _preferences();
      if (prefs.getString(AppPreferenceKeys.ratingPromptAskedVersion) ==
          version) {
        return false;
      }
      if (await _workoutInProgress()) return false;
      final goodMoment =
          await _savedWorkouts() >= savedWorkoutsMoment ||
          await _loggedDays() >= loggedDaysMoment;
      if (!goodMoment || !await _review.isAvailable()) return false;
      // Recorded first: the store decides whether its sheet shows, and a
      // second ask in this version must never happen either way.
      await prefs.setString(
        AppPreferenceKeys.ratingPromptAskedVersion,
        version,
      );
      await _review.requestReview();
      return true;
    } catch (error) {
      AppLogger.warning('Rating prompt skipped: $error', 'Rating');
      return false;
    }
  }
}

final storeReviewClientProvider = Provider<StoreReviewClient>(
  (ref) => const InAppStoreReviewClient(),
);

final ratingPromptProvider = Provider<RatingPrompt>((ref) {
  final db = ref.watch(databaseProvider);
  return RatingPrompt(
    review: ref.watch(storeReviewClientProvider),
    preferences: () async =>
        sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
        await SharedPreferences.getInstance(),
    appVersion: () => ref.read(appVersionLabelProvider.future),
    offlineOnly: () => ref.read(privacyPolicyProvider).isOfflineOnly,
    savedWorkouts: () async =>
        (await db
                .customSelect('SELECT COUNT(*) AS c FROM workout_sessions')
                .getSingle())
            .read<int>('c'),
    loggedDays: () async => (await (await ref.read(
      nutritionReadModelRepositoryProvider.future,
    )).activeLocalDates(userId: kLocalNutritionUserScopeId)).length,
    workoutInProgress: () async =>
        (await db.select(db.workoutDrafts).get()).isNotEmpty,
  );
});

/// The app's snack bars, watched for errors so the rating prompt stays away
/// after one (N14-12). Sits under MaterialApp's own messenger, so every
/// `ScaffoldMessenger.of(context)` below finds it.
class ErrorAwareScaffoldMessenger extends ScaffoldMessenger {
  const ErrorAwareScaffoldMessenger({
    super.key,
    required super.child,
    required this.onErrorShown,
  });

  final VoidCallback onErrorShown;

  @override
  ScaffoldMessengerState createState() => _ErrorAwareScaffoldMessengerState();
}

class _ErrorAwareScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    if (isErrorSnackBar(snackBar, context)) {
      (widget as ErrorAwareScaffoldMessenger).onErrorShown();
    }
    return super.showSnackBar(
      snackBar,
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}

final _errorWords = RegExp(
  r"couldn't|could not|can't|cannot|failed|error|went wrong|try again",
  caseSensitive: false,
);

/// A snack bar in the danger colour, or one whose text reports a failure.
@visibleForTesting
bool isErrorSnackBar(SnackBar snackBar, BuildContext context) {
  final background = snackBar.backgroundColor;
  if (background != null) {
    final danger = context.b05Colors.danger;
    if (background == danger.indicator || background == danger.container) {
      return true;
    }
  }
  final content = snackBar.content;
  final text = content is Text
      ? content.data ?? content.textSpan?.toPlainText()
      : null;
  return text != null && _errorWords.hasMatch(text);
}
