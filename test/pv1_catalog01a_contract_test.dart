import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/food_catalog_capability.dart';
import 'package:indifit/core/catalog/food_catalog_models.dart';

void main() {
  group('PV1-CATALOG-01A: Remote Food Catalog & Provenance Contracts', () {
    group('Atwater 4-4-9 Macro Sanity Validation', () {
      test('Accurately reported food item passes macro balance check', () {
        // Amul Taaza Milk: 58 kcal, 3.0g P, 4.7g C, 3.0g F per 100g
        // Expected: (4*3.0) + (4*4.7) + (9*3.0) = 12 + 18.8 + 27 = 57.8 kcal
        final milk = RemoteFoodCandidate(
          id: 'off_8901030383704',
          provider: FoodCatalogProvider.openFoodFacts,
          providerId: '8901030383704',
          name: 'Amul Taaza Toned Milk',
          category: 'dairy',
          caloriesPer100g: 58.0,
          proteinPer100g: 3.0,
          carbsPer100g: 4.7,
          fatPer100g: 3.0,
          fiberPer100g: 0.0,
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

        expect(milk.isMacroBalanced, isTrue);
        expect(milk.isPhysicallyPossible, isTrue);
        expect(milk.expectedCaloriesPer100g, closeTo(57.8, 0.1));
      });

      test('Discrepant crowdsourced macros fail balance check with warning flag', () {
        // Typo item: User entered 500 kcal but macros are 2g P, 5g C, 1g F (expected 37 kcal)
        final bogusCandidate = RemoteFoodCandidate(
          id: 'off_bogus_123',
          provider: FoodCatalogProvider.openFoodFacts,
          name: 'Suspicious Biscuit',
          category: 'snacks',
          caloriesPer100g: 500.0,
          proteinPer100g: 2.0,
          carbsPer100g: 5.0,
          fatPer100g: 1.0,
          servingOptions: const [],
          provenance: FoodProvenance(
            provider: FoodCatalogProvider.openFoodFacts,
            attributionText: 'Source: Open Food Facts (ODbL)',
            license: 'ODbL',
            fetchedAtUtc: DateTime.utc(2026, 9, 3),
          ),
        );

        expect(bogusCandidate.isMacroBalanced, isFalse,
            reason: 'Reported 500 kcal vs expected 37 kcal must trigger warning');
        expect(bogusCandidate.isPhysicallyPossible, isTrue);
      });

      test('Chemically impossible macros exceeding 105g/100g fail physical bounds', () {
        // Impossible item: 80g P + 40g C + 20g F = 140g per 100g product
        final impossibleCandidate = RemoteFoodCandidate(
          id: 'off_impossible_456',
          provider: FoodCatalogProvider.openFoodFacts,
          name: 'Impossible Protein Bar',
          category: 'supplements',
          caloriesPer100g: 660.0,
          proteinPer100g: 80.0,
          carbsPer100g: 40.0,
          fatPer100g: 20.0,
          servingOptions: const [],
          provenance: FoodProvenance(
            provider: FoodCatalogProvider.openFoodFacts,
            attributionText: 'Source: Open Food Facts (ODbL)',
            license: 'ODbL',
            fetchedAtUtc: DateTime.utc(2026, 9, 3),
          ),
        );

        expect(impossibleCandidate.isPhysicallyPossible, isFalse);
      });
    });

    group('Indian Culinary Serving Unit Conversions', () {
      test('Katori portion accurately computes scaled nutrition', () {
        // Dal Tadka per 100g: 110 kcal, 6g P, 14g C, 3.5g F
        final dal = RemoteFoodCandidate(
          id: 'ifct_dal_tadka',
          provider: FoodCatalogProvider.ifct,
          name: 'Yellow Dal Tadka',
          nameHindi: 'दाल तड़का',
          category: 'dal',
          caloriesPer100g: 110.0,
          proteinPer100g: 6.0,
          carbsPer100g: 14.0,
          fatPer100g: 3.5,
          fiberPer100g: 2.5,
          servingOptions: const [
            ServingOption(unitName: 'katori', gramWeight: 150.0, isDefault: true),
            ServingOption(unitName: 'bowl', gramWeight: 300.0),
          ],
          provenance: FoodProvenance(
            provider: FoodCatalogProvider.ifct,
            attributionText: 'ICMR-NIN Indian Food Composition Tables 2017',
            license: 'Government Open Data',
            fetchedAtUtc: DateTime.utc(2026, 9, 3),
          ),
          verificationLevel: FoodVerificationLevel.governmentStandard,
        );

        // 1 standard katori = 150g (factor 1.5x)
        final katoriNutrients = dal.calculateNutrientsFor(quantity: 1.0, unitName: 'katori');
        expect(katoriNutrients['calories'], closeTo(165.0, 0.01));
        expect(katoriNutrients['protein'], closeTo(9.0, 0.01));
        expect(katoriNutrients['carbs'], closeTo(21.0, 0.01));
        expect(katoriNutrients['fat'], closeTo(5.25, 0.01));
        expect(katoriNutrients['fiber'], closeTo(3.75, 0.01));

        // 2 bowls = 600g (factor 6.0x)
        final bowlsNutrients = dal.calculateNutrientsFor(quantity: 2.0, unitName: 'bowl');
        expect(bowlsNutrients['calories'], closeTo(660.0, 0.01));
        expect(bowlsNutrients['protein'], closeTo(36.0, 0.01));
      });

      test('Roti piece accurately computes multi-unit intake', () {
        // Phulka Roti per 100g: 260 kcal, 9g P, 54g C, 1.5g F
        // 1 medium roti = 35g
        final roti = RemoteFoodCandidate(
          id: 'ifct_phulka_roti',
          provider: FoodCatalogProvider.ifct,
          name: 'Whole Wheat Roti / Phulka',
          nameHindi: 'गेहूं की रोटी / फुल्का',
          category: 'roti',
          caloriesPer100g: 260.0,
          proteinPer100g: 9.0,
          carbsPer100g: 54.0,
          fatPer100g: 1.5,
          servingOptions: const [
            ServingOption(unitName: 'piece', gramWeight: 35.0, isDefault: true),
          ],
          provenance: FoodProvenance(
            provider: FoodCatalogProvider.ifct,
            attributionText: 'ICMR-NIN IFCT 2017',
            license: 'Government Open Data',
            fetchedAtUtc: DateTime.utc(2026, 9, 3),
          ),
        );

        // 3 rotis = 105g (factor 1.05x)
        final nutrients = roti.calculateNutrientsFor(quantity: 3.0, unitName: 'piece');
        expect(nutrients['calories'], closeTo(273.0, 0.01));
        expect(nutrients['protein'], closeTo(9.45, 0.01));
        expect(nutrients['carbs'], closeTo(56.7, 0.01));
      });
    });

    group('Provenance, Licensing & Serialization', () {
      test('RemoteFoodCandidate serializes to JSON and round-trips exactly', () {
        final original = RemoteFoodCandidate(
          id: 'indifit_paneer_tikka',
          provider: FoodCatalogProvider.indifitCloud,
          name: 'Paneer Tikka (Grilled)',
          nameHindi: 'पनीर टिक्का',
          brand: 'IndiFit Kitchen',
          barcode: '8901234567890',
          category: 'snack',
          caloriesPer100g: 240.0,
          proteinPer100g: 16.0,
          carbsPer100g: 8.0,
          fatPer100g: 16.0,
          fiberPer100g: 2.0,
          servingOptions: const [
            ServingOption(unitName: 'plate', gramWeight: 180.0, isDefault: true),
          ],
          provenance: FoodProvenance(
            provider: FoodCatalogProvider.indifitCloud,
            attributionText: 'IndiFit Verified Nutrition Database',
            license: 'Proprietary',
            sourceUrl: 'https://indifit.app/nutrition/paneer-tikka',
            fetchedAtUtc: DateTime.utc(2026, 9, 3, 12, 0),
          ),
          verificationLevel: FoodVerificationLevel.expertVerified,
        );

        final json = original.toJson();
        final reconstructed = RemoteFoodCandidate.fromJson(json);

        expect(reconstructed.id, original.id);
        expect(reconstructed.provider, original.provider);
        expect(reconstructed.name, original.name);
        expect(reconstructed.nameHindi, original.nameHindi);
        expect(reconstructed.brand, original.brand);
        expect(reconstructed.barcode, original.barcode);
        expect(reconstructed.caloriesPer100g, original.caloriesPer100g);
        expect(reconstructed.servingOptions, equals(original.servingOptions));
        expect(reconstructed.provenance, equals(original.provenance));
        expect(reconstructed.verificationLevel, original.verificationLevel);
      });

      test('FoodSearchPage envelope maintains pagination metadata', () {
        final page = FoodSearchPage(
          items: const [],
          totalCount: 42,
          page: 2,
          hasMore: true,
          query: 'paneer',
        );

        final json = page.toJson();
        final parsed = FoodSearchPage.fromJson(json);

        expect(parsed.totalCount, 42);
        expect(parsed.page, 2);
        expect(parsed.hasMore, isTrue);
        expect(parsed.query, 'paneer');
      });
    });

    group('Capability Contract & Offline Fallback', () {
      test('DisabledFoodCatalogCapability safely returns empty results without network', () async {
        const capability = DisabledFoodCatalogCapability();

        final searchResult = await capability.searchRemoteFoods('biryani');
        expect(searchResult.items, isEmpty);
        expect(searchResult.hasMore, isFalse);
        expect(searchResult.totalCount, 0);

        final barcodeResult = await capability.lookupByBarcode('8901030383704');
        expect(barcodeResult, isNull);

        final cachedList = await capability.getRecentCachedCandidates();
        expect(cachedList, isEmpty);
      });
    });
  });
}
