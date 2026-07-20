import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';

final foodApiServiceProvider = Provider<FoodApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return FoodApiService(dio);
});

class FoodApiResult {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingSize;
  final String servingUnit;
  final String? barcode;

  FoodApiResult({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.servingUnit,
    this.barcode,
  });
}

class FoodApiService {
  final Dio _dio;

  FoodApiService([Dio? dio]) : _dio = dio ?? Dio();

  // 1. Fetch product by barcode (Open Food Facts v2 API)
  Future<FoodApiResult?> fetchByBarcode(String barcode) async {
    try {
      final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'];
          final nutriments = p['nutriments'] ?? {};

          final name = p['product_name'] ?? 'Unknown Product';
          
          // Get values per 100g
          final double kcal = (nutriments['energy-kcal_100g'] ?? 
                               nutriments['energy-kcal'] ?? 0.0).toDouble();
          final double protein = (nutriments['proteins_100g'] ?? 0.0).toDouble();
          final double carbs = (nutriments['carbohydrates_100g'] ?? 0.0).toDouble();
          final double fat = (nutriments['fat_100g'] ?? 0.0).toDouble();

          // Serving size info
          final servingQtyText = p['serving_quantity']?.toString() ?? '100';
          final servingSize = double.tryParse(servingQtyText) ?? 100.0;
          final servingUnit = p['serving_quantity_unit'] ?? 'g';

          return FoodApiResult(
            name: name,
            calories: kcal.round(),
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
            barcode: barcode,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 2. Search products online (Open Food Facts Search API)
  Future<List<FoodApiResult>> searchOnline(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = 'https://world.openfoodfacts.org/cgi/search.pl';
      final response = await _dio.get(url, queryParameters: {
        'search_terms': query,
        'search_simple': 1,
        'action': 'process',
        'json': 1,
        'page_size': 10,
      });

      if (response.statusCode == 200 && response.data != null) {
        final products = response.data['products'] as List?;
        if (products == null) return [];

        return products.map((p) {
          final nutriments = p['nutriments'] ?? {};
          final name = p['product_name'] ?? 'Unknown Product';
          
          final double kcal = (nutriments['energy-kcal_100g'] ?? 0.0).toDouble();
          final double protein = (nutriments['proteins_100g'] ?? 0.0).toDouble();
          final double carbs = (nutriments['carbohydrates_100g'] ?? 0.0).toDouble();
          final double fat = (nutriments['fat_100g'] ?? 0.0).toDouble();

          final servingQtyText = p['serving_quantity']?.toString() ?? '100';
          final servingSize = double.tryParse(servingQtyText) ?? 100.0;
          final servingUnit = p['serving_quantity_unit'] ?? 'g';

          return FoodApiResult(
            name: name,
            calories: kcal.round(),
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
