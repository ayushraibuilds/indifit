import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The smallest persisted state needed to show the post-onboarding Today
/// handoff once. The target values themselves continue to come from the
/// canonical nutrition read model.
const String todayOnboardingHandoffPendingKey =
    'today_onboarding_handoff_pending';

final todayOnboardingHandoffPendingProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(todayOnboardingHandoffPendingKey) ?? false;
});

Future<void> markTodayOnboardingHandoffPending() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(todayOnboardingHandoffPendingKey, true);
}

Future<void> acknowledgeTodayOnboardingHandoff(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(todayOnboardingHandoffPendingKey, false);
  ref.invalidate(todayOnboardingHandoffPendingProvider);
}

Future<void> clearTodayOnboardingHandoff() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(todayOnboardingHandoffPendingKey);
}
