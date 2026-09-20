import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/capabilities_registry.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/food_log/barcode_scanner_screen.dart';
import 'package:indifit/features/food_log/widgets/remote_food_review_sheet.dart';
import 'package:indifit/features/nutrition/nutrition_providers.dart';

class _MockCatalogCapability implements FoodCatalogCapability {
  _MockCatalogCapability({
    this.cachedCandidate,
    this.remoteCandidate,
    this.shouldThrow = false,
  });

  final RemoteFoodCandidate? cachedCandidate;
  final RemoteFoodCandidate? remoteCandidate;
  final bool shouldThrow;

  int cachedLookupCalls = 0;
  int remoteLookupCalls = 0;

  @override
  Future<RemoteFoodCandidate?> getCachedCandidate(String candidateId) async {
    cachedLookupCalls++;
    if (shouldThrow) throw Exception('Storage failure');
    return cachedCandidate;
  }

  @override
  Future<RemoteFoodCandidate?> lookupByBarcode(String barcode) async {
    remoteLookupCalls++;
    if (shouldThrow) throw Exception('Network timeout');
    return remoteCandidate;
  }

  @override
  Future<void> cacheRemoteCandidate(RemoteFoodCandidate candidate) async {}

  @override
  Future<List<RemoteFoodCandidate>> getRecentCachedCandidates({int limit = 50}) async {
    return const [];
  }

