import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/catalog/food_catalog_models.dart';
import 'package:indifit/core/catalog/food_catalog_service.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/repositories/food_api_service.dart';
import 'package:indifit/features/food_log/widgets/remote_food_review_sheet.dart';

class _FakeFoodApiService extends FoodApiService {
  _FakeFoodApiService({this.searchResults = const [], this.barcodeProduct});

  final List<FoodApiResult> searchResults;
  final FoodApiResult? barcodeProduct;

  @override
  Future<List<FoodApiResult>> searchOnline(String query, {dynamic cancelToken}) async {
    return searchResults;
  }

  @override
  Future<FoodApiResult?> fetchByBarcode(String barcode) async {
    return barcodeProduct;
  }
}

void main() {
  group('PV1-CATALOG-01B: FoodCatalogService & Review Sheet Contracts', () {
    test('FoodCatalogService adapts raw results and synthesizes Indian serving options', () async {
      final fakeApi = _FakeFoodApiService(
        searchResults: [
          FoodApiResult(
            name: 'Tata Sampann Moong Dal',
            calories: 345.0,
            protein: 24.0,
            carbs: 60.0,
            fat: 1.0,
            servingSize: 30.0,
            servingUnit: 'g',
            barcode: '8901234567890',
            brand: 'Tata Sampann',
          ),
          FoodApiResult(
            name: 'Amul Taaza Milk',
            calories: 58.0,
            protein: 3.0,
            carbs: 4.7,
            fat: 3.0,
            servingSize: 200.0,
            servingUnit: 'ml',
            barcode: '8901030383704',
            brand: 'Amul',
          ),
        ],
      );

      final service = FoodCatalogService(foodApiService: fakeApi);

      final page = await service.searchRemoteFoods('dal');
      expect(page.items, hasLength(2));

      final dal = page.items.first;
      expect(dal.name, 'Tata Sampann Moong Dal');
      expect(dal.brand, 'Tata Sampann');
      expect(dal.category, 'dal');
      expect(dal.provenance.license, 'ODbL');

      // Synthesized Indian options per CATALOG01A §5 exact names.
      final servingUnits = dal.servingOptions.map((s) => s.unitName).toList();
      expect(servingUnits, contains('katori'));
      expect(servingUnits, contains('serving_bowl'));

      final milk = page.items.last;
      expect(milk.category, 'dairy');
      final milkUnits = milk.servingOptions.map((s) => s.unitName).toList();
      expect(milkUnits, contains('glass'));
    });

    test('FoodCatalogService respects offline privacy policy fail-closed', () async {
      final fakeApi = _FakeFoodApiService(
        searchResults: [
          FoodApiResult(
            name: 'Item',
            calories: 100.0,
            protein: 5.0,
            carbs: 10.0,
            fat: 2.0,
            servingSize: 100.0,
            servingUnit: 'g',
            barcode: '123',
          ),
        ],
      );

      const offlinePolicy = PrivacyPolicy(
        isOfflineOnly: true,
        isTelemetryEnabled: false,
      );

      final service = FoodCatalogService(
        foodApiService: fakeApi,
        privacyPolicy: offlinePolicy,
      );

      final page = await service.searchRemoteFoods('test');
      expect(page.items, isEmpty);
      expect(page.totalCount, 0);

      final barcodeItem = await service.lookupByBarcode('123');
      expect(barcodeItem, isNull);
    });

    test('FoodCatalogService lookupByBarcode retrieves and caches product', () async {
      final fakeApi = _FakeFoodApiService(
        barcodeProduct: FoodApiResult(
          name: 'Haldiram Bhujia',
          calories: 560.0,
          protein: 12.0,
          carbs: 42.0,
          fat: 38.0,
          servingSize: 30.0,
          servingUnit: 'g',
          barcode: '8901234567899',
          brand: 'Haldiram',
        ),
      );

      final service = FoodCatalogService(foodApiService: fakeApi);

      final product = await service.lookupByBarcode('8901234567899');
      expect(product, isNotNull);
      expect(product!.name, 'Haldiram Bhujia');
      expect(product.brand, 'Haldiram');

      // Cached lookup returns instantly
      final cached = await service.getCachedCandidate('off_8901234567899');
      expect(cached, isNotNull);
      expect(cached!.name, 'Haldiram Bhujia');
    });

    testWidgets('RemoteFoodReviewSheet renders macro discrepancy warning when unbalanced', (tester) async {
      // Discrepant candidate: 500 kcal reported vs 4*2 + 4*5 + 9*1 = 37 kcal expected
      final candidate = RemoteFoodCandidate(
        id: 'off_discrepant_1',
        provider: FoodCatalogProvider.openFoodFacts,
        name: 'Faulty Biscuit Pack',
        brand: 'Unknown Brand',
        barcode: '8909999999999',
        category: 'snack',
        caloriesPer100g: 500.0,
        proteinPer100g: 2.0,
        carbsPer100g: 5.0,
        fatPer100g: 1.0,
        servingOptions: const [
          ServingOption(unitName: 'piece', gramWeight: 15.0, isDefault: true),
        ],
        provenance: FoodProvenance(
          provider: FoodCatalogProvider.openFoodFacts,
          attributionText: 'Source: Open Food Facts (ODbL)',
          license: 'ODbL',
          fetchedAtUtc: DateTime.utc(2026, 9, 3),
        ),
      );

      var confirmed = false;
      var loggedImmediately = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteFoodReviewSheet(
              candidate: candidate,
              mealType: 'snack',
              selectedDate: DateTime(2026, 9, 3),
              onConfirm: ({
                required RemoteFoodCandidate candidate,
                required double quantity,
                required ServingOption servingOption,
                required bool logImmediately,
              }) async {
                confirmed = true;
                loggedImmediately = logImmediately;
              },
            ),
          ),
        ),
      );

      // Verify Title and Brand
      expect(find.text('Faulty Biscuit Pack'), findsOneWidget);
      expect(find.text('Unknown Brand'), findsOneWidget);

      // Verify Source attribution badge
      expect(find.text('Source: Open Food Facts (ODbL)'), findsOneWidget);

      // Verify Macro Discrepancy warning banner
      expect(find.text('Macro Discrepancy Flag'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Tap "Save to My Foods" (scroll into view: sheet now scrolls with
      // correction fields).
      await tester.ensureVisible(find.text('Save to My Foods'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to My Foods'));
      await tester.pump();

      expect(confirmed, isTrue);
      expect(loggedImmediately, isFalse);
    });

    testWidgets('RemoteFoodReviewSheet renders balanced badge and logs immediately', (tester) async {
      // Balanced candidate: 58 kcal, 3.0g P, 4.7g C, 3.0g F (expected 57.8 kcal)
      final candidate = RemoteFoodCandidate(
        id: 'off_balanced_1',
        provider: FoodCatalogProvider.openFoodFacts,
        name: 'Amul Taaza Toned Milk',
        brand: 'Amul',
        barcode: '8901030383704',
        category: 'dairy',
        caloriesPer100g: 58.0,
        proteinPer100g: 3.0,
        carbsPer100g: 4.7,
        fatPer100g: 3.0,
        servingOptions: const [
          ServingOption(unitName: 'glass', gramWeight: 200.0, isDefault: true),
          ServingOption(unitName: '100ml', gramWeight: 103.0),
        ],
        provenance: FoodProvenance(
          provider: FoodCatalogProvider.openFoodFacts,
          attributionText: 'Source: Open Food Facts (ODbL)',
          license: 'ODbL',
          fetchedAtUtc: DateTime.utc(2026, 9, 3),
        ),
      );

      var loggedImmediately = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteFoodReviewSheet(
              candidate: candidate,
              mealType: 'breakfast',
              selectedDate: DateTime(2026, 9, 3),
              onConfirm: ({
                required RemoteFoodCandidate candidate,
                required double quantity,
                required ServingOption servingOption,
                required bool logImmediately,
              }) async {
                loggedImmediately = logImmediately;
              },
            ),
          ),
        ),
      );

      // Verify balanced badge
      expect(find.text('Balanced macros (4-4-9 verified)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Verify log button label
      expect(find.text('Log BREAKFAST'), findsOneWidget);

      // Tap Log (scroll into view: sheet now scrolls with correction fields).
      await tester.ensureVisible(find.text('Log BREAKFAST'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log BREAKFAST'));
      await tester.pump();

      expect(loggedImmediately, isTrue);
    });
  });
}
