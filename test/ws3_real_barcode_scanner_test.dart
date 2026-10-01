import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/capabilities_registry.dart';
import 'package:indifit/features/food_log/barcode_scanner_screen.dart';
import 'package:indifit/features/food_log/widgets/food_search_recent_list.dart';
import 'package:indifit/features/nutrition/nutrition_providers.dart';

import 'support/fake_mobile_scanner.dart';

class _FakeCatalogCapability implements FoodCatalogCapability {
  RemoteFoodCandidate? foundCandidate;

  @override
  Future<RemoteFoodCandidate?> getCachedCandidate(String candidateId) async =>
      foundCandidate;

  @override
  Future<RemoteFoodCandidate?> lookupByBarcode(String barcode) async =>
      foundCandidate;

  @override
  Future<void> cacheRemoteCandidate(RemoteFoodCandidate candidate) async {}

  @override
  Future<List<RemoteFoodCandidate>> getRecentCachedCandidates({
    int limit = 50,
  }) async => const [];

  @override
  Future<FoodSearchPage> searchRemoteFoods(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async => FoodSearchPage(
    items: const [],
    totalCount: 0,
    page: page,
    hasMore: false,
    query: query,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WS3: Real Barcode Scanner & Offline Behaviour', () {
    testWidgets(
      'BarcodeScannerScreen detects simulated barcode via fake seam',
      (tester) async {
        final fakeCatalog = _FakeCatalogCapability()
          ..foundCandidate = RemoteFoodCandidate(
            id: 'fake_123',
            provider: FoodCatalogProvider.openFoodFacts,
            name: 'Simulated Amul Butter',
            category: 'dairy',
            barcode: '8901030383704',
            caloriesPer100g: 720,
            proteinPer100g: 0.5,
            carbsPer100g: 0.5,
            fatPer100g: 80,
            servingOptions: const [],
            provenance: FoodProvenance(
              provider: FoodCatalogProvider.openFoodFacts,
              attributionText: 'Open Food Facts',
              license: 'ODbL',
              fetchedAtUtc: DateTime.utc(2026, 10, 1),
            ),
          );

        RemoteFoodCandidate? result;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              barcodeScannerViewBuilderProvider.overrideWithValue(
                fakeMobileScannerViewBuilder,
              ),
              foodCatalogCapabilityProvider.overrideWithValue(fakeCatalog),
              nutritionFoodCatalogRepositoryProvider.overrideWith(
                (ref) => throw StateError('catalog unavailable in test'),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final res = await Navigator.push<Object?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BarcodeScannerScreen(),
                      ),
                    );
                    if (res is RemoteFoodCandidate) result = res;
                  },
                  child: const Text('Launch Scanner'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Launch Scanner'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const ValueKey('fake_mobile_scanner')),
          findsOneWidget,
        );

        // Tap the simulated scan trigger
        await tester.tap(
          find.byKey(const ValueKey('simulate_barcode_detection')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(result, isNotNull);
        expect(result!.name, equals('Simulated Amul Butter'));
      },
    );

    testWidgets(
      'FoodSearchRecentList disables barcode lookup with explanation when offline',
      (tester) async {
        bool barcodeTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FoodSearchRecentList(
                loadingRecent: false,
                onRetryRecent: () {},
                canonicalRecentResults: const [],
                recentResults: const [],
                canonicalRecentItemBuilder: (context, recent) => const SizedBox(),
                recentItemBuilder: (context, food) => const SizedBox(),
                onOpenSavedMeals: () {},
                onOpenSavedRecipes: () {},
                onOpenBarcode: () {
                  barcodeTapped = true;
                },
                isOpenFoodFactsAllowed: false,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Turn off Offline Mode to look up packaged foods'),
          findsOneWidget,
        );

        // Tapping the card when disabled should not invoke onOpenBarcode
        await tester.tap(
          find.text('Turn off Offline Mode to look up packaged foods'),
        );
        expect(barcodeTapped, isFalse);
      },
    );
  });
}
