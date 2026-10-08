import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_links.dart';
import '../../core/di/core_providers.dart';

/// Foods someone searched for and couldn't find (CAT-13).
///
/// Kept only on this phone, and only what the person chose to add from a
/// search. Nothing is sent unless they tap "Send to IndiFit", which opens
/// their own mail app with just these words. Erasing all data clears it.
class MissedFoodSearches {
  MissedFoodSearches(this._prefs);

  final Future<SharedPreferences> Function() _prefs;

  static const key = 'missed_food_searches_v1';
  static const maxEntries = 30;
  static const maxLength = 60;

  /// Newest first.
  Future<List<String>> entries() async {
    final raw = (await _prefs()).getString(key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String) item,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Adds [query] to the top of the list. Returns false when it's blank.
  Future<bool> add(String query) async {
    final text = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return false;
    final clipped = text.length > maxLength
        ? text.substring(0, maxLength)
        : text;
    final current = await entries();
    final next = [
      clipped,
      for (final entry in current)
        if (entry.toLowerCase() != clipped.toLowerCase()) entry,
    ].take(maxEntries).toList(growable: false);
    await (await _prefs()).setString(key, jsonEncode(next));
    return true;
  }

  Future<void> clear() async => (await _prefs()).remove(key);

  /// The mail the person sends themselves: the words, and nothing else.
  static Uri email(List<String> entries) => Uri(
    scheme: 'mailto',
    path: AppLinks.supportEmail,
    query: _encodeQuery({
      'subject': 'Foods I couldn\'t find in IndiFit',
      'body': [
        'Please consider adding these foods:',
        '',
        for (final entry in entries) '- $entry',
      ].join('\n'),
    }),
  );

  // mailto wants %20, not the + that Uri's queryParameters writes.
  static String _encodeQuery(Map<String, String> fields) => fields.entries
      .map((field) => '${field.key}=${Uri.encodeComponent(field.value)}')
      .join('&');
}

final missedFoodSearchesProvider = Provider<MissedFoodSearches>(
  (ref) => MissedFoodSearches(
    () async =>
        sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
        await SharedPreferences.getInstance(),
  ),
);

/// The list as Settings → Food database shows it.
final missedFoodSearchEntriesProvider =
    FutureProvider.autoDispose<List<String>>(
      (ref) => ref.watch(missedFoodSearchesProvider).entries(),
    );
