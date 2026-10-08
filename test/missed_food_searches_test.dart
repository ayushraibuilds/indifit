import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_links.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/food_log/missed_food_searches.dart';
import 'package:indifit/features/food_log/widgets/food_search_results_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CAT-13 (PR-K): "couldn't find it" stays on the phone until sent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MissedFoodSearches store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = MissedFoodSearches(SharedPreferences.getInstance);
  });

  test('newest first, no duplicates, blank refused', () async {
    expect(await store.add('  '), isFalse);
    await store.add('kathal sabzi');
    await store.add('Ragi  dosa');
    await store.add('Kathal Sabzi');
    expect(await store.entries(), ['Kathal Sabzi', 'Ragi dosa']);
  });

  test('keeps at most 30 words of up to 60 characters', () async {
    for (var i = 0; i < 35; i++) {
      await store.add('food $i');
    }
    await store.add('x' * 80);
    final entries = await store.entries();
    expect(entries, hasLength(MissedFoodSearches.maxEntries));
    expect(entries.first, hasLength(MissedFoodSearches.maxLength));
    expect(entries, isNot(contains('food 0')));
  });

  test('clear empties the list', () async {
    await store.add('kathal sabzi');
    await store.clear();
    expect(await store.entries(), isEmpty);
  });

  test('the email holds only the words', () {
    final mail = MissedFoodSearches.email(['kathal sabzi', 'ragi dosa']);
    expect(mail.scheme, 'mailto');
    expect(mail.path, AppLinks.supportEmail);
    expect(
      Uri.decodeComponent(mail.query),
      'subject=Foods I couldn\'t find in IndiFit&body=Please consider '
      'adding these foods:\n\n- kathal sabzi\n- ragi dosa',
    );
  });

  testWidgets('the end of a search offers to add the words', (tester) async {
    var added = 0;
    Future<void> pump({required bool saved}) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: FoodSearchResultsList(
            isOnlineSearchOffline: false,
            searchingOnline: false,
            onRetrySearch: () {},
            searchResults: const [],
            searchResultItemBuilder: (_, _) => const SizedBox(),
            onCreateCustomFood: () {},
            missedQuery: 'kathal sabzi',
            missedQuerySaved: saved,
            onAddMissedQuery: () => added++,
          ),
        ),
      ),
    );

    await pump(saved: false);
    expect(find.text('Can\'t find "kathal sabzi"?'), findsOneWidget);
    await tester.tap(find.text('Add to my list'));
    expect(added, 1);

    await pump(saved: true);
    expect(find.text('Add to my list'), findsNothing);
    expect(find.textContaining('Added to your list'), findsOneWidget);
  });
}
