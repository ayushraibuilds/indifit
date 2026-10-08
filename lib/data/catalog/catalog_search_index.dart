import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../services/food_name_spelling.dart';
import '../services/nutrition_food_search_ranking.dart';

/// One catalogue food found by [CatalogSearchIndex.search].
class CatalogSearchHit {
  const CatalogSearchHit({
    required this.foodId,
    required this.legacyFoodItemId,
    required this.matchedTerms,
  });

  final String foodId;

  /// The `food_items` row the food screen lists and logs, when one exists.
  final int? legacyFoodItemId;

  /// Words that matched other than the food's name: its aliases ("arhar
  /// dal" for Toor Dal), and any typed word the index corrected ("chapti"
  /// for Chapati). The screen's ranking reads these so it keeps the hit.
  final List<String> matchedTerms;
}

/// On-device full-text search over the catalogue (CAT-9).
///
/// An FTS5 index of every active catalogue food's name and pack aliases,
/// with prefix matching and a small typo fallback. It is a derived cache:
/// built from `nutrition_foods` and `nutrition_food_aliases` when empty and
/// after each pack import, never backed up, and safe to drop at any time.
class CatalogSearchIndex {
  CatalogSearchIndex(this._db);

  final AppDatabase _db;

  static const table = 'catalog_food_fts';
  static const _vocabulary = 'catalog_food_fts_vocab';

  /// Indexed text uses the ranking's normaliser plus the everyday spelling
  /// folds ("sabzi" → "sabji"), so queries and index agree.
  static String normalize(String text) =>
      foldFoodSpellings(NutritionFoodSearchVocabulary.normalize(text));

  /// Creates the index if it's missing and fills it if it's empty.
  Future<void> ensure() async {
    await _db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS $table USING fts5('
      "food_id UNINDEXED, name, aliases, tokenize = 'unicode61', "
      "prefix = '2 3')",
    );
    await _db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS $_vocabulary '
      "USING fts5vocab($table, 'row')",
    );
    final count = await _db
        .customSelect('SELECT count(*) AS n FROM $table')
        .getSingle();
    if (count.read<int>('n') == 0) await rebuild();
  }

  /// Replaces the index with the active catalogue foods and their aliases.
  Future<void> rebuild() async {
    final foods = await _db
        .customSelect(
          'SELECT id, display_name FROM nutrition_foods '
          "WHERE lifecycle = 'active' "
          "AND source_type IN ('bundled_asset', 'regional_asset')",
        )
        .get();
    final aliases = <String, List<String>>{};
    for (final row
        in await _db
            .customSelect(
              'SELECT food_id, alias FROM nutrition_food_aliases '
              'WHERE is_active = 1 AND food_id IS NOT NULL',
            )
            .get()) {
      (aliases[row.read<String>('food_id')] ??= []).add(
        row.read<String>('alias'),
      );
    }
    final rows = [
      for (final food in foods)
        [
          food.read<String>('id'),
          normalize(food.read<String>('display_name')),
          normalize((aliases[food.read<String>('id')] ?? const []).join(' ')),
        ],
    ];
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM $table');
      if (rows.isEmpty) return;
      await _db.customStatement(
        'INSERT INTO $table (food_id, name, aliases) '
        "SELECT json_extract(value, '\$[0]'), json_extract(value, '\$[1]'), "
        "json_extract(value, '\$[2]') FROM json_each(?1)",
        [jsonEncode(rows)],
      );
    });
    _terms = null;
  }

  List<String>? _terms;

  /// Catalogue foods matching [query], best first. Every word must match
  /// the start of a word in the name or aliases; a word that matches
  /// nothing is retried as the closest indexed word (one edit, two for
  /// longer words).
  Future<List<CatalogSearchHit>> search(String query, {int limit = 60}) async {
    final tokens = normalize(
      query,
    ).split(' ').where((token) => token.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) return const [];

    final corrections = <String, Set<String>>{};
    for (final token in tokens) {
      if (token.length < 4 || await _hasPrefix(token)) continue;
      final close = await _closeTerms(token);
      if (close.isNotEmpty) corrections[token] = close;
    }
    final match = tokens
        .map((token) {
          final options = {token, ...?corrections[token]};
          final terms = options.map((term) => '"$term"*').join(' OR ');
          return options.length == 1 ? terms : '($terms)';
        })
        .join(' AND ');

    final rows = await _db
        .customSelect(
          'SELECT f.food_id AS food_id, f.aliases AS aliases, '
          'm.legacy_food_item_id AS legacy_id '
          'FROM $table f '
          'LEFT JOIN nutrition_legacy_food_mappings m ON m.food_id = f.food_id '
          'WHERE $table MATCH ? '
          'ORDER BY bm25($table, 0.0, 10.0, 4.0) LIMIT ?',
          variables: [Variable.withString(match), Variable.withInt(limit)],
        )
        .get();
    final typed = corrections.keys.toList(growable: false);
    final seen = <String>{};
    return [
      for (final row in rows)
        if (seen.add(row.read<String>('food_id')))
          CatalogSearchHit(
            foodId: row.read<String>('food_id'),
            legacyFoodItemId: row.read<int?>('legacy_id'),
            matchedTerms: [
              if ((row.read<String?>('aliases') ?? '').isNotEmpty)
                row.read<String>('aliases'),
              ...typed,
            ],
          ),
    ];
  }

  Future<bool> _hasPrefix(String token) async {
    final terms = await _vocabularyTerms();
    return terms.any((term) => term.startsWith(token));
  }

  Future<Set<String>> _closeTerms(String token) async {
    final budget = token.length >= 7 ? 2 : 1;
    return {
      for (final term in await _vocabularyTerms())
        if ((term.length - token.length).abs() <= budget &&
            _editDistance(token, term, budget) <= budget)
          term,
    };
  }

  Future<List<String>> _vocabularyTerms() async => _terms ??= [
    for (final row
        in await _db.customSelect('SELECT term FROM $_vocabulary').get())
      row.read<String>('term'),
  ];

  /// Optimal string alignment distance, stopping early past [budget].
  static int _editDistance(String a, String b, int budget) {
    final previous = List<int>.generate(b.length + 1, (i) => i);
    var beforePrevious = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var value = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1] &&
            beforePrevious[j - 2] + 1 < value) {
          value = beforePrevious[j - 2] + 1;
        }
        current[j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > budget) return budget + 1;
      beforePrevious = List.of(previous);
      previous.setAll(0, current);
    }
    return previous[b.length];
  }
}