  @override
  Future<FoodSearchPage> searchRemoteFoods(String query, {int page = 1, int pageSize = 20}) async {
    return FoodSearchPage(items: const [], totalCount: 0, page: page, hasMore: false, query: query);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCandidate = RemoteFoodCandidate(
    id: 'off_8901030383704',
    provider: FoodCatalogProvider.openFoodFacts,
    name: 'Amul Taaza Milk',
    brand: 'Amul',
    barcode: '8901030383704',
    category: 'dairy',
    caloriesPer100g: 58.0,
    proteinPer100g: 3.0,
    carbsPer100g: 4.7,
    fatPer100g: 3.0,
    servingOptions: const [
      ServingOption(unitName: 'glass', gramWeight: 200.0, isDefault: true),
    ],
    provenance: FoodProvenance(
      provider: FoodCatalogProvider.openFoodFacts,
      attributionText: 'Source: Open Food Facts (ODbL)',
      license: 'ODbL',
      fetchedAtUtc: DateTime.utc(2026, 9, 3),
    ),
  );

  group('PV1-CATALOG-01C: Barcode Scanner & Catalog Integration', () {
    testWidgets('Local cache hit returns candidate immediately without remote lookup', (tester) async {
      final mockCapability = _MockCatalogCapability(
        cachedCandidate: sampleCandidate,
      );

      RemoteFoodCandidate? returnedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodCatalogCapabilityProvider.overrideWithValue(mockCapability),
            // Fail fast: these paths never reach the user-food lookup.
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
                    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                  );
                  if (res is RemoteFoodCandidate) returnedResult = res;
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      // Open scanner
      await tester.tap(find.text('Open Scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter barcode manually
      await tester.enterText(find.byType(TextField), '8901030383704');
      await tester.tap(find.text('Lookup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that getCachedCandidate was called, but lookupByBarcode was NOT called
      expect(mockCapability.cachedLookupCalls, 1);
      expect(mockCapability.remoteLookupCalls, 0);

      // Verify result popped back
      expect(returnedResult, isNotNull);
      expect(returnedResult!.name, 'Amul Taaza Milk');
      expect(returnedResult!.barcode, '8901030383704');
    });

    testWidgets('Remote lookup hit fetches candidate when missing in local cache', (tester) async {
      final mockCapability = _MockCatalogCapability(
        cachedCandidate: null,
        remoteCandidate: sampleCandidate,
      );

      RemoteFoodCandidate? returnedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodCatalogCapabilityProvider.overrideWithValue(mockCapability),
            // Fail fast: these paths never reach the user-food lookup.
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
                    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                  );
                  if (res is RemoteFoodCandidate) returnedResult = res;
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), '8901030383704');
      await tester.tap(find.text('Lookup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Both cache and remote were checked in order
      expect(mockCapability.cachedLookupCalls, 1);
      expect(mockCapability.remoteLookupCalls, 1);

      expect(returnedResult, isNotNull);
      expect(returnedResult!.name, 'Amul Taaza Milk');
    });

    testWidgets('Unknown barcode displays not-found dialog with custom food option', (tester) async {
      final mockCapability = _MockCatalogCapability(
        cachedCandidate: null,
        remoteCandidate: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodCatalogCapabilityProvider.overrideWithValue(mockCapability),
            // Fail fast: these paths never reach the user-food lookup.
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) => throw StateError('catalog unavailable in test'),
            ),
          ],
          child: const MaterialApp(
            home: BarcodeScannerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), '9999999999999');
      await tester.tap(find.text('Lookup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog is shown
      expect(find.text('Couldn’t find that product'), findsOneWidget);
      expect(find.text('Create Custom Food'), findsOneWidget);
      expect(find.text('Search foods'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Network error displays lookup unavailable dialog', (tester) async {
      final mockCapability = _MockCatalogCapability(
        shouldThrow: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodCatalogCapabilityProvider.overrideWithValue(mockCapability),
            // Fail fast: these paths never reach the user-food lookup.
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) => throw StateError('catalog unavailable in test'),
            ),
          ],
          child: const MaterialApp(
            home: BarcodeScannerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), '8901030383704');
      await tester.tap(find.text('Lookup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify failure dialog
      expect(find.text('Barcode Lookup Unavailable'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Scanned candidate opens RemoteFoodReviewSheet with Indian portions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RemoteFoodReviewSheet.show(
                    context: context,
                    candidate: sampleCandidate,
                    mealType: 'lunch',
                    selectedDate: DateTime(2026, 9, 3),
                    onConfirm: ({
                      required RemoteFoodCandidate candidate,
                      required double quantity,
                      required ServingOption servingOption,
                      required bool logImmediately,
                    }) async {},
                  );
                },
                child: const Text('Open Review'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Review'));
      await tester.pumpAndSettle();

      expect(find.text('Amul Taaza Milk'), findsOneWidget);
      expect(find.text('Source: Open Food Facts (ODbL)'), findsOneWidget);
      expect(find.text('Balanced macros (4-4-9 verified)'), findsOneWidget);
      expect(find.text('glass (200ml)'), findsOneWidget);
      expect(find.text('Save to My Foods'), findsOneWidget);
      expect(find.text('Log Lunch'), findsOneWidget);
    });

    testWidgets('Rescan of a barcode-tagged custom food pops the saved option', (
      tester,
    ) async {
      final mockCapability = _MockCatalogCapability(
        cachedCandidate: null,
        remoteCandidate: null,
      );

      Object? returnedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodCatalogCapabilityProvider.overrideWithValue(mockCapability),
            nutritionFoodCatalogRepositoryProvider.overrideWith((ref) async {
              final db = AppDatabase.memory();
              ref.onDispose(db.close);
              final repo = NutritionFoodCatalogRepository(
                db: db,
                registry: NutrientRegistry.fromAssetFileSync(
                  'assets/data/nutrient_registry.json',
                ),
              );
              await repo.createUserFood(
                displayName: 'Rescan Protein Bar',
                servingSize: 1,
                servingUnit: 'bar',
                energyKcal: 250,
                proteinG: 20,
                carbohydrateG: 22,
                fatG: 8,
                barcode: '8901030383704',
              );
              return repo;
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await Navigator.push<Object?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BarcodeScannerScreen(),
                    ),
                  );
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Warm the overridden catalog on the real async zone so the
      // barcode fixture is committed before the scan reads it.
      await tester.runAsync(() async {
        final container = ProviderScope.containerOf(
          tester.element(find.text('Scan Food Barcode')),
        );
        final repo = await container.read(
          nutritionFoodCatalogRepositoryProvider.future,
        );
        final seeded = await repo.findUserFoodByBarcode('8901030383704');
        expect(seeded?.displayName, 'Rescan Protein Bar');
      });

      // The user-food lookup touches real sqlite: run it on the real
      // async zone so FakeAsync never gates catalog init, and settle
      // there so the pop delivering the option completes first.
      await tester.runAsync(() async {
        await tester.enterText(find.byType(TextField), '8901030383704');
        await tester.tap(find.text('Lookup'));
        await tester.pumpAndSettle();
      });

      // Remote was never consulted: the user-food lookup resolved first.
      expect(mockCapability.remoteLookupCalls, 0);
      await tester.pump();
      expect(returnedResult, isA<NutritionFoodOption>());
      expect(
        (returnedResult as NutritionFoodOption).displayName,
        'Rescan Protein Bar',
      );
    });
  });
}
