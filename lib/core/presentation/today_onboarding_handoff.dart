import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_preferences_keys.dart';
import '../di/core_providers.dart';

/// The smallest persisted state needed to show the post-onboarding Today
/// handoff once. The target values themselves continue to come from the
/// canonical nutrition read model.
const String todayOnboardingHandoffPendingKey =
    AppPreferenceKeys.todayOnboardingHandoffPending;

final todayOnboardingHandoffPendingProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  SharedPreferences? prefs = sharedPreferencesOrNull(
    () => ref.watch(sharedPreferencesProvider),
  );
  final p = prefs ?? await SharedPreferences.getInstance();
  return p.getBool(todayOnboardingHandoffPendingKey) ?? false;
});

/// True after setup was skipped, until the user finishes setup or dismisses
/// the Today prompt.
final todayFinishSetupPromptProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  SharedPreferences? prefs = sharedPreferencesOrNull(
    () => ref.watch(sharedPreferencesProvider),
  );
  final p = prefs ?? await SharedPreferences.getInstance();
  return (p.getBool(AppPreferenceKeys.onboardingSkipped) ?? false) &&
      !(p.getBool(AppPreferenceKeys.todayFinishSetupDismissed) ?? false);
});

Future<void> dismissTodayFinishSetup(
  WidgetRef ref, [
  SharedPreferences? preferences,
]) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  await prefs.setBool(AppPreferenceKeys.todayFinishSetupDismissed, true);
  ref.invalidate(todayFinishSetupPromptProvider);
}

Future<void> markTodayOnboardingHandoffPending([
  SharedPreferences? preferences,
]) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  await prefs.setBool(todayOnboardingHandoffPendingKey, true);
}

Future<void> acknowledgeTodayOnboardingHandoff(
  WidgetRef ref, [
  SharedPreferences? preferences,
]) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  await prefs.setBool(todayOnboardingHandoffPendingKey, false);
  ref.invalidate(todayOnboardingHandoffPendingProvider);
}

Future<void> clearTodayOnboardingHandoff([
  SharedPreferences? preferences,
]) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  await prefs.remove(todayOnboardingHandoffPendingKey);
}
